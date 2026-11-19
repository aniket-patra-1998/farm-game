"""Unique coats: a pattern painted over an animal's own coat colour, and tufts of fur, for any family.

A row asks for them with `paint=dict(kind=..., c2=...)` and `tufts=1`; `repaint` then works on the family's finished
shapes, so no family has to know the patterns."""
import math
import numpy as np
from .geometry import hx
from .shapes import E

BANDS = 5      # the flat bands a coat takes to turn from one colour to another (see _steps)


def _span(shapes):
    """Where the animal starts and ends along its length."""
    lo, hi = [], []
    for s in shapes:
        if s["kind"] == "ell":
            lo.append(s["c"][2] - s["r"][2]); hi.append(s["c"][2] + s["r"][2])
        else:
            lo.append(min(s["a"][2], s["b"][2]) - s["ra"]); hi.append(max(s["a"][2], s["b"][2]) + s["ra"])
    return min(lo), max(hi)


def _marks(p, lo, hi):
    """Round marks dealt over the body from the coat's own number: (direction from the body's middle, size) each."""
    rs = np.random.RandomState(p.get("seed", 1)); out = []
    for _ in range(p.get("n", 30)):
        ang = rs.uniform(0, 2 * math.pi); z = rs.uniform(-0.9, 0.9); f = math.sqrt(1 - z * z)
        out.append((np.array([math.cos(ang) * f, math.sin(ang) * f, z]), rs.uniform(lo, hi)))
    return out


def _steps(t, n):
    """A blend from 0 to 1 taken in `n` even steps: a coat that turns colour does it in flat bands, so its points are
    shared within a band (a smooth blend gives every triangle its own colour and its own points: a file five times
    the size)."""
    return np.round(np.clip(t, 0, 1) * n) / n


def pattern(p, coat, body, zlo, zhi):
    """The coat as a colour for every point: `p` is the row's `paint`."""
    kind = p["kind"]; c2 = np.array(hx(p.get("c2", "ffffff"))); c, r = body["c"], body["r"]
    if kind == "stripes":       # bands round the body that lean and waver
        f = p.get("f", 9.0) / r[2]
        return lambda P: np.where((np.sin(P[:, 2] * f + P[:, 1] * f * 0.3 + 0.7 * np.sin(P[:, 0] * f * 0.6)) > 0.25)[:, None], c2[None, :], coat[None, :])
    if kind in ("stars", "dots"):   # stars: small pale marks on a coat that turns to another colour toward the tail; dots: bigger marks
        c3 = np.array(hx(p["c3"])) if p.get("c3") else coat
        marks = _marks(p, *((0.09, 0.14) if kind == "stars" else (0.14, 0.22)))

        def fn(P):
            base = coat[None, :] + (c3 - coat)[None, :] * _steps((c[2] + r[2] * 0.9 - P[:, 2]) / (r[2] * 1.8), BANDS)[:, None]
            # a mark is told by where a point lies round the body, not how far out: wool and feathers carry it too
            q = (P - c) / r; far = np.linalg.norm(q, axis=1); qn = q / np.maximum(far, 1e-6)[:, None]
            lit = np.zeros(len(P), bool)
            for md, mr in marks:
                lit |= np.linalg.norm(qn - md, axis=1) < mr
            return np.where((lit & (far > 0.55) & (far < 1.9))[:, None], c2[None, :], base)
        return fn
    if kind == "rainbow":       # a row of colours from nose to tail
        hues = np.array([hx(h) for h in p["hues"]])

        def fn(P):
            n = len(hues) - 1; t = np.minimum(_steps((zhi - P[:, 2]) / (zhi - zlo), n * p.get("steps", 2)) * n, n - 1e-6)
            i = t.astype(int); f = (t - i)[:, None]
            return hues[i] * (1 - f) + hues[np.minimum(i + 1, len(hues) - 1)] * f
        return fn
    if kind == "patches":       # a few big wavering patches
        rs = np.random.RandomState(p.get("seed", 1)); patches = []
        for i in range(7):
            ang = rs.uniform(0.15, math.pi - 0.15) * (1 if i % 2 else -1) + math.pi / 2; z = rs.uniform(-r[2] * 0.85, r[2] * 0.8)
            patches.append((c + np.array([r[0] * math.cos(ang), r[1] * math.sin(ang), z]), rs.uniform(0.25, 0.46, 3) * r[2]))

        def fn(P):
            inside = np.zeros(len(P), bool)
            for pc, pr in patches:
                wob = 1 + 0.12 * np.sin(P[:, 0] * 5 / r[2] + P[:, 2] * 4 / r[2]) * np.sin(P[:, 1] * 5 / r[2])
                inside |= np.linalg.norm((P - pc) / pr, axis=1) < wob
            return np.where(inside[:, None], c2[None, :], coat[None, :])
        return fn
    if kind == "dip":           # the coat turns to another colour toward the ground
        return lambda P: coat[None, :] + (c2 - coat)[None, :] * _steps((c[1] + r[1] * 0.25 - P[:, 1]) / (r[1] * 0.9), BANDS)[:, None]
    if kind == "band":          # a belt round the middle
        return lambda P: np.where((np.abs(P[:, 2] - c[2]) < r[2] * 0.42)[:, None], c2[None, :], coat[None, :])
    if kind == "half":          # the back half another colour
        return lambda P: np.where((P[:, 2] < c[2] + r[2] * 0.1)[:, None], c2[None, :], coat[None, :])
    raise ValueError(kind)


def repaint(shapes, b):
    """The family's shapes with the row's pattern painted wherever its coat colour shows, and its tufts of fur."""
    coat = np.array(hx(b["coat"])); body = shapes[0]
    if body["kind"] != "ell":
        body = dict(c=(body["a"] + body["b"]) / 2, r=np.array([body["ra"], body["ra"], abs(body["a"][2] - body["b"][2]) / 2 + body["ra"]]))
    if b.get("paint"):
        fn = pattern(b["paint"], coat, body, *_span(shapes))
        for s in shapes:
            col = s["col"]
            if callable(col):
                def mixed(P, old=col):
                    was = old(P)
                    return np.where((np.abs(was - coat[None, :]).max(axis=1) < 1e-4)[:, None], fn(P), was)
                s["col"] = mixed
            elif np.abs(np.array(col, float) - coat).max() < 1e-4:
                s["col"] = fn
    if b.get("tufts"):
        # curls: small lumps over the back and sides, light and dark by turns
        c, r = body["c"], body["r"]; n = 26
        for i in range(n):
            y = 0.95 - 1.35 * i / (n - 1); rad = math.sqrt(max(0.0, 1 - y * y)); ang = i * 2.39996
            at = c + np.array([r[0] * rad * math.cos(ang), r[1] * y, r[2] * rad * math.sin(ang)]) * 0.98
            shapes.append(E(at, np.array([0.24, 0.24, 0.24]) * min(r[0], r[1]), tuple(np.minimum(1, coat * (1.1 if i % 2 else 0.86))), k=0.05))
    return shapes
