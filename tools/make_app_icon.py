#!/usr/bin/env python3
"""The game's icon (docs/STORE.md): a drawn picture, the way store icons are made, not a picture of the game.

The barn at dusk, its window and open door alight (the light in Barnlight) and spilling over the field; a
windmill, a tree, a cow and a horse dark against the setting sun, a sheep and a pig in the field, sunflowers in
the near corners. The owner turned down pictures of the Barn and two bright cartoon icons ("too immature") and
picked this style from a sheet of four (27 Nov). Drawn here as shapes (SVG) and made into:

    store/icon_512.png                 the Play listing's icon
    art/app_icon/icon.png              the app's icon (project.godot)
    art/app_icon/foreground_432.png    Android's adaptive icon: the barn, the animals and the flowers
    art/app_icon/background_432.png    and the sky, sun, hills and field behind them

    python3 tools/make_app_icon.py     (needs rsvg-convert)
"""
import math
import os
import subprocess
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIZE = 1024           # the drawing's own size
MID = SIZE // 2
FAR = 600             # how far past its edges the sky and the field are drawn, for the adaptive icon
DARK = "#190d2c"      # everything that stands against the light
NEAR = "#120920"      # and the flowers nearest the eye
RIM = "#ffa95c"       # the lit edge of a dark shape
PETAL = "#e3a43c"     # a sunflower's petals, catching the last light
GROUND = 836          # where the barn stands
CLOSE = 0.78          # the adaptive icon looks at the picture this much closer in,
LOOK_AT = (505, 650)  # about this point, so the cut keeps the barn large

DEFS = f'''
<linearGradient id="sky" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="0" y2="1024">
<stop offset="0" stop-color="#2a1f63"/><stop offset="0.42" stop-color="#a5407e"/>
<stop offset="0.68" stop-color="#ff8552"/><stop offset="0.82" stop-color="#ffd07a"/></linearGradient>
<linearGradient id="field" gradientUnits="userSpaceOnUse" x1="0" y1="{GROUND}" x2="0" y2="1024">
<stop offset="0" stop-color="#3d225c"/><stop offset="1" stop-color="#1e1236"/></linearGradient>
<linearGradient id="spill" gradientUnits="userSpaceOnUse" x1="0" y1="{GROUND}" x2="0" y2="1024">
<stop offset="0" stop-color="#ffc45a" stop-opacity="0.85"/><stop offset="1" stop-color="#ffc45a" stop-opacity="0"/>
</linearGradient>
<radialGradient id="halo"><stop offset="0" stop-color="#ffe9a0" stop-opacity="0.9"/>
<stop offset="1" stop-color="#ffcf70" stop-opacity="0"/></radialGradient>
<filter id="glow" x="-100%" y="-100%" width="300%" height="300%"><feGaussianBlur stdDeviation="30"/></filter>
<filter id="haze" x="-50%" y="-100%" width="200%" height="300%"><feGaussianBlur stdDeviation="12"/></filter>
'''
STARS = ((120, 90, 4), (260, 170, 3), (420, 70, 4), (610, 130, 3), (780, 60, 4), (920, 160, 3), (700, 230, 3),
         (180, 260, 3), (520, 210, 2), (860, 280, 2), (340, 300, 2))
# The sunflowers in the near corners: x, y of the bloom and its size.
SUNFLOWERS = ((74, 912, 50), (172, 980, 36), (960, 918, 50), (898, 990, 32))


def put(what, x, y, scale, facing=1):
    """A shape drawn standing on y = 0 and facing right, stood at x, y; facing -1 turns it to face left."""
    return '<g transform="translate(%d %d) scale(%.3f %.3f)">%s</g>' % (x, y, scale * facing, scale, what)


def dark(parts, colour=DARK):
    return '<g fill="%s" stroke="%s" stroke-width="0" stroke-linecap="round">%s</g>' % (colour, colour, parts)


