"""The dog family: one template, and one row of settings per breed."""
import numpy as np
import math
from ..geometry import hx, sphere
from ..shapes import C, E, both


# ---------------------------------------------------------------- one dog template, many breeds
# A breed is a row of settings: build, legs, skull and muzzle, the kind of ears and tail, how much fur, and the coat.
DOGS = {
    "rottweiler": dict(body=(0.78, 0.8, 1.45), legs=1.5, leg_r=0.23, neck=0.52, skull=(0.62, 0.58, 0.6), muzzle=(0.36, 0.33, 0.4),
                       ears="fold", tail="short", fur=0.0, coat="2b2622", coat2="b8743a", pattern="points", chest=1.14, rel=0.5),
    "golden retriever": dict(body=(0.68, 0.7, 1.5), legs=1.6, leg_r=0.2, neck=0.45, skull=(0.52, 0.52, 0.56), muzzle=(0.28, 0.28, 0.58),
                   ears="long", tail="plume", fur=1.0, coat="d9a441", coat2="efcf85", pattern="solid", chest=1.05, rel=0.5),
    "black lab": dict(body=(0.7, 0.72, 1.48), legs=1.5, leg_r=0.21, neck=0.47, skull=(0.55, 0.53, 0.56), muzzle=(0.31, 0.3, 0.5),
                      ears="flop", tail="otter", fur=0.0, coat="35302f", coat2="35302f", pattern="solid", chest=1.06, rel=0.48),
    "brown dog": dict(body=(0.64, 0.66, 1.4), legs=1.55, leg_r=0.19, neck=0.42, skull=(0.5, 0.5, 0.54), muzzle=(0.28, 0.27, 0.46),
                      ears="fold", tail="otter", fur=0.38, coat="8a5a34", coat2="d2ad7e", pattern="bib", chest=1.04, rel=0.45),
    "spotted dog": dict(body=(0.62, 0.66, 1.48), legs=1.8, leg_r=0.17, neck=0.4, skull=(0.5, 0.5, 0.55), muzzle=(0.27, 0.27, 0.54),
                        ears="flop", tail="otter", fur=0.0, coat="f6f3ec", coat2="2b2b30", pattern="spots", chest=1.02, tail_len=1.15, rel=0.48),
    "indie dog": dict(body=(0.55, 0.58, 1.4), legs=1.9, leg_r=0.16, neck=0.36, skull=(0.46, 0.46, 0.52), muzzle=(0.24, 0.24, 0.56),
                  ears="up", tail="curl", fur=0.0, coat="c8935a", coat2="f3ead8", pattern="socks", chest=1.0, rel=0.46),
}


