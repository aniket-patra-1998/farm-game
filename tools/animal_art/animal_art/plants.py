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
SUN = np.array([0.72, 0.84, 0.25])                     # what a leaf's tip goes toward in the light
LEAF_GAIN = 0.72       # crop leaves lie open to the sun in the game's light: written this much darker, they are seen as chosen
STAGES = ("sprout", "young", "ripe", "withered")       # the game's "seeds" stage keeps its own look (bare seeds)
# what each plant measures in the game's own units, taken from the models they replace
SIZE = {"strawberries": ("width", 0.25), "wheat": ("height", 0.46), "pumpkins": ("width", 0.34), "sunflowers": ("height", 0.6),
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


def card(base, d, L, W, col, n_hint=UP, fold=0.28, droop=0.22, simple=False, produce=False, lit=None, lo=0.6, hi=1.12, glow=0.25):
    """A leaf (or petal) as a thin folded card: pointed at both ends, creased along its midrib, its tip curling
    down. It is painted as a leaf is lit: dark where it leaves the plant, light and a little yellower at its tip,
    one half a shade off the other (the crease). Eight triangles, or four when `simple`. For produce, `col` is a
    shade 0..1."""
    base = np.array(base, float); d = unit(d); n = np.array(n_hint, float) - (np.array(n_hint, float) @ d) * d
    n = unit(n) if np.linalg.norm(n) > 1e-6 else unit(np.cross(d, [1.0, 0, 0.2])); sd = np.cross(d, n)
    mid = lambda t: base + d * L * t - n * droop * L * t * t

    def paint(ts, side):
        k = (lo + (hi - lo) * np.array(ts)) * side
        if produce:
            return np.clip(k * float(np.mean(col)) / hi, 0, 1)
        c = np.array(col, float)[None, :] * k[:, None]
        return np.clip(c + (SUN - c) * (np.array(ts) * glow)[:, None], 0, 1)

    out = []
    if simple:
        w = W * 0.5; ts = (0.0, 0.5, 1.0, 0.45)
        for sgn, side in ((-1, 0.9), (1, 1.04)):
            e = mid(0.45) + sgn * sd * w + n * fold * w
            out.append(piece([mid(0.0), mid(0.5), mid(1.0), e], [[0, 1, 3], [1, 2, 3]], col, produce, face=n)); out[-1]["cols"] = paint(ts, side)
    else:
        w1, w2 = W * 0.5, W * 0.4; ts = (0.0, 0.36, 0.72, 1.0, 0.36, 0.72)
        for sgn, side in ((-1, 0.9), (1, 1.04)):
            e1, e2 = mid(0.36) + sgn * sd * w1 + n * fold * w1, mid(0.72) + sgn * sd * w2 + n * fold * w2
            out.append(piece([mid(0.0), mid(0.36), mid(0.72), mid(1.0), e1, e2], [[0, 1, 4], [1, 5, 4], [1, 2, 5], [2, 3, 5]], col, produce, face=n))
            out[-1]["cols"] = paint(ts, side)
    for p in out:
        p["lit"] = lit        # the way the light takes it (a crown's leaves are lit as the crown, not each by its own tilt)
    return out


def gem(c, r, up, down, col, n=6, produce=False):
    """A low-poly fruit or bud: a ring of points with one above and one below."""
    c = np.array(c, float); ring = [c + np.array([r * math.cos(math.tau * i / n), 0, r * math.sin(math.tau * i / n)]) for i in range(n)]
    V = ring + [c + UP * up, c - UP * down]; T = [[i, (i + 1) % n, n] for i in range(n)] + [[(i + 1) % n, i, n + 1] for i in range(n)]
    return piece(V, T, col, produce, smooth=True)


def ball(c, radii, col, n=4, produce=False, under=None):
    """A ball; with `under`, painted from that colour underneath to `col` on top (a crown's own shade)."""
    V, T = sphere(c, radii, None, n); p = piece(V, T, col, produce, smooth=True)
    if under is not None:
        k = np.clip(0.5 + 0.75 * (V[:, 1] - np.array(c)[1]) / radii[1], 0, 1)[:, None]
        p["cols"] = np.array(under, float)[None, :] * (1 - k) + np.array(col, float)[None, :] * k
    return p


def bar(a, b, ra, rb, col, n=4, tip=None):
    """A stem or trunk; with `tip`, painted from `col` at its foot to that colour at its top."""
    V, T = tube(a, b, ra, rb, n); p = piece(V, T, col)
    if tip is not None:
        a, b = np.array(a, float), np.array(b, float); k = np.clip(((V - a) @ (b - a)) / ((b - a) @ (b - a)), 0, 1)[:, None]
        p["cols"] = np.array(col, float)[None, :] * (1 - k) + np.array(tip, float)[None, :] * k
    return p


def ribbed(c, R, H, lit, dark, produce=True, n=8, rows=(-0.92, -0.45, 0.2, 0.75, 0.97)):
    """A pumpkin: a squat ball whose ribs are real (a valley between each pair of lobes), darker in the valleys
    and underneath."""
    c = np.array(c, float); V, C_ = [], []; m = 2 * n
    for y in rows:
        rad = math.sqrt(max(0.0, 1 - y * y)); low = 0.72 + 0.28 * min(1.0, (y + 1.0) / 1.2)
        for i in range(m):
            a = math.tau * i / m; k = 1.0 if i % 2 == 0 else 0.86            # lobe, valley
            V.append(c + np.array([R * rad * k * math.cos(a), H * y, R * rad * k * math.sin(a)])); C_.append((lit if i % 2 == 0 else dark) * low)
    T = []
    for j in range(len(rows) - 1):
        for i in range(m):
            a0, a1, b0, b1 = j * m + i, j * m + (i + 1) % m, (j + 1) * m + i, (j + 1) * m + (i + 1) % m
            T += [[a0, b0, a1], [a1, b0, b1]]
    top, bot = len(V), len(V) + 1
    V += [c + UP * H, c - UP * H]; C_ += [dark, dark * 0.7]
    T += [[(len(rows) - 1) * m + i, top, (len(rows) - 1) * m + (i + 1) % m] for i in range(m)] + [[i, (i + 1) % m, bot] for i in range(m)]
    p = piece(V, T, lit, produce, smooth=True); p["cols"] = np.array(C_, float)
    return p


def rosette(out, rs, n, up, reach, L, W, col, y=0.03, turn=0.0, simple=False, droop=0.25, fold=0.22, lo=0.6, hi=1.12):
    """A ring of `n` leaves round the plant's middle, each lifted by `up` and set `reach` out from it."""
    for i in range(n):
        a = math.tau * i / n + turn + rs.uniform(-0.18, 0.18); flat = np.array([math.cos(a), 0.0, math.sin(a)])
        out += card(flat * reach + UP * y, flat + UP * up, L * rs.uniform(0.9, 1.1), W, tint(col, rs), fold=fold, droop=droop, simple=simple, lo=lo, hi=hi)


# ---------------------------------------------------------------- crops (stage: sprout, young, ripe, withered)
def strawberry(stage, seed=1, leaf="4f9a36"):
    """A low mound of broad leaves, the berries out round its rim where they show."""
    rs = np.random.RandomState(seed); dry = stage == "withered"; out = []; g = DRY if dry else np.array(hx(leaf))
    if stage == "sprout":
        rosette(out, rs, 4, 0.9, 0.0, 0.3, 0.24, g * 1.05, simple=True)
        return out
    k = 0.8 if stage == "young" else 1.0
    rosette(out, rs, 7, 0.08 if dry else 0.32, 0.05, 0.62 * k, 0.5 * k, g * 0.85, droop=0.5 if dry else 0.3)
    rosette(out, rs, 5, 0.3 if dry else 0.85, 0.02, 0.5 * k, 0.42 * k, g * 1.0, y=0.1, turn=0.6, droop=0.5 if dry else 0.3)
    if not dry:
        rosette(out, rs, 3, 1.8, 0.0, 0.36 * k, 0.3 * k, g * 1.12, y=0.18, turn=0.2, simple=True)
    if stage == "ripe":
        for i in range(6):
            a = math.tau * (i + 0.5) / 6 + 0.4; r = 0.56 + 0.06 * (i % 2); p = np.array([r * math.cos(a), 0.3 + 0.08 * (i % 2), r * math.sin(a)])
            out.append(gem(p, 0.165, 0.11, 0.24, 0.8 + 0.2 * (i % 2), 6, True))
            for j in range(3):
                b = math.tau * j / 3 + i
                out += card(p + np.array([0, 0.11, 0]), (math.cos(b), -0.15, math.sin(b)), 0.16, 0.1, g * 0.8, fold=0.1, droop=0.3, simple=True)
    if stage == "young":
        for i in range(5):
            a = math.tau * i / 5 + 1.0; c = np.array([0.42 * math.cos(a), 0.42, 0.42 * math.sin(a)])
            for j in range(5):
                b = math.tau * j / 5
                out += card(c, (math.cos(b), 0.3, math.sin(b)), 0.15, 0.13, (0.99, 0.98, 0.95), fold=0.1, droop=0.1, simple=True, lo=0.9, hi=1.0, glow=0.0)
            out.append(gem(c + np.array([0, 0.03, 0]), 0.045, 0.04, 0.02, hx("f2c230"), 4))
    return out


def wheat(stage, seed=2, leaf="6f9a3a", straw="f0c040"):
    """A thick tuft of stalks, each with a plump ear and its bristles."""
    rs = np.random.RandomState(seed); green = np.array(hx(leaf)); gold = np.array(hx(straw)); out = []
    col = {"sprout": green * 1.1, "young": green, "ripe": gold, "withered": DRY}[stage]; H = {"sprout": 0.4, "young": 1.0, "ripe": 1.15, "withered": 0.62}[stage]
    lean = {"sprout": 0.3, "young": 0.2, "ripe": 0.24, "withered": 0.7}[stage]
    for i in range(6 if stage == "sprout" else 8):       # blades
        a = math.tau * i / 8 + rs.uniform(-0.3, 0.3)
        out += card((0.06 * math.cos(a), 0.02, 0.06 * math.sin(a)), (math.cos(a) * (lean + 0.25), 1.0, math.sin(a) * (lean + 0.25)), H * rs.uniform(0.6, 0.85),
                    0.13, tint(col, rs, 0.1, 0.06), n_hint=(math.cos(a), 0, math.sin(a)), fold=0.3, droop=-0.4, simple=True, lo=0.7, hi=1.1, glow=0.1)
    if stage == "sprout":
        return out
    for i in range(6 if stage == "withered" else 10):
        a = math.tau * i / 9 + 0.3; r = 0.0 if i == 0 else 0.2 * (0.6 + 0.4 * (i % 2)); out_ = np.array([math.cos(a), 0, math.sin(a)]) * (i > 0)
        base = out_ * r + UP * 0.02; d = unit(out_ * lean + UP); h = H * (1.0 if i == 0 else rs.uniform(0.82, 0.98)); top = base + d * h
        out.append(bar(base, top, 0.03, 0.022, col * 0.75, 3, tip=col))
        if stage == "withered":
            continue
        ripe = stage == "ripe"; u = unit(np.cross(d, [0.3, 0.1, 1.0]))
        for j in range(2):                               # the ear: two plump beads, the upper the smaller
            c = top + d * (0.07 + 0.17 * j); rr = 0.075 - 0.02 * j
            out.append(gem(c, rr, 0.13, 0.1, (0.6 + 0.2 * j) if ripe else green * 1.15, 5, ripe))
        for sgn in (-1, 1):                              # bristles
            out += card(top + d * 0.3, d + u * 0.35 * sgn, 0.3, 0.03, gold * 1.1 if ripe else green * 1.2, n_hint=u, fold=0.0, droop=0.0, simple=True, lo=0.9, hi=1.1, glow=0.0)
    return out


def pumpkin(stage, seed=3, leaf="3f7f32"):
    """Broad leaves sprawling low, one fat ribbed pumpkin on them."""
    rs = np.random.RandomState(seed); dry = stage == "withered"; out = []; g = DRY if dry else np.array(hx(leaf)) * 1.1
    if stage == "sprout":
        rosette(out, rs, 3, 0.7, 0.0, 0.36, 0.3, g * 1.1, simple=True)
        return out
    rosette(out, rs, 6, 0.05 if dry else 0.22, 0.25, 0.8, 0.66, g * 0.9, droop=0.4 if dry else 0.22)
    rosette(out, rs, 4, 0.3 if dry else 0.7, 0.15, 0.6, 0.5, g * 1.08, y=0.12, turn=0.5, droop=0.4 if dry else 0.22)
    if stage in ("young", "ripe"):
        R = 0.3 if stage == "young" else 0.7; cy = R * 0.86 + 0.08
        if stage == "ripe":
            out.append(ribbed((0, cy, 0), R, R * 0.86, 1.0, 0.74))
        else:
            out.append(ribbed((0, cy, 0), R, R * 0.86, np.array(hx("a8c84c")), np.array(hx("86a83c")), produce=False))
        out.append(bar((0, cy + R * 0.8, 0), (0.07, cy + R * 1.16, 0.03), 0.09, 0.06, np.array(hx("5f6f28")), 4, tip=np.array(hx("8a9a3a"))))
    if stage == "young":
        c = np.array([-0.5, 0.5, 0.45])
        for j in range(5):
            b = math.tau * j / 5
            out += card(c, (math.cos(b), 0.5, math.sin(b)), 0.24, 0.18, hx("f7c832"), fold=0.15, droop=0.3, simple=True, lo=0.85, hi=1.05, glow=0.0)
    return out


def sunflower(stage, seed=4, leaf="4f9a36"):
    """A tall stem with broad leaves and one big face of petals round a dark disc, lifted to the sky."""
    rs = np.random.RandomState(seed); dry = stage == "withered"; out = []; g = DRY if dry else np.array(hx(leaf))
    H = {"sprout": 0.45, "young": 1.5, "ripe": 1.9, "withered": 1.6}[stage]; top = np.array([0.0, H, 0.0]); thick = stage != "sprout"
    out.append(bar((0, 0.0, 0), top, 0.075 if thick else 0.035, 0.055 if thick else 0.03, g * 0.6, 5, tip=g * 0.8))
    for i in range(1 if stage == "sprout" else 3):
        y = H * (0.22 + 0.2 * i) if thick else H * 0.8
        for sgn in (-1, 1):
            a = 1.1 * i + (0 if sgn > 0 else math.pi); L = (0.3 if not thick else 0.4 if not dry else 0.3) * (1 - 0.1 * i)
            out += card((0, y, 0), (math.cos(a), -0.25 if dry else 0.4, math.sin(a)), L, L * 0.72, tint(g * 0.82, rs), fold=0.22, droop=0.4)
    if stage == "young":
        out.append(gem(top + np.array([0, 0.08, 0]), 0.17, 0.15, 0.1, g * 1.1, 6))
        for j in range(6):
            b = math.tau * j / 6; o_ = np.array([math.cos(b), 0, math.sin(b)])
            out += card(top + o_ * 0.1, o_ * 0.5 + UP, 0.3, 0.17, tint(g * 0.9, rs), n_hint=o_, fold=0.3, droop=-0.2, simple=True)
    if stage in ("ripe", "withered"):
        f = unit((0.0, 0.9, 0.42)) if not dry else unit((0.0, -0.3, 1.0)); c = top + f * 0.08; u = unit(np.cross(UP, f)); v = np.cross(f, u); hs = 0.5
        if not dry:
            for ring, (n, r0, ln, lift) in enumerate(((12, 0.24 * hs, 0.44 * hs, 0.1), (9, 0.2 * hs, 0.34 * hs, 0.42))):
                for j in range(n):
                    b = math.tau * (j + 0.5 * ring) / n; dr = math.cos(b) * u + math.sin(b) * v
                    out += card(c + dr * r0 + f * 0.03 * ring, dr * math.cos(lift) + f * math.sin(lift), ln, 0.2 * hs, 0.82 + 0.18 * ring,
                                n_hint=f, fold=0.22, droop=0.1, simple=True, produce=True, lo=0.62, hi=1.0)
        disc = np.array(hx("5a3618")) * (0.75 if dry else 1.0); R = 0.36 * hs
        ring_ = [c + (math.cos(math.tau * i / 8) * u + math.sin(math.tau * i / 8) * v) * R for i in range(8)]
        p = piece(ring_ + [c + f * 0.09, c - f * 0.08], [[i, (i + 1) % 8, 8] for i in range(8)] + [[(i + 1) % 8, i, 9] for i in range(8)], disc, smooth=True)
        p["cols"] = np.array([disc * 0.8] * 8 + [disc * 1.35, disc * 0.6]); out.append(p)
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


def apple_tree(seed=5, leaves=230, fruit="d93b30", leaf="46a634", bark="c98f58"):
    """{part name: pieces}: `body` (a slim trunk, and a crown of a few round masses clothed in leaves that lie on it
    like feathers on a bird, dark below and sunlit on top), and the fruit as the two states of `ready`."""
    rs = np.random.RandomState(seed); bark = np.array(hx(bark)); g = np.array(hx(leaf))
    tones = [g * 0.62, g * 0.82, g * 1.0, np.clip(g * 1.18 + np.array([0.06, 0.06, 0.0]), 0, 1)]
    body = [bar((0, 0.0, 0), (0.05, 3.7, 0.02), 0.24, 0.16, bark, 6, tip=bark * 0.85)]
    for i in range(4):
        a = math.tau * i / 4 + 0.4
        body.append(bar((0.06 * math.cos(a), 0.4, 0.06 * math.sin(a)), (0.46 * math.cos(a), 0.0, 0.46 * math.sin(a)), 0.15, 0.06, bark * 0.85, 3))
    c0 = np.array([0.0, 5.7, 0.0]); masses = [(c0, (2.1, 1.6, 2.1), 6), (c0 + np.array([0, 1.05, 0]), (1.45, 1.05, 1.45), 5)]
    masses += [(c0 + np.array([1.55 * math.cos(a), -0.2 + 0.3 * (i % 2), 1.55 * math.sin(a)]), (1.15, 0.95, 1.15), 4) for i, a in enumerate(np.arange(5) * math.tau / 5 + 0.2)]
    crown = [E(c, r, None, k=0.15) for c, r, _ in masses]
    body += [ball(c, r, tones[1] * 0.95, n, under=tones[0] * 0.7) for c, r, n in masses]
    ylo, yhi = c0[1] - 1.7, c0[1] + 2.2
    for i in range(leaves):                              # leaves all over the crown, lying on it, pointing out and down
        y = 1.0 - 1.72 * (i + 0.5) / leaves; rad = math.sqrt(max(0.0, 1 - y * y)); ang = i * 2.39996
        d = np.array([rad * math.cos(ang), y, rad * math.sin(ang)]); p, nrm = on_surface(crown, c0, d)
        down = -UP - (-UP @ nrm) * nrm
        if np.linalg.norm(down) < 0.3:
            down = np.array([d[0], 0.0, d[2]]) + np.array([1e-3, 0, 0])
        h = float(np.clip((p[1] - ylo) / (yhi - ylo), 0, 1)); tone = tones[int(np.clip(h * 3.2 + rs.uniform(-0.5, 0.9), 0, 3))]
        body += card(p - nrm * 0.12, unit(down) * 0.75 + nrm * 0.42 + rs.normal(size=3) * 0.12, rs.uniform(0.8, 1.05), rs.uniform(0.6, 0.74), tint(tone, rs, 0.07, 0.08),
                     n_hint=nrm, fold=0.22, droop=0.18, lit=unit((p - c0) / np.array([2.6, 2.1, 2.6]) + UP * 0.7), lo=0.72, hi=1.1, glow=0.18)
    parts = {"body": body}
    for ready, name in ((True, "when_ready_true"), (False, "when_ready_false")):
        n = 15 if ready else 8; fr = 0.4 if ready else 0.2; fc = np.array(hx(fruit)) if ready else np.array(hx("b4d050")); bits = []
        for i in range(n):
            y = 0.62 - 1.0 * (i + 0.5) / n; rad = math.sqrt(1 - y * y); ang = i * 2.39996 + 0.9
            d = np.array([rad * math.cos(ang), y, rad * math.sin(ang)]); p, nrm = on_surface(crown, c0, d); p = p + nrm * fr * 0.75
            bits.append(ball(p, (fr, fr * 0.94, fr), np.clip(fc * 1.12, 0, 1), 4, under=fc * 0.62) if ready else gem(p, fr, fr, fr, fc, 5))
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


def mesh_of(pieces, scale, linear=False, soft=0.0):
    """Pieces joined into one mesh: points, normals, colours (RGBA; produce: its shade in every channel, alpha 0),
    triangles. Cards are flat-shaded and face their `face` side; solids are smooth and face outward. `linear`:
    colours written as light (trees, drawn by the master material) and not as the game's crop shader reads them.
    `soft` (crops): a leaf that lies open to the sky faces up, and takes the sky's light this much more than its
    own tilt's, so a plant is lit as a whole and its painted shades show."""
    Vs, Ns, Cs, Ts, n = [], [], [], [], 0
    for p in pieces:
        V, T = p["V"] * scale, p["T"].copy(); face = p["face"]
        if face is not None and soft > 0 and face[1] < 0:
            face = -face
        fn = np.cross(V[T[:, 1]] - V[T[:, 0]], V[T[:, 2]] - V[T[:, 0]])
        out = np.tile(face, (len(T), 1)) if face is not None else V[T].mean(1) - V.mean(0)
        flip = (fn * out).sum(1) < 0
        T[flip] = T[flip][:, [0, 2, 1]]; fn[flip] *= -1
        ln = np.linalg.norm(fn, axis=1, keepdims=True); fn = fn / np.maximum(ln, 1e-12)
        if p.get("lit") is not None:
            fn = np.tile(p["lit"], (len(T), 1))
        elif face is not None and soft > 0:
            open_ = fn[:, 1] > 0.45; fn[open_] = fn[open_] * (1 - soft) + UP * soft
            fn /= np.linalg.norm(fn, axis=1, keepdims=True)
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
        parts = [("when_stage_" + s,) + mesh_of(stages[s], k, soft=0.6) for s in STAGES]
    else:
        tree = TREES[name](); k = _scale(name, tree["body"])
        parts = [(part,) + mesh_of(pieces, k, linear=True) for part, pieces in tree.items()]
    write_glb("%s/%s.glb" % (folder, name), parts)
    return {p[0]: len(p[4]) for p in parts}
