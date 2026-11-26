"""The horse family: one template, and one row of settings per breed."""
import numpy as np
import math
from ..geometry import hx
from ..shapes import C, E, both


# ---------------------------------------------------------------- one horse template, many breeds
HORSES = {
    "horse": dict(body=(0.8, 0.84, 1.75), legs=1.9, leg_r=0.23, neck=0.42, skull=(0.42, 0.5, 0.6), muzzle=(0.3, 0.32, 0.62),
                  mane=0.8, tail=1.15, feather=0.25, fur=0.0, coat="9a6438", points="3a2416", dark_legs=True, blaze=False,
                  socks=False, rel=1.19),
    "draft horse": dict(body=(1.0, 1.02, 1.85), legs=1.85, leg_r=0.32, neck=0.56, skull=(0.5, 0.58, 0.66), muzzle=(0.37, 0.39, 0.66),
                        mane=0.8, tail=1.1, feather=1.0, fur=0.0, coat="6e4326", points="24170f", dark_legs=False, blaze=True,
                        socks=True, rel=1.32),
    "pony": dict(body=(0.76, 0.78, 1.5), legs=1.62, leg_r=0.23, neck=0.5, skull=(0.46, 0.52, 0.58), muzzle=(0.31, 0.33, 0.5),
                 mane=1.0, tail=1.2, feather=0.35, fur=0.8, coat="c9a37a", points="6b4a2a", dark_legs=False, blaze=False,
                 socks=False, rel=0.85),
    "white stallion": dict(body=(0.8, 0.86, 1.78), legs=2.0, leg_r=0.23, neck=0.46, skull=(0.42, 0.5, 0.6), muzzle=(0.29, 0.31, 0.62),
                           mane=1.5, tail=1.45, feather=0.0, fur=0.0, coat="f4f1ea", points="a39c90", dark_legs=False,
                           blaze=False, socks=False, rel=1.22),
}


HORSES["gray horse"] = dict(HORSES["horse"], coat="a0a0a8", points="5a5a62", rel=1.19)


HORSES["black pony"] = dict(HORSES["pony"], coat="3b3536", points="1c1a1b", rel=0.85)


HORSES["mustang"] = dict(HORSES["horse"], coat="8a4a22", points="2b1a10", patches=True, mane=0.9, tail=1.2, rel=1.15)


HORSES["donkey"] = dict(body=(0.8, 0.86, 1.5), legs=1.6, leg_r=0.21, neck=0.46, skull=(0.46, 0.54, 0.64), muzzle=(0.33, 0.35, 0.6),
                        mane=0.3, tail=0.7, feather=0.0, fur=0.0, coat="9c9289", points="4a403a", dark_legs=False, blaze=False, socks=False,
                        ear_len=1.9, pale=True, no_forelock=True, tail_style="tuft", rel=0.84)


NECK_LEN = 0.68   # the horse family's neck, as a share of the first draft's


FACE_LEN = 0.68   # and how long its face runs from the eyes to the nose


