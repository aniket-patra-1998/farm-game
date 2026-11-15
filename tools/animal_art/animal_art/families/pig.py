"""The pig family: one template, and one row of settings per breed."""
import numpy as np
import math
from ..geometry import cone, hx, sphere
from ..shapes import C, E, both


# ---------------------------------------------------------------- one pig template, many breeds
PIGS = {
    "pink pig": dict(body=(1.0, 0.95, 1.6), legs=0.85, leg_r=0.24, neck=0.5, skull=(0.72, 0.7, 0.7), muzzle=(0.42, 0.38, 0.55),
                     ears="flop", coat="f4b6b8", coat2="e08f96", pattern="solid", rel=0.73),
    "berkshire pig": dict(body=(1.02, 0.97, 1.6), legs=0.85, leg_r=0.25, neck=0.5, skull=(0.74, 0.72, 0.7), muzzle=(0.42, 0.38, 0.45),
                          ears="up", coat="34302f", coat2="f4b6b8", pattern="points", rel=0.74),
    "tamworth pig": dict(body=(0.9, 0.88, 1.7), legs=1.05, leg_r=0.22, neck=0.5, skull=(0.66, 0.65, 0.7), muzzle=(0.36, 0.33, 0.78),
                         ears="up", coat="c0602a", coat2="8f4320", pattern="solid", rel=0.76),
    "spotted pig": dict(body=(1.0, 0.95, 1.6), legs=0.85, leg_r=0.24, neck=0.5, skull=(0.72, 0.7, 0.7), muzzle=(0.42, 0.38, 0.55),
                        ears="flop", coat="f2d6cf", coat2="3b3330", pattern="spots", rel=0.73),
    "kunekune pig": dict(body=(1.06, 1.0, 1.42), legs=0.68, leg_r=0.25, neck=0.5, skull=(0.76, 0.74, 0.7), muzzle=(0.42, 0.38, 0.34),
                         ears="up", coat="d9b48a", coat2="5a3a22", pattern="patches", tassels=True, seed=5, rel=0.66),
    "boar": dict(body=(0.92, 0.96, 1.7), legs=1.1, leg_r=0.22, neck=0.5, skull=(0.66, 0.66, 0.72), muzzle=(0.34, 0.32, 0.88),
                 ears="up", coat="8a5a4a", coat2="3b2a1e", pattern="boar", tusks=True, tail="straight", rel=0.8),
    "saddleback pig": dict(body=(1.0, 0.95, 1.62), legs=0.88, leg_r=0.24, neck=0.5, skull=(0.72, 0.7, 0.7), muzzle=(0.42, 0.38, 0.55),
                           ears="flop", coat="35312f", coat2="f4f1ea", pattern="saddle", rel=0.74),
}


