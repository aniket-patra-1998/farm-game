#!/usr/bin/env python3
"""Paints every crop and flower as flat pictures (docs/WORLD.md "Crops are painted pictures"): a plot of each crop part
grown and ripe, what it gives gathered (its Market picture), the one sprouting plot every crop shares, and each flower
in bud and open, single and full bloom. A picture is written as a recipe of shapes (SVG text, `.paint`), which
the game turns into a texture on the device the first time it is shown (PaintedCrops.picture): a few kilobytes
shipped, not an image.

The manner is the farm's own: no black outlines (each shape is edged in its own darker tone), flat tones with a
soft light from the upper left, the tree crowns' deep greens. A picture is 512 x 400, its plot a diamond 500 wide
round (256, 262); PaintedCrops knows those numbers.

Run: python3 tools/paint_plants.py   (writes art/painted/crops and art/painted/blooms; --check: fails if what is there is not what it paints)"""
import json, math, os, random, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..") + "/"
OUT = ROOT + "art/painted/"
SOIL = [False]   # (the game draws the bed itself: a picture is the plants alone)
W, H, CX, CY = 512, 400, 256, 262
LEAF = "#38a02a"


def rgb(c):
    c = c.lstrip("#")
    return [int(c[i:i + 2], 16) for i in (0, 2, 4)]


def hexc(v):
    return "#%02x%02x%02x" % tuple(max(0, min(255, int(round(x)))) for x in v)


def mix(a, b, t):
    A, B = rgb(a), rgb(b)
    return hexc([A[i] + (B[i] - A[i]) * t for i in range(3)])


def _hsv(c, fn):
    import colorsys
    h, s, v = colorsys.rgb_to_hsv(*[x / 255.0 for x in rgb(c)])
    h, s, v = fn(h, s, v)
    return hexc([x * 255.0 for x in colorsys.hsv_to_rgb(h % 1.0, max(0.0, min(1.0, s)), max(0.0, min(1.0, v)))])


def dark(c, t=0.3):
    """A deeper tone of `c`: darker and a little richer, never greyer (shade keeps the colour's strength)."""
    return _hsv(c, lambda h, s, v: (h, s * (1.0 + 0.25 * t), v * (1.0 - 0.8 * t)))


def light(c, t=0.3):
    """A sunlit tone of `c`: brighter, hardly paler (mixing towards white made every crop bland)."""
    return _hsv(c, lambda h, s, v: (h - 0.02 * t, s * (1.0 - 0.45 * t), v + (1.0 - v) * 0.9 * t))


class Pic:
    def __init__(self, w=W, h=H):
        self.w, self.h, self.defs, self.items, self.n = w, h, {}, [], 0

    def grad(self, c):
        """A soft light from the upper left over colour `c`."""
        if c not in self.defs:
            self.defs[c] = "g%d" % len(self.defs)
        return "url(#%s)" % self.defs[c]

    def add(self, depth, s):
        self.n += 1
        self.items.append((depth, self.n, s))

    def svg(self):
        d = "".join('<linearGradient id="%s" x1="0.15" y1="0" x2="0.85" y2="1"><stop offset="0" stop-color="%s"/>'
                    '<stop offset="0.5" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient>'
                    % (i, light(c, 0.32), c, dark(c, 0.3)) for c, i in self.defs.items() if i is not None)
        body = "".join(s for _, _, s in sorted(self.items))
        return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d"><defs>%s</defs>%s</svg>'
                % (self.w, self.h, self.w, self.h, d, body))


def tf(x, y, rot=0.0, sx=1.0, sy=None):
    return 'transform="translate(%.1f,%.1f) rotate(%.1f) scale(%.3f,%.3f)"' % (x, y, rot, sx, sx if sy is None else sy)


def shape(p, d, c, sw=2.0, edge=None, extra=""):
    return '<path d="%s" fill="%s" stroke="%s" stroke-width="%.1f" stroke-linejoin="round" %s/>' % (
        d, p.grad(c), edge or dark(c, 0.42), sw, extra)


def ell(p, cx, cy, rx, ry, c, sw=2.0, rot=0.0):
    return '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s" stroke="%s" stroke-width="%.1f" transform="rotate(%.1f %.1f %.1f)"/>' % (
        cx, cy, rx, ry, p.grad(c), dark(c, 0.42), sw, rot, cx, cy)


def shine(cx, cy, rx, ry, rot=-25, o=0.5):
    return '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="#ffffff" opacity="%.2f" transform="rotate(%d %.1f %.1f)"/>' % (
        cx, cy, rx, ry, o, rot, cx, cy)


def leaf(p, x, y, length, width, rot, c, rib=True):
    """A pointed leaf from its stalk at (x, y), pointing along `rot` (0: right, -90: up)."""
    l, w = length, width
    d = "M0,0 C%.1f,%.1f %.1f,%.1f %.1f,0 C%.1f,%.1f %.1f,%.1f 0,0 Z" % (l * 0.25, -w, l * 0.8, -w * 0.7, l, l * 0.8, w * 0.7, l * 0.25, w)
    s = "<g %s>%s" % (tf(x, y, rot), shape(p, d, c))
    if rib:
        s += '<path d="M%.1f,0 L%.1f,0" stroke="%s" stroke-width="1.6" stroke-linecap="round" opacity="0.8"/>' % (l * 0.08, l * 0.86, light(c, 0.35))
    return s + "</g>"


def stalk(x0, y0, x1, y1, bend, c, w=5.0):
    d = "M%.1f,%.1f Q%.1f,%.1f %.1f,%.1f" % (x0, y0, (x0 + x1) / 2 + bend, (y0 + y1) / 2, x1, y1)
    return ('<path d="%s" fill="none" stroke="%s" stroke-width="%.1f" stroke-linecap="round"/><path d="%s" fill="none" stroke="%s" '
            'stroke-width="%.1f" stroke-linecap="round"/>') % (d, dark(c, 0.4), w + 2.4, d, c, w)


