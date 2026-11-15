"""One bird template, many kinds: chickens, turkeys, ducks, the swan and the goose. A kind is a row of settings."""
import numpy as np
import math
from ..geometry import cone, hx, sphere, tube
from ..shapes import C, E, both, plumage, shingle


# ---------------------------------------------------------------- one bird template, many kinds
# A bird is a row too: build, legs, neck (length, thickness at each end), head, the kind of tail, beak and feet, and
# the plumage. Chickens, turkeys, ducks, the swan and the goose all come from this one function.
_H = dict(body=(0.85, 0.95, 1.15), legs=0.85, neck=(1.0, 0.5, 0.42), neck_lean=0.42, head=(0.5, 0.5, 0.54), tail="hen", tail_k=1.0,
          comb=1.0, wattle=1.0, beak="beak", feet="toes", feathers=0.3, rel=0.35)


_T = dict(body=(1.15, 1.2, 1.3), legs=0.95, neck=(1.05, 0.42, 0.32), neck_lean=0.35, head=(0.42, 0.44, 0.47), tail="fan", fan_r=1.8,
          snood=True, beak="beak", beak_col="e8c060", leg_col="b8862e", feet="toes", head_col="dcb6c2", feathers=0.47, rel=0.55)


_D = dict(body=(0.85, 0.75, 1.3), legs=0.6, neck=(1.05, 0.42, 0.36), neck_lean=0.34, head=(0.5, 0.48, 0.54), tail="duck", beak="bill",
          feet="web", feathers=0.3, rel=0.38)


BIRDS = {
    "chicken": dict(_H, coat="fbfaf4", wing="ece8dc"),
    "brown chicken": dict(_H, coat="a8703e", coat2="d9b083", pattern="breast", tail_col="6a4022", wing="925c30"),
    "red chicken": dict(_H, coat="9c3a22", tail_col="2c2a30", wing="842e1a", tail_k=1.1),
    "grey chicken": dict(_H, coat="c9cdd3", coat2="868b93", pattern="barred", tail_col="6c7178"),
    "black chicken": dict(_H, coat="302e34", wing="26242a", tail_col="1f4a44", tail_k=1.3, comb=1.25),
    "golden chicken": dict(_H, coat="f2c230", coat2="fbe690", pattern="hackle", tail_col="a8701a", wing="dba520"),
    "cornish chicken": dict(_H, body=(1.0, 0.96, 1.12), legs=0.68, coat="c08a4a", coat2="2b2420", pattern="laced", comb=0.6, tail_k=0.72,
                            tail_col="3a2c22", leg_gap=1.25),
    "turkey": dict(_T, coat="8a5a3c", wing="6e452c", fan_tip="f4ece0"),
    "wild turkey": dict(_T, body=(1.05, 1.1, 1.36), legs=1.15, coat="5a3a22", wing="8a6a2e", fan_tip="c0703a", head_col="a9bbd6"),
    "baby turkey": dict(body=(0.8, 0.8, 0.92), legs=0.5, neck=(0.45, 0.46, 0.42), neck_lean=0.3, head=(0.58, 0.56, 0.6), tail="none",
                        beak="beak", beak_k=0.7, beak_col="e8c060", leg_col="d9a05a", feet="toes", coat="a07a5a", coat2="ecd7ae",
                        pattern="chick", fluff=True, wing_k=0.6, eye_k=1.28, rel=0.2),
    "duck": dict(_D, coat="fbfaf4", wing="ebe7da"),
    "belted duck": dict(_D, coat="302e34", coat2="f4f1ea", pattern="belt", wing="302e34"),
    "swan": dict(_D, body=(0.92, 0.78, 1.42), legs=0.55, neck=(3.0, 0.3, 0.2), neck_curve=True, head=(0.38, 0.36, 0.48), tail="swan",
                 coat="fbfaf4", wing="f4f1e8", wing_lift=0.16, wing_plain=True, beak_col="f2702a", knob=True, leg_col="45454a", rel=0.44),
    "ugly duckling": dict(body=(0.8, 0.76, 0.98), legs=0.42, neck=(0.5, 0.42, 0.38), neck_lean=0.3, head=(0.56, 0.54, 0.58), tail="none",
                          beak="bill", beak_k=0.8, beak_col="606066", leg_col="606066", feet="web", coat="9a9a8a", coat2="cfcfc2",
                          pattern="chick", fluff=True, scruffy=True, wing_k=0.6, eye_k=1.28, rel=0.2),
    "goose": dict(_D, body=(0.9, 0.85, 1.45), legs=0.78, neck=(1.8, 0.4, 0.3), neck_lean=0.29, head=(0.44, 0.42, 0.5), coat="f4f4f4",
                  wing="e2e2e2", feathers=0.34, rel=0.56),
}


