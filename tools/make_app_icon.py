#!/usr/bin/env python3
"""The game's icon (docs/STORE.md): a drawn picture, the way store icons are made, not a picture of the game.

A horse, a cow in a straw hat, a sheep and a pig stand in a row before the red barn with its window alight (the
light in Barnlight), fruit trees to either side and flowers at their feet: animals, the barn, trees and flowers
in one picture (owner, 27 Nov: "something that summarizes the entire concept"; he chose the four animals with
the barn over one face, and asked for the flowers and trees). Drawn here as shapes (SVG) and made into:

    store/icon_512.png                 the Play listing's icon
    art/app_icon/icon.png              the app's icon (project.godot)
    art/app_icon/foreground_432.png    Android's adaptive icon: the animals and flowers, inside the safe middle
    art/app_icon/background_432.png    and what stands behind them

    python3 tools/make_app_icon.py     (needs rsvg-convert)
"""
import math
import os
import subprocess
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INK = "#4a2a18"       # every outline
SIZE = 1024           # the drawing's own size
MID = SIZE // 2
LINE = 6.5            # an animal's outline as drawn, whatever her size
SAFE = 0.66           # the adaptive icon keeps only its middle: the animals, barn and trees at this size
SPILL = 1.12          # its sky and hill, drawn past the edges
HILL_UP = -59         # and its hill lifted so the smaller barn still stands in the grass

DEFS = '''
<radialGradient id="sky" cx="0.5" cy="0.46" r="0.75"><stop offset="0" stop-color="#fff3b0"/>
<stop offset="0.35" stop-color="#8fd6ff"/><stop offset="1" stop-color="#2f8fe6"/></radialGradient>
<linearGradient id="hill" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#8fdc4f"/>
<stop offset="1" stop-color="#3f9f2f"/></linearGradient>
<linearGradient id="face" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffffff"/>
<stop offset="1" stop-color="#e9dfd0"/></linearGradient>
<linearGradient id="muzzle" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffcfca"/>
<stop offset="1" stop-color="#f29a9c"/></linearGradient>
<linearGradient id="barn" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#e2493a"/>
<stop offset="1" stop-color="#b52f28"/></linearGradient>
<linearGradient id="roof" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#6a8db6"/>
<stop offset="1" stop-color="#3d5878"/></linearGradient>
<linearGradient id="hat" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffe08a"/>
<stop offset="1" stop-color="#e9b648"/></linearGradient>
<radialGradient id="eye" cx="0.35" cy="0.3" r="0.8"><stop offset="0" stop-color="#7a4a2a"/>
<stop offset="1" stop-color="#2a140a"/></radialGradient>
<radialGradient id="lamp" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#fff6c8"/>
<stop offset="1" stop-color="#ffc94a"/></radialGradient>
<linearGradient id="pig" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffc9d3"/>
<stop offset="1" stop-color="#f797ae"/></linearGradient>
<linearGradient id="snout" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffaabd"/>
<stop offset="1" stop-color="#ee7c98"/></linearGradient>
<linearGradient id="wool" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffffff"/>
<stop offset="1" stop-color="#e6dfd2"/></linearGradient>
<linearGradient id="tan" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fde6cc"/>
<stop offset="1" stop-color="#ecc49c"/></linearGradient>
<linearGradient id="horse" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#d08a4c"/>
<stop offset="1" stop-color="#a5622e"/></linearGradient>
<linearGradient id="hmuz" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f8e2c0"/>
<stop offset="1" stop-color="#e2ba88"/></linearGradient>
'''
HEAD = ("M512 300 C700 300 800 420 790 590 C784 700 740 760 700 800 C660 880 590 930 512 930 "
        "C434 930 364 880 324 800 C284 760 240 700 234 590 C224 420 324 300 512 300 Z")
HORSE = ("M0 -330 C190 -330 240 -220 220 -80 C210 20 200 80 205 160 C210 290 110 350 0 350 "
         "C-110 350 -210 290 -205 160 C-200 80 -210 20 -220 -80 C-240 -220 -190 -330 0 -330 Z")
# The flowers at the animals' feet: kind, colour, x, y of the foot of the stem, size.
FLOWERS = (("sun", "#ffd02e", 96, 1016, 1.4), ("tulip", "#e2493a", 204, 1014, 1.25),
           ("daisy", "#ffffff", 276, 1018, 1.1), ("tulip", "#ff8fb4", 468, 1022, 1.1),
           ("daisy", "#ffffff", 562, 1020, 1.1), ("tulip", "#9a6ae0", 696, 1022, 1.15),
           ("daisy", "#ffffff", 818, 1020, 1.1), ("sun", "#ffd02e", 930, 1016, 1.3))


