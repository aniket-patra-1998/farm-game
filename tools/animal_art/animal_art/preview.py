"""Previews of the models in motion: every animal in two of the game's poses, and short clips."""
import math

from PIL import Image

from .build import lightest
from .motion import deform, pose, script
from .registry import MADE
from .render import camera, label, paint
from .rig import rig_of

YAW = 1.3            # the game's camera angle
GROUND = (111, 168, 68)


def pose_sheet(out, names, tile=230, per_row=4):
    """Every named animal at phone weight in two poses: mid-stride (or mid-hop) and head down."""
    rows = (len(names) + per_row - 1) // per_row
    im = Image.new("RGB", (tile * 2 * per_row, tile * rows), GROUND)
    for i, name in enumerate(names):
        a = lightest(MADE[name][0]); rig, W = rig_of(a, name); span, cen = camera(a, YAW, 1.5)
        poses = (dict(gait=0.3, stride=1.0, hop=0.7 if rig.get("hop") else 0.0, time=0.4), dict(head=1.0, time=0.0))
        for j, p in enumerate(poses):
            V, N = deform(a, W, pose(rig, p), p, rig)
            im.paste(paint(a, YAW, size=tile, span=span, center=cen, V=V, vn=N), (((i % per_row) * 2 + j) * tile, (i // per_row) * tile))
        label(im, ((i % per_row) * 2 * tile + 8, (i // per_row) * tile + tile - 22), name)
    im.save(out)


def clip(out, names, tile=300, fps=12, seconds=6.0):
    """Up to four animals moving side by side: walk (or hop, or hover), look and blink, head down, head up."""
    made = []
    for name in names[:4]:
        a = lightest(MADE[name][0]); rig, W = rig_of(a, name); made.append((name, a, rig, W, camera(a, YAW, 1.5)))
    frames = []
    for i in range(int(seconds * fps)):
        fr = Image.new("RGB", (tile * 2, tile * 2), GROUND)
        for k, (name, a, rig, W, (span, cen)) in enumerate(made):
            p = script(i / fps, rig); V, N = deform(a, W, pose(rig, p), p, rig)
            fr.paste(paint(a, YAW, size=tile, span=span, center=cen, V=V, vn=N), ((k % 2) * tile, (k // 2) * tile))
            label(fr, ((k % 2) * tile + 8, (k // 2) * tile + tile - 22), name)
        frames.append(fr)
    frames[0].save(out, save_all=True, append_images=frames[1:], duration=int(1000 / fps), loop=0)