def mound_leaves(p, r, n, size, c, up=True):
    """A clump of leaves fanning out and up from the foot: the body of any low plant."""
    s = ""
    tones = [dark(c, 0.22), c, light(c, 0.12)]
    for i in range(n):
        a = r.uniform(-175, -5) if up else r.uniform(0, 360)
        s += leaf(p, r.uniform(-4, 4), r.uniform(-3, 2), size * r.uniform(0.75, 1.1), size * r.uniform(0.3, 0.42), a, tones[i % 3])
    return s


# ---------------------------------------------------------------- produce

def fruit(p, kind, x, y, s, c):
    g = "<g %s>" % tf(x, y, 0, s)
    if kind == "round":
        g += ell(p, 0, 0, 13, 12.5, c) + shine(-4.5, -5, 4, 2.4)
    elif kind == "tomato":
        g += ell(p, 0, 0, 14, 12.5, c) + shine(-5, -5, 4.5, 2.6)
        g += '<path d="M0,-10 L-7,-14 L-2,-11 L0,-17 L2,-11 L7,-14 Z" fill="%s" stroke="%s" stroke-width="1.4"/>' % (LEAF, dark(LEAF, 0.4))
    elif kind == "heart":
        g += shape(p, "M0,15 C-16,2 -14,-12 0,-9 C14,-12 16,2 0,15 Z", c) + shine(-5, -3, 3.4, 2)
        g += "".join('<circle cx="%d" cy="%d" r="1" fill="#ffe9a8"/>' % q for q in ((-5, 3), (4, 1), (0, 8), (6, -4), (-1, -2)))
        g += '<path d="M0,-8 L-8,-13 L-2,-10 L0,-16 L2,-10 L8,-13 Z" fill="%s" stroke="%s" stroke-width="1.4"/>' % (LEAF, dark(LEAF, 0.4))
    elif kind == "bell":
        g += ell(p, -6, 1, 8, 13, c) + ell(p, 6, 1, 8, 13, c) + ell(p, 0, 2, 8, 13.5, c, 0) + shine(-6, -5, 3, 4.5, -10)
        g += '<path d="M0,-11 L1,-19" stroke="%s" stroke-width="3.6" stroke-linecap="round"/>' % dark(LEAF, 0.2)
    elif kind == "chili":
        g += shape(p, "M-4,-12 C8,-12 10,6 2,20 C-2,8 -8,0 -4,-12 Z", c) + shine(1, -4, 2, 5, -8)
        g += '<path d="M-2,-12 L-3,-19" stroke="%s" stroke-width="3" stroke-linecap="round"/>' % dark(LEAF, 0.2)
    elif kind == "eggplant":
        g += shape(p, "M0,-13 C12,-13 15,12 0,21 C-15,12 -12,-13 0,-13 Z", c) + shine(-4, 0, 2.6, 6, -8)
        g += '<path d="M-8,-11 L0,-18 L8,-11 L3,-8 L0,-12 L-3,-8 Z" fill="%s" stroke="%s" stroke-width="1.4"/>' % (LEAF, dark(LEAF, 0.4))
    elif kind == "pod":
        g += shape(p, "M-15,-4 C-6,8 8,8 16,-5 C8,2 -6,2 -15,-4 Z", c, 1.6)
        g += "".join('<circle cx="%d" cy="%.1f" r="2.6" fill="%s"/>' % (q, 1.5 - abs(q) * 0.12, light(c, 0.25)) for q in (-7, 0, 7))
    elif kind == "cluster":
        for q in ((-6, -5), (5, -6), (0, 0), (-7, 5), (6, 5), (0, 10)):
            g += ell(p, q[0], q[1], 6, 6, c, 1.4) + shine(q[0] - 2, q[1] - 2, 1.6, 1)
    elif kind == "bunch":
        for q in ((-9, -8), (0, -9), (9, -8), (-5, 0), (5, 0), (0, 8), (-9, 1), (9, 1), (0, 16)):
            g += ell(p, q[0], q[1], 6, 6, c, 1.4) + shine(q[0] - 2, q[1] - 2, 1.6, 1)
    elif kind == "boll":
        for q in ((-6, -3), (6, -3), (0, -9), (0, 3)):
            g += ell(p, q[0], q[1], 8, 7.5, c, 1.4)
    elif kind == "potato":
        g += ell(p, 0, 0, 14, 9.5, c, 2, -12) + shine(-4, -3, 4, 2)
    return g + "</g>"


# ---------------------------------------------------------------- plants (each drawn on its foot at 0,0)

def bush(p, r, leafc, kind=None, c=None, n=5, size=1.0, big=1.0):
    s = "<g %s>" % tf(0, 0, 0, size)
    s += mound_leaves(p, r, 13, 46, leafc)
    spots = [(r.uniform(-30, 30), r.uniform(-42, -8)) for _ in range(n)]
    for (x, y) in sorted(spots, key=lambda q: q[1]):
        if kind:
            s += fruit(p, kind, x, y, big, c)
    s += mound_leaves(p, r, 3, 30, leafc)
    return s + "</g>"


def staked(p, r, leafc, kind, c, n=5, big=1.0):
    """A tall plant tied to a stake, its fruit hanging where the camera sees it."""
    s = '<path d="M0,2 L0,-112" stroke="#8a6238" stroke-width="5" stroke-linecap="round"/>'
    s += stalk(0, 0, 3, -96, 6, dark(leafc, 0.1), 5)
    for i in range(9):
        y = -14 - i * 10
        s += leaf(p, 0, y, r.uniform(30, 42), r.uniform(11, 15), (-150 if i % 2 else -30) + r.uniform(-14, 14), [dark(leafc, 0.2), leafc, light(leafc, 0.1)][i % 3])
    for i in range(n):
        s += fruit(p, kind, r.uniform(-26, 26), -22 - i * (70.0 / n) + r.uniform(-5, 5), big, c)
    return s