def horse(b):
    coat, pts, white = np.array(hx(b["coat"])), np.array(hx(b["points"])), np.array([0.97, 0.96, 0.93])
    rx, ry, rz = b["body"]; ll = b["legs"]; lr = b["leg_r"]; mane, tail, feather, fur = b["mane"], b["tail"], b["feather"], b["fur"]
    tl = b.get("tail_len", 1.0); HEAD = 1.45
    skw, skh, skl = (v * HEAD for v in b["skull"]); mw, mh, ml = (v * HEAD for v in b["muzzle"])
    puff = 1 + 0.1 * fur
    yb = ll + ry * 0.7
    nb = np.array([0.0, yb + ry * 0.55, rz * 0.8]); nt = nb + np.array([0.0, 1.5, 0.95]) * NECK_LEN
    hy, hz = nt[1] + 0.28, nt[2] + 0.3
    if b["socks"]:
        legc = lambda P: np.where((P[:, 1] < ll * 0.42)[:, None], white[None, :], coat[None, :])
    elif b["dark_legs"]:
        legc = lambda P: np.where((P[:, 1] < ll * 0.5)[:, None], pts[None, :], coat[None, :])
    else:
        legc = tuple(coat)
    facec = tuple(coat)
    nosec = tuple(coat * 0.62 + 0.1) if not b["dark_legs"] else tuple(pts * 1.25)
    bodyc = tuple(coat)
    if b.get("patches"):
        # a pinto coat: white patches dealt out from the animal's own number
        rs = np.random.RandomState(b.get("seed", 2)); pp = []
        for i in range(9):
            ang = rs.uniform(-0.35, math.pi + 0.35); z = -rz * 0.85 + rz * 1.7 * ((i * 0.37 + rs.uniform(0, 0.2)) % 1.0)
            pp.append(((rx * math.cos(ang), yb + ry * math.sin(ang), z), tuple(rs.uniform(0.4, 0.72, 3))))

        def bodyc(P):
            inside = np.zeros(len(P), bool)
            for pc, pr in pp:
                inside |= np.linalg.norm((P - np.array(pc)) / np.array(pr), axis=1) < 1 + 0.12 * np.sin(P[:, 0] * 5 + P[:, 2] * 4)
            return np.where(inside[:, None], white[None, :], coat[None, :])
    if b.get("pale"):
        pale = np.minimum(1, coat * 0.3 + 0.66); nosec = tuple(pale)
        bodyc = lambda P: np.where((P[:, 1] < yb - ry * 0.5)[:, None], pale[None, :], coat[None, :])
    s = [E((0, yb, 0), (rx * puff, ry * puff, rz), bodyc), E((0, yb + 0.05, rz * 0.56), (rx * 0.98 * puff, ry * 1.08 * puff, rz * 0.45), bodyc),
         E((0, yb + 0.1, -rz * 0.6), (rx * 1.04 * puff, ry * 1.1 * puff, rz * 0.47), bodyc),
         C(nb, nt, b["neck"] * 1.5, b["neck"], tuple(coat)),
         E((0, hy, hz), (skw, skh, skl), facec, head=True, rx=0.5),
         E((0, hy - skh * (0.3 + 0.45 * FACE_LEN), hz + skl * (0.35 + 0.6 * FACE_LEN)), (mw, mh, ml * FACE_LEN), facec, head=True, rx=0.62, k=0.2),
         E((0, hy - skh * (0.4 + 0.9 * FACE_LEN), hz + skl * (0.45 + 1.05 * FACE_LEN)), (mw * 0.92, mh * 0.8, mw * 0.8), nosec, head=True, k=0.16)]
    lx, lz = rx * 0.6, rz * 0.72
    hoof = tuple(pts * 0.8) if b["dark_legs"] else (0.25, 0.2, 0.17)
    top = yb - ry * 0.35; mid = 0.3 + (top - 0.3) * 0.46
    # legs in two parts: a knee in front, a hock that angles back behind, narrowing to the hoof
    s += both(C, (lx, top, lz), (lx, mid, lz + 0.05), lr * 1.5, lr * 1.02, legc)
    s += both(C, (lx, mid, lz + 0.05), (lx, 0.3, lz), lr * 1.02, lr * 0.84, legc)
    s += both(E, (lx, mid, lz + 0.09), (lr * 1.12, lr * 1.25, lr * 1.15), legc, k=0.1)
    s += both(C, (lx, top, -lz), (lx, mid + 0.12, -lz - 0.26), lr * 1.6, lr * 1.05, legc)
    s += both(C, (lx, mid + 0.12, -lz - 0.26), (lx, 0.3, -lz - 0.04), lr * 1.05, lr * 0.84, legc)
    for z in (lz, -lz - 0.04):
        s += both(E, (lx, 0.18, z + 0.03), (lr * 1.2, 0.19, lr * 1.35), hoof, k=0.07)
        if feather > 0:
            s += both(E, (lx, 0.52, z - 0.06), (lr * 1.5 * feather, 0.5, lr * 1.7 * feather), tuple(white if b["socks"] else coat * 1.05), k=0.14)
    s += both(E, (lx * 1.02, yb - ry * 0.2, -lz + 0.1), (lr * 1.9, ry * 0.75, 0.55), bodyc)
    # ears: upright, set out to the sides so the forelock sits between them, not over them
    el = b.get("ear_len", 1.0)
    s += both(C, (skw * 0.62, hy + skh * 0.5, hz - skl * 0.5), (skw * (0.98 + 0.1 * (el - 1)), hy + skh * 0.5 + 0.72 * el, hz - skl * 0.62), 0.2 + 0.04 * (el - 1), 0.06, tuple(coat * 0.85), k=0.07, part="ear")
    # mane: a crest along the neck that stands clear of it, locks hanging down both sides when it is long, a forelock
    # between the ears, and a tail: how much hair is the breed's
    mc = tuple(pts)
    for i in range(6):
        f = i / 5.0; p = nt + (nb - nt) * f + np.array([0.0, 0.42 + 0.14 * mane, -0.34])
        s.append(E(p, (0.2 + 0.1 * mane, 0.36 + 0.32 * mane, 0.34), mc, k=0.06))
        if mane > 0.6:
            for sgn, big in ((-1, 1.0), (1, 0.8)):
                s.append(E(p + np.array([sgn * (0.3 + 0.08 * mane), -0.5 * mane * big, 0.0]), (0.13, 0.55 * mane * big, 0.3), mc, k=0.06))
    if not b.get("no_forelock"):
        s.append(E((0, hy + skh * 0.62, hz + skl * 0.22), (0.15 + 0.04 * mane, 0.18 + 0.14 * mane, 0.28), mc, head=False, k=0.07))
    t0 = np.array([0.0, yb + ry * 0.7, -rz * 0.98])
    if b.get("tail_style") == "tuft":
        # a donkey's tail: a thin switch carried clear of the rump, with a tuft at the end
        tm = t0 + np.array([0, -0.35, -0.55]) * tl; te = tm + np.array([0, -1.3, -0.15]) * tl
        s.append(C(t0, tm, 0.17, 0.13, tuple(coat), k=0.12)); s.append(C(tm, te, 0.13, 0.1, tuple(coat), k=0.1))
        s.append(E(te + np.array([0, -0.2, 0]), (0.24, 0.42, 0.24), mc, k=0.07))
    else:
        s.append(C(t0, t0 + np.array([0, -0.25, -0.5]) * tl, 0.2, 0.24 + 0.06 * tail, mc, k=0.12))
        te = t0 + np.array([0, -0.5 - 1.45 * tail, -0.8]) * tl
        s.append(C(t0 + np.array([0, -0.25, -0.5]) * tl, te, 0.3 + 0.12 * tail, 0.16, mc, k=0.12))
        s.append(E(te, (0.2 + 0.06 * tail, 0.3, 0.24), mc, k=0.1))
    if fur > 0:
        for i, z in enumerate(np.linspace(-rz * 0.6, rz * 0.6, 6)):
            s.append(E((0, yb - ry * 1.08 - 0.05 * (i % 2), z), (rx * 0.5, 0.22 * fur, 0.22), tuple(coat * 0.95), k=0.08))
    opt = dict(eye_k=1.55 * b.get("eye", 1.0))
    if b["blaze"]:
        opt["blaze"] = tuple(white)
    return s, [], opt
