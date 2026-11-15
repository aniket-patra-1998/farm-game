"""Crops and trees in the animals' style, at the game's weight: thin creased leaf cards (each its own green), low-poly
fruit, matte. A plant is built for each of the game's growth stages and written as one file whose parts are named for
them (`when_stage_ripe`, `when_ready_true`), so the game swaps the mesh and everything else stays as it is: its
shader still grows, sways and tints the plant. Produce is marked as the game marks it (vertex alpha 0, its red channel
the shade), so one model serves every crop of that form, each in its own catalog colour."""
import math

import numpy as np

from .geometry import hx, sphere, tube
from .gltf import write_glb
from .shapes import E, field

UP = np.array([0.0, 1.0, 0.0])
GREEN, GREEN2 = np.array(hx("4fa536")), np.array(hx("3c8a2e"))
DRY, DRY2 = np.array(hx("9a7a42")), np.array(hx("6e5530"))
LEAF_GAIN = 0.8        # crop leaves lie open to the sun in the game's light: written this much darker, they are seen as chosen
STAGES = ("sprout", "young", "ripe", "withered")       # the game's "seeds" stage keeps its own look (bare seeds)
# what each plant measures in the game's own units, taken from the models they replace
SIZE = {"strawberries": ("width", 0.21), "wheat": ("height", 0.47), "pumpkins": ("width", 0.30), "sunflowers": ("height", 0.61),
        "apple_tree": ("width", 1.36)}


def unit(v):
    v = np.array(v, float); return v / np.linalg.norm(v)


def tint(col, rs, dv=0.1, warm=0.12):
    """A leaf's own colour: its kind's, a little lighter or darker and a little yellower, so no two are the same."""
    c = np.array(col, float) * rs.uniform(1 - dv, 1 + dv)
    return np.clip(c + (np.array([0.78, 0.86, 0.22]) - c) * rs.uniform(0, warm), 0, 1)


def piece(V, T, col, produce=False, smooth=False, face=None):
    """One bit of a plant: points, triangles, a colour (or, for produce, a shade 0..1), and which way its front
    faces (`face`: a direction for a flat card, or None for a closed solid, whose front is its outside)."""
    return dict(V=np.array(V, float), T=np.array(T, int), col=np.array(col, float), produce=produce, smooth=smooth, face=face)


def card(base, d, L, W, col, n_hint=UP, fold=0.28, droop=0.22, simple=False, produce=False, lit=None):
    """A leaf (or petal) as a thin folded card: pointed at both ends, creased along its midrib, its tip curling
    down. Each half takes its own shade (the crease catches the light), lighter toward the tip. Eight triangles,
    or four when `simple`."""
    base = np.array(base, float); d = unit(d); n = np.array(n_hint, float) - (np.array(n_hint, float) @ d) * d
    n = unit(n) if np.linalg.norm(n) > 1e-6 else unit(np.cross(d, [1.0, 0, 0.2])); sd = np.cross(d, n); col = np.array(col, float)
    mid = lambda t: base + d * L * t - n * droop * L * t * t
    shades = (0.86, 0.97, 1.0, 1.12) if not produce else (0.7, 0.85, 0.9, 1.0)
    tone = lambda k: (np.minimum(1, col * shades[k]) if not produce else shades[k] * float(np.mean(col)))
    if simple:
        b, c, tip = mid(0.0), mid(0.5), mid(1.0); w = W * 0.5
        l, r = mid(0.45) - sd * w + n * fold * w, mid(0.45) + sd * w + n * fold * w
        out = [piece([b, c, l, c, tip, l], [[0, 1, 2], [3, 4, 5]], tone(0), produce, face=n),
               piece([b, r, c, c, r, tip], [[0, 1, 2], [3, 4, 5]], tone(3), produce, face=n)]
        for p in out:
            p["lit"] = lit
        return out
    b, c1, c2, tip = mid(0.0), mid(0.36), mid(0.7), mid(1.0); w1, w2 = W * 0.5, W * 0.36
    l1, r1 = c1 - sd * w1 + n * fold * w1, c1 + sd * w1 + n * fold * w1
    l2, r2 = c2 - sd * w2 + n * fold * w2, c2 + sd * w2 + n * fold * w2
    two = [[0, 1, 2], [3, 4, 5]]
    out = [piece([b, c1, l1, c1, l2, l1], two, tone(0), produce, face=n), piece([c1, c2, l2, c2, tip, l2], two, tone(1), produce, face=n),
           piece([b, r1, c1, c1, r1, r2], two, tone(2), produce, face=n), piece([c1, r2, c2, c2, r2, tip], two, tone(3), produce, face=n)]
    for p in out:
        p["lit"] = lit        # the way the light takes it (a crown's leaves are lit as the crown, not each by its own tilt)
    return out


