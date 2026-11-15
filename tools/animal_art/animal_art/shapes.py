"""Soft shapes and how they melt together: an animal is a list of these (eggs, tapered bars, feather tiles).
Each is a signed distance; `field` blends them with a smooth minimum, so parts join like clay."""
import numpy as np
import math


RES = 46       # cells along an animal's longest side (lower: fewer triangles)


BLEND = 0.22   # how softly neighbouring shapes melt together


EDGE_SPLITS = 2   # times the mesh is refined along colour borders


def rotm(rx=0.0, ry=0.0, rz=0.0):
    cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    return (np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]]) @ np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
            @ np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]]))


def E(c, r, col, head=False, rx=0.0, ry=0.0, rz=0.0, k=BLEND, part=None):
    """`part` names what a shape is when the animation needs to know (e.g. "stub": a turtle's leg, which slides)."""
    return dict(kind="ell", c=np.array(c, float), r=np.array(r, float), col=col, head=head, R=rotm(rx, ry, rz), k=k, part=part)


def C(a, b, ra, rb, col, head=False, k=BLEND, part=None):
    return dict(kind="cap", a=np.array(a, float), b=np.array(b, float), ra=ra, rb=rb, col=col, head=head, k=k, part=part)


def both(f, *a, **kw):
    """The same shape on the left and the right (x mirrored): the shape's points are mirrored, and its lean."""
    out = []; npts = 1 if f is E else 2
    for sx in (-1, 1):
        aa = [np.array(v, float) * np.array([sx, 1, 1]) if i < npts else v for i, v in enumerate(a)]
        k2 = dict(kw)
        for key in ("ry", "rz"):
            if key in k2:
                k2[key] = k2[key] * sx
        out.append(f(*aa, **k2))
    return out


def sdf(p, s):
    if s["kind"] == "ell":
        q = (p - s["c"]) @ s["R"]
        return (np.linalg.norm(q / s["r"], axis=1) - 1.0) * s["r"].min()
    ab = s["b"] - s["a"]; t = np.clip(((p - s["a"]) @ ab) / (ab @ ab), 0, 1)
    return np.linalg.norm(p - (s["a"] + t[:, None] * ab), axis=1) - (s["ra"] + t * (s["rb"] - s["ra"]))


def field(p, shapes):
    d = None
    for s in shapes:
        ds = sdf(p, s)
        if d is None:
            d = ds; continue
        h = np.clip(0.5 + 0.5 * (ds - d) / s["k"], 0, 1)
        d = ds * (1 - h) + d * h - s["k"] * h * (1 - h)
    return d


def shingle(center, n, back, size, col, tilt=0.3, k=0.045):
    """One feather lying on a surface like a roof tile: `n` is the way the surface faces there, `back` the way the
    feather points; its front edge tucks under and its tip lifts, by `tilt`. size = (thickness, half width, half length)."""
    n = np.array(n, float); n /= np.linalg.norm(n); back = np.array(back, float); back = back - (back @ n) * n; back /= np.linalg.norm(back)
    t = np.cross(n, back); f = math.cos(tilt) * back + math.sin(tilt) * n; mm = math.cos(tilt) * n - math.sin(tilt) * back
    return dict(kind="ell", c=np.array(center, float) + n * size[0] * 0.2, r=np.array(size, float), col=col, head=False,
                R=np.column_stack([mm, t, f]), k=k)


def plumage(parts, zs, size, col, th0=-0.75, th1=math.pi + 0.75, skip=None, tilt=0.3):
    """Feathers over a body made of a few egg shapes `parts` [(centre, radii)]: even rings of them from back to front,
    each ring set between the feathers of the last, all pointing to the tail."""
    out = []; cy = np.mean([c[1] for c, _r in parts])
    for ri, z in enumerate(zs):
        ring = []
        steps = 60
        for th in np.linspace(th0, th1, steps):
            d = np.array([math.cos(th), math.sin(th), 0.0]); o0 = np.array([0.0, cy, z]); best = None
            for c, r in parts:
                c = np.array(c, float); r = np.array(r, float); oc = (o0 - c) / r; dd = d / r
                A2, B2, C2 = dd @ dd, 2 * oc @ dd, oc @ oc - 1
                disc = B2 * B2 - 4 * A2 * C2
                if disc > 0:
                    s_ = (-B2 + math.sqrt(disc)) / (2 * A2)
                    if s_ > 0 and (best is None or s_ > best[0]):
                        P = o0 + d * s_; best = (s_, P, (P - c) / (r * r))
            ring.append(best)
        ok = [b for b in ring if b is not None]
        if len(ok) < steps * 0.6:
            continue
        arc = sum(np.linalg.norm(ok[i + 1][1] - ok[i][1]) for i in range(len(ok) - 1))
        n = max(4, int(round(arc / (size[1] * 1.7))))
        for j in range(n):
            f = (j + (0.5 if ri % 2 else 0.0)) / n
            if f >= 1:
                continue
            b = ok[min(len(ok) - 1, int(f * len(ok)))]
            if skip is not None and skip(b[1]):
                continue
            out.append(shingle(b[1], b[2], (0, 0, -1), size, col, tilt))
    return out
