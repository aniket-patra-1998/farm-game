"""A small software renderer for previews: the finished look (two-tone light, rim, outline, ground shadow), sheets and labels."""
import numpy as np
import math
import sys
from PIL import Image
from PIL import ImageDraw
from scipy import ndimage
from .geometry import view_rot
from .build import build
from .look import BG, LIT_COL, SHADE_COL, bake
from .registry import MADE


def extent(a, yaw, pitch=0.5):
    P = a["V"] @ view_rot(yaw, pitch).T; d = P.max(0) - P.min(0)
    return max(d[0], d[1])


def paint(a, yaw, pitch=0.5, size=640, baked=True, fancy=True, span=None, center=None, V=None, vn=None, rim=0.3, step_k=0.03, ink=1.0):
    """`V` and `vn` draw the animal in a pose (same triangles, moved points); `center` holds the camera still.
    `rim` is the strength of the rim of light (0: matte, for plants); `step_k` is how big a jump in depth, as a share of
    the picture's span, draws an inner outline (higher: fewer inner lines); `ink` is how dark the outline is."""
    V = a["V"] if V is None else V; vn = a["vn"] if vn is None else vn
    T, cols, nb = a["T"], a["C"], a["nbody"]
    Bk = a["bake"] if baked else np.ones((len(V), 3))
    R = view_rot(yaw, pitch); P = V @ R.T
    lo, hi = P.min(0), P.max(0); c = (lo + hi) / 2
    if span is None:
        span = max(hi[0] - lo[0], hi[1] - lo[1]) * 1.3
    else:
        c[1] = lo[1] + 0.36 * span        # a shared scale: every animal stands on the same line in its tile
    if center is not None:
        c = np.array(center, float)
    sx = lambda Q: (Q[:, 0] - c[0]) / span * size + size / 2
    sy = lambda Q: size / 2 - (Q[:, 1] - c[1]) / span * size
    X, Y, Z = sx(P), sy(P), P[:, 2]
    img = np.zeros((size, size, 3), np.float32) + BG
    zb = np.full((size, size), -1e9, np.float32)
    L = np.array([-0.35, 0.8, 0.5]); L = L / np.linalg.norm(L)
    VN = vn @ R.T
    if fancy:
        # a soft shadow on the ground, straight under the animal
        G = V[:a["nsoft"]].copy(); G[:, 1] = 0.0; Gp = G @ R.T
        sh = np.zeros((size, size), np.float32)
        gx, gy = np.clip(sx(Gp).astype(int), 0, size - 1), np.clip(sy(Gp).astype(int), 0, size - 1); sh[gy, gx] = 1
        sh = ndimage.gaussian_filter(ndimage.binary_dilation(sh > 0, iterations=max(3, size // 120)).astype(np.float32), size / 80)
        img *= (1 - 0.36 * np.clip(sh * 1.3, 0, 1) ** 1.5)[..., None]
    for ti, (t, col) in enumerate(zip(T, cols)):
        p0, p1, p2 = P[t[0]], P[t[1]], P[t[2]]
        n = np.cross(p1 - p0, p2 - p0); ln = np.linalg.norm(n)
        if ln < 1e-12:
            continue
        n = n / ln
        if n[2] < 0:
            n = -n
        x0, x1, x2 = X[t]; y0, y1, y2 = Y[t]; z0, z1, z2 = Z[t]
        mnx, mxx = int(max(0, math.floor(min(x0, x1, x2)))), int(min(size - 1, math.ceil(max(x0, x1, x2))))
        mny, mxy = int(max(0, math.floor(min(y0, y1, y2)))), int(min(size - 1, math.ceil(max(y0, y1, y2))))
        if mnx > mxx or mny > mxy:
            continue
        gx, gy = np.meshgrid(np.arange(mnx, mxx + 1) + 0.5, np.arange(mny, mxy + 1) + 0.5)
        den = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2)
        if abs(den) < 1e-9:
            continue
        w0 = ((y1 - y2) * (gx - x2) + (x2 - x1) * (gy - y2)) / den
        w1 = ((y2 - y0) * (gx - x2) + (x0 - x2) * (gy - y2)) / den
        w2 = 1 - w0 - w1
        z = w0 * z0 + w1 * z1 + w2 * z2
        m = (w0 >= -1e-4) & (w1 >= -1e-4) & (w2 >= -1e-4) & (z > zb[mny:mxy + 1, mnx:mxx + 1])
        if not m.any():
            continue
        zb[mny:mxy + 1, mnx:mxx + 1][m] = z[m]
        base = np.array(col, np.float32) * 255
        if ti >= nb:                      # a drawing on the surface (eye, mouth): flat and bright
            sh_ = (0.55 + 0.45 * max(0.0, float(n @ L))) if not fancy else 0.97
            img[mny:mxy + 1, mnx:mxx + 1][m] = base * sh_
            continue
        nn = w0[..., None] * VN[t[0]] + w1[..., None] * VN[t[1]] + w2[..., None] * VN[t[2]]
        nn = nn * np.where(nn[..., 2:3] < 0, -1.0, 1.0)
        nn = 0.7 * nn / np.maximum(np.linalg.norm(nn, axis=2, keepdims=True), 1e-9) + 0.3 * n
        nn = nn / np.maximum(np.linalg.norm(nn, axis=2, keepdims=True), 1e-9)
        bk = w0[..., None] * Bk[t[0]] + w1[..., None] * Bk[t[1]] + w2[..., None] * Bk[t[2]]
        ndl = nn @ L
        if fancy:
            s_ = np.clip((ndl + 0.05) / 0.5, 0, 1); s_ = s_ * s_ * (3 - 2 * s_)
            # two tones with a soft edge between them: a warm lit side and a cool shadow side, as a painter would
            tone = SHADE_COL[None, None, :] + (LIT_COL - SHADE_COL)[None, None, :] * s_[..., None]
            px = base[None, None, :] * bk * tone
            glow = np.clip(1 - nn[..., 2], 0, 1) ** 3 * np.clip(0.55 + 0.45 * nn[..., 1], 0, 1) * rim
            px = px + glow[..., None] * np.array([255, 246, 222], np.float32)
        else:
            px = base[None, None, :] * bk * (0.55 + 0.45 * np.maximum(0.0, ndl))[..., None]
        img[mny:mxy + 1, mnx:mxx + 1][m] = px[m]
    if fancy:
        # the outline: a dark edge round the whole animal and along its inner steps (a leg in front of the body),
        # taking its colour from the part it borders
        mask = zb > -1e8; w = max(2, size // 150)
        near = ndimage.maximum_filter(np.where(mask[..., None], img, 0), size=(2 * w + 3, 2 * w + 3, 1))
        ring = ndimage.binary_dilation(mask, iterations=w) & ~mask
        zf = np.where(mask, zb, zb[mask].min())
        step = mask & ((ndimage.maximum_filter(zf, size=2 * w + 1) - zf) > span * step_k)
        line = ndimage.gaussian_filter((ring | step).astype(np.float32), 0.7) * ink
        dark = near * 0.22 + np.array([34, 18, 24], np.float32) * 0.6
        img = img * (1 - line[..., None]) + dark * line[..., None]
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))


def sheet(out, rows, tile=380, yaws=(1.3, 0.7)):
    """Every named animal in the new look, one tile each, all at one scale: the game angle on top, front quarter below."""
    try:
        from PIL import ImageFont
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 15)
    except Exception:
        font = None
    built = {}
    for n in [x for r in rows for x in r]:
        fn, rel = MADE[n]; a = bake(build(fn)); a["rel"] = rel
        L = a["V"][:a["nsoft"], 2].max() - a["V"][:a["nsoft"], 2].min(); a["s"] = rel / L
        print("TRIS", n, a["tris"], file=sys.stderr); built[n] = a
    cols_ = max(len(r) for r in rows); H = tile * len(rows)
    im = Image.new("RGB", (tile * cols_, H * len(yaws)), (111, 168, 68)); d = ImageDraw.Draw(im)
    for k, yaw in enumerate(yaws):
        common = max(extent(a, yaw) * a["s"] for a in built.values()) * 1.22
        for i, r in enumerate(rows):
            for j, n in enumerate(r):
                a = built[n]; x, y = j * tile, k * H + i * tile
                im.paste(paint(a, yaw, size=tile, span=common / a["s"]), (x, y))
                d.text((x + 10, y + tile - 24), n, fill=(255, 255, 255), font=font)
    im.save(out)


def camera(a, yaw, zoom=1.42):
    R = view_rot(yaw, 0.5); P0 = a["V"] @ R.T; lo, hi = P0.min(0), P0.max(0); cen = (lo + hi) / 2
    span = max(hi[0] - lo[0], hi[1] - lo[1]) * zoom; cen[1] -= span * 0.07
    return span, cen


def label(im, xy, text, size=14):
    try:
        from PIL import ImageFont
        f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", size)
    except Exception:
        f = None
    ImageDraw.Draw(im).text(xy, text, fill=(255, 255, 255), font=f)
