#!/usr/bin/env python3
"""The game's icon (docs/STORE.md): a drawn mascot, the way store icons are made, not a picture of the game.

A cow in a straw hat, close up; behind her the red barn with its window alight (the light in Barnlight), a
sunflower, and a stalk of wheat in her mouth: animals, crops and the barn in one picture (owner, 27 Nov: "something
that summarizes the entire concept"). Drawn here as shapes (SVG) and made into:

    store/icon_512.png                 the Play listing's icon
    art/app_icon/icon.png              the app's icon (project.godot)
    art/app_icon/foreground_432.png    Android's adaptive icon: the cow, inside the safe middle
    art/app_icon/background_432.png    and what stands behind her

    python3 tools/make_app_icon.py     (needs rsvg-convert)
"""
import math
import os
import subprocess
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INK = "#4a2a18"       # every outline
SIZE = 1024           # the drawing's own size
SAFE = 0.74           # how much of her size the cow keeps on the adaptive foreground (its edges are cut away)
SPILL = 1.12          # the adaptive background's sky and hill, drawn past the edges
DRAWN_IN = 0.8        # and its barn and sunflower, brought in towards the middle

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
'''
HEAD = ("M512 300 C700 300 800 420 790 590 C784 700 740 760 700 800 C660 880 590 930 512 930 "
        "C434 930 364 880 324 800 C284 760 240 700 234 590 C224 420 324 300 512 300 Z")


def sky():
    rays = "".join('<path d="M512 470 L%d %d L%d %d Z" fill="#ffffff" opacity="0.16"/>' % (
        512 + math.cos(a) * 1100, 470 + math.sin(a) * 1100, 512 + math.cos(a + 0.105) * 1100,
        470 + math.sin(a + 0.105) * 1100) for a in [k * math.tau / 16 for k in range(16)])
    return '<rect width="1024" height="1024" fill="url(#sky)"/>' + rays


def barn():
    planks = "".join('<path d="M%d 178 L%d 330" stroke="#8f241f" stroke-width="4" fill="none"/>' % (x, x)
                     for x in (70, 100, 200, 230))
    return f'''<g transform="translate(20 236) scale(1.42)" stroke="{INK}" stroke-width="8" stroke-linejoin="round">
<path d="M40 330 L40 170 L150 60 L260 170 L260 330 Z" fill="url(#barn)"/>{planks}
<path d="M18 182 L150 44 L282 182 L262 200 L150 86 L38 200 Z" fill="url(#roof)"/>
<path d="M44 168 L150 58" stroke="#a9c4e2" stroke-width="5" fill="none" opacity="0.8"/>
<rect x="110" y="230" width="80" height="100" fill="#fff6e0"/>
<path d="M110 230 L190 330 M190 230 L110 330" fill="none" stroke-width="7"/>
<circle cx="150" cy="150" r="24" fill="url(#lamp)"/>
<path d="M150 126 L150 174 M126 150 L174 150" stroke-width="5" fill="none"/>
</g><circle cx="233" cy="449" r="86" fill="#ffe48a" opacity="0.38"/>'''


def hill():
    tufts = "".join('<path d="M%d %d l-10 -26 M%d %d l2 -30 M%d %d l12 -24" stroke="#2f8a2a" stroke-width="7" '
                    'stroke-linecap="round" fill="none"/>' % (x, y, x, y, x, y)
                    for x, y in ((120, 820), (300, 900), (760, 930), (930, 850), (560, 985)))
    return f'''<path d="M-40 760 Q512 610 1064 760 L1064 1064 L-40 1064 Z" fill="url(#hill)" stroke="{INK}"
stroke-width="10"/><path d="M-20 772 Q512 628 1044 772" fill="none" stroke="#c4f08a" stroke-width="10"
opacity="0.7"/>{tufts}'''


def sunflower():
    def ring(turn, colour):
        return "".join('<ellipse cx="0" cy="-84" rx="26" ry="50" fill="%s" stroke="%s" stroke-width="8" '
                       'transform="rotate(%d)"/>' % (colour, INK, k * 30 + turn) for k in range(12))
    return f'''<g transform="translate(905 596) scale(0.88)">
