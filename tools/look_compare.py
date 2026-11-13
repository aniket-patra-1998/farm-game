#!/usr/bin/env python3
"""Join the pictures of two look_shot folders side by side (before left, after right), one file per view.
   look_compare.py <before_dir> <after_dir> <out_dir> [view ...]"""
import os
import sys
from PIL import Image, ImageDraw

before, after, out = sys.argv[1:4]
views = sys.argv[4:] or ["all", "buildings", "trees_animals", "crops"]
os.makedirs(out, exist_ok=True)
for v in views:
    a = Image.open(os.path.join(before, v + ".png")).convert("RGB")
    b = Image.open(os.path.join(after, v + ".png")).convert("RGB")
    sheet = Image.new("RGB", (a.width + b.width + 12, a.height + 30), "#222")
    sheet.paste(a, (0, 30))
    sheet.paste(b, (a.width + 12, 30))
    d = ImageDraw.Draw(sheet)
    d.text((10, 8), "BEFORE", fill="white")
    d.text((a.width + 22, 8), "AFTER", fill="white")
    sheet.save(os.path.join(out, v + ".png"))