def grain(p, r, stalkc, earc, ear="wheat", tall=96, n=9):
    s = ""
    for i in range(n):
        a = math.radians(r.uniform(-22, 22))
        h = tall * r.uniform(0.82, 1.08)
        x1, y1 = math.sin(a) * h, -math.cos(a) * h
        s += stalk(r.uniform(-5, 5), 0, x1, y1, r.uniform(-5, 5), stalkc, 2.6)
        deg = math.degrees(a)
        if ear == "wheat":
            s += "<g %s>%s" % (tf(x1, y1, deg), ell(p, 0, -13, 5.5, 16, earc, 1.6))
            s += "".join('<path d="M-5,%d L0,%d L5,%d" fill="none" stroke="%s" stroke-width="1.3"/>' % (q, q - 5, q, dark(earc, 0.35)) for q in (-4, -11, -18))
            s += '<path d="M0,-28 L0,-40 M-3,-26 L-7,-36 M3,-26 L7,-36" stroke="%s" stroke-width="1.1"/></g>' % dark(earc, 0.2)
        elif ear == "droop":
            s += "<g %s>" % tf(x1, y1, deg + 35)
            s += "".join(ell(p, 2 + q * 0.5, -q, 3.4, 4.6, earc, 1.1) for q in (2, 9, 16, 23)) + "</g>"
        elif ear == "spike":
            s += "<g %s>" % tf(x1, y1, deg)
            s += "".join(ell(p, (q % 2) * 4 - 2, -q * 4.6, 4.6, 4.2, earc, 1.1) for q in range(8)) + "</g>"
        elif ear == "plume":
            s += "<g %s>%s%s</g>" % (tf(x1, y1, deg + 14), shape(p, "M0,4 C-12,-8 -9,-34 2,-46 C13,-32 11,-8 0,4 Z", earc),
                                     "".join('<circle cx="%d" cy="%d" r="2" fill="%s"/>' % (q[0], q[1], light(earc, 0.3)) for q in ((-3, -10), (4, -20), (-2, -30), (3, -36))))
        elif ear == "spear":
            s += "<g %s>%s</g>" % (tf(x1, y1, deg), shape(p, "M-5,6 L-5,-10 C-5,-18 0,-24 0,-24 C0,-24 5,-18 5,-10 L5,6 Z", earc, 1.5))
        elif ear == "floret":
            for q in range(5):
                t = 0.45 + q * 0.13
                s += "<g %s>%s</g>" % (tf(x1 * t + (7 if q % 2 else -7), y1 * t, 0), flower_head(p, "cup", earc, light(earc, 0.5), 9))
    return s


def tall(p, r, kind, c):
    s = ""
    for k in range(2 if kind == "corn" else 4):
        x0 = (k - 0.5) * 26 if kind == "corn" else (k - 1.5) * 15
        h = r.uniform(118, 138)
        if kind == "corn":
            s += stalk(x0, 0, x0 + 2, -h, 3, "#5f9a3a", 5.5)
            for i in range(6):
                side = -1 if i % 2 else 1
                y = -18 - i * 17
                s += shape(p, "M0,0 C%d,-22 %d,-18 %d,8 C%d,-8 %d,-10 0,0 Z" % (side * 14, side * 36, side * 48, side * 34, side * 14), [LEAF, light(LEAF, 0.1), dark(LEAF, 0.15)][i % 3], 1.8, extra=tf(x0, y))
            s += "<g %s>%s%s%s</g>" % (tf(x0 + 9, -60, 14), ell(p, 0, 0, 8.5, 21, c),
                                       "".join('<path d="M-7,%d L7,%d" stroke="%s" stroke-width="1" opacity="0.6"/>' % (q, q, dark(c, 0.3)) for q in (-12, -6, 0, 6, 12)),
                                       shape(p, "M-9,22 C-12,6 -10,-2 -8,-6 C-4,6 -3,14 0,22 Z", "#7ab648", 1.6))
            s += "".join('<path d="M%.1f,%.1f l%d,-18" stroke="#d9c06a" stroke-width="2" stroke-linecap="round"/>' % (x0 + 2, -h, q) for q in (-9, -3, 3, 9))
        else:
            s += '<path d="M%.1f,0 L%.1f,%.1f" stroke="%s" stroke-width="10.5" stroke-linecap="round"/>' % (x0, x0 + 3, -h, dark(c, 0.42))
            s += '<path d="M%.1f,0 L%.1f,%.1f" stroke="%s" stroke-width="7.5" stroke-linecap="round"/>' % (x0, x0 + 3, -h, c)
            s += "".join('<path d="M%.1f,%d l9,0" stroke="%s" stroke-width="2"/>' % (x0 - 4, -q, dark(c, 0.4)) for q in range(20, int(h), 24))
            for i in range(5):
                s += leaf(p, x0 + 3, -h + i * 5, r.uniform(40, 56), 7, -90 + (i - 2) * 38 + r.uniform(-8, 8), [LEAF, light(LEAF, 0.12)][i % 2])
    return s


