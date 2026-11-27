#!/usr/bin/env python3
"""The store's preview video (docs/STORE.md), from what tools/store_film.tscn films.

Cuts the day and night recordings into scenes, each under its caption band (the screenshots' style), adds an end
card with the game's name, and joins them: store/preview.mp4 (1280x720, 30 frames a second, no sound).

    python3 tools/make_store_film.py <day.avi> <night.avi> <name=first frame,...>

where the last argument is what store_film printed ("FILM crops 180 105" is crops=180; the night recording's
scene is landmarks_night). A scene filmed again on its own names its recording: landmarks=58@/tmp/again.avi.
"""
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw

from make_store_art import GOLD, NAME, RED, WORDS, font

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "store", "preview.mp4")
SIZE = (1280, 720)
BAND = 120
RULE = 8
FRAMES = 105          # a scene's length, as store_film films it
END_SECONDS = 2.6
FADE = 12             # frames of fade in at the start and out at the end
ENCODE = ["-c:v", "libx264", "-crf", "18", "-preset", "veryfast", "-pix_fmt", "yuv420p", "-r", "30", "-an"]
# [scene, which recording (0 day, 1 night), caption], in order.
SCENES = [("landmarks", 0, "Build your dream farm"), ("crops", 0, "Plant, grow and harvest"),
          ("animals", 0, "Raise animals of every kind"), ("homes", 0, "Barns, homes and workshops"),
          ("landmarks_night", 1, "Day turns to night")]


def band(caption, path, tall=BAND, size=54):
    im = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, SIZE[0], tall), fill=RED + (255,))
    d.rectangle((0, tall - RULE, SIZE[0], tall), fill=GOLD + (255,))
    d.text(((SIZE[0] - d.textlength(caption, font=font(size))) / 2, (tall - RULE - size * 1.45) / 2), caption,
           font=font(size), fill=WORDS)
    im.save(path)


def run(args):
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error"] + args, check=True)


def main():
    day, night, marks = sys.argv[1], sys.argv[2], sys.argv[3]
    starts = {}
    films = {}
    for m in marks.split(","):
        name, where = m.split("=")
        starts[name] = int(where.split("@")[0])
        if "@" in where:
            films[name] = where.split("@")[1]
    work = tempfile.mkdtemp()
    parts = []
    for k, (name, which, caption) in enumerate(SCENES):
        over = os.path.join(work, name + ".png")
        band(caption, over)
        first = starts[name]
        fade = ",fade=in:0:%d" % FADE if k == 0 else ""
        part = os.path.join(work, "%d_%s.mp4" % (k, name))
        run(["-i", films.get(name, [day, night][which]), "-i", over, "-filter_complex",
             "[0:v]trim=start_frame=%d:end_frame=%d,setpts=PTS-STARTPTS[v];[v][1:v]overlay=0:0%s" % (
                 first, first + FRAMES, fade)] + ENCODE + [part + ".tmp.mp4"])
        os.rename(part + ".tmp.mp4", part)
        parts.append(part)
    # The end card: the first scene's last frame, held, under a deeper band with the game's name.
    still = os.path.join(work, "end.png")
    run(["-i", films.get("landmarks", day), "-vf", "select=eq(n\\,%d)" % (starts["landmarks"] + FRAMES - 1),
         "-frames:v", "1", still])
    card = Image.open(still).convert("RGBA")
    over = os.path.join(work, "end_band.png")
    band(NAME, over, 260, 120)
    name_band = Image.open(over).crop((0, 0, SIZE[0], 260))
    card.alpha_composite(name_band, (0, (SIZE[1] - 260) // 2))
    card.convert("RGB").save(still)
    count = int(END_SECONDS * 30)
    part = os.path.join(work, "9_end.mp4")
    run(["-framerate", "30", "-i", still, "-vf",
         "format=yuv420p,loop=-1:1,trim=duration=%.2f,fade=out:%d:%d" % (END_SECONDS, count - FADE, FADE)]
        + ENCODE + [part + ".tmp.mp4"])
    os.rename(part + ".tmp.mp4", part)
    parts.append(part)
    listing = os.path.join(work, "parts.txt")
    with open(listing, "w") as f:
        f.write("".join("file '%s'\n" % p for p in parts))
    run(["-f", "concat", "-safe", "0", "-i", listing, "-c", "copy", OUT + ".tmp.mp4"])
    os.rename(OUT + ".tmp.mp4", OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
