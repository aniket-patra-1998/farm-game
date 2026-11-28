#!/usr/bin/env python3
"""The people's pictures (PortraitIcon): the two farmers a player picks between and the six neighbours.

Each is drawn as shapes (SVG) with soft light and shadow and no outlines, the style the owner picked from a
sheet of three (27 Nov: the faces drawn by code "are too bad"), and each has a face of her own: its shape, hair,
and what she wears. Written to art/portraits/<name>.png; data/social.json's `look.portrait` and Settings name
the picture a face uses.

    python3 tools/make_portraits.py     (needs rsvg-convert)
"""
import os
import subprocess
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "art", "portraits")
SIZE = 512            # the drawing's own size
PIXELS = 256          # the picture's size as written
MID = SIZE // 2
CLOSER = 1.2          # the figure is drawn this much larger about the top of the head, so the face fills the badge
CROWN = 150
STRAW = "#e7c66a"
LIPS = {"soft": "#c2575a", "plain": "#a8524a"}

# name: skin, hair, shirt, the badge behind, hair style, jaw (0 narrow .. 1 wide), lips, and what else she has.
PEOPLE = {
    "farmer_boy": dict(skin="#f1c9a5", hair="#5a3a1e", shirt="#d9483b", back="#a8d5f0", style="short", jaw=0.8,
                       lips="plain", extras=("overalls",)),
    "farmer_girl": dict(skin="#f1c9a5", hair="#5a3a1e", shirt="#d9483b", back="#a8d5f0", style="braids", jaw=0.2,
                        lips="soft", extras=("overalls", "lashes")),
    "maple": dict(skin="#f1c7a1", hair="#b5532e", shirt="#5c9a3e", back="#9ccbe8", style="long", jaw=0.3,
                  lips="soft", extras=("lashes", "freckles")),
    "barley": dict(skin="#d9a27a", hair="#e2c35a", shirt="#3d78c9", back="#b9dba3", style="straw_hat", jaw=1.0,
                   lips="plain", extras=()),
    "clover": dict(skin="#f6d3b5", hair="#3b2412", shirt="#e86aa0", back="#a9dccd", style="bun", jaw=0.1,
                   lips="soft", extras=("lashes", "earrings")),
    "hazel": dict(skin="#a8714a", hair="#2b1a10", shirt="#d9442f", back="#eccb8c", style="curls", jaw=0.4,
                  lips="soft", extras=("lashes", "earrings")),
    "rusty": dict(skin="#e8b48c", hair="#c0502a", shirt="#7a5a3a", back="#b7cfe0", style="cap", jaw=0.9,
                  lips="plain", extras=("beard", "freckles")),
    "poppy": dict(skin="#8a5a3a", hair="#1e1410", shirt="#f2b632", back="#c9b8e6", style="long", jaw=0.3,
                  lips="soft", extras=("lashes", "flower")),
}
# Hair behind the head, and over the forehead, by style.
BEHIND = {
    "long": "M152 226 C130 116 200 64 256 64 C312 64 382 116 360 226 C372 316 390 396 374 456 L138 456 "
            "C122 396 140 316 152 226 Z",
    "braids": "M156 226 C136 120 202 68 256 68 C310 68 376 120 356 226 C360 262 352 286 344 300 L168 300 "
              "C160 286 152 262 156 226 Z",
}
FRONT = {
    "short": "M160 212 C150 112 212 82 256 82 C300 82 362 112 352 212 C340 170 318 152 284 146 "
             "C262 160 220 160 196 150 C176 164 166 184 160 212 Z",
    "long": "M158 226 C146 118 220 86 272 92 C334 98 366 150 354 228 C338 182 302 150 262 138 "
            "C240 170 200 192 158 226 Z",
    "braids": "M160 216 C150 114 214 84 256 84 C298 84 362 114 352 216 C340 172 306 142 256 134 "
              "C206 142 172 172 160 216 Z",
    "bun": "M160 214 C152 116 214 84 256 84 C298 84 360 116 352 214 C340 172 306 140 256 132 "
           "C206 140 172 172 160 214 Z",
}
CURLS = ((168, 196, 38), (176, 148, 44), (212, 108, 46), (256, 94, 48), (300, 108, 46), (336, 148, 44),
         (344, 196, 38), (232, 138, 40), (280, 138, 40))