def head(p, r, kind, c):
    s = ""
    if kind == "cabbage":
        for a in (200, 340, 250, 290):
            s += leaf(p, 0, -6, 52, 28, a - 360, dark(c, 0.25), False)
        s += ell(p, 0, -24, 30, 26, c)
        s += shape(p, "M-28,-22 C-20,-48 14,-52 28,-30 C10,-36 -8,-34 -28,-22 Z", light(c, 0.2), 1.6)
        s += shape(p, "M-30,-18 C-12,-2 16,-2 30,-20 C22,6 -22,6 -30,-18 Z", dark(c, 0.1), 1.6) + shine(-9, -38, 8, 3.4)
    elif kind == "broccoli":
        s += mound_leaves(p, r, 9, 46, dark(LEAF, 0.1))
        s += stalk(0, -6, 0, -26, 0, "#7fae52", 9)
        for q in ((-15, -34), (15, -34), (0, -44), (-8, -27), (9, -27), (0, -33)):
            s += ell(p, q[0], q[1], 13, 11.5, c, 1.6)
        s += "".join('<circle cx="%d" cy="%d" r="2.2" fill="%s" opacity="0.8"/>' % (q[0], q[1], light(c, 0.3)) for q in ((-16, -38), (-3, -48), (12, -38), (2, -36)))
    elif kind == "artichoke":
        s += mound_leaves(p, r, 9, 50, "#6f9a66")
        s += stalk(0, -4, 0, -40, 0, "#6f9a5a", 6)
        s += ell(p, 0, -56, 19, 22, c)
        for row, y in enumerate((-46, -56, -66)):
            for q in (-10, 0, 10):
                s += shape(p, "M-7,0 L0,-11 L7,0 Z", light(c, 0.1 * row), 1.2, extra=tf(q + (5 if row % 2 else 0) - 2, y))
    elif kind == "aloe":
        for i in range(9):
            s += leaf(p, 0, 0, r.uniform(48, 66), 9, -90 + (i - 4) * 19 + r.uniform(-5, 5), [dark(c, 0.15), c, light(c, 0.12)][i % 3], False)
    else:   # a rosette of leaves: spinach, basil, tea, clover
        s += mound_leaves(p, r, 16, 44 if kind != "clover" else 30, c)
        if kind == "clover":
            for q in range(4):
                s += ell(p, r.uniform(-24, 24), r.uniform(-34, -14), 5.5, 5.5, "#f3c6dc", 1.2)
    return s


def root(p, r, kind, c):
    s = ""
    if kind == "carrot":
        for q in (-17, 0, 17):
            s += shape(p, "M-8,-2 L8,-2 L3,10 L-3,10 Z", c, 1.6, extra=tf(q, -2))
            for i in range(5):
                s += leaf(p, q, -4, r.uniform(34, 50), 6.5, -90 + (i - 2) * 16 + r.uniform(-6, 6), [light(LEAF, 0.18), LEAF][i % 2], False)
    elif kind == "onion":
        for q in (-17, 0, 17):
            for i in range(4):
                s += stalk(q, -6, q + (i - 1.5) * 9, -r.uniform(44, 58), (i - 1.5) * 3, "#5fa046", 3.4)
            s += ell(p, q, -5, 11, 9, c) + shine(q - 4, -8, 3, 1.6)
    else:   # potatoes, ginger, peanuts: a leafy top, the crop lying at its foot
        s += mound_leaves(p, r, 12, 40, LEAF)
        for q in ((-18, 2), (16, 4), (0, 8)):
            s += fruit(p, "potato", q[0], q[1], 0.9 if kind != "peanut" else 0.6, c)
    return s


def vine_leaf(p, x, y, s, rot, c):
    g = "<g %s>" % tf(x, y, rot, s, s * 0.6)
    for a in (-42, 42, 0):
        g += ell(p, 0, -20, 13, 24, c, 2.2, a).replace('transform="rotate(%.1f 0.0 -20.0)"' % a, 'transform="rotate(%d)"' % a)
    g += "".join('<path d="M0,0 L0,-34" transform="rotate(%d)" stroke="%s" stroke-width="2" stroke-linecap="round"/>' % (a, light(c, 0.35)) for a in (-42, 42, 0))
    return g + "</g>"


def gourd(p, r, kind, c, x, y):
    k = r.uniform(0.92, 1.05)
    rot = r.uniform(-28, 28)
    s = '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="#0c2c14" opacity="0.4"/>' % (x + 5, y + 40 * k, 78 * k, 26 * k)
    g = "<g %s>" % tf(x, y, rot, k)
    if kind in ("watermelon", "square_melon", "yellow_melon", "zucchini", "cucumber", "squash", "acorn"):
        rx, ry = {"watermelon": (82, 55), "square_melon": (60, 54), "yellow_melon": (70, 52), "zucchini": (88, 26), "cucumber": (80, 22),
                  "squash": (74, 40), "acorn": (56, 52)}[kind]
        cid = "c%d" % r.randint(0, 10 ** 9)
        body = '<rect x="%d" y="%d" width="%d" height="%d" rx="20"/>' % (-rx, -ry, rx * 2, ry * 2) if kind == "square_melon" else \
            '<ellipse rx="%d" ry="%d"/>' % (rx, ry)
        g += '<clipPath id="%s">%s</clipPath>' % (cid, body)
        g += body.replace("/>", ' fill="%s" stroke="%s" stroke-width="2.6"/>' % (p.grad(c), dark(c, 0.45)))
        if kind in ("watermelon", "square_melon", "acorn"):
            g += '<g clip-path="url(#%s)">' % cid
            for f in (0.0, 0.42, 0.78):
                for sg in ((1,) if f == 0 else (1, -1)):
                    d = "M%d,0 " % -rx + " ".join("L%.1f,%.1f" % (-rx * math.cos(math.pi * i / 12), -sg * ry * f * math.sin(math.pi * i / 12) + (3 if i % 2 else -3)) for i in range(1, 13))
                    g += '<path d="%s" fill="none" stroke="%s" stroke-width="%.1f" stroke-linejoin="round"/>' % (d, dark(c, 0.5 if kind != "acorn" else 0.3), 7 * (1 - 0.3 * f))
            g += "</g>"
        g += shine(-rx * 0.38, -ry * 0.5, rx * 0.22, max(ry * 0.12, 3), -12, 0.55)
    elif kind in ("pumpkin", "carnival", "pattypan"):
        ry = 44 if kind != "pattypan" else 26
        for q, rx in ((-34, 26), (34, 26), (-17, 30), (17, 30), (0, 30)):
            g += ell(p, q, 0, rx, ry, c if kind != "carnival" or abs(q) != 17 else "#4f8a3a", 2.2)
        g += shine(-22, -ry * 0.5, 9, 4, -20, 0.5)
        g += '<path d="M0,%d C2,%d 8,%d 12,%d" fill="none" stroke="%s" stroke-width="7" stroke-linecap="round"/>' % (-ry + 4, -ry - 8, -ry - 14, -ry - 16, "#5f7a34")
    elif kind == "pineapple":
        for i in range(9):
            g += leaf(p, 0, 26, r.uniform(60, 82), 9, -90 + (i - 4) * 24, ["#3f8a4a", "#5aa05a"][i % 2], False)
        g += ell(p, 0, -6, 26, 34, c)
        g += "".join('<path d="M-24,%d L24,%d M-24,%d L24,%d" stroke="%s" stroke-width="1.6" opacity="0.7"/>' % (q, q + 22, q + 22, q, dark(c, 0.4)) for q in (-34, -18, -2))
        for i in range(5):
            g += leaf(p, 0, -38, 30, 7, -90 + (i - 2) * 26, "#4f9a4a", False)
    return s + g + "</g>"