<path d="M0 60 Q-10 180 6 300" fill="none" stroke="#2f7d2a" stroke-width="22" stroke-linecap="round"/>
<path d="M4 190 q70 -40 96 10 q-50 34 -96 -10 Z" fill="#4fae3a" stroke="{INK}" stroke-width="8"
stroke-linejoin="round"/>{ring(15, "#f2a51c")}{ring(0, "#ffd02e")}
<circle r="52" fill="#7a4a22" stroke="{INK}" stroke-width="8"/><circle cx="-14" cy="-14" r="16" fill="#9a6432"/>
</g>'''


def cow():
    grains = "".join('<ellipse cx="%d" cy="%d" rx="20" ry="11" fill="#ffd24a" transform="rotate(%d %d %d)"/>' % (
        x, y, r, x, y) for x, y, r in ((846, 822, -40), (872, 806, -36), (834, 850, 20), (868, 838, 10),
                                        (896, 816, -30)))
    weave = "".join('<path d="M%d %d q%d -16 %d 0" fill="none" stroke="#c9952e" stroke-width="6" opacity="0.55"/>' % (
        x, y, w // 2, w) for x, y, w in ((380, 262, 90), (500, 236, 90), (560, 268, 90), (420, 222, 70)))
    return f'''<clipPath id="headclip"><path d="{HEAD}"/></clipPath>
<ellipse cx="512" cy="950" rx="300" ry="34" fill="#1f5a1f" opacity="0.35"/>
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
</g>
<g stroke="{INK}" stroke-width="8" stroke-linecap="round" stroke-linejoin="round">
<path d="M560 868 Q700 900 820 840" fill="none" stroke="#c9952e" stroke-width="12"/>{grains}
</g>'''


def drawing(layers):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">'
            '<defs>%s</defs>%s</svg>' % (SIZE, SIZE, SIZE, SIZE, DEFS, "".join(layers)))


def about_middle(scale, layers):
    """These layers made larger or smaller about the middle of the picture."""
    return '<g transform="translate(512 512) scale(%.3f) translate(-512 -512)">%s</g>' % (scale, "".join(layers))


def write(svg, path, size):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with tempfile.NamedTemporaryFile("w", suffix=".svg", delete=False) as f:
        f.write(svg)
    subprocess.run(["rsvg-convert", "-w", str(size), "-h", str(size), f.name, "-o", path], check=True)
    os.unlink(f.name)


def main():
    placed = '<g transform="translate(96 118) scale(0.87)">%s</g>' % cow()
    whole = drawing([sky(), barn(), hill(), sunflower(), placed])
    write(whole, os.path.join(ROOT, "store", "icon_512.png"), 512)
    write(whole, os.path.join(ROOT, "art", "app_icon", "icon.png"), 512)
    # Android cuts an adaptive icon to its own shape and may slide the two layers: the cow sits inside the
    # safe middle of hers; the sky and the hill behind are drawn a little larger so their edges are never
    # seen, and the barn and the sunflower are drawn in towards the middle so the cut does not lose them.
    centred = '<g transform="translate(512 512) scale(%.3f) translate(-512 -600)">%s</g>' % (SAFE * 0.87, cow())
    write(drawing([centred]), os.path.join(ROOT, "art", "app_icon", "foreground_432.png"), 432)
    behind = [about_middle(SPILL, [sky()]), about_middle(DRAWN_IN, [barn()]), about_middle(SPILL, [hill()]),
              about_middle(DRAWN_IN, [sunflower()])]
    write(drawing(behind), os.path.join(ROOT, "art", "app_icon", "background_432.png"), 432)
    print("wrote the store icon and the app's icons")


if __name__ == "__main__":
    main()