def rgb(colour):
    return tuple(int(colour[i:i + 2], 16) for i in (1, 3, 5))


def mix(a, b, share):
    return "#%02x%02x%02x" % tuple(round(x + (y - x) * share) for x, y in zip(rgb(a), rgb(b)))


def shade(colour, kept):
    return mix(colour, "#000000", 1 - kept)


def tint(colour, share):
    return mix(colour, "#ffffff", share)


def fall(name, top, bottom, across=False):
    """A gradient from top to bottom (or from the upper left to the lower right)."""
    ends = 'x1="0.2" y1="0" x2="0.8" y2="1"' if across else 'x1="0" y1="0" x2="0" y2="1"'
    return ('<linearGradient id="%s" %s><stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/>'
            '</linearGradient>' % (name, ends, top, bottom))


def face_path(jaw):
    """The face's outline; a wider jaw is squarer."""
    w = 62 + 16 * jaw
    return ("M164 214 C164 128 348 128 348 214 C348 262 %d 304 %d 322 C%d 340 280 347 256 347 "
            "C232 347 %d 340 %d 322 C%d 304 164 262 164 214 Z" % (
                MID + w + 8, MID + w - 10, MID + w - 30, MID - w + 30, MID - w + 10, MID - w - 8))


def defs(who, outline):
    skin, hair, shirt, back = who["skin"], who["hair"], who["shirt"], who["back"]
    return (fall("back", tint(back, 0.4), back) + fall("hair", tint(hair, 0.16), shade(hair, 0.7), True)
            + fall("shirt", tint(shirt, 0.12), shade(shirt, 0.7)) + fall("neck", shade(skin, 0.64), shade(skin, 0.9))
            + fall("denim", "#4f81c9", "#2f5590") + fall("straw", tint(STRAW, 0.2), shade(STRAW, 0.82))
            + fall("cap", "#4d8a72", "#2c5a48")
            + '<linearGradient id="skin" x1="0.2" y1="0" x2="0.8" y2="1"><stop offset="0" stop-color="%s"/>'
              '<stop offset="0.6" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient>' % (
                  tint(skin, 0.2), skin, shade(skin, 0.84))
            + '<clipPath id="badge"><circle cx="256" cy="256" r="256"/></clipPath>'
              '<clipPath id="face"><path d="%s"/></clipPath>' % outline
            + '<filter id="drop" x="-30%" y="-30%" width="160%" height="170%">'
              '<feGaussianBlur in="SourceAlpha" stdDeviation="8"/><feOffset dy="9"/><feComponentTransfer>'
              '<feFuncA type="linear" slope="0.3"/></feComponentTransfer><feMerge><feMergeNode/>'
              '<feMergeNode in="SourceGraphic"/></feMerge></filter>'
              '<filter id="blur" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="7"/>'
              '</filter>')


def body(who):
    shirt = who["shirt"]
    out = ('<path d="M36 532 C46 430 150 396 220 384 L292 384 C362 396 466 430 476 532 Z" fill="url(#shirt)" '
           'filter="url(#drop)"/>'
           '<path d="M214 300 L214 392 Q256 432 298 392 L298 300 Z" fill="url(#neck)"/>'
           '<path d="M196 386 L256 442 L316 386" fill="none" stroke="%s" stroke-width="15" stroke-linejoin="round" '
           'stroke-linecap="round"/>' % tint(shirt, 0.32))
    if "overalls" in who["extras"]:
        out += ('<path d="M150 408 L186 396 L204 532 L160 532 Z M362 408 L326 396 L308 532 L352 532 Z" '
                'fill="url(#denim)"/><rect x="176" y="472" width="160" height="60" rx="10" fill="url(#denim)"/>'
                '<circle cx="190" cy="484" r="9" fill="#f2c14e"/><circle cx="322" cy="484" r="9" fill="#f2c14e"/>')
    return out