def put(what, x, y, scale, turn=0):
    """A drawing made about its own middle, stood at x, y."""
    return '<g transform="translate(%d %d) rotate(%d) scale(%.3f)">%s</g>' % (x, y, turn, scale, what)


def inked(width):
    return '<g stroke="%s" stroke-width="%.1f" stroke-linejoin="round" stroke-linecap="round">' % (INK, width)


def cloud(circles, fill):
    """Circles that read as one soft shape: each outlined, then filled again so only the outer line is left."""
    return ("".join('<circle cx="%d" cy="%d" r="%d" fill="%s"/>' % (x, y, r, fill) for x, y, r in circles)
            + "".join('<circle cx="%d" cy="%d" r="%d" fill="%s" stroke-width="0"/>' % (x, y, r, fill)
                      for x, y, r in circles))


def eyes(apart, y, rx=56, ry=70):
    out = ""
    for side in (-1, 1):
        cx = side * apart
        ix = cx - side * 9
        out += '<ellipse cx="%d" cy="%d" rx="%d" ry="%d" fill="#fff"/>' % (cx, y, rx, ry)
        out += '<ellipse cx="%d" cy="%d" rx="%d" ry="%d" fill="url(#eye)" stroke-width="0"/>' % (
            ix, y + 11, rx * 0.65, ry * 0.7)
        out += '<circle cx="%d" cy="%d" r="%d" fill="#fff" stroke-width="0"/>' % (ix - 14, y - 12, rx * 0.29)
        out += '<circle cx="%d" cy="%d" r="%d" fill="#fff" stroke-width="0" opacity="0.9"/>' % (
            ix + 13, y + 34, rx * 0.13)
    return out


def blush(apart, y, rx=44, ry=26):
    return "".join('<ellipse cx="%d" cy="%d" rx="%d" ry="%d" fill="#ff8fa3" opacity="0.5" stroke-width="0"/>' % (
        side * apart, y, rx, ry) for side in (-1, 1))


def both_sides(part):
    return part + '<g transform="scale(-1 1)">%s</g>' % part


def sky():
    rays = "".join('<path d="M512 470 L%d %d L%d %d Z" fill="#ffffff" opacity="0.16"/>' % (
        512 + math.cos(a) * 1100, 470 + math.sin(a) * 1100, 512 + math.cos(a + 0.105) * 1100,
        470 + math.sin(a + 0.105) * 1100) for a in [k * math.tau / 16 for k in range(16)])
    return '<rect width="1024" height="1024" fill="url(#sky)"/>' + rays


def barn():
    planks = "".join('<path d="M%d 178 L%d 330" stroke="#8f241f" stroke-width="3" fill="none"/>' % (x, x)
                     for x in (70, 100, 200, 230))
    return f"""<g transform="translate(182 14) scale(2.2)" stroke="{INK}" stroke-width="6" stroke-linejoin="round">
<path d="M40 330 L40 170 L150 60 L260 170 L260 330 Z" fill="url(#barn)"/>{planks}
<path d="M18 182 L150 44 L282 182 L262 200 L150 86 L38 200 Z" fill="url(#roof)"/>
<path d="M44 168 L150 58" stroke="#a9c4e2" stroke-width="4" fill="none" opacity="0.8"/>
<rect x="110" y="230" width="80" height="100" fill="#fff6e0"/>
<path d="M110 230 L190 330 M190 230 L110 330" fill="none" stroke-width="5"/>
<circle cx="150" cy="150" r="24" fill="url(#lamp)"/>
<path d="M150 126 L150 174 M126 150 L174 150" stroke-width="4" fill="none"/>
<circle cx="150" cy="150" r="52" fill="#ffe48a" opacity="0.4" stroke="none"/></g>"""


def hill(lift=0):
    tufts = "".join('<path d="M%d %d l-10 -26 M%d %d l2 -30 M%d %d l12 -24" stroke="#2f8a2a" stroke-width="7" '
                    'stroke-linecap="round" fill="none"/>' % (x, y, x, y, x, y)
                    for x, y in ((380, 950), (640, 965), (760, 940)))
    return f"""<g transform="translate(0 {40 + lift})"><path d="M-40 760 Q512 610 1064 760 L1064 1264 L-40 1264 Z"
fill="url(#hill)" stroke="{INK}" stroke-width="10"/><path d="M-20 772 Q512 628 1044 772" fill="none"
stroke="#c4f08a" stroke-width="10" opacity="0.7"/>{tufts}</g>"""