def lit(parts, towards, colour=DARK):
    """A dark shape with a thin lit edge on the side the light comes from (towards: 1 right, -1 left)."""
    return '<g transform="translate(%d -3)">%s</g>%s' % (3 * towards, dark(parts, RIM), dark(parts, colour))


def leg(x, top, foot, width):
    return '<path d="M%d %d l%d 0 l-2 %d l%d 0 Z"/>' % (x, top, width, foot - top, 4 - width)


def cow():
    return ('<g transform="translate(0 -150)"><rect x="24" y="50" width="140" height="62" rx="26"/>'
            '<ellipse cx="142" cy="84" rx="32" ry="34"/><ellipse cx="42" cy="80" rx="28" ry="32"/>'
            '<path d="M140 56 L176 38 L192 66 L160 94 Z"/>'
            '<path d="M170 38 C186 30 204 34 210 48 L218 78 C220 90 206 96 198 88 L176 62 Z"/>'
            '<path d="M174 40 l-18 -8 l10 16 Z"/><path d="M182 34 q4 -18 18 -20 q-8 10 -5 22 Z"/>'
            + leg(140, 100, 150, 14) + leg(158, 100, 150, 13) + leg(30, 100, 150, 14) + leg(50, 100, 150, 13)
            + '<ellipse cx="66" cy="113" rx="17" ry="9"/>'
            '<path d="M22 60 q-16 30 -9 60" fill="none" stroke-width="6"/>'
            '<ellipse cx="13" cy="124" rx="6" ry="10"/></g>')


def horse():
    return ('<g transform="translate(0 -150)"><rect x="34" y="50" width="126" height="54" rx="26"/>'
            '<ellipse cx="150" cy="76" rx="28" ry="30"/><ellipse cx="46" cy="74" rx="28" ry="30"/>'
            '<path d="M138 62 C148 30 160 10 178 -2 L202 8 C190 28 184 52 178 88 Z"/>'
            '<path d="M176 -6 C190 -12 200 -4 204 8 L222 44 C226 54 214 60 208 52 L186 26 Z"/>'
            '<path d="M180 -4 l2 -20 l11 15 Z"/>'
            '<path d="M152 26 C140 42 136 58 132 74 L146 66 C150 48 158 30 172 4 Z"/>'
            + leg(144, 96, 150, 11) + leg(160, 96, 150, 10) + leg(36, 96, 150, 11) + leg(54, 96, 150, 10)
            + '<path d="M24 60 C2 70 0 112 10 138 C16 112 24 92 36 80 Z"/></g>')


def sheep():
    fleece = "".join('<circle cx="%d" cy="%d" r="%d"/>' % c for c in (
        (30, 40, 24), (52, 34, 26), (74, 40, 24), (40, 52, 22), (64, 52, 22)))
    return ('<g transform="translate(0 -80)">' + fleece
            + '<ellipse cx="97" cy="36" rx="14" ry="11" transform="rotate(24 97 36)"/>'
            '<path d="M88 28 l-12 -4 l8 10 Z"/>'
            + leg(34, 58, 80, 7) + leg(44, 58, 80, 7) + leg(66, 58, 80, 7) + leg(76, 58, 80, 7) + "</g>")


def pig():
    return ('<g transform="translate(0 -70)"><ellipse cx="55" cy="38" rx="46" ry="26"/>'
            '<circle cx="96" cy="36" r="21"/>'
            '<rect x="110" y="32" width="15" height="13" rx="4"/><path d="M86 20 l4 -17 l14 13 Z"/>'
            + leg(26, 52, 70, 10) + leg(40, 52, 70, 10) + leg(68, 52, 70, 10) + leg(82, 52, 70, 10)
            + '<path d="M10 30 q-13 -4 -9 -15 q7 -9 13 0" fill="none" stroke-width="5"/></g>')


