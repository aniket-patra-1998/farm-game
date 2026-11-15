"""The goat family: one template, and one row of settings per breed."""
import numpy as np
import math
from ..geometry import hx
from ..shapes import C, E, both


# ---------------------------------------------------------------- one goat template, many breeds
GOATS = {
    "goat": dict(body=(0.85, 0.9, 1.5), legs=1.5, leg_r=0.2, neck=0.48, skull=(0.5, 0.55, 0.66), muzzle=(0.36, 0.34, 0.45),
                 horns=0.9, beard=0.7, ears="side", fur=0.0, coat="d8c7a8", coat2="7a6650", pattern="points", rel=0.67),
    "boer goat": dict(body=(0.95, 0.98, 1.5), legs=1.35, leg_r=0.22, neck=0.54, skull=(0.52, 0.56, 0.66), muzzle=(0.38, 0.36, 0.45),
                      horns=0.6, beard=0.3, ears="droop", fur=0.0, coat="f4f1ea", coat2="8a3a1e", pattern="head", rel=0.7),
    "arapawa goat": dict(body=(0.82, 0.88, 1.5), legs=1.5, leg_r=0.2, neck=0.47, skull=(0.5, 0.54, 0.66), muzzle=(0.35, 0.33, 0.45),
                         horns=1.3, beard=0.8, ears="side", fur=0.6, coat="6a4a32", coat2="2b1a10", pattern="badger", rel=0.66),
    "billy goat": dict(body=(0.92, 0.96, 1.6), legs=1.55, leg_r=0.23, neck=0.56, skull=(0.54, 0.58, 0.7), muzzle=(0.38, 0.36, 0.47),
                       horns=1.7, beard=1.3, ears="side", fur=1.15, coat="8f8a82", coat2="45413c", pattern="points", rel=0.78),
}