def gem(c, r, up, down, col, n=6, produce=False):
    """A low-poly fruit or bud: a ring of points with one above and one below."""
    c = np.array(c, float); ring = [c + np.array([r * math.cos(math.tau * i / n), 0, r * math.sin(math.tau * i / n)]) for i in range(n)]
    V = ring + [c + UP * up, c - UP * down]; T = [[i, (i + 1) % n, n] for i in range(n)] + [[(i + 1) % n, i, n + 1] for i in range(n)]
    return piece(V, T, col, produce, smooth=True)


def ball(c, radii, col, n=4, produce=False):
    V, T = sphere(c, radii, None, n)
    return piece(V, T, col, produce, smooth=True)


def bar(a, b, ra, rb, col, n=4):
    V, T = tube(a, b, ra, rb, n)
    return piece(V, T, col)


def ribbed(c, R, H, lit, dark, produce=True, n=8, rows=(-0.92, -0.45, 0.2, 0.75, 0.97)):
    """A pumpkin: a squat ball whose ribs are real (a valley between each pair of lobes), darker in the valleys."""
    c = np.array(c, float); V, C_ = [], []; m = 2 * n
    for y in rows:
        rad = math.sqrt(max(0.0, 1 - y * y))
        for i in range(m):
            a = math.tau * i / m; k = 1.0 if i % 2 == 0 else 0.86            # lobe, valley
            V.append(c + np.array([R * rad * k * math.cos(a), H * y, R * rad * k * math.sin(a)])); C_.append(lit if i % 2 == 0 else dark)
    T = []
    for j in range(len(rows) - 1):
        for i in range(m):
            a0, a1, b0, b1 = j * m + i, j * m + (i + 1) % m, (j + 1) * m + i, (j + 1) * m + (i + 1) % m
            T += [[a0, b0, a1], [a1, b0, b1]]
    top, bot = len(V), len(V) + 1
    V += [c + UP * H, c - UP * H]; C_ += [dark, dark]
    T += [[(len(rows) - 1) * m + i, top, (len(rows) - 1) * m + (i + 1) % m] for i in range(m)] + [[i, (i + 1) % m, bot] for i in range(m)]
    p = piece(V, T, lit, produce, smooth=True); p["cols"] = np.array(C_, float)
    return p


# ---------------------------------------------------------------- crops (stage: sprout, young, ripe, withered)
def strawberry(stage, seed=1):
    rs = np.random.RandomState(seed); dry = stage == "withered"; out = []
    g1, g2 = (DRY, DRY2) if dry else (GREEN, GREEN2)
    tiers = ((3, 0.9, 0.2, 0.05),) if stage == "sprout" else ((6, 0.1 if dry else 0.28, 0.42, 0.06), (5, 0.4 if dry else 0.75, 0.36, 0.12), (3, 1.0 if dry else 1.6, 0.26, 0.16))
    for tier, (n, up, stalk, y) in enumerate(tiers):
        for i in range(n):
            a = math.tau * (i + 0.5 * tier) / n + rs.uniform(-0.15, 0.15); d = unit((math.cos(a), up, math.sin(a))); tip = np.array([0, y, 0]) + d * stalk
            flat = unit((math.cos(a), up * 0.25, math.sin(a))); sdv = unit(np.cross(flat, UP)); base = (g2 * 0.95, g1, g1 * 1.12)[min(tier, 2)]
            k = 0.7 if stage == "sprout" else 1.0
            for turn, ln in ((0.0, 0.34), (0.85, 0.28), (-0.85, 0.28)):          # three leaflets to a leaf
                out += card(tip - flat * 0.12, flat * math.cos(turn) + sdv * math.sin(turn), (ln + 0.12) * k, ln * 0.85 * k, tint(base, rs),
                            fold=0.22, droop=0.45 if dry else 0.25, simple=True)
    if stage in ("young", "ripe"):
        for i in range(6):
            a = math.tau * (i + 0.5) / 6 + 0.4; r = 0.5 + 0.08 * (i % 2); sz = 0.6 if stage == "young" else 1.0
            p = np.array([r * math.cos(a), 0.2 * sz + 0.06 + 0.12 * (i % 2), r * math.sin(a)])
            out.append(gem(p, 0.15 * sz, 0.12 * sz, 0.2 * sz, 0.75 + 0.25 * (i % 2), 6, True) if stage == "ripe" else gem(p, 0.15 * sz, 0.12 * sz, 0.2 * sz, hx("d6e6a6")))
            for j in range(3):
                b = math.tau * j / 3 + i
                out += card(p + np.array([0, 0.11 * sz, 0]), (math.cos(b), -0.2, math.sin(b)), 0.13 * sz, 0.08 * sz, g2 * 0.9, fold=0.1, droop=0.3, simple=True)
    if stage == "young":
        for i in range(4):
            a = math.tau * i / 4 + 1.0; c = np.array([0.3 * math.cos(a), 0.5, 0.3 * math.sin(a)])
            for j in range(5):
                b = math.tau * j / 5
                out += card(c, (math.cos(b), 0.25, math.sin(b)), 0.12, 0.1, (0.99, 0.98, 0.95), fold=0.1, droop=0.1, simple=True)
            out.append(gem(c + np.array([0, 0.02, 0]), 0.035, 0.03, 0.02, hx("f2c230"), 4))
    return out