# ---------------------------------------------------------------- flowers

BUD = [False]   # (a flower is being drawn in bud)
PET = "M0,0 C-0.78,-0.12 -0.9,-0.82 -0.3,-1.0 C-0.12,-1.06 0.12,-1.06 0.3,-1.0 C0.9,-0.82 0.78,-0.12 0,0 Z"


def petal(p, ang, length, width, c, pointed=False):
    d = "M0,0 C-0.7,-0.2 -0.6,-0.7 0,-1.0 C0.6,-0.7 0.7,-0.2 0,0 Z" if pointed else PET
    gid = "pp" + c[1:]
    if gid not in p.defs:
        p.defs[gid] = None
    return ('<g transform="rotate(%.1f) scale(%.1f,%.1f)"><path d="%s" fill="url(#%s)" stroke="%s" stroke-width="%.4f" stroke-linejoin="round"/></g>'
            % (ang, width, length, d, gid, dark(c, 0.38), 3.2 / (width + length)))


def flower_head(p, kind, c, accent, r):
    if BUD[0]:
        return shape(p, 'M0,%.1f C%.1f,%.1f %.1f,%.1f 0,%.1f C%.1f,%.1f %.1f,%.1f 0,%.1f Z' % (r * 0.5, -r * 0.5, r * 0.3, -r * 0.42, -r * 0.5, -r * 0.75, r * 0.42, -r * 0.5, r * 0.5, r * 0.3, r * 0.5), '#5aa046') + shape(p, 'M%.1f,%.1f C%.1f,%.1f %.1f,%.1f 0,%.1f C%.1f,%.1f %.1f,%.1f %.1f,%.1f Z' % (-r * 0.2, -r * 0.3, -r * 0.2, -r * 0.6, -r * 0.05, -r * 0.8, -r * 0.88, r * 0.05, -r * 0.8, r * 0.2, -r * 0.6, r * 0.2, -r * 0.3), c, 1.4)
    rnd = random.Random(int(r * 977) + len(c))
    s = '<g transform="scale(1,0.9)">'

    def ring(n, length, width, col, turn, pointed=False):
        order = sorted(range(n), key=lambda i: math.cos(math.radians(turn + 360.0 * i / n)), reverse=True)
        return "".join(petal(p, turn + 360.0 * i / n + rnd.uniform(-5, 5), length, width, col, pointed) for i in order)
    if kind == "rose":
        s += ring(7, r, r * 0.6, c, 0) + ring(6, r * 0.76, r * 0.5, light(c, 0.12), 30) + ring(5, r * 0.52, r * 0.4, dark(c, 0.08), 8)
        s += ring(3, r * 0.3, r * 0.3, c, 60)
    elif kind == "ray":
        s += ring(14, r, r * 0.26, dark(c, 0.06), 12) + ring(13, r * 0.92, r * 0.26, c, 0)
        s += ell(p, 0, 0, r * 0.4, r * 0.4, accent) + "".join('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" opacity="0.6"/>' % (
            math.cos(a) * r * 0.2, math.sin(a) * r * 0.2, r * 0.05, light(accent, 0.4)) for a in (0.4, 1.9, 3.3, 4.6, 5.6))
    elif kind == "trumpet":
        s += ring(6, r, r * 0.52, c, 0, True) + ell(p, 0, 0, r * 0.4, r * 0.38, accent) + ell(p, 0, 0, r * 0.22, r * 0.2, dark(accent, 0.25), 1)
    elif kind == "cup":
        s += petal(p, -24, r * 1.25, r * 0.6, dark(c, 0.1), True) + petal(p, 24, r * 1.25, r * 0.6, dark(c, 0.1), True) + petal(p, 0, r * 1.3, r * 0.7, c, True)
    elif kind == "poppy":
        s += ring(5, r, r * 0.86, c, 0) + ell(p, 0, 0, r * 0.26, r * 0.26, accent)
        s += "".join('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="#f6dd6a"/>' % (math.cos(a) * r * 0.34, math.sin(a) * r * 0.34, r * 0.045) for a in [i * 0.785 for i in range(8)])
    elif kind == "star":
        s += ring(6, r * 1.15, r * 0.42, c, 0, True)
        s += "".join('<path d="M0,0 L%.1f,%.1f" stroke="%s" stroke-width="2"/><circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s"/>' % (
            math.cos(a) * r * 0.45, math.sin(a) * r * 0.45, light(c, 0.4), math.cos(a) * r * 0.45, math.sin(a) * r * 0.45, r * 0.07, accent) for a in (0.5, 1.6, 2.7, 3.8, 4.9, 6.0))
    elif kind == "iris":
        s += ring(3, r * 1.1, r * 0.6, dark(c, 0.12), 180) + ring(3, r * 1.05, r * 0.5, light(c, 0.1), 0)
        s += "".join('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s"/>' % (math.sin(a) * r * 0.5, -math.cos(a) * r * 0.5, r * 0.09, r * 0.2, accent) for a in (math.pi, math.pi / 3, -math.pi / 3))
    elif kind == "tiny":
        for q in ((-0.6, -0.3), (0.6, -0.35), (0, 0.45), (0, -0.9), (-0.75, 0.6), (0.75, 0.55)):
            s += '<g transform="translate(%.1f,%.1f)">%s%s</g>' % (q[0] * r, q[1] * r, ring(5, r * 0.5, r * 0.42, c, 0), ell(p, 0, 0, r * 0.12, r * 0.12, accent, 0.8))
    return s + "</g>"


