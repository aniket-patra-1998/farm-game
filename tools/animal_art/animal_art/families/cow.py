"""The cow family: one template, and one row of settings per breed."""
import numpy as np
import math
from ..geometry import cone, hx, torus, tube
from ..paint import second
from ..shapes import C, E, both


# ---------------------------------------------------------------- one cow template, many breeds
_C = dict(body=(1.0, 1.02, 1.7), legs=1.55, leg_r=0.27, neck=0.62, skull=(0.56, 0.56, 0.62), muzzle=(0.5, 0.42, 0.5),
          horns="nubs", udder=True, hump=0.0, pattern="solid", rel=1.0)


COWS = {
    "dairy cow": dict(_C, coat="f4f1ea", coat2="3b3330", pattern="spots", seed=1),
    "brown cow": dict(_C, coat="8a5a3a", coat2="f4f1ea", rel=0.97),
    "pink cow": dict(_C, coat="f4a8c0", coat2="fbe3ea", muzzle_col="fbe3ea", tuft="d9648f"),
    "jersey cow": dict(_C, coat="c08a50", coat2="3b2a1e", pattern="points", body=(0.94, 0.98, 1.62), rel=0.93),
    "longhorn": dict(_C, coat="b5652e", coat2="f0e6d0", pattern="spots", horns="long", udder=False, seed=6),
    "hereford cow": dict(_C, coat="8a3a1e", coat2="f6f2ea", pattern="whiteface"),
    "gelbvieh cow": dict(_C, coat="c0802a", coat2="7a4a1e"),
    "galician blond cow": dict(_C, coat="e0b070", coat2="8a6030", horns="short"),
    "red cow": dict(_C, coat="b0301e", coat2="f6f2ea"),
    "belted cow": dict(_C, coat="3a2f27", coat2="f6f2ea", pattern="belt", muzzle_col="eadfd2"),
    "bull": dict(_C, body=(1.14, 1.12, 1.82), legs=1.6, leg_r=0.31, neck=0.78, skull=(0.62, 0.6, 0.66), muzzle=(0.54, 0.45, 0.52),
                 horns="short", udder=False, hump=1.7, coat="7a4a2c", coat2="2b2420", dark_front=True, ring=True, rel=1.15),
    "ox": dict(_C, body=(1.16, 1.1, 1.85), legs=1.65, leg_r=0.32, neck=0.74, skull=(0.62, 0.6, 0.68), muzzle=(0.54, 0.45, 0.54),
               horns="up", udder=False, hump=0.9, coat="8a5a3a", coat2="3b2a1e", pattern="points", rel=1.15),
}