def chunky_bird(b, body=0.9, girth=1.08, legs=0.72, head=1.3, neck=(0.8, 1.12), eye=1.25):
    """The approved chicken shape: a bigger head, a rounder body and shorter legs, by one rule for every chicken."""
    y = dict(b); rx, ry, rz = b["body"]; nl, n1, n2 = b["neck"]
    y.update(body=(rx * girth, ry * girth, rz * body), legs=b["legs"] * legs, head=tuple(v * head for v in b["head"]),
             neck=(nl * neck[0], n1 * neck[1], n2 * neck[1]), eye_k=b.get("eye_k", 1.15) * eye / 1.12,
             comb=b.get("comb", 0) * 1.15, wattle=b.get("wattle", 0) * 1.1, lid=0.72)
    return y


for _n in list(BIRDS):
    if _n.endswith("chicken"):
        BIRDS[_n] = chunky_bird(BIRDS[_n])


def bird_t(b):
    coat = np.array(hx(b["coat"])); rx, ry, rz = b["body"]; ll = b["legs"]; pat = b.get("pattern", "solid")
    acc = hx(b.get("accent", "e2453c")); legc = hx(b.get("leg_col", "f2a33a")); beakc = hx(b.get("beak_col", "f2a33a"))
    wingc = np.array(hx(b["wing"])) if b.get("wing") else coat * 0.9
    tailc = np.array(hx(b["tail_col"])) if b.get("tail_col") else coat * 0.84
    c2 = np.array(hx(b["coat2"])) if b.get("coat2") else coat * 0.6
    yb = ll + ry * 0.8
    bodyc = breastc = neckc = tuple(coat); headc = hx(b["head_col"]) if b.get("head_col") else tuple(coat); wingf = tuple(wingc)
    if pat == "barred":
        bodyc = breastc = neckc = wingf = lambda P: np.where((np.sin(P[:, 1] * 19 + P[:, 2] * 8) > 0.0)[:, None], coat[None, :], c2[None, :])
    elif pat == "laced":
        # every feather edged in black: a staggered grid of dark flecks
        bodyc = breastc = wingf = lambda P: np.where((np.sin(P[:, 1] * 15) * np.sin(P[:, 2] * 15 + P[:, 1] * 7) > 0.45)[:, None], c2[None, :], coat[None, :])
    elif pat == "belt":
        bodyc = breastc = wingf = lambda P: np.where((np.abs(P[:, 2] - rz * 0.02) < rz * 0.3)[:, None], c2[None, :], coat[None, :])
    elif pat == "breast":
        breastc = tuple(c2); bodyc = lambda P: np.where((P[:, 1] < yb - ry * 0.35)[:, None], c2[None, :], coat[None, :])
    elif pat == "hackle":
        neckc = tuple(c2)
    elif pat == "chick":
        # down: a pale belly and face, darker stripes along the back and over the crown
        dk = coat * 0.66
        stripe = lambda P: (np.abs(P[:, 0]) < 0.14) | ((np.abs(P[:, 0]) > 0.4) & (np.abs(P[:, 0]) < 0.56))
        bodyc = lambda P: np.where((P[:, 1] < yb - ry * 0.15)[:, None], c2[None, :], np.where((stripe(P) & (P[:, 1] > yb + ry * 0.45))[:, None], dk[None, :], coat[None, :]))
        breastc = tuple(c2); neckc = tuple(coat * 0.5 + c2 * 0.5)
    s = [E((0, yb, 0), (rx, ry, rz), bodyc), E((0, yb + ry * 0.1, rz * 0.42), (rx * 0.92, ry * 0.98, rz * 0.6), breastc),
         E((0, yb + ry * 0.18, -rz * 0.5), (rx * 0.8, ry * 0.76, rz * 0.55), bodyc)]
    nl, nr1, nr2 = b["neck"]; lean = b.get("neck_lean", 0.4)
    nb = np.array([0.0, yb + ry * 0.42, rz * 0.65])
    if b.get("neck_curve"):
        pts = [nb + nl * np.array([0.0, yy, zz]) for yy, zz in ((0, 0), (0.15, 0.2), (0.36, 0.27), (0.58, 0.17), (0.78, 0.06), (0.94, 0.05), (1.02, 0.15))]
    else:
        pts = [nb, nb + nl * np.array([0.0, math.cos(lean), math.sin(lean)])]
    if b.get("snood"):
        top = pts[-1][1]; red = np.array(acc) * 0.95
        neckc = lambda P: np.where((P[:, 1] > top - 0.5)[:, None], red[None, :], coat[None, :])
    for i in range(len(pts) - 1):
        f0, f1 = i / (len(pts) - 1), (i + 1) / (len(pts) - 1)
        s.append(C(pts[i], pts[i + 1], nr1 + (nr2 - nr1) * f0, nr1 + (nr2 - nr1) * f1, neckc, k=0.22 if i == 0 else 0.1))
    nt = pts[-1]; hw, hh, hl = b["head"]
    hc = nt + np.array([0.0, hh * 0.5, hl * 0.22]); hy, hz = hc[1], hc[2]; f = hh / 0.5
    if pat == "chick":
        headf = lambda P: np.where(((np.abs(P[:, 0]) < 0.15) & (P[:, 1] > hy + hh * 0.35))[:, None], (coat * 0.66)[None, :], (coat * 0.35 + c2 * 0.65)[None, :])
    elif pat == "hackle":
        headf = tuple(coat * 0.5 + c2 * 0.5)
    else:
        headf = headc
    s.append(E(hc, (hw, hh, hl), headf, head=True))
    # wings: a folded wing on each side with three long feathers stepping back behind it
    wk = b.get("wing_k", 1.0); wy = yb + ry * (0.12 + b.get("wing_lift", 0.0))
    s += both(E, (rx * 0.9, wy, -rz * 0.05), (0.22, ry * 0.6 * wk, rz * 0.66 * wk), wingf, k=0.08)
    dkw = (lambda i: tuple(wingc * (0.93 - 0.06 * i))) if (pat not in ("barred", "laced", "belt") and not b.get("wing_plain")) else (lambda i: wingf)
    fs = b.get("feathers", 0.0)
    if fs > 0:
        # real plumage: tiles of feathers over the back, sides and breast; a ruff where the neck meets the body; and
        # a wing made of two rows of short feathers with three long ones behind
        parts = [((0, yb, 0), (rx, ry, rz)), ((0, yb + ry * 0.1, rz * 0.42), (rx * 0.92, ry * 0.98, rz * 0.6)),
                 ((0, yb + ry * 0.18, -rz * 0.5), (rx * 0.8, ry * 0.76, rz * 0.55))]
        wyz = np.array([wy, -rz * 0.05]); wr = np.array([ry * 0.6 * wk, rz * 0.66 * wk]) * 0.92
        under_wing = lambda P: abs(P[0]) > rx * 0.55 and np.linalg.norm((P[1:] - wyz) / wr) < 1
        size = (fs * 0.36, fs * 0.9, fs * 1.3)
        nr_ = max(4, int(round(rz * 1.5 / (size[2] * 0.95))))
        s += plumage(parts, np.linspace(-rz * 0.74, rz * 0.74, nr_), size, bodyc, skip=under_wing, tilt=0.36)
        ax = pts[1] - pts[0]; ax = ax / np.linalg.norm(ax)
        for ri, (fr, sc) in enumerate(((0.12, 1.0), (0.5, 0.8))):
            cen = pts[0] + (pts[1] - pts[0]) * fr; rr = (nr1 + (nr2 - nr1) * fr / max(1, len(pts) - 1)) * 0.96
            e1 = np.cross(ax, [1.0, 0, 0]); e1 /= np.linalg.norm(e1); e2 = np.cross(ax, e1)
            for j in range(8):
                a = 2 * math.pi * (j + 0.5 * ri) / 8; nrm = math.cos(a) * e1 + math.sin(a) * e2
                s.append(shingle(cen + nrm * rr, nrm, -ax, (fs * 0.32 * sc, fs * 0.66 * sc, fs * 1.1 * sc), neckc, 0.34))
        wxr, wyr, wzr = 0.22, ry * 0.6 * wk, rz * 0.66 * wk
        for sx in (-1, 1):
            wc = np.array([sx * rx * 0.9, wy, -rz * 0.05])

            def on_wing(dy, dz):
                q = max(0.05, 1 - dy * dy - dz * dz)
                P = wc + np.array([sx * wxr * math.sqrt(q), dy * wyr, dz * wzr]); return P, (P - wc) / np.array([wxr, wyr, wzr]) ** 2
            for dz, rows_ in ((0.42, (0.3, -0.3)), (-0.02, (0.42, -0.05, -0.5)), (-0.44, (0.36, -0.2))):
                for dy in rows_:
                    P, nrm = on_wing(dy, dz)
                    s.append(shingle(P, nrm, (0, -0.25, -1), (0.095, wyr * 0.32, wzr * 0.34), wingf, 0.32))
            for i, dy in enumerate((0.42, 0.05, -0.32)):
                P, nrm = on_wing(dy, -0.7)
                s.append(shingle(P, nrm, (0, -0.1 + 0.18 * (1 - i), -1), (0.1, wyr * 0.2, wzr * 0.52), dkw(2), 0.16))
    for i in range(3 if (wk >= 1 and fs == 0) else 0):
        s += both(E, (rx * (0.9 - 0.07 * i), wy - ry * 0.1 + 0.1 * i + ry * b.get("wing_lift", 0.0) * 0.6 * i, -rz * (0.46 + 0.17 * i)),
                  (0.15, ry * (0.36 - 0.05 * i), rz * 0.36), dkw(i + 1), k=0.05)
    # tail
    tk = b.get("tail_k", 1.0); tail = b["tail"]
    if tail == "hen":
        base = np.array([0.0, yb + ry * 0.4, -rz * 0.78])
        for i, a in enumerate((0.2, 0.52, 0.86)):
            L = tk * (1.25 - 0.14 * i)
            s.append(E(base + L * 0.5 * np.array([0.0, math.cos(a), -math.sin(a)]), (0.2 * tk, L * 0.55, 0.27 * tk), tuple(tailc * (1 - 0.05 * i)), rx=-a, k=0.06))
        s += both(E, tuple(base + np.array([0.22, 0.42 * tk, -0.3 * tk])), (0.15, 0.5 * tk, 0.25 * tk), tuple(tailc * 0.92), rx=-0.6, k=0.06)
    elif tail == "duck":
        s.append(E((0, yb + ry * 0.38, -rz * 0.95), (rx * 0.42, 0.22, 0.52), tuple(tailc), rx=0.45, k=0.12))
    elif tail == "swan":
        s.append(E((0, yb + ry * 0.3, -rz * 0.98), (rx * 0.4, 0.24, 0.62), tuple(coat), rx=0.35, k=0.14))
    elif tail == "fan":
        base = np.array([0.0, yb + ry * 0.05, -rz * 0.62]); R = b["fan_r"]; tip = np.array(hx(b["fan_tip"])); dk = coat * 0.62

        def fanc(P):
            d = np.linalg.norm(P - base, axis=1) / R
            return np.where((d > 0.9)[:, None], tip[None, :], np.where((d > 0.74)[:, None], (dk * 0.7)[None, :], np.where((d > 0.5)[:, None], coat[None, :], dk[None, :])))
        for a in np.linspace(-1.35, 1.35, 11):
            s.append(C(base + np.array([0, 0, -0.12]), base + R * np.array([math.sin(a), math.cos(a), -0.2]), 0.2, 0.27, fanc, k=0.05))
    # down on a chick: a tuft on the crown; a scruffy one has tufts sticking out all over
    if b.get("fluff"):
        for dx, dz in ((0, 0), (-0.1, -0.12), (0.1, -0.12)):
            s.append(E((dx, hy + hh * 0.95, hz - 0.05 + dz), (0.09, 0.2, 0.09), tuple(coat * 0.66) if pat == "chick" else headf, rz=dx * 4, k=0.05))
    if b.get("scruffy"):
        for i, z in enumerate(np.linspace(-rz * 0.7, rz * 0.3, 5)):
            s.append(E(((-1) ** i * 0.22, yb + ry * 0.92, z), (0.1, 0.2, 0.12), tuple(coat * 0.8), rx=-0.5, k=0.05))
        s += both(E, (rx * 0.95, yb + ry * 0.25, -rz * 0.5), (0.12, 0.12, 0.24), tuple(coat * 0.8), k=0.05)
        s.append(E((0, yb + ry * 0.35, -rz * 0.98), (0.2, 0.18, 0.28), tuple(coat * 0.8), rx=0.5, k=0.08))
    # legs and feet
    lx = rx * 0.42 * b.get("leg_gap", 1.0); zl = 0.05; fk = max(0.7, min(1.25, rx / 0.85)); hard = []
    s += both(E, (lx, yb - ry * 0.72, zl), (0.27 * fk, 0.36, 0.3 * fk), bodyc, k=0.14)
    for sx in (-1, 1):
        x = sx * lx
        hard.append((tube((x, ll + 0.12, zl), (x, 0.06, zl), 0.105 * fk, 0.085 * fk), legc))
        if b["feet"] == "web":
            hard.append((sphere((x, 0.05, zl + 0.26 * fk), (0.28 * fk, 0.05, 0.38 * fk), None, 7), legc))
        else:
            for a in (-0.5, 0.0, 0.5):
                hard.append((cone((x, 0.07, zl), (x + 0.46 * fk * math.sin(a), 0.02, zl + 0.46 * fk * math.cos(a)), 0.075 * fk, 6), legc))
            hard.append((cone((x, 0.07, zl), (x, 0.02, zl - 0.24 * fk), 0.065 * fk, 6), legc))
    # beak or bill, and what hangs off the head
    bk = b.get("beak_k", 1.0) * f; by, bz = hy - 0.08 * f, hz + hl * 0.84
    if b["beak"] == "beak":
        hard.append((cone((0, by, bz - 0.06), (0, by - 0.13 * bk, bz + 0.5 * bk), 0.18 * bk, 8), beakc))
        hard.append((cone((0, by - 0.1 * bk, bz - 0.06), (0, by - 0.17 * bk, bz + 0.3 * bk), 0.12 * bk, 8), tuple(np.array(beakc) * 0.85)))
    else:
        hard.append((sphere((0, by - 0.06 * bk, bz + 0.3 * bk), (0.3 * bk, 0.1 * bk, 0.44 * bk), None, 8), beakc))
        hard.append((sphere((0, by - 0.15 * bk, bz + 0.2 * bk), (0.23 * bk, 0.06 * bk, 0.32 * bk), None, 8), tuple(np.array(beakc) * 0.85)))
        if b.get("knob"):
            hard.append((sphere((0, by + 0.07, bz + 0.02), (0.15, 0.14, 0.15), None, 6), (0.14, 0.13, 0.14)))
    ck = b.get("comb", 0.0)
    for i in range(3 if ck > 0 else 0):
        hard.append((sphere((0, hy + (0.5 + 0.1 * ck) * f, hz + (0.1 - 0.22 * i) * f), (0.1, (0.26 - 0.04 * i) * ck * f, 0.17 * f), None, 6), acc))
    if b.get("wattle", 0) > 0:
        hard.append((sphere((0, hy - 0.4 * f, hz + 0.38 * f), (0.1, 0.21 * b["wattle"] * f, 0.12), None, 6), acc))
    if b.get("snood"):
        hard.append((sphere((0.05, by - 0.16, bz + 0.2), (0.085, 0.3, 0.1), None, 6), acc))
        hard.append((sphere((0, hy - hh * 0.95, hz + hl * 0.35), (0.15, 0.28, 0.15), None, 6), acc))
    return s, hard, dict(mouth=False, nostril=False, eye_k=b.get("eye_k", 1.15), eye_t=0.56, eye_s=0.6, lid=b.get("lid", 0.6), wrap=True,
                         res=56 if fs > 0 else None)
