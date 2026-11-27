#!/usr/bin/env python3
"""The Play Store's pictures (docs/STORE.md), from the raw ones tools/store_shots.tscn takes.

Each screenshot is a raw picture under a caption band (the style the owner picked, 27 Nov: "B"); the feature
graphic is the first picture with the game's name. Writes store/*.jpg (1920x1080) and store/feature_graphic.png
(1024x500, no alpha), the sizes Google Play asks for.

    python3 tools/make_store_art.py [raw folder, default ci_shots/store]
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTS = os.path.join(ROOT, "fonts")
OUT = os.path.join(ROOT, "store")
SIZE = (1920, 1080)
FEATURE = (1024, 500)
BAND = 250            # the caption band's height
RULE = 14             # the gold rule under it
MARGIN = 60           # cream round the picture
CORNER = 36
CREAM, RED, GOLD, WORDS = (251, 245, 230), (180, 69, 47), (240, 190, 60), (255, 250, 235)
NAME = "Barnlight"
# [raw picture, caption, how far down the picture the cut starts (0 top .. 1 bottom)], in the listing's order.
# Captions say what is there and never "best", "free" or a rank (Google refuses those).
SHOTS = [
    ("landmarks", "Build your dream farm", 0.35),
    ("crops", "Plant, grow and harvest", 0.5),
    ("animals", "Raise animals of every kind", 0.5),
    ("homes", "Barns, homes and workshops", 0.5),
    ("orchard", "Orchards and flower gardens", 0.6),
    ("farm", "Trees in every colour", 0.4),
    ("landmarks_night", "Day turns to night", 0.35),
    ("market", "A market full of things to collect", 0.0),
]


def font(size, weight="Bold"):
    return ImageFont.truetype(os.path.join(FONTS, "Poppins-%s.ttf" % weight), size)


def rounded(picture, radius):
    mask = Image.new("L", picture.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, picture.size[0] - 1, picture.size[1] - 1), radius, fill=255)
    out = picture.convert("RGBA")
    out.putalpha(mask)
    return out


def shadow(size, radius, blur=24, alpha=110):
    s = Image.new("RGBA", (size[0] + blur * 4, size[1] + blur * 4), (0, 0, 0, 0))
    ImageDraw.Draw(s).rounded_rectangle((blur * 2, blur * 2, blur * 2 + size[0], blur * 2 + size[1]), radius,
                                        fill=(30, 20, 10, alpha))
    return s.filter(ImageFilter.GaussianBlur(blur))


def screenshot(raw, caption, cut):
    im = Image.new("RGB", SIZE, CREAM)
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, SIZE[0], BAND), fill=RED)
    d.rectangle((0, BAND - RULE, SIZE[0], BAND), fill=GOLD)
    size = 96
    while d.textlength(caption, font=font(size)) > SIZE[0] - 2 * MARGIN:
        size -= 4
    d.text(((SIZE[0] - d.textlength(caption, font=font(size))) / 2, (BAND - RULE - size * 1.45) / 2), caption,
           font=font(size), fill=WORDS)
    wide = SIZE[0] - 2 * MARGIN
    tall = SIZE[1] - BAND - MARGIN - 40
    full = raw.resize((wide, wide * raw.size[1] // raw.size[0]), Image.LANCZOS)
    top = int((full.size[1] - tall) * cut)
    shot = rounded(full.crop((0, top, wide, top + tall)), CORNER)
    im = im.convert("RGBA")
    im.alpha_composite(shadow(shot.size, CORNER), (MARGIN - 48, BAND + 40 - 48 + 10))
    im.alpha_composite(shot, (MARGIN, BAND + 40))
    return im.convert("RGB")


def feature(raw):
    full = raw.resize((FEATURE[0], FEATURE[0] * raw.size[1] // raw.size[0]), Image.LANCZOS)
    band = 150
    top = int((full.size[1] - (FEATURE[1] - band)) * 0.3)
    im = Image.new("RGB", FEATURE, RED)
    im.paste(full.crop((0, top, FEATURE[0], top + FEATURE[1] - band)), (0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle((0, FEATURE[1] - band, FEATURE[0], FEATURE[1] - band + 8), fill=GOLD)
    d.text(((FEATURE[0] - d.textlength(NAME, font=font(84))) / 2, FEATURE[1] - band + 14), NAME, font=font(84), fill=WORDS)
    return im


def main():
    raw_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "ci_shots", "store")
    os.makedirs(OUT, exist_ok=True)
    for k, (name, caption, cut) in enumerate(SHOTS):
        raw = Image.open(os.path.join(raw_dir, name + ".png")).convert("RGB")
        screenshot(raw, caption, cut).save(os.path.join(OUT, "%d_%s.jpg" % (k + 1, name)), quality=92)
        if k == 0:
            feature(raw).save(os.path.join(OUT, "feature_graphic.png"))
    print("wrote %d screenshots and the feature graphic to %s" % (len(SHOTS), OUT))


if __name__ == "__main__":
    main()