def goat_t(b):
    coat, c2 = np.array(hx(b["coat"])), np.array(hx(b["coat2"])); pat = b["pattern"]; fur = b["fur"]
    rx, ry, rz = b["body"]; ll = b["legs"]; lr = b["leg_r"]; tl = b.get("tail_len", 1.0); HEAD = 1.3
    skw, skh, skl = (v * HEAD for v in b["skull"]); mw, mh, ml = (v * HEAD for v in b["muzzle"])
    puff = 1 + 0.08 * fur
    yb = ll + ry * 0.7
    nb = np.array([0.0, yb + ry * 0.42, rz * 0.74]); nt = nb + np.array([0.0, 0.85, 0.62])
    hy, hz = nt[1] + 0.22, nt[2] + 0.32
    pale = tuple(np.minimum(1, coat * 0.4 + 0.58))
    if pat == "head":
        bodyc, headc, neckc, legc, muzc = tuple(coat), tuple(c2), tuple(c2), tuple(coat), tuple(c2 * 0.9)
    elif pat == "badger":
        bodyc = lambda P: np.where(((np.abs(P[:, 0]) < 0.22) & (P[:, 1] > yb + ry * 0.55))[:, None], c2[None, :], coat[None, :])
        legc = lambda P: np.where((P[:, 1] < ll * 0.6)[:, None], c2[None, :], coat[None, :])
        headc, neckc, muzc = tuple(coat), tuple(coat), pale
    elif pat == "points":
        bodyc, headc, neckc, muzc = tuple(coat), tuple(coat), tuple(coat), pale
        legc = lambda P: np.where((P[:, 1] < ll * 0.4)[:, None], c2[None, :], coat[None, :])
    else:
        bodyc, headc, neckc, legc, muzc = tuple(coat), tuple(coat), tuple(coat), tuple(coat), pale
    dark = tuple(c2)
    s = [E((0, yb, 0), (rx * puff, ry * puff, rz), bodyc), E((0, yb + 0.02, rz * 0.52), (rx * 0.97 * puff, ry * 1.03 * puff, rz * 0.48), bodyc),
         E((0, yb + 0.06, -rz * 0.58), (rx * 1.0 * puff, ry * 1.0 * puff, rz * 0.47), bodyc), C(nb, nt, b["neck"] * 1.3, b["neck"], neckc, k=0.28),
         E((0, hy, hz), (skw, skh, skl), headc, head=True, rx=0.35),
         E((0, hy - skh * 0.56, hz + skl * 0.92), (mw * 0.8, mh * 0.82, ml), headc, head=True, rx=0.3, k=0.2),
         E((0, hy - skh * 0.56 - ml * 0.22, hz + skl * 0.92 + ml * 0.68), (mw * 0.58, mh * 0.52, ml * 0.42), muzc, head=True, k=0.1)]
    lx, lz = rx * 0.58, rz * 0.7; top = yb - ry * 0.35; mid = 0.3 + (top - 0.3) * 0.46
    s += both(C, (lx, top, lz), (lx, mid, lz + 0.04), lr * 1.45, lr * 1.02, legc) + both(C, (lx, mid, lz + 0.04), (lx, 0.28, lz), lr * 1.02, lr * 0.86, legc)
    s += both(E, (lx, mid, lz + 0.08), (lr * 1.1, lr * 1.2, lr * 1.1), legc, k=0.1)
    s += both(C, (lx, top, -lz), (lx, mid + 0.1, -lz - 0.2), lr * 1.55, lr * 1.05, legc) + both(C, (lx, mid + 0.1, -lz - 0.2), (lx, 0.28, -lz - 0.03), lr * 1.05, lr * 0.86, legc)
    for z in (lz, -lz - 0.03):
        s += both(E, (lx, 0.17, z + 0.03), (lr * 1.15, 0.18, lr * 1.3), (0.2, 0.16, 0.13), k=0.07)
    s += both(E, (lx * 1.02, yb - ry * 0.2, -lz + 0.1), (lr * 1.8, ry * 0.7, 0.5), bodyc)
    earc = dark if pat != "head" else tuple(c2 * 0.9)
    if b["ears"] == "droop":
        s += both(E, (skw + 0.1, hy - skh * 0.15, hz - skl * 0.4), (0.14, 0.6, 0.28), earc, rz=-0.12, k=0.08, part="ear")
    else:
        s += both(E, (skw + 0.34, hy + skh * 0.2, hz - skl * 0.42), (0.42, 0.13, 0.22), earc, rz=-0.3, k=0.08, part="ear")
    if b["beard"] > 0:
        s.append(E((0, hy - skh * 0.58 - mh * 0.9 - 0.18 * b["beard"], hz + skl * 0.92 + ml * 0.1), (0.19, 0.38 * b["beard"], 0.19), dark, k=0.1))
    t0 = np.array([0.0, yb + ry * 0.7, -rz * 0.96])
    s.append(C(t0, t0 + np.array([0, 0.5, -0.38]) * tl, 0.2, 0.12, dark, k=0.1))
    # horns sweep up and back in an arc; how long is the breed's
    if b["horns"] > 0:
        Lh = b["horns"]; hc = hx("a89878"); TH = 1.75; R = Lh / TH
        for sx in (-1, 1):
            st = np.array([sx * skw * 0.42, hy + skh * 0.78, hz - skl * 0.3]); prev = st
            for i in range(1, 7):
                th = TH * i / 6.0
                p = st + np.array([sx * 0.32 * Lh * (i / 6.0), R * math.sin(th), -R * (1 - math.cos(th))])
                s.append(C(prev, p, 0.21 - 0.018 * (i - 1), 0.21 - 0.018 * i, hc, k=0.04))
                prev = p
    if fur > 0:
        # a shaggy coat: a ruff on the chest and under the neck, a deep belly fringe, a skirt of long locks hanging
        # along both flanks, and woolly thighs and forelegs
        shag = tuple(coat * 0.9)
        s.append(E((0, yb - ry * 0.4, rz * 0.84), (rx * 0.9, ry * 0.95 * fur, 0.6), shag, k=0.2))
        s.append(E(nb + np.array([0.0, 0.1, 0.25]), (0.5, 0.75 * fur, 0.45), shag, k=0.2))
        s.append(E((0, yb - ry * 1.05, 0.0), (rx * 0.7, 0.45 * fur, rz * 0.75), shag, k=0.2))
        for i, z in enumerate(np.linspace(-rz * 0.75, rz * 0.7, 8)):
            s += both(E, (rx * 0.78, yb - ry * (0.78 + 0.08 * (i % 2)), z), (0.24, 0.5 * fur, 0.2), shag, k=0.07)
        s += both(E, (lx * 1.05, yb - ry * 0.75, -lz - 0.28), (0.24, 0.62 * fur, 0.38), shag, k=0.14)
        s += both(E, (lx * 1.02, yb - ry * 0.85, lz + 0.1), (0.2, 0.5 * fur, 0.3), shag, k=0.14)
    opt = dict(eye_k=1.35 * b.get("eye", 1.0))
    if pat == "head":
        opt["blaze"] = (0.97, 0.96, 0.93)
    return s, [], opt
