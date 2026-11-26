"""The face every animal shares: eyes seated on the head's own surface, blush, nostrils, mouth, optional blaze and cleft lip."""
import numpy as np
from . import decal
from .decal import DARK, ell, eye, fan, frame
from .geometry import cast
from .head import EYE_K, EYE_S, EYE_SIZE, EYE_T, Head, LASH, MOUTH, find_eye, side_hit


EYES = []
LID_OPEN = 0.4      # every family's lid is lifted this share of the way to wide open: eyes a little wider awake


DARK_FACE = 0.32  # a face darker than this (its colour's mean) gets the light eye: a pale rim and an amber iris


def face(m, V, T, cols, wh, mouth=True, nostril=True, lashes=True, eye_k=1.0, lid=0.38, brow=None, eye_set="side", blaze=None, cleft=False,
         eye_t=None, eye_s=None, wrap=False):
    """The measured face: the eye by proportion of the head, seated on its surface; then blush, nostrils and mouth."""
    hd = Head(V, T, wh, None)
    lid += (1.0 - lid) * LID_OPEN
    if wrap:
        # a round head is as wide as it looks: measure its real half-width, so the eye may sit right on its side
        hd.half = float(np.percentile(np.abs(V[wh > 0.5][:, 0]), 97)) / 1.5
    # where along the head the eye sits is a trait of the family: at the side, a third of the way along (grazers,
    # birds), or set forward, just behind where the muzzle meets the skull (dogs)
    t0 = hd.eye_t() if eye_set == "forward" else (EYE_T if eye_t is None else eye_t)
    r = EYE_K * hd.depth(t0) * EYE_SIZE * eye_k
    Th = T[(wh[T] > 0.3).any(1)]
    wup = np.array([0.0, 1.0, 0.0])
    if blaze is not None:
        # a stripe down the face from the forehead to the nose, laid on the surface: wide between the eyes, narrow below
        rows = []
        for t in np.linspace(0.14, 0.9, 14):
            y, z = hd.at(t, 1.0); w = hd.half * (0.95 - 0.5 * t)
            row = []
            for f in (-0.5, -0.25, 0.0, 0.25, 0.5):          # five points across, so the stripe follows the ridge
                q, n, _k = cast(V, Th, np.array([f * w, y, z]) + hd.e3 * 3.0, -hd.e3)
                row.append(None if q is None else q + n * 0.035)
            if all(r is not None for r in row):
                rows.append(row)
        if len(rows) > 1:
            k = len(rows); pts3 = [p for row in rows for p in row]; tri = []
            for j in range(k - 1):
                for c in range(4):
                    a0 = j * 5 + c; tri += [[a0, a0 + 1, a0 + 5], [a0 + 1, a0 + 6, a0 + 5]]
            m.add(pts3, tri, blaze)
    if cleft:
        # the split upper lip of a llama or alpaca: a short line down the front of the muzzle, from the nose to the mouth
        pts3 = []
        for sv in np.linspace(0.5, 0.2, 5):
            y, z = hd.at(1.0, sv)
            q, n, _k = cast(V, T, np.array([0.0, y, z]) + hd.d3 * 6.0, -hd.d3)
            if q is not None:
                pts3.append(q + n * 0.03)
        if len(pts3) > 1:
            w = np.array([0.045 * r / 0.2, 0.0, 0.0]); k = len(pts3)
            m.add([q + w for q in pts3] + [q - w for q in pts3], [t for j in range(k - 1) for t in ([j, j + 1, k + j], [j + 1, k + j + 1, k + j])], DARK)
    for sx in (-1, 1):
        h = find_eye(V, T, hd, sx, t0, Th, eye_s)
        if h is not None:
            p, out, k = h
            fc = np.array(cols[k])
            u0, up0 = frame(out, hd.d3); hits = []
            for a2 in (-0.8, 0.0, 0.8):
                for b2 in (-0.8, 0.0, 0.8):
                    q, _n, _k = cast(V, Th, p + u0 * a2 * r + up0 * b2 * r + out * 0.6, -out)
                    if q is not None and np.linalg.norm(q - p) < 1.2 * r + 0.3:
                        hits.append(q)
            if len(hits) >= 4:
                H = np.array(hits); cen = H.mean(0); n = np.linalg.svd(H - cen)[2][2]
                if n @ out < 0:
                    n = -n
                p, out = p + n * ((cen - p) @ n + ((H - cen) @ n).max() + 0.012), n
            a = wup - out * (wup @ out); a /= np.linalg.norm(a)
            b = hd.e3 - out * (hd.e3 @ out); b /= np.linalg.norm(b)
            up = 0.85 * a + 0.15 * b; up /= np.linalg.norm(up)
            u = np.cross(up, out)
            if u @ hd.d3 < 0:
                u = -u
            lidc = tuple(fc * 0.88) if fc.mean() > DARK_FACE else tuple(np.minimum(1, fc * 1.08 + 0.015))
            if wrap:
                # a small round head curves away under a flat eye, which then stands off it like a plate. Measure the
                # head's own curve under the eye (a smooth bowl fitted to it) and lay the whole drawing on that.
                rowsA, hgt = [], []
                for a2 in np.linspace(-1.7, 1.7, 7):
                    for b2 in np.linspace(-1.9, 1.5, 7):
                        q, _n, _k = cast(V, Th, p + u * a2 * r + up * b2 * r + out * 0.6, -out)
                        if q is not None and (q - p) @ out > -1.3 * r:
                            x_, y_ = a2 * r, b2 * r
                            rowsA.append([1.0, x_, y_, x_ * x_, x_ * y_, y_ * y_]); hgt.append((q - p) @ out)
                if len(hgt) >= 14:
                    A_ = np.array(rowsA); hv = np.array(hgt); coef = np.linalg.lstsq(A_, hv, rcond=None)[0]
                    lift = min(0.03, max(0.0, float((hv - A_ @ coef).max())))

                    def proj(P, _o, p0=p.copy(), u_=u.copy(), up_=up.copy(), o_=out.copy(), cf=coef, lf=lift):
                        d = P - p0; x_, y_ = d @ u_, d @ up_
                        return p0 + u_ * x_ + up_ * y_ + o_ * (cf @ np.array([1.0, x_, y_, x_ * x_, x_ * y_, y_ * y_]) + lf)
                    decal.PROJ = proj
            _e0 = m.n
            eye(m, p, u, up, out, r, lidc, lashes=lashes, lid=lid, pupil=0.82, lash=LASH,
                iris=(decal.CHESTNUT if fc.mean() < DARK_FACE else (0.2, 0.12, 0.08)),
                rim=(decal.PALE_RIM if fc.mean() < DARK_FACE else None))
            EYES.append((_e0, m.n, p.copy(), up.copy()))        # this eye's own points, so it can blink
            if fc.mean() >= DARK_FACE:   # (a blush is lost on a dark face, and reads as a stray mark)
                fan(m, p, u, up, out, ell(0.4 * r, 0.27 * r, -0.3 * r, -1.62 * r, 16), 0, tuple(fc * 0.68 + np.array([0.98, 0.5, 0.56]) * 0.32))
            decal.PROJ = None
        if brow is not None:
            hb = side_hit(V, T, hd, sx, t0 - 0.02, min(0.96, EYE_S + 0.25))
            if hb is not None:
                ub, upb = frame(hb[1], hd.d3)
                fan(m, hb[0], ub, upb, hb[1], ell(0.34 * r, 0.3 * r, n=12), 0, brow)
        if nostril:
            y, z = hd.at(1.0, 0.55)
            p2, o2, k2 = cast(V, T, np.array([sx * hd.half * 0.3, y, z]) + hd.d3 * 6.0, -hd.d3)
            if p2 is not None:
                u2, up2 = frame(o2, np.array([1.0, 0.0, 0.0]))
                fan(m, p2, u2, up2, o2, ell(0.2 * r, 0.3 * r, n=12), 0, tuple(np.array(cols[k2]) * 0.6))
        if mouth:
            hits = []
            for t, s in MOUTH:
                hh = side_hit(V, T, hd, sx, t, s)
                if hh is not None:
                    hits.append(hh[0] + hh[1] * 0.025)
            if len(hits) > 1:
                w = np.array([0.0, 0.07 * r, 0.0])
                m.add([q + w for q in hits] + [q - w for q in hits],
                      [t for j in range(len(hits) - 1) for t in ([j, j + 1, len(hits) + j], [j + 1, len(hits) + j + 1, len(hits) + j])], DARK)
