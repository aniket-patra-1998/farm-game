#!/usr/bin/env python3
"""Makes the game's number face (fonts/Poppins-BoldTab.ttf) from Poppins Bold: every digit as wide as the widest,
its shape centred in that width, so a number that changes (coins counting up, a timer) never shifts sideways.
Poppins has no tabular-figures feature of its own. A Modified Version under the SIL OFL (fonts/OFL.txt), renamed.

    python3 tools/make_tabular_font.py
"""
import os
from fontTools.ttLib import TTFont

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "fonts", "Poppins-Bold.ttf")
OUT = os.path.join(HERE, "..", "fonts", "Poppins-BoldTab.ttf")
FAMILY = "Poppins Tab"   # (renamed: a modified font must not carry the original's name as its own)


def main() -> None:
    font = TTFont(SRC)
    cmap = font.getBestCmap()
    hmtx = font["hmtx"]
    glyf = font["glyf"]
    digits = [cmap[ord(str(d))] for d in range(10)]
    wide = max(hmtx[g][0] for g in digits)
    for g in digits:
        adv, lsb = hmtx[g]
        dx = (wide - adv) // 2
        glyph = glyf[g]
        if dx and glyph.numberOfContours != 0:
            if glyph.isComposite():
                for comp in glyph.components:
                    comp.x += dx
            else:
                glyph.coordinates.translate((dx, 0))
            glyph.recalcBounds(glyf)
        hmtx[g] = (wide, lsb + dx)
    for rec in font["name"].names:
        if rec.nameID in (1, 4, 16):
            rec.string = rec.toUnicode().replace("Poppins", FAMILY)
        elif rec.nameID == 6:
            rec.string = rec.toUnicode().replace("Poppins", FAMILY.replace(" ", ""))
    font.save(OUT)
    print("wrote", os.path.relpath(OUT, os.path.join(HERE, "..")), "digits", wide, "units wide")


if __name__ == "__main__":
    main()
