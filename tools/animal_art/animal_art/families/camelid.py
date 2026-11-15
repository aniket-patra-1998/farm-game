"""The camelid family: one template, and one row of settings per breed."""
import numpy as np
import math
from ..geometry import hx
from ..shapes import C, E, both


# ---------------------------------------------------------------- one llama/alpaca template, many breeds
CAMELIDS = {
    "llama": dict(body=(0.85, 0.9, 1.35), legs=1.7, leg_r=0.19, neck=0.42, neck_len=1.9, skull=(0.4, 0.42, 0.5), muzzle=(0.27, 0.27, 0.42),
                  fluff=0.0, coat="e8dcc4", coat2="8a6a4a", pattern="saddle", rel=0.87),
    "brown llama": dict(body=(0.86, 0.9, 1.38), legs=1.7, leg_r=0.19, neck=0.42, neck_len=1.9, skull=(0.4, 0.42, 0.5), muzzle=(0.27, 0.27, 0.42),
                        fluff=0.0, coat="6e4a30", coat2="f3ecdd", pattern="bib", rel=0.87),
    "alpaca": dict(body=(0.88, 0.92, 1.25), legs=1.3, leg_r=0.2, neck=0.44, neck_len=1.45, skull=(0.42, 0.44, 0.48), muzzle=(0.27, 0.27, 0.32),
                   fluff=1.0, coat="f2e6d0", coat2="f2e6d0", pattern="solid", rel=0.7),
    "brown alpaca": dict(body=(0.88, 0.92, 1.25), legs=1.3, leg_r=0.2, neck=0.44, neck_len=1.45, skull=(0.42, 0.44, 0.48), muzzle=(0.27, 0.27, 0.32),
                         fluff=1.0, coat="a8683a", coat2="a8683a", pattern="solid", rel=0.7),
}