def wheat(stage, seed=2):
    rs = np.random.RandomState(seed); green = np.array(hx("6fa83a")); straw = np.array(hx("f0cf62")); out = []
    col = {"sprout": green, "young": green, "ripe": straw, "withered": DRY}[stage]; H = {"sprout": 0.42, "young": 1.2, "ripe": 1.3, "withered": 1.05}[stage]
    for i in range(7):
        a = math.tau * i / 7 + rs.uniform(-0.3, 0.3); L = H * (rs.uniform(0.6, 0.85) if stage != "sprout" else 1.0)
        out += card((0.05 * math.cos(a), 0.02, 0.05 * math.sin(a)), (math.cos(a) * (0.9 if stage == "withered" else 0.42), 1.0, math.sin(a) * (0.9 if stage == "withered" else 0.42)),
                    L, 0.11, tint(col, rs, 0.12, 0.08), n_hint=(math.cos(a), 0, math.sin(a)), fold=0.35, droop=-0.45, simple=True)
    if stage == "sprout":
        return out
    for i in range(6):
        a = math.tau * i / 5 + 0.3; r = 0.0 if i == 0 else 0.17; lean = {"young": 0.08, "ripe": 0.22, "withered": 0.5}[stage]
        base = np.array([r * math.cos(a), 0.03, r * math.sin(a)]); h = H * (1.0 if i == 0 else rs.uniform(0.85, 0.97))
        d = unit((math.cos(a) * lean * (i > 0), 1.0, math.sin(a) * lean * (i > 0))); top = base + d * h
        u = unit(np.cross(d, [0.3, 0.1, 1.0])); v = np.cross(d, u)
        out.append(bar(base, top, 0.034, 0.026, col * 0.95, 3))
        if stage == "withered":
            continue
        ripe = stage == "ripe"
        for j in range(4):                               # the ear: grains like little scales, by turns on four sides
            for q in range(2):
                b = math.pi * q + 1.57 * (j % 2); o_ = u * math.cos(b) + v * math.sin(b)
                out += card(top + d * (0.0 + 0.11 * j) + o_ * 0.02, d * 1.0 + o_ * 0.7, 0.26, 0.16, (0.75 + 0.25 * ((j + q) % 2),) * 3 if ripe else green * 1.08,
                            n_hint=o_, fold=0.3, droop=-0.1, simple=True, produce=ripe)
        out += card(top + d * 0.45, d, 0.3, 0.035, straw * 1.08 if ripe else green * 1.1, n_hint=u, fold=0.0, droop=0.0, simple=True)    # the bristle
    return out