def tree(fruit):
    crown = cloud(((0, -10, 100), (-88, 24, 78), (88, 24, 78), (-50, -62, 80), (50, -62, 80), (0, 56, 88)),
                  "url(#hill)")
    fruits = "".join('<circle cx="%d" cy="%d" r="17" fill="%s" stroke-width="5"/><circle cx="%d" cy="%d" r="5" '
                     'fill="#fff" opacity="0.8" stroke-width="0"/>' % (x, y, fruit, x - 5, y - 6)
                     for x, y in ((-84, 20), (-30, -52), (38, -84), (84, 4), (22, 28), (-28, 84), (58, 80)))
    return (inked(8) + '<path d="M-26 330 C-20 200 -22 130 -30 60 L30 60 C22 130 20 200 26 330 Z" fill="#8a5a34"/>'
            + crown + '<circle cx="-56" cy="-86" r="24" fill="#c4f08a" opacity="0.6" stroke-width="0"/>'
            + '<circle cx="-104" cy="-14" r="13" fill="#c4f08a" opacity="0.6" stroke-width="0"/>' + fruits + "</g>")


def flower(kind, colour):
    stem = ('<path d="M0 0 Q-6 -40 0 -80" fill="none" stroke="#2f7d2a" stroke-width="9" stroke-linecap="round"/>'
            '<path d="M0 -26 q26 -18 38 2 q-20 14 -38 -2 Z" fill="#4fae3a" stroke="%s" stroke-width="4" '
            'stroke-linejoin="round"/>' % INK)
    if kind == "tulip":
        bloom = ('<path d="M-22 -30 C-30 14 30 14 22 -30 L10 -10 L0 -34 L-10 -10 Z" fill="%s" stroke="%s" '
                 'stroke-width="5" stroke-linejoin="round"/>' % (colour, INK))
    else:
        petals = 12 if kind == "sun" else 8
        bloom = "".join('<ellipse cx="0" cy="-25" rx="9" ry="17" fill="%s" stroke="%s" stroke-width="4" '
                        'transform="rotate(%d)"/>' % (colour, INK, k * 360 // petals) for k in range(petals))
        bloom += '<circle r="14" fill="%s" stroke="%s" stroke-width="4"/>' % (
            "#7a4a22" if kind == "sun" else "#ffc93a", INK)
    return stem + '<g transform="translate(0 -88)">%s</g>' % bloom


def pig():
    ear = '<path d="M-240 -110 C-345 -250 -235 -335 -105 -232 Z" fill="#f48aa2"/>'
    return (both_sides(ear) + '<ellipse cx="0" cy="0" rx="285" ry="255" fill="url(#pig)"/>'
            + '<path d="M-232 -50 C-222 -140 -160 -200 -85 -222" fill="none" stroke="#fff" stroke-width="16" '
            'opacity="0.65"/>' + blush(205, 60, 50, 30)
            + '<ellipse cx="0" cy="88" rx="138" ry="100" fill="url(#snout)"/>'
            + '<path d="M-90 30 Q0 2 90 30" fill="none" stroke="#fff" stroke-width="11" opacity="0.55"/>'
            + both_sides('<ellipse cx="-48" cy="90" rx="22" ry="34" fill="#b4506a" stroke-width="0"/>')
            + eyes(128, -78) + '<path d="M-52 212 Q0 244 52 212" fill="none"/>')


def sheep():
    fleece = [(math.cos(math.radians(a)) * 205, -70 + math.sin(math.radians(a)) * 205, 108)
              for a in range(-205, 30, 29)]
    ear = '<ellipse cx="-232" cy="52" rx="88" ry="44" fill="#e9bf96" transform="rotate(-24 -232 52)"/>'
    return (cloud(fleece + [(0, -70, 225)], "url(#wool)") + both_sides(ear)
            + '<ellipse cx="0" cy="70" rx="176" ry="188" fill="url(#tan)"/>'
            + cloud(((-78, -118, 72), (78, -118, 72), (0, -146, 84)), "#ffffff")
            + blush(118, 140, 36, 22) + eyes(84, 42, 46, 58)
            + '<path d="M-30 150 Q0 138 30 150 Q0 188 -30 150 Z" fill="#e98a94"/>'
            + '<path d="M0 180 L0 200 M-40 204 Q-20 226 0 200 Q20 226 40 204" fill="none"/>')


def horse():
    ear = ('<path d="M-190 -250 C-225 -400 -130 -430 -78 -292 Z" fill="url(#horse)"/>'
           '<path d="M-166 -290 C-180 -360 -138 -372 -112 -306 Z" fill="#f2b9a0" stroke-width="0"/>')
    return ('<path d="M150 -300 C330 -240 330 20 262 150 C250 40 230 -80 170 -180 Z" fill="#5a3018"/>'
            + both_sides(ear) + '<path d="%s" fill="url(#horse)"/>' % HORSE
            + '<clipPath id="horseclip"><path d="%s"/></clipPath><g clip-path="url(#horseclip)" stroke="none">' % HORSE
            + '<path d="M-46 -340 C-80 -150 -64 0 -96 150 L96 150 C64 0 80 -150 46 -340 Z" fill="#fff3de"/>'
            + '<path d="M-196 -60 C-200 -170 -160 -250 -90 -290" fill="none" stroke="#fff" stroke-width="15" '
            'opacity="0.4"/></g>' + '<path d="%s" fill="none"/>' % HORSE
            + '<ellipse cx="0" cy="232" rx="196" ry="136" fill="url(#hmuz)"/>'
            + both_sides('<ellipse cx="-72" cy="212" rx="22" ry="32" fill="#7a4a2a" stroke-width="0"/>')
            + '<path d="M-70 296 Q0 336 70 296" fill="none"/>' + blush(150, 110, 38, 22) + eyes(122, -62, 52, 66)
            + '<path d="M-96 -338 C-44 -404 84 -402 114 -330 C96 -262 44 -204 -22 -172 C0 -232 -42 -262 -104 -252 '
            'C-124 -292 -114 -320 -96 -338 Z" fill="#5a3018"/>')


def cow():
    weave = "".join('<path d="M%d %d q%d -16 %d 0" fill="none" stroke="#c9952e" stroke-width="6" opacity="0.55"/>' % (
        x, y, w // 2, w) for x, y, w in ((380, 262, 90), (500, 236, 90), (560, 268, 90), (420, 222, 70)))
    return f'''<g transform="translate(-512 -600)"><clipPath id="headclip"><path d="{HEAD}"/></clipPath>
<g stroke="{INK}" stroke-width="14" stroke-linejoin="round" stroke-linecap="round">
<path d="M268 470 C170 400 110 450 120 520 C130 590 220 590 290 560 Z" fill="url(#face)"/>
<path d="M250 498 C196 468 160 490 166 524 C172 556 220 552 262 540 Z" fill="#f7a9a6" stroke-width="0"/>
<path d="M756 470 C854 400 914 450 904 520 C894 590 804 590 734 560 Z" fill="#5a3a2a"/>
<path d="M774 498 C828 468 864 490 858 524 C852 556 804 552 762 540 Z" fill="#f7a9a6" stroke-width="0"/>
<path d="{HEAD}" fill="url(#face)"/>
<g clip-path="url(#headclip)" stroke="none">
<path d="M560 280 C760 280 860 430 800 620 C740 640 640 600 620 500 C606 420 560 380 560 280 Z" fill="#5a3a2a"/>
<path d="M200 300 L824 300 L824 400 C700 372 324 372 200 400 Z" fill="#3a2414" opacity="0.16"/>
<path d="M234 700 C300 760 330 860 420 930 L200 960 Z" fill="#000" opacity="0.07"/>
<path d="M790 700 C724 760 694 860 604 930 L824 960 Z" fill="#000" opacity="0.07"/>
<path d="M262 560 C262 450 320 380 400 350" fill="none" stroke="#ffffff" stroke-width="16" opacity="0.7"/>
</g>
<path d="{HEAD}" fill="none"/>
<path d="M512 640 C650 640 730 700 720 790 C710 880 620 930 512 930 C404 930 314 880 304 790 C294 700 374 640 512 640 Z"
fill="url(#muzzle)"/>
<path d="M392 676 Q512 648 632 676" fill="none" stroke="#ffffff" stroke-width="12" opacity="0.6"/>
<ellipse cx="440" cy="760" rx="26" ry="36" fill="#b85a62" stroke-width="0"/>
<ellipse cx="584" cy="760" rx="26" ry="36" fill="#b85a62" stroke-width="0"/>
<path d="M430 846 Q512 906 594 846" fill="none" stroke-width="12"/>
<ellipse cx="350" cy="700" rx="40" ry="24" fill="#ff9aa8" opacity="0.55" stroke-width="0"/>
<ellipse cx="674" cy="700" rx="40" ry="24" fill="#ff9aa8" opacity="0.55" stroke-width="0"/>
<ellipse cx="400" cy="540" rx="62" ry="78" fill="#ffffff"/><ellipse cx="624" cy="540" rx="62" ry="78" fill="#ffffff"/>
<ellipse cx="410" cy="552" rx="40" ry="54" fill="url(#eye)" stroke-width="0"/>
<ellipse cx="614" cy="552" rx="40" ry="54" fill="url(#eye)" stroke-width="0"/>
<circle cx="394" cy="528" r="18" fill="#fff" stroke-width="0"/><circle cx="598" cy="528" r="18" fill="#fff" stroke-width="0"/>
<circle cx="424" cy="578" r="8" fill="#fff" stroke-width="0" opacity="0.9"/>
<circle cx="628" cy="578" r="8" fill="#fff" stroke-width="0" opacity="0.9"/>
<path d="M336 452 Q396 416 456 448" fill="none" stroke-width="12"/><path d="M568 448 Q628 416 688 452" fill="none"
stroke-width="12"/>
</g>
<g stroke="{INK}" stroke-width="14" stroke-linejoin="round">
<path d="M196 352 C300 300 724 300 828 352 C860 370 840 404 800 398 C640 366 384 366 224 398 C184 404 164 370 196 352 Z"
fill="url(#hat)"/>
<path d="M330 330 C330 180 694 180 694 330 C600 310 424 310 330 330 Z" fill="url(#hat)"/>{weave}
<path d="M334 300 C430 276 594 276 690 300 L694 332 C600 312 424 312 330 332 Z" fill="#e2493a"/>
<path d="M352 300 C440 282 584 282 672 300" fill="none" stroke="#ff8a78" stroke-width="6" opacity="0.8"/>
</g></g>'''




def animal(drawn, x, y, scale, turn):
    """One of the animals that are drawn about their own middle, her outline the same weight at any size."""
    return put(inked(LINE / scale) + drawn + "</g>", x, y, scale, turn)


def behind():
    """The trees and the barn."""
    return [put(tree("#ff9a2e"), 100, 310, 1.2), put(tree("#e53b2f"), 930, 340, 1.25), barn()]


def in_front():
    """The four animals and the flowers at their feet."""
    return ['<ellipse cx="512" cy="960" rx="480" ry="60" fill="#1f5a1f" opacity="0.3"/>',
            animal(horse(), 138, 640, 0.52, -5), put(cow(), 372, 740, 0.46, -2), animal(sheep(), 622, 780, 0.45, 2),
            animal(pig(), 852, 790, 0.46, 5)] + [put(flower(kind, colour), x, y, size)
                                                 for kind, colour, x, y, size in FLOWERS]


def drawing(layers):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">'
            '<defs>%s</defs>%s</svg>' % (SIZE, SIZE, SIZE, SIZE, DEFS, "".join(layers)))


def about_middle(scale, layers):
    """These layers made larger or smaller about the middle of the picture."""
    return '<g transform="translate(%d %d) scale(%.3f) translate(-%d -%d)">%s</g>' % (
        MID, MID, scale, MID, MID, "".join(layers))


def write(svg, path, size):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with tempfile.NamedTemporaryFile("w", suffix=".svg", delete=False) as f:
        f.write(svg)
    subprocess.run(["rsvg-convert", "-w", str(size), "-h", str(size), f.name, "-o", path], check=True)
    os.unlink(f.name)


def main():
    whole = drawing([sky()] + behind() + [hill()] + in_front())
    write(whole, os.path.join(ROOT, "store", "icon_512.png"), 512)
    write(whole, os.path.join(ROOT, "art", "app_icon", "icon.png"), 512)
    # Android cuts an adaptive icon to its own shape and may slide the two layers: the animals, the barn and
    # the trees are drawn smaller about the middle so the cut keeps them, and the sky and the hill are drawn a
    # little larger so their edges are never seen.
    front = drawing([about_middle(SAFE, in_front())])
    write(front, os.path.join(ROOT, "art", "app_icon", "foreground_432.png"), 432)
    back = [about_middle(SPILL, [sky()]), about_middle(SAFE, behind()), about_middle(SPILL, [hill(HILL_UP)])]
    write(drawing(back), os.path.join(ROOT, "art", "app_icon", "background_432.png"), 432)
    print("wrote the store icon and the app's icons")


if __name__ == "__main__":
    main()
