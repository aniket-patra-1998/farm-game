"""The sheep family: one template, and one row of settings per breed."""
import numpy as np
import math
from ..geometry import hx
from ..paint import second
from ..shapes import C, E, both


CURL = 0.46          # a curl of fleece: its radius (big enough to be a form of its own, not a ripple)
CURL_RINGS = 5       # rings of curls from tail to shoulder..
CURL_ROUND = 6       # ..and curls round the widest ring
CURL_IN = 0.74       # how far out from the body's middle a curl sits, of the body's radius (the rest of it bulges)
CURL_CREASE = 0.05   # how sharply two curls meet: the crease between them is what draws the fleece


# ---------------------------------------------------------------- one sheep template, many breeds
SHEEP = {
    "sheep": dict(body=(0.9, 0.88, 1.35), legs=1.05, leg_r=0.15, neck=0.55, skull=(0.42, 0.44, 0.5), muzzle=(0.32, 0.3, 0.4),
                  wool=1.0, horns=False, woolly_head=False, coat="eeeae0", face="5a4a42", legs_col="4a3d36", rel=0.7),
    "woolly sheep": dict(body=(0.92, 0.9, 1.35), legs=1.1, leg_r=0.17, neck=0.58, skull=(0.42, 0.44, 0.5), muzzle=(0.32, 0.3, 0.38),
                         wool=1.35, horns=False, woolly_head=True, coat="f4f0e6", face="efe0cf", legs_col="f4f0e6", rel=0.72),
    "ram": dict(body=(0.98, 0.95, 1.45), legs=1.12, leg_r=0.18, neck=0.66, skull=(0.46, 0.47, 0.54), muzzle=(0.35, 0.33, 0.42),
                wool=1.0, horns=True, woolly_head=False, coat="e8e2d4", face="8a7a5a", legs_col="6e6048", rel=0.82),
    "black sheep": dict(body=(0.9, 0.88, 1.35), legs=1.05, leg_r=0.15, neck=0.55, skull=(0.42, 0.44, 0.5), muzzle=(0.32, 0.3, 0.4),
                        wool=1.0, horns=False, woolly_head=False, coat="3d3837", face="6d6360", legs_col="2a2627", rel=0.7),
    "mouflon sheep": dict(body=(0.84, 0.86, 1.42), legs=1.3, leg_r=0.17, neck=0.5, skull=(0.44, 0.46, 0.54), muzzle=(0.33, 0.31, 0.42),
                          wool=0.0, horns=True, horn_k=1.25, woolly_head=False, coat="8a5a32", face="8a5a32", legs_col="8a5a32", pale="e8dcc4", rel=0.74),
}