def flower(p, r, kind, c, accent, tall=92, size=24, leaves=5):
    s = stalk(0, 0, r.uniform(-4, 4), -tall + size * 0.3, r.uniform(-6, 6), "#3f8f3a", 4.5)
    for i in range(leaves):
        s += leaf(p, 0, -6 - i * (tall * 0.45 / leaves), r.uniform(30, 44), r.uniform(9, 13), (-155 if i % 2 else -25) + r.uniform(-12, 12), [dark(LEAF, 0.18), LEAF, light(LEAF, 0.1)][i % 3])
    return s + '<g transform="translate(0,%.1f)">%s</g>' % (-tall, flower_head(p, kind, c, accent, size))


FLOWERS = {"sunflowers": ("ray", "#6b3e1e", 112, 30), "orange_daisies": ("ray", "#7a4a1e", 84, 22), "daffodils": ("trumpet", "#f29a1e", 84, 22),
           "morning_glory": ("poppy", "#fdf3c0", 80, 21), "red_tulips": ("cup", "#f9d27a", 88, 20), "lilies": ("star", "#e8a23a", 92, 24),
           "purple_poppies": ("poppy", "#2a1a3a", 84, 22), "columbine": ("star", "#f6e9a0", 84, 21), "iris": ("iris", "#f6d743", 92, 24),
           "white_roses": ("rose", "#f6d743", 84, 23), "pink_roses": ("rose", "#f6d743", 84, 23), "forget_me_nots": ("tiny", "#f6d743", 66, 20),
           "saffron": ("cup", "#f2902a", 60, 19)}
SPIKES = {"lilac": ("spike", 92), "lavender": ("spike", 84), "gladiolus": ("floret", 104), "amaranth": ("plume", 96), "asparagus": ("spear", 84),
          "aloe_vera": None}
GOURDS = {"pumpkins": "pumpkin", "squash": "squash", "watermelon": "watermelon", "zucchini": "zucchini", "yellow_melon": "yellow_melon",
          "acorn_squash": "acorn", "square_melon": "square_melon", "carnival_squash": "carnival", "cucumber": "cucumber",
          "pattypan_squash": "pattypan", "pineapples": "pineapple"}
FRUITS = {"tomatoes": ("tomato", True), "eggplant": ("eggplant", True), "bell_peppers": ("bell", True), "ghost_chili": ("chili", True),
          "peppers": ("bell", True), "rhubarb": None, "peas": ("pod", True), "purple_pod_peas": ("pod", True), "chickpea": ("pod", False),
          "soybeans": ("pod", False), "coffee": ("cluster", False), "grapes": ("bunch", True), "white_grapes": ("bunch", True),
          "cotton": ("boll", False), "strawberries": ("heart", False), "starter_seeds": ("heart", False)}
HEADS = {"cabbage": "cabbage", "broccoli": "broccoli", "artichokes": "artichoke", "clover": "clover"}
ROOTS = {"carrots": "carrot", "heirloom_carrots": "carrot", "onions": "onion", "potatoes": "potato", "ginger": "potato", "peanuts": "peanut"}


# How big a half-grown plot's plants are painted, of ripe ones: its bed is already mostly green.
YOUNG = 0.72


