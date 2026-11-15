"""Command line:  python3 -m animal_art <command> ...   (run from tools/animal_art)
  list                          every animal the game has, by family, and the parked extras
  sheet  OUT.png  "a,b|c,d"     the finished look, full detail: rows of animals, game angle on top, front quarter below
  poses  OUT.png  "a,b,c"       phone weight, two of the game's poses each: mid-stride and head down
  clip   OUT.gif  "a,b,c,d"     phone weight, up to four animals moving
  export FOLDER   [a,b]         the crops and trees as the game's model files (.glb), all of them or the ones named"""
import sys

from .registry import GAME, MADE, PARKED


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if not argv or argv[0] in ("-h", "--help", "help"):
        print(__doc__)
        return 0
    cmd = argv[0]
    if cmd == "list":
        for family, names in GAME.items():
            print("%-9s %s" % (family, ", ".join(names)))
        print("%-9s %s" % ("parked", ", ".join(PARKED)))
        return 0
    if cmd == "export" and len(argv) >= 2:
        from . import plants
        every = list(plants.CROPS) + list(plants.TREES)
        wanted = argv[2].split(",") if len(argv) > 2 else every
        unknown = [n for n in wanted if n not in every]
        if unknown:
            print("unknown plant(s): " + ", ".join(unknown))
            return 2
        for n in wanted:
            parts = plants.export(n, argv[1])
            print("%-14s %5d triangles  (%s)" % (n, sum(parts.values()), ", ".join("%s %d" % (k.replace("when_", ""), v) for k, v in parts.items())))
        return 0
    if len(argv) < 3:
        print(__doc__)
        return 2
    out = argv[1]
    names = [n for row in argv[2].split("|") for n in row.split(",")]
    unknown = [n for n in names if n not in MADE]
    if unknown:
        print("unknown animal(s): " + ", ".join(unknown))
        return 2
    if cmd == "sheet":
        from .render import sheet
        sheet(out, [row.split(",") for row in argv[2].split("|")])
    elif cmd == "poses":
        from .preview import pose_sheet
        pose_sheet(out, names)
    elif cmd == "clip":
        from .preview import clip
        clip(out, names)
    else:
        print(__doc__)
        return 2
    return 0