def camelid(b):
    coat, c2 = np.array(hx(b["coat"])), np.array(hx(b["coat2"])); pat = b["pattern"]; fl = b["fluff"]
    rx, ry, rz = b["body"]; ll = b["legs"]; lr = b["leg_r"]; tl = b.get("tail_len", 1.0); HEAD = 1.3
    skw, skh, skl = (v * HEAD for v in b["skull"]); mw, mh, ml = (v * HEAD for v in b["muzzle"])
    yb = ll + ry * 0.7
    nb = np.array([0.0, yb + ry * 0.4, rz * 0.72]); nt = nb + np.array([0.0, b["neck_len"], 0.42])
    hy, hz = nt[1] + 0.2, nt[2] + 0.28
    if pat == "saddle":
        bodyc = lambda P: np.where((np.linalg.norm((P - np.array([0.0, yb + ry * 0.55, -0.1])) / np.array([rx * 1.3, ry * 0.95, rz * 0.62]), axis=1) < 1)[:, None], c2[None, :], coat[None, :])
        neckc, headc, legc = tuple(coat), tuple(coat), tuple(coat)
    elif pat == "bib":
        bodyc = tuple(coat); legc = tuple(coat)
        neckc = lambda P: np.where((P[:, 2] > nb[2] + (P[:, 1] - nb[1]) * 0.22 + 0.05)[:, None], c2[None, :], coat[None, :])
        headc = tuple(c2)
    else:
        bodyc, neckc, headc, legc = tuple(coat), tuple(coat), tuple(coat), tuple(coat)
    s = [E((0, yb, 0), (rx, ry, rz), bodyc), E((0, yb + 0.04, rz * 0.5), (rx * 0.96, ry * 1.02, rz * 0.5), bodyc),
         E((0, yb + 0.05, -rz * 0.55), (rx * 1.0, ry * 1.0, rz * 0.5), bodyc), C(nb, nt, b["neck"] * 1.45, b["neck"], neckc, k=0.3),
         E((0, hy, hz), (skw, skh, skl), headc, head=True, rx=0.2),
         # the muzzle: short, deep and blunt, carried level with the eyes (a llama's face is a soft wedge, not a
         # long drooping tube), ending in a small rounded nose
         E((0, hy - skh * 0.28, hz + skl * 0.74), (mw * 1.18, mh * 1.15, ml * 0.74), headc, head=True, rx=0.08, k=0.24),
         E((0, hy - skh * 0.22, hz + skl * 0.74 + ml * 0.62), (mw * 0.62, mh * 0.5, ml * 0.26), tuple(np.array(headc if not callable(headc) else coat) * 0.8 + np.array([0.06, 0.0, 0.0])), head=True, k=0.1)]
    lx, lz = rx * 0.58, rz * 0.68; top = yb - ry * 0.35; mid = 0.3 + (top - 0.3) * 0.46
    s += both(C, (lx, top, lz), (lx, mid, lz + 0.04), lr * 1.45, lr * 1.02, legc) + both(C, (lx, mid, lz + 0.04), (lx, 0.26, lz), lr * 1.02, lr * 0.86, legc)
    s += both(C, (lx, top, -lz), (lx, mid + 0.1, -lz - 0.2), lr * 1.55, lr * 1.05, legc) + both(C, (lx, mid + 0.1, -lz - 0.2), (lx, 0.26, -lz - 0.03), lr * 1.05, lr * 0.86, legc)
    for z in (lz, -lz - 0.03):
        s += both(E, (lx, 0.16, z + 0.05), (lr * 1.15, 0.17, lr * 1.4), (0.24, 0.2, 0.17), k=0.07)
    s += both(E, (lx * 1.02, yb - ry * 0.2, -lz + 0.1), (lr * 1.8, ry * 0.7, 0.5), bodyc)
    earc = tuple(np.array(headc if not callable(headc) else coat) * 0.8)
    s += both(C, (skw * 0.5, hy + skh * 0.6, hz - skl * 0.4), (skw * 0.78, hy + skh * 0.6 + 0.72, hz - skl * 0.28), 0.18, 0.06, earc, k=0.07)
    s.append(E((0, yb + ry * 0.35, -rz * 1.0), (0.2, 0.34 * tl, 0.2), bodyc if not callable(bodyc) else tuple(coat), k=0.1))
    if fl > 0:
        # fleece like the sheep's: curls of one size in even rings, on the body, up the neck, down the thighs and
        # forelegs, and a topknot on the head with woolly cheeks
        cr = 0.3 * (0.85 + 0.2 * fl); wc = tuple(coat)
        for ri, z in enumerate(np.linspace(-rz * 0.84, rz * 0.84, 7)):
            k2 = math.sqrt(max(0.05, 1 - (z / (rz * 1.02)) ** 2)); n = max(5, int(round(10 * k2)))
            ths = np.linspace(-0.6, math.pi + 0.6, n) if ri % 2 == 0 else (np.linspace(-0.6, math.pi + 0.6, n)[:-1] + (math.pi + 1.2) / (n - 1) / 2)
            for th in ths:
                s.append(E((rx * math.cos(th) * k2 * 0.97, yb + ry * math.sin(th) * k2 * 0.97, z), (cr, cr, cr), wc, k=0.06))
        for i in range(6):
            f = i / 5.0 * 0.8; p = nb + (nt - nb) * f; rr = b["neck"] * (1.45 - 0.45 * f) * 0.95   # (the fleece stops short of the face)
            for j in range(5):
                th = 2 * math.pi * (j + 0.5 * (i % 2)) / 5
                s.append(E(p + np.array([rr * math.cos(th), 0.0, rr * math.sin(th)]), (cr * 0.85, cr * 0.85, cr * 0.85), wc, k=0.06))
        for z in (lz, -lz - 0.1):
            for yy in np.linspace(mid - 0.1, top, 3):
                s += both(E, (lx, yy, z), (lr * 1.75, 0.26, lr * 1.75), wc, k=0.07)
        for x in (-skw * 0.36, 0.0, skw * 0.36):
            s.append(E((x, hy + skh * 0.98, hz - skl * 0.5), (cr * 0.8, cr * 0.8, cr * 0.8), wc, k=0.06))
        s.append(E((0, hy + skh * 1.0, hz - skl * 0.1), (cr * 0.7, cr * 0.6, cr * 0.7), wc, k=0.06))
    return s, [], dict(eye_k=1.4 * b.get("eye", 1.0))