def plot(cid, shp, c, grow=1.0):
    """One plot of crop `cid` (its catalog shape and colour): ripe, or part grown (`grow` < 1: smaller, its crop still green),
    or just sprouted (`grow` 0)."""
    p = Pic()
    if 0.0 < grow < 1.0:
        c = mix(c, "#7ab648", 0.82)
    r = random.Random(sum(map(ord, cid)))
    if SOIL[0]:
        p.add(-999, '<path d="M%d,%d L%d,%d L%d,%d L%d,%d Z" fill="#7a4f2e" stroke="#4a2e1a" stroke-width="3" stroke-linejoin="round"/>' % (
            CX - 250, CY, CX, CY - 125, CX + 250, CY, CX, CY + 125))
    for i in range(-3, 4) if SOIL[0] else ():   # furrows
        p.add(-998, '<path d="M%.1f,%.1f L%.1f,%.1f" stroke="#5a381f" stroke-width="5" opacity="0.6"/>' % (
            CX + (i * 0.27 + 1) * 125 - 0, CY + (i * 0.27 - 1) * 62.5 + 62.5, CX + (i * 0.27 - 1) * 125, CY + (i * 0.27 + 1) * 62.5 - 62.5))

    def at(u, v):
        return CX + (u - v) * 125, CY + (u + v) * 62.5

    def grid(n, fn, jitter=0.05, edge=0.72, k=1.4):
        # (a row more each way than a plot strictly holds, the plants lapping over each other and the plot's edge: a
        # full, close-planted bed with hardly any soil showing, as the classic farm games' are; owner, 27 Nov)
        n += 1
        edge = min(edge + 0.08, 0.88)
        k *= 0.92 * max(grow, 0.3)
        for a in range(n):
            for b in range(n):
                u = (a / (n - 1.0) * 2 - 1) * edge + r.uniform(-jitter, jitter)
                v = (b / (n - 1.0) * 2 - 1) * edge + r.uniform(-jitter, jitter)
                x, y = at(u, v)
                p.add(y, '<g transform="translate(%.1f,%.1f) scale(%.2f)">%s</g>' % (x, y, k, fn()))
    if grow <= 0.0:
        grow = 1.0
        grid(4, lambda: leaf(p, 0, 0, 20, 8, -150 + r.uniform(-12, 12), light(LEAF, 0.15)) + leaf(p, 0, 0, 20, 8, -30 + r.uniform(-12, 12), LEAF)
             + stalk(0, 2, 0, -8, 0, "#5fa046", 2.4), 0.04, 0.78, 1.0)
    elif cid in GOURDS:
        kind = GOURDS[cid]
        for i in range(56):
            x, y = at(r.uniform(-0.99, 0.99), r.uniform(-0.99, 0.99))
            p.add(y - 60, vine_leaf(p, x, y + 8, r.uniform(1.1, 1.5), r.uniform(-70, 70), [dark(LEAF, 0.15), LEAF, "#2f7a30"][i % 3]))
        spots = [(-0.55, -0.55), (0.5, -0.6), (-0.02, 0.0), (-0.6, 0.55), (0.55, 0.52), (0.0, -0.8), (0.0, 0.84)]
        if kind in ("zucchini", "cucumber", "pattypan", "squash"):
            spots += [(-0.8, 0.0), (0.82, 0.02)]
        for (u, v) in spots:
            x, y = at(u, v)
            small = 0.62 if kind in ("pattypan",) else (0.8 if kind in ("pumpkin", "carnival", "acorn", "square_melon", "pineapple") else 1.0)
            p.add(y + 20, '<g transform="translate(%.1f,%.1f) scale(%.2f)">%s</g>' % (x, y - 20 * grow, small * (grow if grow >= 1.0 else grow * 0.75), gourd(p, r, kind, c, 0, 0)))
    elif cid in FLOWERS:
        k = FLOWERS[cid]
        grid(3, lambda: flower(p, r, k[0], c, k[1], k[2] * r.uniform(0.9, 1.08), k[3]))
    elif cid in ("lilac", "lavender", "gladiolus", "amaranth", "asparagus"):
        k = SPIKES[cid]
        grid(3, lambda: mound_leaves(p, r, 5, 34, LEAF) + grain(p, r, "#4f8f3a", c, k[0], k[1], 5 if cid != "gladiolus" else 3))
    elif cid == "aloe_vera":
        grid(3, lambda: head(p, r, "aloe", c))
    elif shp == "grain" and cid != "soybeans":
        ripe = mix(c, "#b89a4a", 0.3)
        grid(4, lambda: grain(p, r, ripe if cid != "rice" else "#7fae4a", c, "droop" if cid in ("rice", "oats") else "wheat", 92, 8), 0.06, 0.8, 1.1)
    elif cid in ("corn", "posole_corn"):
        grid(3, lambda: tall(p, r, "corn", c), 0.05, 0.72, 1.12)
    elif cid in ("sugarcane", "bamboo"):
        grid(3, lambda: tall(p, r, "cane", c), 0.05, 0.72, 1.12)
    elif cid in HEADS:
        grid(3, lambda: head(p, r, HEADS[cid], c))
    elif shp == "leafy":
        grid(3, lambda: head(p, r, "rosette", c))
    elif cid in ROOTS:
        grid(3, lambda: root(p, r, ROOTS[cid], c))
    elif cid == "rhubarb":
        grid(3, lambda: rhubarb(p, c))
    elif cid in FRUITS:
        kind, up = FRUITS[cid]
        if kind == "heart":
            grid(4, lambda: bush(p, r, LEAF, "heart", c, 4, 0.62, 1.3), 0.05, 0.8, 1.55)
        elif up:
            grid(3, lambda: staked(p, r, LEAF if "pea" not in cid else "#5aa046", kind, c, 5 if kind != "bunch" else 3, 1.0 if kind != "bunch" else 1.25), 0.05, 0.72, 1.2)
        else:
            grid(3, lambda: bush(p, r, LEAF, kind, c, 5, 0.95))
    else:   # the berries
        grid(3, lambda: bush(p, r, dark(LEAF, 0.08), "cluster", c, 5, 0.95))
    return p


def rhubarb(p, c):
    return "".join(stalk(q, 0, q * 2.2, -46, q * 0.3, c, 5.5) for q in (-10, -3, 4, 11)) + "".join(
        leaf(p, q * 2.2, -44, 44, 24, -90 + q * 2.4, [LEAF, dark(LEAF, 0.15)][i % 2]) for i, q in enumerate((-10, -3, 4, 11)))


def harvest(cid, shp, c):
    """What crop `cid` gives, gathered (256 x 256): its Market picture. What you pick, not the patch it grows in."""
    p = Pic(256, 256)
    r = random.Random(sum(map(ord, cid)) + 5)

    def put(depth, x, y, k, s):
        p.add(depth, '<g transform="translate(%.1f,%.1f) scale(%.2f)">%s</g>' % (x, y, k, s))
    if cid in GOURDS:
        kind = GOURDS[cid]
        k = 1.3 if kind in ("zucchini", "cucumber") else (1.5 if kind in ("pineapple", "pattypan") else 1.2)
        if kind not in ("pineapple", "watermelon", "square_melon", "yellow_melon"):
            put(0, 156, 112, k * 0.8, gourd(p, r, kind, c, 0, 0))
        put(1, 122, 150, k, gourd(p, r, kind, c, 0, 0))
    elif cid in FLOWERS:
        f = FLOWERS[cid]
        for i, rot in enumerate((-20, 20, 0)):
            p.add(i, '<g transform="translate(128,244) rotate(%d) scale(1.5)">%s</g>' % (rot, flower(p, r, f[0], c, f[1], 108, f[3], 3)))
    elif cid in ("lilac", "lavender", "gladiolus", "amaranth", "asparagus"):
        put(0, 128, 240, 2.0, grain(p, r, "#4f8f3a", c, SPIKES[cid][0], 96, 5))
    elif cid == "aloe_vera":
        put(0, 128, 222, 2.7, head(p, r, "aloe", c))
    elif shp == "grain" and cid != "soybeans":
        put(0, 128, 244, 2.0, grain(p, r, mix(c, "#b89a4a", 0.3), c, "droop" if cid in ("rice", "oats") else "wheat", 92, 9))
    elif cid in ("corn", "posole_corn"):
        put(0, 128, 248, 1.7, tall(p, r, "corn", c))
    elif cid in ("sugarcane", "bamboo"):
        put(0, 128, 248, 1.55, tall(p, r, "cane", c))
    elif cid in HEADS:
        put(0, 128, 206, 2.7, head(p, r, HEADS[cid], c))
    elif shp == "leafy":
        put(0, 128, 206, 2.8, head(p, r, "rosette", c))
    elif cid in ROOTS:
        put(0, 128, 196, 2.7, root(p, r, ROOTS[cid], c))
    elif cid == "rhubarb":
        put(0, 128, 226, 3.0, rhubarb(p, c))
    else:
        kind = FRUITS[cid][0] if cid in FRUITS else "cluster"
        for i, a in enumerate((200, 340)):
            put(i, 128, 150, 2.6, leaf(p, 0, 0, 44, 16, a - 360, [LEAF, dark(LEAF, 0.15)][i]))
        for i, (x, y) in enumerate(((128, 96), (88, 160), (168, 160))):
            put(10 + i, x, y, 3.3 if kind not in ("bunch", "boll") else 2.6, fruit(p, kind, 0, 0, 1.0, c))
    return p


