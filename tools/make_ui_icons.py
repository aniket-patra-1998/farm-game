#!/usr/bin/env python3
"""The interface's icons as smooth vector files (our own look): art/icons/ui/<kind>.svg, read by UiSvg and drawn
crisp at any size. Each icon is a few shapes, each filled with a soft top-lit gradient of its colour, a dark ink
outline and a white sticker edge round the whole, plus glossy highlights. Run: python3 tools/make_ui_icons.py"""
import colorsys, math, os

INK = "#3b2414"
OUT = os.path.join(os.path.dirname(__file__), "..", "art", "icons", "ui")
EDGE, LINE = 11.0, 4.5


def shade(hexc, k):
    r, g, b = (int(hexc[i:i + 2], 16) / 255 for i in (1, 3, 5))
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    l = max(0, min(1, l + k))
    r, g, b = colorsys.hls_to_rgb(h, l, min(1, s * (1.05 if k > 0 else 1)))
    return "#%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255))


def star(cx, cy, R, r, n=5, turn=-90):
    pts = []
    for k in range(n * 2):
        a = math.radians(turn + 180 * k / n)
        rr = R if k % 2 == 0 else r
        pts.append("%.1f %.1f" % (cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    return "M" + " L".join(pts) + " Z"


def gear(cx, cy, R, r, n=8):
    pts = []
    for k in range(n):
        a0 = 2 * math.pi * k / n
        for da, rad in ((-0.2, r), (-0.12, R), (0.12, R), (0.2, r)):
            a = a0 + da
            pts.append("%.1f %.1f" % (cx + math.cos(a) * rad, cy + math.sin(a) * rad))
    return "M" + " L".join(pts) + " Z"


# A part: (shape element, attributes, colour) — colour None: a highlight (white, see-through, no outline);
# ("line", d, width, colour): a thick stroke with an outline.
def P(tag, col, **a):
    return (tag, a, col)


def L(d, w, col):
    return ("line", {"d": d, "w": w}, col)


def HI(tag, op=0.5, **a):
    return (tag, a, None, op)


ICONS = {
    "arrow": [P("path", "#ffffff", d="M38 16 L38 100 L58 82 L72 112 L88 105 L74 76 L100 76 Z"),
              HI("path", 0.0, d="")],
    "hoe": [P("rect", "#c98d4a", x=-6, y=-50, width=12, height=100, rx=6, transform="translate(56 70) rotate(40)"),
            P("path", "#c3ccd4", d="M84 22 L106 22 L112 58 L82 58 Z"),
            HI("path", 0.55, d="M88 27 L94 27 L92 52 L87 52 Z")],
    "seeds": [P("path", "#e8c98c", d="M40 44 C44 24 84 24 88 44 Z"),
              P("path", "#f1d9a4", d="M38 52 C30 70 28 96 36 106 C46 116 82 116 92 106 C100 96 98 70 90 52 Z"),
              P("rect", "#e0503d", x=42, y=42, width=44, height=13, rx=6.5),
              P("path", "#5cb85c", d="M64 98 C52 96 44 86 46 74 C58 76 64 86 64 98 Z"),
              P("path", "#6cc85c", d="M64 98 C64 84 72 74 84 72 C86 84 78 96 64 98 Z"),
              HI("ellipse", 0.5, cx=52, cy=66, rx=7, ry=12)],
    "basket": [L("M30 66 C30 18 98 18 98 66", 7, "#b8773a"),
               P("circle", "#8fd05a", cx=64, cy=48, r=15),
               P("circle", "#e5483b", cx=46, cy=58, r=16),
               P("circle", "#f5a43a", cx=82, cy=56, r=16),
               P("path", "#d39a52", d="M24 66 L104 66 L96 108 C95 112 92 114 88 114 L40 114 C36 114 33 112 32 108 Z"),
               P("rect", "#b8773a", x=18, y=60, width=92, height=13, rx=6.5),
               HI("ellipse", 0.6, cx=41, cy=51, rx=5, ry=4), HI("ellipse", 0.6, cx=77, cy=49, rx=5, ry=4),
               HI("path", 0.25, d="M34 84 L94 84 L93 89 L35 89 Z"), HI("path", 0.25, d="M37 99 L91 99 L90 104 L38 104 Z")],
    "fertilizer": [P("path", "#7cb342", d="M34 40 L94 40 L100 108 C100 112 97 114 93 114 L35 114 C31 114 28 112 28 108 Z"),
                   P("rect", "#5e9a2e", x=30, y=28, width=68, height=16, rx=5),
                   P("circle", "#fff3dd", cx=64, cy=78, r=19),
                   P("path", "#5cb85c", d="M64 90 C54 88 50 80 52 70 C61 72 65 80 64 90 Z"),
                   P("path", "#6cc85c", d="M64 90 C64 79 70 72 78 70 C80 80 74 88 64 90 Z"),
                   HI("path", 0.4, d="M40 48 L46 48 L42 104 L36 104 Z")],
    "barn": [P("path", "#e04a36", d="M24 64 L64 36 L104 64 L104 112 L24 112 Z"),
             P("path", "#8a4b3a", d="M14 68 L64 26 L114 68 L106 76 L64 42 L22 76 Z"),
             P("rect", "#fff3dd", x=44, y=76, width=40, height=36, rx=3),
             L("M48 80 L80 108 M80 80 L48 108", 3.5, "#e04a36"),
             P("rect", "#fff3dd", x=56, y=50, width=16, height=14, rx=3),
             HI("path", 0.35, d="M30 70 L36 66 L36 106 L30 106 Z")],
    "tag": [P("path", "#f7c234", d="M22 56 L58 20 C60 18 62 17 65 17 L104 17 C108 17 111 20 111 24 L111 63 C111 66 110 68 108 70 L72 106 C67 111 61 111 56 106 L22 72 C17 67 17 61 22 56 Z"),
            P("circle", "#fff3dd", cx=92, cy=36, r=8),
            P("circle", "#e8a417", cx=62, cy=64, r=14),
            HI("path", 0.45, d="M30 58 L60 28 L66 31 L35 62 Z")],
    "market": [P("rect", "#b8773a", x=24, y=40, width=9, height=40, rx=3), P("rect", "#b8773a", x=95, y=40, width=9, height=40, rx=3)]
              + [P("path", "#e5483b" if i % 2 == 0 else "#fff3dd",
                   d="M%d 24 L%d 24 L%d 46 C%d 56 %d 56 %d 46 Z" % (14 + 20 * i, 34 + 20 * i, 34 + 20 * i, 32 + 20 * i, 16 + 20 * i, 14 + 20 * i))
                 for i in range(5)]
              + [P("rect", "#d39a52", x=20, y=72, width=88, height=40, rx=7),
                 P("circle", "#e5483b", cx=44, cy=68, r=10), P("circle", "#f6c23a", cx=64, cy=66, r=10),
                 P("circle", "#8fd05a", cx=84, cy=68, r=10),
                 HI("path", 0.3, d="M26 90 L102 90 L102 95 L26 95 Z")],
    "album": [P("rect", "#3d7dd8", x=28, y=16, width=74, height=96, rx=9),
              P("rect", "#2c5fae", x=28, y=16, width=16, height=96, rx=7),
              P("path", "#e5483b", d="M80 104 L80 122 L87 115 L94 122 L94 104 Z"),
              P("path", "#f6c23a", d=star(73, 62, 20, 9)),
              HI("path", 0.35, d="M50 22 L96 22 L96 28 L50 28 Z")],
    "ribbon": [P("path", "#3d7dd8", d="M50 66 L32 114 L46 108 L54 120 L66 72 Z"),
               P("path", "#2c5fae", d="M78 66 L96 114 L82 108 L74 120 L62 72 Z"),
               P("path", "#f6c23a", d=star(64, 50, 40, 33, 14)),
               P("circle", "#fbe08a", cx=64, cy=50, r=22),
               P("path", "#e8a417", d=star(64, 50, 13, 6)),
               HI("ellipse", 0.5, cx=55, cy=40, rx=8, ry=5)],
    "neighbours": [P("path", "#3aa6b9", d="M56 114 C56 84 110 84 110 114 Z"),
                   P("circle", "#f2c09a", cx=83, cy=58, r=17),
                   P("path", "#7a4a2a", d="M66 56 C66 34 100 34 100 56 C92 48 74 48 66 56 Z"),
                   P("path", "#6cbf4a", d="M18 116 C18 82 82 82 82 116 Z"),
                   P("circle", "#f5c8a2", cx=50, cy=62, r=20),
                   P("path", "#5a3418", d="M30 60 C30 34 70 34 70 60 C60 50 40 50 30 60 Z"),
                   HI("ellipse", 0.4, cx=40, cy=96, rx=8, ry=5)],
    "gear": [P("path", "#a7b3bf", d=gear(64, 64, 50, 38)),
             P("circle", "#d8dee4", cx=64, cy=64, r=22),
             P("circle", "#5b6772", cx=64, cy=64, r=10),
             HI("ellipse", 0.45, cx=50, cy=40, rx=10, ry=5)],
    "ready": [P("path", "#ff9ccc", d="M24 32 L104 32 L64 104 Z"),
              HI("path", 0.5, d="M36 38 L60 38 L44 62 Z")],
    "fit": [L("M80 80 L108 108", 12, "#b8773a"),
            P("circle", "#cdeefc", cx=54, cy=54, r=32),
            L("M40 54 L68 54", 6, "#3d7dd8"),
            HI("ellipse", 0.6, cx=44, cy=40, rx=9, ry=6)],
    "search": [L("M78 78 L108 108", 12, "#b8773a"),
               P("circle", "#e8f6fd", cx=54, cy=54, r=32),
               HI("ellipse", 0.7, cx=44, cy=42, rx=9, ry=6)],
    # A farm hand, literally: a tan leather work glove, fingers up, its cuff turned down, a sprout tucked in it.
    "helpers": [P("rect", "#d39a55", x=-8, y=-22, width=16, height=42, rx=8, transform="translate(38 74) rotate(-38)"),
                P("rect", "#d9a05b", x=38, y=48, width=56, height=48, rx=14),
                P("rect", "#e2ad68", x=39, y=24, width=13, height=40, rx=6.5),
                P("rect", "#e2ad68", x=53, y=14, width=13, height=50, rx=6.5),
                P("rect", "#e2ad68", x=67, y=18, width=13, height=46, rx=6.5),
                P("rect", "#e2ad68", x=81, y=30, width=13, height=34, rx=6.5),
                L("M98 100 C104 86 106 70 108 56", 5, "#4f9a3e"),
                P("ellipse", "#6cbf4a", cx=116, cy=50, rx=10, ry=5.5, transform="rotate(-35 116 50)"),
                P("ellipse", "#5aae42", cx=102, cy=50, rx=8, ry=4.5, transform="rotate(35 102 50)"),
                P("rect", "#b9793e", x=34, y=88, width=64, height=26, rx=7),
                HI("path", 0.45, d="M44 30 L48 30 L48 58 L44 58 Z"),
                HI("path", 0.4, d="M40 94 L92 94 L92 98 L40 98 Z")],
    "farmhand": [L("M34 54 C34 12 94 12 94 54", 5, "#5b6772"),
                 P("path", "#c3ccd4", d="M30 50 L98 50 L88 108 C87 112 84 114 80 114 L48 114 C44 114 41 112 40 108 Z"),
                 P("ellipse", "#e4e9ee", cx=64, cy=50, rx=34, ry=9),
                 P("ellipse", "#ffffff", cx=64, cy=51, rx=27, ry=5),
                 HI("path", 0.5, d="M40 62 L47 62 L50 104 L45 104 Z")],
    "arborist": [P("rect", "#c98d4a", x=-6, y=-50, width=12, height=100, rx=6, transform="translate(70 70) rotate(-35)"),
                 P("path", "#c3ccd4", d="M-6 -54 L14 -54 L14 -30 L-6 -30 L-10 -26 C-34 -22 -42 -40 -36 -60 C-26 -54 -16 -56 -6 -54 Z",
                   transform="translate(70 70) rotate(-35)"),
                 HI("path", 0.5, d="M-30 -52 C-22 -48 -14 -48 -8 -48 L-8 -44 C-18 -44 -26 -44 -32 -47 Z", transform="translate(70 70) rotate(-35)")],
    "gardener": [L("M52 56 C52 26 86 26 86 56", 6, "#3d8a48"),
                 P("path", "#4fae5c", d="M46 74 L16 46 L22 40 L54 66 Z"),
                 P("ellipse", "#3d8a48", cx=17, cy=41, rx=9, ry=11, transform="rotate(-45 17 41)"),
                 P("path", "#5cc06a", d="M40 54 L94 54 L90 108 C89 112 86 114 82 114 L52 114 C48 114 45 112 44 108 Z"),
                 HI("path", 0.45, d="M48 60 L55 60 L56 104 L51 104 Z")],
    "unwither": [P("rect", "#c98d4a", x=50, y=14, width=28, height=16, rx=5),
                 P("rect", "#d6f1fa", x=54, y=28, width=20, height=24, rx=3),
                 P("circle", "#d6f1fa", cx=64, cy=80, r=34),
                 P("path", "#5cc06a", d="M32 82 L96 82 A32 32 0 0 1 32 82 Z"),
                 P("path", "#2f8f3c", d="M64 104 C56 102 52 96 54 88 C61 90 65 96 64 104 Z"),
                 HI("ellipse", 0.65, cx=50, cy=66, rx=7, ry=11)],
    "fuel": [P("rect", "#c43a2c", x=42, y=18, width=34, height=20, rx=7),
             P("rect", "#3b2414", x=50, y=24, width=18, height=8, rx=4),
             P("rect", "#f6c23a", x=82, y=12, width=12, height=24, rx=3, transform="rotate(30 88 24)"),
             P("rect", "#e5483b", x=28, y=32, width=72, height=82, rx=11),
             L("M40 46 L88 100 M88 46 L40 100", 4, "#c43a2c"),
             HI("path", 0.4, d="M34 42 L40 42 L40 104 L34 104 Z")],
    "star": [P("path", "#f6c23a", d=star(64, 68, 58, 28)),
             HI("path", 0.45, d=star(58, 58, 22, 10))],
    "coin": [P("circle", "#f5b82e", cx=64, cy=64, r=46),
             P("circle", "#fbd25a", cx=64, cy=64, r=33),
             P("path", "#e8a417", d=star(64, 64, 18, 8)),
             HI("path", 0.55, d="M30 50 C36 32 52 22 68 22 L68 28 C54 28 42 36 36 52 Z")],
    "gem": [P("path", "#2fb3e0", d="M22 46 L106 46 L64 112 Z"),
            P("path", "#8ae0f5", d="M22 46 L42 20 L86 20 L106 46 Z"),
            L("M42 20 L52 46 L64 112 M86 20 L76 46 L64 112 M64 20 L52 46 M64 20 L76 46", 0.1, "#1d8fbd"),
            HI("path", 0.6, d="M44 25 L58 25 L50 42 L34 42 Z")],
}
ICONS["arrow"] = [ICONS["arrow"][0], HI("path", 0.0, d="M44 30 L44 44 L54 40 Z")]


def grad(gid, col):
    return ('<linearGradient id="%s" x1="0" y1="0" x2="0" y2="1">'
            '<stop offset="0" stop-color="%s"/><stop offset="0.55" stop-color="%s"/><stop offset="1" stop-color="%s"/>'
            '</linearGradient>') % (gid, shade(col, 0.12), col, shade(col, -0.12))


def attrs(a):
    return " ".join('%s="%s"' % (k.replace("_", "-"), v) for k, v in a.items())


def build(parts):
    defs, edge, body = [], [], []
    for n, part in enumerate(parts):
        tag, a, col = part[0], part[1], part[2]
        if col is None:   # a highlight
            if a.get("d", "x"):
                body.append('<%s %s fill="#ffffff" fill-opacity="%s"/>' % (tag, attrs(a), part[3]))
            continue
        if tag == "line":
            w = a["w"]
            if w < 1:   # facet lines: thin ink only
                body.append('<path d="%s" fill="none" stroke="%s" stroke-width="2.5" stroke-linecap="round" '
                            'stroke-opacity="0.6"/>' % (a["d"], col))
                continue
            common = 'd="%s" fill="none" stroke-linecap="round" stroke-linejoin="round"' % a["d"]
            edge.append('<path %s stroke="#ffffff" stroke-width="%.1f"/>' % (common, w + LINE + EDGE))
            body.append('<path %s stroke="%s" stroke-width="%.1f"/>' % (common, INK, w + LINE * 2))
            body.append('<path %s stroke="%s" stroke-width="%.1f"/>' % (common, col, w))
            continue
        gid = "g%d" % n
        defs.append(grad(gid, col))
        edge.append('<%s %s fill="#ffffff" stroke="#ffffff" stroke-width="%.1f" stroke-linejoin="round"/>' % (tag, attrs(a), EDGE + LINE))
        body.append('<%s %s fill="url(#%s)" stroke="%s" stroke-width="%.1f" stroke-linejoin="round"/>' % (tag, attrs(a), gid, INK, LINE))
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" width="128" height="128">'
            '<defs>%s</defs>%s%s</svg>\n') % ("".join(defs), "".join(edge), "".join(body))


def main():
    os.makedirs(OUT, exist_ok=True)
    for kind, parts in ICONS.items():
        with open(os.path.join(OUT, kind + ".svg"), "w") as f:
            f.write(build(parts))
        with open(os.path.join(OUT, kind + ".svg.import"), "w") as f:
            f.write('[remap]\n\nimporter="keep"\n')   # (read as the file itself, drawn at the size it is shown)
    print("%d icons" % len(ICONS))


if __name__ == "__main__":
    main()