def hair_behind(who):
    style = who["style"]
    out = ""
    if style in BEHIND:
        out += '<path d="%s" fill="url(#hair)"/>' % BEHIND[style]
    if style == "bun":
        out += ('<circle cx="256" cy="74" r="46" fill="url(#hair)"/><path d="M226 56 Q256 34 286 56" fill="none" '
                'stroke="%s" stroke-width="8" stroke-linecap="round" opacity="0.5" filter="url(#blur)"/>'
                % tint(who["hair"], 0.5))
    if style == "curls":
        out += "".join('<circle cx="%d" cy="%d" r="%d" fill="url(#hair)"/>' % c for c in CURLS[:7])
    return out


def braids(who):
    """Two plaits falling in front of the shoulders, each tied with a ribbon."""
    out = ""
    for side in (-1, 1):
        x = MID + side * 118
        out += "".join('<ellipse cx="%d" cy="%d" rx="24" ry="20" fill="url(#hair)"/>' % (x + side * (k % 2) * 6, y)
                       for k, y in enumerate(range(300, 430, 26)))
        out += '<rect x="%d" y="424" width="40" height="14" rx="7" fill="#e2493a"/>' % (x - 20)
        out += '<ellipse cx="%d" cy="452" rx="15" ry="18" fill="url(#hair)"/>' % x
    return out


def hair_front(who):
    style, hair = who["style"], who["hair"]
    shine = ('<path d="M206 112 C232 98 282 98 308 114" fill="none" stroke="%s" stroke-width="9" '
             'stroke-linecap="round" opacity="0.45" filter="url(#blur)"/>' % tint(hair, 0.4))
    if style in FRONT:
        return '<path d="%s" fill="url(#hair)"/>' % FRONT[style] + shine
    if style == "curls":
        return ('<ellipse cx="256" cy="150" rx="94" ry="40" fill="url(#hair)"/>'
                + "".join('<circle cx="%d" cy="%d" r="%d" fill="url(#hair)"/>' % c for c in CURLS))
    sides = "".join('<ellipse cx="%d" cy="226" rx="13" ry="26" fill="url(#hair)"/>' % x for x in (170, 342))
    if style == "cap":
        return (sides + '<path d="M162 198 C158 108 220 82 256 82 C292 82 354 108 350 198 Z" fill="url(#cap)"/>'
                '<path d="M150 196 C200 172 320 172 372 192 C392 200 388 216 368 214 C304 196 212 196 162 212 '
                'C146 214 138 202 150 196 Z" fill="#234a3b"/><circle cx="256" cy="84" r="9" fill="#234a3b"/>'
                '<path d="M196 120 C220 100 280 98 306 114" fill="none" stroke="#9fd0b8" stroke-width="8" '
                'stroke-linecap="round" opacity="0.5" filter="url(#blur)"/>')
    return (sides + '<ellipse cx="256" cy="180" rx="196" ry="42" fill="url(#straw)" filter="url(#drop)"/>'
            '<path d="M172 176 C170 84 342 84 340 176 C300 190 212 190 172 176 Z" fill="url(#straw)"/>'
            '<path d="M172 166 C212 182 300 182 340 166 L340 180 C300 196 212 196 172 180 Z" fill="#c0392b"/>'
            '<path d="M200 118 C224 100 288 100 312 118" fill="none" stroke="#fff3c4" stroke-width="8" '
            'stroke-linecap="round" opacity="0.6" filter="url(#blur)"/>')


def features(who):
    skin, hair, extras = who["skin"], who["hair"], who["extras"]
    brow = shade(hair, 0.55) if rgb(hair)[0] > 90 else "#1c120c"
    out = ""
    for side, x in ((-1, 216), (1, 296)):
        out += ('<ellipse cx="%d" cy="236" rx="16" ry="10" fill="#fff"/><circle cx="%d" cy="236" r="9.5" '
                'fill="#3a2414"/><circle cx="%d" cy="233" r="3" fill="#fff"/>' % (x, x, x - 3))
        out += ('<path d="M%d 232 Q%d 219 %d 232" fill="none" stroke="#2a1810" stroke-width="4.5" '
                'stroke-linecap="round"/>' % (x - 17, x, x + 17))
        if "lashes" in extras:
            out += ('<path d="M%d 231 l%d -7" stroke="#2a1810" stroke-width="4" stroke-linecap="round"/>'
                    % (x + side * 16, side * 7))
        out += ('<path d="M%d 208 Q%d 197 %d 206" fill="none" stroke="%s" stroke-width="%d" '
                'stroke-linecap="round" opacity="0.9"/>' % (x - 20, x, x + 20, brow, 5 if "lashes" in extras else 8))
    out += ('<path d="M252 252 Q244 278 256 284 Q264 286 268 280" fill="none" stroke="%s" stroke-width="4" '
            'stroke-linecap="round" opacity="0.8"/>' % shade(skin, 0.7))
    out += '<path d="M228 302 Q256 330 284 302 Q256 313 228 302 Z" fill="%s"/>' % LIPS[who["lips"]]
    if "freckles" in extras:
        out += "".join('<circle cx="%d" cy="%d" r="3" fill="%s" opacity="0.7"/>' % (x, y, shade(skin, 0.68))
                       for x, y in ((198, 262), (210, 270), (222, 260), (290, 260), (302, 270), (314, 262)))
    return out