def pumpkin(stage, seed=3):
    rs = np.random.RandomState(seed); dry = stage == "withered"; out = []; g1, g2 = (DRY, DRY2) if dry else (GREEN, GREEN2)
    tiers = ((2, 0.5, 0.16, 0.34),) if stage == "sprout" else ((6, 0.05 if dry else 0.2, 0.55, 0.7), (4, 0.3 if dry else 0.75, 0.4, 0.56))
    for tier, (n, up, stalk, L) in enumerate(tiers):
        for i in range(n):
            a = math.tau * (i + 0.5 * tier) / n + 0.5 + rs.uniform(-0.2, 0.2); d = unit((math.cos(a), up + 0.5, math.sin(a))); tip = np.array([0, 0.05, 0]) + d * stalk
            flat = unit((math.cos(a), up * 0.35, math.sin(a))); sdv = unit(np.cross(flat, UP)); bc = g2 if tier == 0 else g1
            for turn, k in ((0.0, 1.0), (0.7, 0.82), (-0.7, 0.82)):                 # a broad leaf of three lobes
                out += card(tip - flat * 0.3, flat * math.cos(turn) + sdv * math.sin(turn), L * k + 0.25, L * 0.62 * k, tint(bc, rs), fold=0.2, droop=0.4 if dry else 0.2, simple=True)
    if stage in ("young", "ripe"):
        R = 0.3 if stage == "young" else 0.66; cy = R * 0.86 + 0.08
        if stage == "ripe":
            out.append(ribbed((0, cy, 0), R, R * 0.86, 1.0, 0.72))
        else:
            out.append(ribbed((0, cy, 0), R, R * 0.86, np.array(hx("a8c84c")), np.array(hx("86a83c")), produce=False))
        out.append(bar((0, cy + R * 0.8, 0), (0.07, cy + R * 1.15, 0.03), 0.08, 0.055, np.array(hx("6b7a2e")), 4))
    if stage == "young":
        c = np.array([-0.5, 0.5, 0.45])
        for j in range(5):
            b = math.tau * j / 5
            out += card(c, (math.cos(b), 0.5, math.sin(b)), 0.2, 0.15, hx("f7c832"), fold=0.15, droop=0.3, simple=True)
    return out


def sunflower(stage, seed=4):
    rs = np.random.RandomState(seed); dry = stage == "withered"; out = []; g1, g2 = (DRY, DRY2) if dry else (GREEN, GREEN2)
    H = {"sprout": 0.45, "young": 1.6, "ripe": 1.95, "withered": 1.7}[stage]; top = np.array([0.0, H, 0.0])
    out.append(bar((0, 0.0, 0), top, 0.07 if stage != "sprout" else 0.035, 0.055 if stage != "sprout" else 0.03, g2 * 0.95, 5))
    for i in range(1 if stage == "sprout" else 3):
        y = H * (0.25 + 0.2 * i) if stage != "sprout" else H * 0.8
        for sgn in (-1, 1):
            a = 1.1 * i + (0 if sgn > 0 else math.pi); L = {"sprout": 0.3, "young": 0.38, "ripe": 0.42, "withered": 0.4}[stage] * (1 - 0.1 * i)
            out += card((0, y, 0), (math.cos(a), -0.2 if dry else 0.45, math.sin(a)), L, L * 0.65, tint(g1 if i % 2 else g2, rs), fold=0.22, droop=0.4)
    if stage == "young":
        out.append(gem(top + np.array([0, 0.08, 0]), 0.16, 0.14, 0.1, g1 * 1.05, 6))
        for j in range(6):
            b = math.tau * j / 6
            out += card(top + np.array([0.1 * math.cos(b), 0.0, 0.1 * math.sin(b)]), (math.cos(b) * 0.5, 1.0, math.sin(b) * 0.5), 0.3, 0.16, tint(g2, rs),
                        n_hint=(math.cos(b), 0, math.sin(b)), fold=0.3, droop=-0.2, simple=True)
    if stage in ("ripe", "withered"):
        f = unit((0.0, 0.95, 0.3)) if not dry else unit((0.0, -0.3, 1.0)); c = top + f * 0.1; u = unit(np.cross(UP, f)); v = np.cross(f, u)
        hs = 0.6                                         # the head's size: nine stand to a plot, and must not crowd it
        if not dry:
            for ring, (n, r0, ln, lift) in enumerate(((13, 0.26 * hs, 0.4 * hs, 0.12), (10, 0.22 * hs, 0.32 * hs, 0.42))):
                for j in range(n):
                    b = math.tau * (j + 0.5 * ring) / n; dr = math.cos(b) * u + math.sin(b) * v
                    out += card(c + dr * r0 + f * 0.03 * ring, dr * math.cos(lift) + f * math.sin(lift), ln, 0.17 * hs, (0.8 + 0.2 * ((j + ring) % 2),) * 3,
                                n_hint=f, fold=0.25, droop=0.12, simple=True, produce=True)
        disc = np.array(hx("5e3a1a")) * (0.8 if dry else 1.0); ring_ = [c + (math.cos(math.tau * i / 8) * u + math.sin(math.tau * i / 8) * v) * 0.33 * hs for i in range(8)]
        out.append(piece(ring_ + [c + f * 0.1, c - f * 0.08], [[i, (i + 1) % 8, 8] for i in range(8)] + [[(i + 1) % 8, i, 9] for i in range(8)], disc, smooth=True))
    return out