def sunflower(x, y, size):
    petals = "".join('<ellipse cx="0" cy="%.1f" rx="%.1f" ry="%.1f" transform="rotate(%d)"/>' % (
        -size * 0.7, size * 0.17, size * 0.34, k * 360 // 14) for k in range(14))
    stem = '<path d="M0 0 Q%d %d %d %d" fill="none" stroke-width="%.1f"/>' % (
        -size // 5, size * 2, size // 6, size * 5, size * 0.2)
    leaf = '<path d="M0 %d q%d %d %d %d q%d %d %d %d Z"/>' % (
        size * 1.6, size, -size * 0.6, size * 1.5, size * 0.1, -size * 0.7, size * 0.5, -size * 1.5, -size * 0.1)
    return '<g transform="translate(%d %d)">%s%s%s</g>' % (
        x, y, dark(stem + leaf, NEAR), dark(petals, PETAL), dark('<circle r="%.1f"/>' % (size * 0.46), NEAR))


def behind():
    """The sky, the sun going down, the hills and the field, all drawn far past the picture's edges."""
    wide = SIZE + FAR
    stars = "".join('<circle cx="%d" cy="%d" r="%d" fill="#fff" opacity="0.8"/>' % s for s in STARS)
    clouds = ('<g filter="url(#haze)" fill="#ff9a7a" opacity="0.55"><ellipse cx="250" cy="420" rx="210" ry="16"/>'
              '<ellipse cx="640" cy="350" rx="170" ry="13"/><ellipse cx="900" cy="470" rx="150" ry="12"/></g>')
    furrows = "".join('<path d="M%d 1100 Q%d 930 470 %d" fill="none" stroke="#4a2c6c" stroke-width="7"/>' % (
        x, (x + 470) // 2 + bend, GROUND + 2) for x, bend in (
            (-260, -40), (-40, -24), (220, -8), (720, 10), (980, 28), (1240, 44)))
    return [f'<rect x="{-FAR}" y="{-FAR}" width="{SIZE + 2 * FAR}" height="{SIZE + 2 * FAR}" fill="url(#sky)"/>',
            stars, clouds, '<circle cx="790" cy="730" r="340" fill="url(#halo)"/>',
            '<circle cx="790" cy="730" r="168" fill="#fff3c0"/>',
            f'<path d="M{-FAR} 760 L0 760 Q300 700 560 760 T1024 740 L{wide} 750 L{wide} 900 L{-FAR} 900 Z" '
            'fill="#8f3d76"/>',
            f'<path d="M{-FAR} 790 L0 780 Q200 690 430 770 T1024 790 L{wide} 800 L{wide} 900 L{-FAR} 900 Z" '
            'fill="#6a2c66"/>',
            f'<path d="M{-FAR} 850 L0 838 Q512 800 1024 838 L{wide} 850 L{wide} {wide} L{-FAR} {wide} Z" '
            'fill="url(#field)"/>', furrows]


def in_front():
    """The fence, the windmill, the tree, the barn with its lights, the animals and the near flowers."""
    fence = "".join('<rect x="%d" y="770" width="12" height="68"/>' % x for x in range(-FAR + 14, SIZE + FAR, 62))
    fence += "".join('<rect x="%d" y="%d" width="%d" height="8"/>' % (-FAR, y, SIZE + 2 * FAR) for y in (784, 808))
    sails = "".join('<path d="M-9 0 L-24 -150 L24 -150 L9 0 Z" transform="rotate(%d)"/>' % (k * 90 + 22)
                    for k in range(4))
    windmill = ('<path d="M72 838 L104 540 L136 540 L168 838 Z"/><g transform="translate(120 540)">%s'
                '<circle r="15"/></g>' % sails)
    tree = ('<rect x="978" y="600" width="26" height="240"/><circle cx="990" cy="520" r="90"/>'
            '<circle cx="922" cy="575" r="66"/><circle cx="1050" cy="570" r="66"/><circle cx="992" cy="452" r="64"/>'
            '<circle cx="934" cy="500" r="58"/>')
    barn = ('<path d="M290 %d L290 600 L342 500 L470 432 L598 500 L650 600 L650 %d Z"/>' % (GROUND + 4, GROUND + 4)
            + '<path d="M452 444 L452 410 L470 396 L488 410 L488 444 Z"/>'
            '<path d="M470 398 L470 364 M450 372 L490 372 M482 364 l9 8 l-9 8" fill="none" stroke-width="4"/>')
    lights = (f'<path d="M470 432 L598 500 L650 600" fill="none" stroke="{RIM}" stroke-width="5" '
              f'stroke-linecap="round" opacity="0.9"/>'
              f'<path d="M650 600 L650 {GROUND}" stroke="{RIM}" stroke-width="4" opacity="0.45"/>'
              f'<path d="M136 540 L166 820" stroke="{RIM}" stroke-width="4" opacity="0.5"/>'
              '<circle cx="470" cy="548" r="90" fill="#ffd86a" opacity="0.55" filter="url(#glow)"/>'
              f'<ellipse cx="470" cy="780" rx="90" ry="120" fill="#ffc45a" opacity="0.4" filter="url(#glow)"/>'
              f'<circle cx="470" cy="548" r="36" fill="#ffe08a"/>'
              f'<path d="M470 512 L470 584 M434 548 L506 548" stroke="{DARK}" stroke-width="7"/>'
              f'<path d="M424 {GROUND + 4} L424 716 Q470 690 516 716 L516 {GROUND + 4} Z" fill="#ffc45a"/>'
              f'<path d="M424 {GROUND} L516 {GROUND} L680 1100 L250 1100 Z" fill="url(#spill)"/>')
    birds = (f'<path d="M250 250 q16 -16 32 0 q16 -16 32 0 M340 310 q12 -12 24 0 q12 -12 24 0" fill="none" '
             f'stroke="{DARK}" stroke-width="6" stroke-linecap="round"/>')
    return [dark(fence + windmill + tree + barn + put(cow(), 668, GROUND + 2, 0.73)
                 + put(horse(), 1018, GROUND + 2, 0.73, -1)), lights,
            put(lit(sheep(), 1), 200, 958, 1.5), put(lit(pig(), 1), 860, 970, 1.4, -1), birds] + [
                sunflower(*one) for one in SUNFLOWERS]


def drawing(layers):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">'
            '<defs>%s</defs>%s</svg>' % (SIZE, SIZE, SIZE, SIZE, DEFS, "".join(layers)))


def closer(layers):
    """These layers as the adaptive icon sees them: nearer, and looking at the barn."""
    return ['<g transform="translate(%d %d) scale(%.3f) translate(%d %d)">%s</g>' % (
        MID, MID, CLOSE, -LOOK_AT[0], -LOOK_AT[1], "".join(layers))]


def write(svg, path, size):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with tempfile.NamedTemporaryFile("w", suffix=".svg", delete=False) as f:
        f.write(svg)
    subprocess.run(["rsvg-convert", "-w", str(size), "-h", str(size), f.name, "-o", path], check=True)
    os.unlink(f.name)


def main():
    whole = drawing(behind() + in_front())
    write(whole, os.path.join(ROOT, "store", "icon_512.png"), 512)
    write(whole, os.path.join(ROOT, "art", "app_icon", "icon.png"), 512)
    # Android cuts an adaptive icon to its own shape (a circle, a rounded square) and shows only its middle,
    # so both layers look at the picture closer in; the sky and the field are drawn far enough to fill it.
    write(drawing(closer(in_front())), os.path.join(ROOT, "art", "app_icon", "foreground_432.png"), 432)
    write(drawing(closer(behind())), os.path.join(ROOT, "art", "app_icon", "background_432.png"), 432)
    print("wrote the store icon and the app's icons")


if __name__ == "__main__":
    main()