def sheep(b):
    wool, facec, legc = hx(b["coat"]), hx(b["face"]), hx(b["legs_col"])
    rx, ry, rz = b["body"]; ll = b["legs"]; lr = b["leg_r"]; w = b["wool"]; tl = b.get("tail_len", 1.0); HEAD = 1.3
    skw, skh, skl = (v * HEAD for v in b["skull"]); mw, mh, ml = (v * HEAD for v in b["muzzle"])
    yb = ll + ry * 0.72
    nb = np.array([0.0, yb + ry * 0.3, rz * 0.72]); nt = nb + np.array([0.0, 0.5, 0.52])
    hy, hz = nt[1] + 0.18, nt[2] + 0.3
    pale = np.array(hx(b["pale"])) if b.get("pale") else None
    if pale is not None:
        # a short-haired wild sheep: pale belly, rump, muzzle and lower legs on a brown coat
        wa = np.array(wool)
        bodyc = lambda P: np.where(((P[:, 1] < yb - ry * 0.5) | ((P[:, 2] < -rz * 0.72) & (P[:, 1] < yb + ry * 0.45)))[:, None], pale[None, :], wa[None, :])
        legc = lambda P: np.where((P[:, 1] < ll * 0.6)[:, None], pale[None, :], wa[None, :])
        s = [E((0, yb, 0), (rx, ry, rz), bodyc), E((0, yb + 0.03, rz * 0.5), (rx * 0.98, ry * 1.05, rz * 0.5), bodyc),
             E((0, yb + 0.06, -rz * 0.55), (rx * 1.0, ry * 1.02, rz * 0.5), bodyc), C(nb, nt, b["neck"] * 1.2, b["neck"], tuple(wa * 0.88))]
        s += both(E, (rx * 0.6, yb - ry * 0.2, -rz * 0.55), (0.3, ry * 0.7, 0.45), bodyc)
    else:
        s = [E((0, yb, 0), (rx * 0.93, ry * 0.93, rz * 0.96), wool), C(nb, nt, b["neck"] * 1.2, b["neck"], wool)]
    # the fleece: curls of ONE size laid in even rings round the body, each ring set between the curls of the last
    # (like roof tiles) and the same on both sides, so the wool is regular all over and never patchy
    cr = CURL * (0.86 + 0.2 * w)
    for ri, z in enumerate(np.linspace(-rz * 0.8, rz * 0.8, CURL_RINGS) if w > 0 else []):
        k2 = math.sqrt(max(0.05, 1 - (z / (rz * 1.02)) ** 2))
        n = max(4, int(round(CURL_ROUND * k2)))
        ths = np.linspace(-0.6, math.pi + 0.6, n) if ri % 2 == 0 else (np.linspace(-0.6, math.pi + 0.6, n)[:-1] + (math.pi + 1.2) / (n - 1) / 2)
        for j, th in enumerate(ths):
            s.append(E((rx * math.cos(th) * k2 * CURL_IN, yb + ry * math.sin(th) * k2 * CURL_IN, z), (cr, cr, cr),
                       wool if j % 2 == 0 else second(wool), k=CURL_CREASE))
    for zc in ((rz * 0.98, -rz * 0.98) if w > 0 else ()):
        s.append(E((0, yb + 0.05, zc), (cr, cr, cr), wool, k=0.06))
    for i in range(4 if w > 0 else 0):
        f = i / 3.0; p = nb + (nt - nb) * f
        for th in (math.pi * 0.2, math.pi * 0.5, math.pi * 0.8):
            rr = b["neck"] * (1.2 - 0.2 * f) * 0.9
            s.append(E(p + np.array([rr * math.cos(th), rr * math.sin(th), 0.0]), (cr * 0.9, cr * 0.9, cr * 0.9), wool, k=0.06))
    s += [E((0, hy, hz), (skw, skh, skl), facec, head=True, rx=0.4),
          E((0, hy - skh * 0.6, hz + skl * 0.95), (mw, mh, ml), facec if pale is None else tuple(pale), head=True, rx=0.35, k=0.2)]
    for x in ((-skw * 0.5, 0.0, skw * 0.5) if w > 0 else ()):
        s.append(E((x, hy + skh * 0.72, hz - skl * 0.35), (cr * 0.85, cr * 0.8, cr * 0.85), wool, k=0.06))
    if b["woolly_head"]:
        s += both(E, (skw * 0.75, hy - skh * 0.1, hz - skl * 0.45), (0.3, 0.42, 0.34), wool, k=0.08)
        s.append(E((0, hy + skh * 0.55, hz + skl * 0.25), (skw * 0.7, 0.24, 0.3), wool, k=0.08))
    s += both(E, (skw + 0.3, hy + skh * 0.12, hz - skl * 0.45), (0.38, 0.12, 0.21), tuple(np.array(facec) * 0.95), rz=-0.35, k=0.08, part="ear")
    lx, lz = rx * 0.58, rz * 0.62
    for z in (lz, -lz):
        s += both(C, (lx, yb - ry * 0.45, z), (lx, 0.24, z), lr * 1.35, lr, legc)
        s += both(E, (lx, 0.15, z + 0.03), (lr * 1.15, 0.16, lr * 1.3), (0.16, 0.13, 0.12), k=0.07)
    s.append(E((0, yb + ry * 0.2, -rz * 1.0), (0.24, 0.32 * tl, 0.24), wool if pale is None else tuple(pale), k=0.1))
    if b["horns"]:
        hc = hx("a88d62"); hk = b.get("horn_k", 1.0)
        for sx in (-1, 1):
            c = np.array([sx * (skw * 0.75), hy + skh * 0.35, hz - skl * 0.5]); prev = None
            for i, t in enumerate(np.linspace(0, 1, 9)):
                a2 = 1.7 + 5.4 * t; rr = (0.5 - 0.2 * t) * hk
                p = c + np.array([sx * (0.18 + 0.34 * t) * hk, rr * math.sin(a2), -rr * math.cos(a2)])
                if prev is not None:
                    s.append(C(prev, p, 0.2 - 0.015 * i, 0.185 - 0.015 * i, hc, k=0.04))
                prev = p
    return s, [], dict(eye_k=1.4 * b.get("eye", 1.0), cleft=True)