# ---------------------------------------------------------------- a tree: its body, and its fruit growing or ready
def on_surface(shapes, c0, d, far=5.5, step=0.05):
    """The point where a line from `c0` along `d` leaves the shapes, and the way the surface faces there."""
    t = far
    while t > 0.3 and field((c0 + d * t)[None, :], shapes)[0] > 0:
        t -= step
    p = c0 + d * t; e = 0.08
    g = np.array([field((p + np.eye(3)[k] * e)[None, :], shapes)[0] - field((p - np.eye(3)[k] * e)[None, :], shapes)[0] for k in range(3)])
    return p, (unit(g) if np.linalg.norm(g) > 1e-9 else d)


def apple_tree(seed=5, leaves=240, fruit="d93b30"):
    """{part name: pieces}: `body` (trunk, boughs, the dark inner crown and its leaves), and the fruit as the two
    states of `ready`."""
    rs = np.random.RandomState(seed); bark = np.array(hx("9a6a3a")); tones = [np.array(hx(h)) for h in ("2f7a2a", "3f9231", "58ab3b", "7cc247")]
    body = [bar((0, 0.0, 0), (0.07, 1.7, 0.0), 0.33, 0.25, bark, 7), bar((0.07, 1.7, 0.0), (0.0, 3.4, 0.04), 0.25, 0.2, bark * 0.92, 7)]
    for i in range(5):
        a = math.tau * i / 5 + 0.4
        body.append(bar((0.08 * math.cos(a), 0.45, 0.08 * math.sin(a)), (0.62 * math.cos(a), 0.0, 0.62 * math.sin(a)), 0.2, 0.08, bark * 0.8, 3))
    for i in range(3):
        a = math.tau * i / 3 + 1.0
        body.append(bar((0, 3.0, 0), (1.3 * math.cos(a), 4.4, 1.3 * math.sin(a)), 0.2, 0.12, bark * 0.86, 4))
    c0 = np.array([0.0, 5.8, 0.0]); inner = tones[1] * 0.8
    crown = [E(c0, (2.15, 1.65, 2.15), None, k=0.15), E(c0 + np.array([0, 1.1, 0]), (1.5, 1.1, 1.5), None, k=0.15)]
    crown += [E(c0 + np.array([1.8 * math.cos(a), -0.25 + 0.3 * (i % 2), 1.8 * math.sin(a)]), (1.15, 1.0, 1.15), None, k=0.15)
              for i, a in enumerate(np.arange(6) * math.tau / 6 + 0.2)]
    body += [ball(c0 - UP * 0.1, (2.0, 1.5, 2.0), inner, 5), ball(c0 + np.array([0, 1.0, 0]), (1.4, 1.0, 1.4), inner * 1.05, 4)]
    ylo, yhi = c0[1] - 1.9, c0[1] + 2.3
    for i in range(leaves):                              # thin pointed leaves all over the crown, hanging out and down
        y = 1.0 - 1.75 * (i + 0.5) / leaves; rad = math.sqrt(max(0.0, 1 - y * y)); ang = i * 2.39996
        d = np.array([rad * math.cos(ang), y, rad * math.sin(ang)]); p, nrm = on_surface(crown, c0, d)
        down = -UP - (-UP @ nrm) * nrm
        if np.linalg.norm(down) < 0.35:
            down = np.array([d[0], 0.0, d[2]]) + np.array([1e-3, 0, 0])
        tone = tones[int(np.clip((p[1] - ylo) / (yhi - ylo) * 4 + rs.uniform(-0.8, 0.8), 0, 3))]
        body += card(p - nrm * 0.25, unit(down) * 0.7 + nrm * 0.7 + rs.normal(size=3) * 0.15, rs.uniform(0.95, 1.25), rs.uniform(0.55, 0.7), tint(tone, rs, 0.08, 0.1),
                     n_hint=nrm, fold=0.25, droop=0.2, lit=unit((p - c0) / np.array([2.6, 2.1, 2.6]) + UP * 0.45))
    parts = {"body": body}
    for ready, name in ((True, "when_ready_true"), (False, "when_ready_false")):
        n = 16 if ready else 7; fr = 0.36 if ready else 0.18; fc = np.array(hx(fruit)) if ready else np.array(hx("a8c84c")); bits = []
        for i in range(n):
            y = 0.55 - 0.95 * (i + 0.5) / n; rad = math.sqrt(1 - y * y); ang = i * 2.39996 + 0.9
            d = np.array([rad * math.cos(ang), y, rad * math.sin(ang)]); p = on_surface(crown, c0, d)[0] + d * (0.45 + fr * 0.5)
            bits.append(ball(p, (fr, fr * 0.94, fr), fc, 4) if ready else gem(p, fr, fr, fr, fc, 5))
        parts[name] = bits
    return parts