def pig(b):
    coat, c2 = np.array(hx(b["coat"])), np.array(hx(b["coat2"])); pat = b["pattern"]
    rx, ry, rz = b["body"]; ll = b["legs"]; lr = b["leg_r"]; tl = b.get("tail_len", 1.0); HEAD = 1.2
    skw, skh, skl = (v * HEAD for v in b["skull"]); sw, sh, sl = (v * HEAD for v in b["muzzle"])
    yb = ll + ry * 0.72
    hy, hz = yb + ry * 0.22, rz * 0.82 + skl * 0.55
    snout_c = tuple(c2) if pat in ("points", "solid", "boar") else hx({"saddle": "d99a9c", "patches": "c9937c"}.get(pat, "e9a6a8"))
    if pat in ("spots", "patches"):
        rs = np.random.RandomState(b.get("seed", 3)); spots = []
        for i in range(10 if pat == "spots" else 6):
            ang = rs.uniform(0, 2 * math.pi); z = rs.uniform(-rz * 0.9, rz * 0.9)
            spots.append(((rx * math.cos(ang), yb + ry * math.sin(ang), z), tuple(rs.uniform(0.28, 0.5, 3) if pat == "spots" else rs.uniform(0.5, 0.85, 3))))

        def bodyc(P):
            inside = np.zeros(len(P), bool)
            for pc, pr in spots:
                inside |= np.linalg.norm((P - np.array(pc)) / np.array(pr), axis=1) < 1
            return np.where(inside[:, None], c2[None, :], coat[None, :])
    elif pat == "saddle":
        # a white band over the shoulders that runs down both front legs
        bodyc = lambda P: np.where(((P[:, 2] > rz * 0.2) & (P[:, 2] < rz * 0.68))[:, None], c2[None, :], coat[None, :])
    else:
        bodyc = tuple(coat)
    legc = (lambda P: np.where((P[:, 1] < (0.42 if pat == "points" else ll * 0.62))[:, None], c2[None, :], coat[None, :])) if pat in ("points", "boar") else tuple(coat)
    legf = tuple(c2) if pat == "saddle" else legc
    earc = tuple(coat * 0.9) if pat not in ("spots", "patches") else tuple(c2)
    s = [E((0, yb, 0), (rx, ry, rz), bodyc), E((0, yb, rz * 0.5), (rx * 0.98, ry * 1.0, rz * 0.5), bodyc),
         E((0, yb + 0.05, -rz * 0.55), (rx * 1.02, ry * 1.02, rz * 0.5), bodyc),
         E((0, hy, hz), (skw, skh, skl), tuple(coat), head=True, k=0.3),
         C((0, hy - skh * 0.2, hz + skl * 0.55), (0, hy - skh * 0.28, hz + skl * 0.55 + sl), sw, sw * 0.86, snout_c if pat in ("points", "boar") else tuple(coat), head=True, k=0.16),
         E((0, hy - skh * 0.55, hz + skl * 0.1), (skw * 0.85, skh * 0.5, skl * 0.7), tuple(coat), head=True)]
    lx, lz = rx * 0.6, rz * 0.66
    for z in (lz, -lz):
        s += both(C, (lx, yb - ry * 0.4, z), (lx, 0.26, z), lr * 1.45, lr, legf if z > 0 else legc)
        hoof = (0.2, 0.16, 0.15) if pat in ("saddle", "boar", "patches") else (tuple(c2 * 0.8) if pat != "points" else tuple(c2))
        s += both(E, (lx, 0.16, z + 0.04), (lr * 1.05, 0.17, lr * 1.2), hoof, k=0.07)
    s += both(E, (lx * 1.05, yb - ry * 0.2, -lz + 0.1), (lr * 1.8, ry * 0.7, 0.5), bodyc)
    if b["ears"] == "flop":
        s += both(E, (skw * 0.8, hy + skh * 0.72, hz - skl * 0.1), (0.34, 0.12, 0.4), earc, rx=0.55, rz=-0.3, k=0.08)
    else:
        s += both(C, (skw * 0.62, hy + skh * 0.62, hz - skl * 0.25), (skw * 1.0, hy + skh * 0.62 + 0.62, hz - skl * 0.2), 0.27, 0.07, earc, k=0.08)
    p = np.array([0.0, yb + ry * 0.55, -rz * 0.98]); tc = tuple(coat * 0.92)
    if b.get("tail") == "straight":
        # a boar's tail: straight, held out, with a dark tuft
        q = p + np.array([0, -0.55, -0.5]) * tl
        s.append(C(p, q, 0.13, 0.09, tc, k=0.08)); s.append(E(q + np.array([0, -0.12, -0.05]), (0.15, 0.26, 0.15), tuple(c2), k=0.06))
    else:
        # a curly tail: a little spiral standing clear of the rump
        for i, d in enumerate(((0, 0.28, -0.34), (0.2, 0.24, 0.04), (-0.08, 0.06, 0.26), (-0.24, -0.2, -0.06), (0.1, -0.2, -0.2))):
            q = p + np.array(d) * tl * 1.15
            s.append(C(p, q, 0.13 - 0.015 * i, 0.12 - 0.015 * i, tuple(c2) if (pat == "points" and i > 2) else tc, k=0.06))
            p = q
    if pat == "boar":
        # a crest of bristles along the neck and back, and a paler belly
        for i, z in enumerate(np.linspace(-rz * 0.25, rz * 0.9, 9)):
            kz = math.sqrt(max(0.1, 1 - (z / (rz * 1.05)) ** 2))
            s.append(E((0, yb + ry * kz * 0.97 + 0.04, z), (0.15, 0.24, 0.2), tuple(c2), k=0.06))
    if b.get("tassels"):
        s += both(E, (skw * 0.34, hy - skh * 0.98, hz + skl * 0.3), (0.1, 0.22, 0.1), tuple(coat * 0.9), k=0.05)
    tip = np.array([0.0, hy - skh * 0.28, hz + skl * 0.55 + sl + sw * 0.72])
    hard = [(sphere(tip, (sw * 0.95, sw * 0.86, 0.07), None, 10), tuple(np.array(snout_c) * (0.93 if pat != "boar" else 1.5)))]
    if b.get("tusks"):
        for sx in (-1, 1):
            base = np.array([sx * sw * 0.78, hy - skh * 0.5, hz + skl * 0.55 + sl * 0.62])
            hard.append((cone(base, base + np.array([sx * 0.16, 0.42, 0.1]), 0.1, 8), hx("f3ecd8")))
    return s, hard, dict(eye_k=1.25 * b.get("eye", 1.0))