def beard(who):
    return ('<path d="M168 256 C172 318 212 358 256 358 C300 358 340 318 344 256 C330 296 300 328 256 328 '
            'C212 328 182 296 168 256 Z" fill="url(#hair)"/>'
            '<path d="M222 296 Q256 284 290 296 Q256 302 222 296 Z" fill="%s"/>' % shade(who["hair"], 0.85))


def portrait(who):
    outline = face_path(who["jaw"])
    skin, extras = who["skin"], who["extras"]
    shoulders = body(who)
    # The hair under everything, so no gap shows between the hairline and the face.
    head = '<ellipse cx="256" cy="186" rx="95" ry="100" fill="url(#hair)"/>'
    head += "".join('<ellipse cx="%d" cy="242" rx="16" ry="26" fill="%s"/>' % (x, shade(skin, 0.9))
                    for x in (163, 349))
    if "earrings" in extras:
        head += "".join('<circle cx="%d" cy="276" r="9" fill="none" stroke="#f2c14e" stroke-width="5"/>' % x
                        for x in (160, 352))
    head += '<path d="%s" fill="url(#skin)" filter="url(#drop)"/>' % outline
    # Light on the brow, colour in the cheeks, and the hair's shadow across the forehead.
    head += ('<g clip-path="url(#face)"><ellipse cx="222" cy="184" rx="48" ry="26" fill="#fff" opacity="0.18" '
             'filter="url(#blur)"/>'
             + "".join('<ellipse cx="%d" cy="272" rx="24" ry="15" fill="#e36a5c" opacity="0.28" filter="url(#blur)"/>'
                       % x for x in (204, 308))
             + '<ellipse cx="256" cy="150" rx="110" ry="30" fill="%s" opacity="0.35" filter="url(#blur)"/></g>'
             % shade(skin, 0.5))
    if "beard" in extras:
        head += beard(who)
    head += features(who) + hair_front(who)
    if "flower" in extras:
        head += ("".join('<ellipse cx="344" cy="134" rx="13" ry="22" fill="#e2493a" transform="rotate(%d 344 158)"/>'
                         % (k * 72) for k in range(5)) + '<circle cx="344" cy="158" r="12" fill="#ffd02e"/>')
    front = braids(who) if who["style"] == "braids" else ""
    ring = '<circle cx="256" cy="256" r="250" fill="none" stroke="%s" stroke-width="12"/>' % shade(who["back"], 0.8)
    figure = '<g transform="translate(%d %d) scale(%.2f) translate(%d %d)">%s%s%s%s</g>' % (
        MID, CROWN, CLOSER, -MID, -CROWN, hair_behind(who), shoulders, head, front)
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d"><defs>%s</defs>'
            '<g clip-path="url(#badge)"><circle cx="256" cy="256" r="256" fill="url(#back)"/>%s</g>%s</svg>'
            % (SIZE, SIZE, SIZE, SIZE, defs(who, outline), figure, ring))


def write(svg, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with tempfile.NamedTemporaryFile("w", suffix=".svg", delete=False) as f:
        f.write(svg)
    subprocess.run(["rsvg-convert", "-w", str(PIXELS), "-h", str(PIXELS), f.name, "-o", path], check=True)
    os.unlink(f.name)


def main():
    for name, who in PEOPLE.items():
        write(portrait(who), os.path.join(OUT, name + ".png"))
    print("wrote %d portraits" % len(PEOPLE))


if __name__ == "__main__":
    main()