CROPS = {"strawberries": strawberry, "wheat": wheat, "pumpkins": pumpkin, "sunflowers": sunflower}
TREES = {"apple_tree": apple_tree}


# ---------------------------------------------------------------- from pieces to a mesh, and to a file
def to_linear(c):
    """A screen colour as the light it stands for (the game's file material multiplies light, so a colour written
    this way is seen as it was chosen)."""
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def mesh_of(pieces, scale, linear=False):
    """Pieces joined into one mesh: points, normals, colours (RGBA; produce: its shade in every channel, alpha 0),
    triangles. Cards are flat-shaded and face their `face` side; solids are smooth and face outward. `linear`:
    colours written as light (trees, drawn by the master material) and not as the game's crop shader reads them."""
    Vs, Ns, Cs, Ts, n = [], [], [], [], 0
    for p in pieces:
        V, T = p["V"] * scale, p["T"].copy()
        fn = np.cross(V[T[:, 1]] - V[T[:, 0]], V[T[:, 2]] - V[T[:, 0]])
        out = np.tile(p["face"], (len(T), 1)) if p["face"] is not None else V[T].mean(1) - V.mean(0)
        flip = (fn * out).sum(1) < 0
        T[flip] = T[flip][:, [0, 2, 1]]; fn[flip] *= -1
        ln = np.linalg.norm(fn, axis=1, keepdims=True); fn = fn / np.maximum(ln, 1e-12)
        if p.get("lit") is not None:
            fn = np.tile(p["lit"], (len(T), 1))
        if p["smooth"]:
            N = np.zeros_like(V)
            for k in range(3):
                np.add.at(N, T[:, k], fn * ln)
            N /= np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-12); Vp, Tp = V, T; idx = np.arange(len(V))
        else:
            Vp = V[T].reshape(-1, 3); N = np.repeat(fn, 3, axis=0); Tp = np.arange(len(Vp)).reshape(-1, 3); idx = T.reshape(-1)
        cols = p.get("cols")
        if p["produce"]:
            shade = (cols[idx] if cols is not None else np.full(len(idx), float(np.mean(p["col"]))))
            C = np.c_[shade, shade, shade, np.zeros(len(idx))]
        else:
            rgb = cols[idx] if cols is not None else np.tile(np.clip(p["col"], 0, 1), (len(idx), 1))
            C = np.c_[to_linear(rgb) if linear else np.clip(rgb * LEAF_GAIN, 0, 1), np.ones(len(idx))]
        Vs.append(Vp); Ns.append(N); Cs.append(C); Ts.append(Tp + n); n += len(Vp)
    return np.vstack(Vs), np.vstack(Ns), np.vstack(Cs), np.vstack(Ts)


def _scale(name, pieces):
    V = np.vstack([p["V"] for p in pieces]); what, size = SIZE[name]
    span = (V[:, 1].max() - 0.0) if what == "height" else max(V[:, 0].max() - V[:, 0].min(), V[:, 2].max() - V[:, 2].min())
    return size / span


def export(name, folder):
    """Writes `<folder>/<name>.glb` and returns {part: triangles}."""
    if name in CROPS:
        stages = {s: CROPS[name](s) for s in STAGES}; k = _scale(name, stages["ripe"])
        parts = [("when_stage_" + s,) + mesh_of(stages[s], k) for s in STAGES]
    else:
        tree = TREES[name](); k = _scale(name, tree["body"])
        parts = [(part,) + mesh_of(pieces, k, linear=True) for part, pieces in tree.items()]
    write_glb("%s/%s.glb" % (folder, name), parts)
    return {p[0]: len(p[4]) for p in parts}