def finish(p):
    s = p.svg()
    extra = "".join('<linearGradient id="%s" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="%s"/><stop offset="0.55" stop-color="%s"/>'
                    '<stop offset="1" stop-color="%s"/></linearGradient>' % (g, dark("#" + g[2:], 0.3), "#" + g[2:], light("#" + g[2:], 0.5))
                    for g, v in p.defs.items() if v is None)
    return s.replace("</defs>", extra + "</defs>")


def bloom(kind, c, accent, heads):
    """One flower standing in its mound of soil (`kind`: its family; `heads`: 1, or 3 for a full bloom), 256 x 330, its
    foot at (128, 300); PaintedBloom knows those numbers."""
    p = Pic(256, 330)
    r = random.Random(len(kind) * 31 + heads)
    bx, by = 128, 300
    p.add(-9, '<ellipse cx="%d" cy="%d" rx="70" ry="26" fill="%s" stroke="#4a2e1a" stroke-width="2.6"/>' % (bx, by, p.grad("#8a5c36")))
    hk, size, tallest = {"rose": ("rose", 62, 180), "tulip": ("cup", 44, 176), "daisy": ("ray", 56, 172), "sunflower": ("ray", 68, 206),
                         "lily": ("star", 58, 184), "iris": ("iris", 56, 190)}[kind]
    spots = [(0, tallest, size, 0)] if heads == 1 else [(0, tallest, size * 0.9, 0), (-60, tallest - 54, size * 0.76, -16), (62, tallest - 48, size * 0.76, 16)]
    body = ""
    wide = kind in ("tulip", "iris", "lily")
    for i in range(10):
        if wide:   # long blades from the foot
            body += leaf(p, r.uniform(-8, 8), -8, r.uniform(90, 130), 13, -90 + (i - 4.5) * 15 + r.uniform(-5, 5), [dark(LEAF, 0.2), LEAF, light(LEAF, 0.1)][i % 3])
        else:
            body += leaf(p, r.uniform(-6, 6), -14 - (i // 2) * 20, r.uniform(54, 76), r.uniform(17, 23), (-168 if i % 2 else -12) + r.uniform(-16, 16) + (i // 2) * (9 if i % 2 else -9),
                         [dark(LEAF, 0.22), LEAF, light(LEAF, 0.1)][i % 3])
    for (dx, t, sz, bend) in spots:
        body = stalk(0, -6, dx, -t + sz * 0.3, bend, "#3f8f3a", 8) + body
    for (dx, t, sz, bend) in sorted(spots, key=lambda q: -q[1]):
        body += '<g transform="translate(%.1f,%.1f)">%s</g>' % (dx, -t, flower_head(p, hk, c, accent, sz))
    p.add(0, '<g transform="translate(%d,%d)">%s</g>' % (bx, by, body))
    return p


def pictures():
    """Every picture's name and recipe."""
    out = {}
    crops = json.load(open(ROOT + "data/catalog/crops.json"))
    for fam in crops["families"]:
        for v in fam["variants"]:
            shp, col = v.get("shape", ""), v.get("color", "#6ab04c")
            out["crops/" + v["id"] + "_young"] = finish(plot(v["id"], shp, col, YOUNG))
            out["crops/" + v["id"] + "_ripe"] = finish(plot(v["id"], shp, col))
            out["crops/" + v["id"] + "_harvest"] = finish(harvest(v["id"], shp, col))
    out["crops/sprout"] = finish(plot("strawberries", "berry", "#6ab04c", 0.0))
    for fam in json.load(open(ROOT + "data/catalog/blooms.json"))["families"]:
        d = fam["defaults"]
        for heads in (1, 3):
            for look in ("bud", "open"):
                BUD[0] = look == "bud"
                out["blooms/%s_%d_%s" % (fam["id"], heads, look)] = finish(bloom(fam["id"], d["color"], d["accent"], heads))
    BUD[0] = False
    return out


if __name__ == "__main__":
    made = pictures()
    if "--check" in sys.argv:
        stale = [n for n, text in made.items() if not os.path.exists(OUT + n + ".paint") or open(OUT + n + ".paint").read() != text]
        if stale:
            sys.exit("the painted crops and flowers are not what tools/paint_plants.py paints (%d, first %s): run it" % (len(stale), stale[0]))
        print("the painted crops and flowers are up to date (%d pictures)" % len(made))
    else:
        for n, text in made.items():
            os.makedirs(os.path.dirname(OUT + n), exist_ok=True)
            open(OUT + n + ".paint", "w").write(text)
        print("painted %d pictures" % len(made))