def dog(b):
    coat, c2 = np.array(hx(b["coat"])), np.array(hx(b["coat2"]))
    rx, ry, rz = b["body"]; ll = b["legs"]; lr = b["leg_r"]; fur = b["fur"]; pat = b["pattern"]
    puff = 1 + 0.14 * fur
    yb = ll + ry * 0.72
    HEAD = 1.25   # the family look: heads a quarter bigger than life, like the other animals
    skw, skh, skl = (v * HEAD for v in b["skull"]); mw, mh, ml = (v * HEAD for v in b["muzzle"])
    hz, hy = rz * 0.78 + 0.8, yb + ry * 0.45 + 0.98
    my, mzc = hy - skh * 0.32, hz + skl * 0.55 + ml * 0.62
    low = (lambda P: np.where((P[:, 1] < ll * 0.5)[:, None], c2[None, :], coat[None, :])) if pat in ("points", "socks") else tuple(coat)
    paw = tuple(c2) if pat in ("points", "socks") else tuple(coat)
    bc = tuple(coat)
    if pat == "spots":
        # round spots dealt out over the body, legs, neck and head from the dog's own number
        rs = np.random.RandomState(b.get("seed", 4)); sp = []
        for i in range(30):
            a = rs.uniform(-0.5, math.pi + 0.5); z = rs.uniform(-rz * 0.95, rz * 0.95); kz = math.sqrt(max(0.1, 1 - (z / rz) ** 2))
            sp.append((np.array([rx * math.cos(a) * kz, yb + ry * math.sin(a) * kz, z]), rs.uniform(0.13, 0.25)))
        for i in range(12):
            sp.append((np.array([rs.choice([-1, 1]) * rx * 0.75, rs.uniform(0.5, yb - ry * 0.3), rs.choice([-1, 1]) * rz * 0.66 + rs.uniform(-0.15, 0.15)]), rs.uniform(0.11, 0.18)))
        for i in range(9):
            a = rs.uniform(0, math.pi)
            sp.append((np.array([skw * math.cos(a), hy + skh * math.sin(a) * 0.9, hz - rs.uniform(-0.1, 1.3)]), rs.uniform(0.1, 0.17)))

        def bc(P):
            inside = np.zeros(len(P), bool)
            for pc, pr in sp:
                inside |= np.linalg.norm(P - pc, axis=1) < pr
            return np.where(inside[:, None], c2[None, :], coat[None, :])
        low = bc
    if pat == "points":
        muz = lambda P: np.where((P[:, 1] > my + mh * 0.35)[:, None], coat[None, :], c2[None, :])
    else:
        muz = tuple(coat * 0.5 + c2 * 0.5) if pat == "socks" else (tuple(c2) if pat == "bib" else tuple(np.minimum(1, coat * 1.06)))
    s = [E((0, yb, 0), (rx * puff, ry * puff, rz), bc),
         E((0, yb - 0.04, rz * 0.5), (rx * 1.02 * puff, ry * b["chest"] * puff, rz * 0.56), bc),
         E((0, yb + 0.05, -rz * 0.55), (rx * 0.9, ry * 0.86, rz * 0.5), bc),
         C((0, yb + ry * 0.45, rz * 0.72), (0, hy - 0.22, hz - 0.4), b["neck"] * 1.12, b["neck"], bc),
         E((0, hy, hz), (skw, skh, skl), bc, head=True),
         E((0, my, mzc), (mw, mh, ml), muz, head=True, k=0.16)]
    lx, lz = rx * 0.62, rz * 0.66
    for z in (lz, -lz):
        s += both(C, (lx, yb - ry * 0.3, z), (lx, 0.24, z + 0.03), lr * 1.3, lr, low)
        s += both(E, (lx, 0.17, z + 0.13), (lr * 1.25, 0.17, lr * 1.65), paw, k=0.1)
    s += both(E, (lx * 1.02, yb - ry * 0.25, -lz + 0.12), (lr * 1.5, ry * 0.62, 0.46), bc)
    if pat in ("points", "socks", "bib"):
        s.append(E((0, yb - ry * 0.45, rz * 0.9), (rx * 0.55, ry * 0.5, 0.3), tuple(c2), k=0.12))
    # ears
    e = b["ears"]; ec = tuple(c2) if pat == "spots" else tuple(coat * (0.72 if pat == "bib" else 0.82))
    if e == "fold":
        s += both(E, (skw + 0.04, hy + 0.2, hz - 0.08), (0.13, 0.36, 0.28), ec, rz=-0.25, k=0.1)
    elif e == "flop":
        s += both(E, (skw + 0.08, hy - 0.02, hz - 0.1), (0.14, 0.55, 0.34), ec, rz=-0.15, k=0.1)
    elif e == "long":
        s += both(E, (skw + 0.12, hy - 0.26, hz - 0.1), (0.2, 0.84, 0.46), tuple(coat * 0.9), rz=-0.12, k=0.1)
    else:
        s += both(C, (skw * 0.62, hy + skh * 0.7, hz - 0.2), (skw * 0.95, hy + skh * 0.7 + 0.78, hz - 0.32), 0.27, 0.05, ec, k=0.1)
    # tail
    t = b["tail"]; ty, tz = yb + ry * 0.55, -rz * 0.95; tl = b.get("tail_len", 1.0)
    if t == "short":
        s.append(C((0, ty, tz), (0, ty + 0.28, tz - 0.3), 0.17, 0.1, tuple(coat)))
    elif t == "otter":
        s.append(C((0, ty, tz), (0, ty - 0.35 * tl, tz - 1.2 * tl), 0.23, 0.1, tuple(coat)))
    elif t == "plume":
        s.append(C((0, ty, tz), (0, ty - 0.05, tz - 1.45 * tl), 0.24, 0.15, tuple(coat)))
        s.append(E((0, ty - 0.5 * tl, tz - 0.9 * tl), (0.17, 0.62 * tl, 0.78 * tl), tuple(c2), k=0.14))
        for i in range(4):
            s.append(E((0, ty - (0.95 + 0.05 * (i % 2)) * tl, tz - (0.4 + 0.32 * i) * tl), (0.13, 0.22, 0.17), tuple(c2), k=0.07))
    else:
        pts = [(0, ty, tz), (0, ty + 0.7 * tl, tz - 0.32 * tl), (0, ty + 1.15 * tl, tz - 0.05 * tl), (0, ty + 0.98 * tl, tz + 0.3 * tl)]
        for i in range(3):
            s.append(C(pts[i], pts[i + 1], 0.17 - 0.02 * i, 0.15 - 0.02 * i, tuple(coat), k=0.1))
    # fur: a fuller, softer outline, all scaled by how much fur the breed has: a ruff round the neck and chest, a
    # belly fringe, feathers behind the legs, "trousers" on the thighs, fluffy cheeks, and small tufts that break
    # the smooth edge so it reads as hair
    if fur > 0:
        mix = tuple(coat * 0.55 + c2 * 0.45)
        s.append(E((0, yb + ry * 0.3, rz * 0.74), (rx * 1.0, ry * 1.0 * fur, 0.6), mix, k=0.25))
        s.append(E((0, yb - ry * 0.42, rz * 0.86), (rx * 0.92, ry * 0.95 * fur, 0.62), tuple(c2), k=0.2))
        s.append(E((0, yb - ry * 1.0, 0.0), (rx * 0.66, 0.36 * fur, rz * 0.72), tuple(c2), k=0.2))
        s += both(E, (lx, yb - ry * 1.05, lz - 0.28), (0.13, 0.6 * fur, 0.3), tuple(c2), k=0.14)
        s += both(E, (lx * 1.05, yb - ry * 0.75, -lz - 0.3), (0.21, 0.64 * fur, 0.38), tuple(c2), k=0.16)
        s += both(E, (skw * 0.88, hy - skh * 0.5, hz + 0.02), (0.2, 0.3 * fur, 0.3), mix, head=True, k=0.14)
        for i, z in enumerate(np.linspace(-rz * 0.62, rz * 0.62, 7)):
            s.append(E((0, yb - ry * 1.2 - 0.06 * (i % 2), z), (rx * 0.36, 0.2 * fur, 0.19), tuple(c2), k=0.07))
        for i in range(4):
            s.append(E((0, yb + ry * (0.35 - 0.36 * i), rz * 1.0 + 0.2 - 0.05 * i), (rx * 0.5, 0.22 * fur, 0.2), tuple(c2), k=0.07))
    nose = (sphere((0, my + mh * 0.38, mzc + ml * 0.93), (0.14, 0.11, 0.11), None, 6), (0.1, 0.08, 0.08))
    opt = dict(nostril=False, eye_k=1.3 * b.get("eye", 1.0), eye_set="forward")
    if pat == "points":
        opt["brow"] = tuple(c2)
    return s, [nose], opt