def cow(b):
    coat, c2 = np.array(hx(b["coat"])), np.array(hx(b["coat2"])); pink = (0.93, 0.68, 0.66)
    rx, ry, rz = b["body"]; ll = b["legs"]; lr = b["leg_r"]; pat = b["pattern"]; tl = b.get("tail_len", 1.0); HEAD = 1.35
    skw, skh, skl = (v * HEAD for v in b["skull"]); mw, mh, ml = (v * HEAD for v in b["muzzle"])
    yb = ll + ry * 0.7
    nb = np.array([0.0, yb + ry * 0.4, rz * 0.82]); nt = nb + np.array([0.0, 0.6, 0.62])
    hy, hz = nt[1] + 0.2, nt[2] + 0.34
    legc0 = None
    if pat == "spots":
        # the patches are dealt out from the animal's own number, so no two spotted cows carry the same coat
        rs = np.random.RandomState(b.get("seed", 1)); patches = []
        for i in range(7):
            ang = rs.uniform(0.15, math.pi - 0.15) * (1 if i % 2 else -1) + math.pi / 2; z = rs.uniform(-rz * 0.85, rz * 0.8)
            patches.append(((rx * math.cos(ang), yb + ry * math.sin(ang), z), tuple(rs.uniform(0.42, 0.78, 3))))
        side = -1 if b.get("seed", 1) % 2 else 1

        def bodyc(P):
            inside = np.zeros(len(P), bool)
            for pc, pr in patches:
                wob = 1 + 0.12 * np.sin(P[:, 0] * 5 + P[:, 2] * 4) * np.sin(P[:, 1] * 5)
                inside |= np.linalg.norm((P - np.array(pc)) / np.array(pr), axis=1) < wob
            return np.where(inside[:, None], c2[None, :], coat[None, :])

        headc = lambda P: np.where(((P[:, 0] * side > 0.12) & (P[:, 1] > hy - skh * 0.55) & (P[:, 2] < hz + skl * 0.75))[:, None], c2[None, :], coat[None, :])
        earc, muzc = tuple(c2), tuple(coat)
    elif pat == "belt":
        bodyc = lambda P: np.where((np.abs(P[:, 2] - 0.05) < 0.78)[:, None], c2[None, :], coat[None, :])
        headc, earc, muzc = tuple(coat), tuple(np.minimum(1, coat * 1.25)), hx(b.get("muzzle_col", "eadfd2"))
    elif pat == "whiteface":
        # a white face, chest, belly and socks on a coloured coat
        bodyc = lambda P: np.where(((P[:, 1] < yb - ry * 0.6) | ((P[:, 2] > rz * 0.62) & (P[:, 1] < yb + ry * 0.15)))[:, None], c2[None, :], coat[None, :])
        headc, earc, muzc = tuple(c2), tuple(coat), tuple(c2)
        legc0 = lambda P: np.where((P[:, 1] < ll * 0.45)[:, None], c2[None, :], coat[None, :])
    elif pat == "points":
        # dark lower legs, ears and tail tuft, a pale ring round the muzzle
        bodyc, headc, earc, muzc = tuple(coat), tuple(coat), tuple(c2), tuple(np.minimum(1, coat * 0.3 + 0.66))
        legc0 = lambda P: np.where((P[:, 1] < ll * 0.45)[:, None], c2[None, :], coat[None, :])
    elif pat == "panda":
        # white, with black ears, eye patches and legs, and a black band over the shoulders
        bodyc = lambda P: np.where(((P[:, 2] > rz * 0.28) & (P[:, 2] < rz * 0.72))[:, None], c2[None, :], coat[None, :])
        headc = lambda P: np.where(((np.abs(np.abs(P[:, 0]) - skw * 0.52) < skw * 0.3) & (np.abs(P[:, 1] - hy - skh * 0.08) < skh * 0.36) & (P[:, 2] > hz - skl * 0.1))[:, None],
                                   c2[None, :], coat[None, :])
        earc, muzc, legc0 = tuple(c2), tuple(coat), tuple(c2)
    else:
        if b.get("dark_front"):
            dk = coat * 0.66
            bodyc = lambda P: coat[None, :] + (dk - coat)[None, :] * np.clip((P[:, 2] - rz * 0.05) / (rz * 0.5), 0, 1)[:, None]
            headc = tuple(dk)
        else:
            bodyc = tuple(coat); headc = tuple(coat)
        earc = tuple(coat * 0.85); muzc = hx(b["muzzle_col"]) if b.get("muzzle_col") else tuple(np.minimum(1, coat * 0.3 + 0.66))
    legc = legc0 if legc0 is not None else tuple(coat)
    s = [E((0, yb, 0), (rx, ry, rz), bodyc), E((0, yb - 0.02, rz * 0.56), (rx * 0.98, ry * 1.04, rz * 0.45), bodyc),
         E((0, yb + 0.08, -rz * 0.6), (rx * 1.02, ry * 1.02, rz * 0.47), bodyc), C(nb, nt, b["neck"] * 1.15, b["neck"], headc if pat != "spots" else tuple(coat), k=0.3),
         E((0, hy, hz), (skw, skh, skl), headc, head=True, rx=0.35),
         E((0, hy - skh * 0.55, hz + skl * 0.95), (mw, mh, ml), muzc, head=True, rx=0.3, k=0.2),
         E((0, hy - skh * 0.68, hz + skl * 0.95 + ml * 0.72), (mw * 0.95, mh * 0.82, ml * 0.5), pink, head=True, k=0.12)]
    # a tuft of curls on the poll, between the horns, in the coat's second tone
    for dx, dz, rr in ((0.0, 0.0, 0.3), (-0.2, -0.16, 0.24), (0.2, -0.16, 0.24)):
        s.append(E((dx, hy + skh * 0.88, hz - skl * 0.12 + dz), (rr, rr * 0.8, rr), second(tuple(coat)), k=0.05))
    if b["hump"] > 0:
        s.append(E((0, yb + ry * 0.8, rz * 0.48), (rx * 0.68, 0.46 * b["hump"], 0.72), bodyc, k=0.3))
    lx, lz = rx * 0.6, rz * 0.7; hoof = (0.22, 0.17, 0.14)
    top = yb - ry * 0.35; mid = 0.3 + (top - 0.3) * 0.46
    s += both(C, (lx, top, lz), (lx, mid, lz + 0.04), lr * 1.45, lr * 1.05, legc) + both(C, (lx, mid, lz + 0.04), (lx, 0.3, lz), lr * 1.05, lr * 0.9, legc)
    s += both(E, (lx, mid, lz + 0.08), (lr * 1.12, lr * 1.2, lr * 1.12), legc, k=0.1)
    s += both(C, (lx, top, -lz), (lx, mid + 0.1, -lz - 0.2), lr * 1.55, lr * 1.08, legc) + both(C, (lx, mid + 0.1, -lz - 0.2), (lx, 0.3, -lz - 0.03), lr * 1.08, lr * 0.9, legc)
    for z in (lz, -lz - 0.03):
        s += both(E, (lx, 0.18, z + 0.03), (lr * 1.2, 0.19, lr * 1.35), hoof, k=0.07)
    s += both(E, (lx * 1.02, yb - ry * 0.2, -lz + 0.1), (lr * 1.8, ry * 0.72, 0.52), bodyc)
    s += both(E, (skw + 0.34, hy + skh * (0.3 + b.get("ear_up", 0.0)), hz - skl * 0.4), (0.44, 0.15, 0.25), earc, rz=-0.25 + b.get("ear_tilt", 0.0), k=0.08, part="ear")
    if b["udder"]:
        s.append(E((0, yb - ry * 0.98, -rz * 0.42), (0.42, 0.3, 0.45), pink, k=0.1))
    # tail: thick enough to see, carried out behind the rump before it hangs, with a big tuft in a colour that shows
    # against the coat (dark on a pale cow, pale on a dark one)
    t0 = np.array([0.0, yb + ry * 0.74, -rz * 0.97]); tm = t0 + np.array([0, -0.42, -0.62]) * tl; te = tm + np.array([0, -1.25, -0.16]) * tl
    tailc = tuple(c2) if pat == "spots" else tuple(coat)
    tuftc = hx(b["tuft"]) if b.get("tuft") else ((0.2, 0.16, 0.14) if coat.mean() > 0.5 else (0.93, 0.88, 0.8))
    s.append(C(t0, tm, 0.19, 0.14, tailc, k=0.12))
    s.append(C(tm, te, 0.14, 0.1, tailc, k=0.1))
    s.append(E(te + np.array([0, -0.22, 0]), (0.27, 0.46, 0.27), tuftc, k=0.07))
    if b.get("fur") == "shaggy":
        # a long coat: a fringe over the brow, locks down the cheeks, a ruff on the chest and a skirt of locks along the flanks
        dk = tuple(coat * 0.8); lt = tuple(np.minimum(1, coat * 1.22))
        for x in (-0.5, 0.0, 0.5):
            s.append(E((x * skw, hy + skh * 0.5 - abs(x) * 0.1, hz + skl * 0.72), (skw * 0.34, skh * 0.62, skl * 0.34), lt if x == 0 else dk, head=True, rx=0.35, k=0.07))
        s += both(E, (skw * 0.82, hy - skh * 0.35, hz + skl * 0.15), (0.24, 0.5, 0.32), dk, head=True, k=0.08)
        s.append(E((0, yb - ry * 0.3, rz * 0.98), (rx * 0.72, ry * 0.85, 0.46), dk, k=0.12))
        for i, z in enumerate(np.linspace(-rz * 0.8, rz * 0.8, 7)):
            s += both(E, (rx * 0.9, yb - ry * 0.66, z), (0.3, 0.7, 0.26), dk if i % 2 else lt, rz=0.22, k=0.06)
        for z in (lz, -lz - 0.03):
            s += both(E, (lx, 0.5, z), (lr * 1.5, 0.34, lr * 1.5), lt, k=0.07)
    hard = []
    hl = {"none": 0.0, "nubs": 0.34, "short": 0.62, "up": 0.95, "long": 1.55}[b["horns"]]
    if hl > 0:
        sweep = {"long": (1.0, 0.32, 0.0), "up": (0.45, 0.9, -0.05)}.get(b["horns"], (0.75, 0.7, -0.05))
        for sx in (-1, 1):
            base = np.array([sx * skw * 0.62, hy + skh * 0.72, hz - skl * 0.42])
            if b["horns"] == "long":
                # very long and wide: out sideways, then curving up to a dark tip
                p1 = base + np.array([sx * 0.95, 0.1, 0.0]); p2 = p1 + np.array([sx * 0.75, 0.42, 0.05]); p3 = p2 + np.array([sx * 0.3, 0.62, 0.08])
                hard += [(tube(base - np.array([sx * 0.1, 0, 0]), p1, 0.17, 0.14), hx("ece3cf")), (tube(p1, p2, 0.14, 0.1), hx("ece3cf")), (cone(p2, p3, 0.1), hx("8a7a66"))]
            else:
                hard.append((cone(base, base + np.array([sx * hl * sweep[0], hl * sweep[1], sweep[2]]), 0.11 + 0.045 * min(hl, 1.2)), hx("ece3cf")))
    if b.get("ring"):
        hard.append((torus((0, hy - skh * 0.68 - mh * 0.8, hz + skl * 0.95 + ml * 1.2), 0.27, 0.055), (0.93, 0.74, 0.22)))
    return s, hard, dict(eye_k=1.4 * b.get("eye", 1.0))
