"""Command line:  python3 -m animal_art <command> ...   (run from tools/animal_art)
  list                          every animal the game has, by family, and the parked extras
  sheet  OUT.png  "a,b|c,d"     the finished look, full detail: rows of animals, game angle on top, front quarter below
  poses  OUT.png  "a,b,c"       phone weight, two of the game's poses each: mid-stride and head down
  clip   OUT.gif  "a,b,c,d"     phone weight, up to four animals moving
  export DIR      "a,b,c"       the game's files: DIR/<id>.glb each (mesh, colours, moves as blend shapes);
                                list each in data/assets.json ("budget": "animal") to use it in the game"""
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
    elif cmd == "export":
        import os
        from .export import export
        for n in names:
            print(export(n, os.path.join(out, n.replace(" ", "_") + ".glb")))
        # Every game animal exported: the files are what the builder makes now. Record it, and the pictures'
        # fingerprints (tools/make_art_versions.py; CI fails when the builder changes without a new export).
        game = {g for row in GAME.values() for g in row}
        if game <= set(names):
            import subprocess
            subprocess.run([sys.executable, os.path.join(os.path.dirname(__file__), "..", "..", "make_art_versions.py"),
                            "--exported", "animals"], check=False)
        else:
            print("(some animals only: run every animal before pushing, or CI will ask for it)")
    else:
        print(__doc__)
        return 2
    return 0
