"""Measures every sound file: the first step before (and after) any change to a sound.

python3 tools/sound_cuts/audit.py            prints a table
python3 tools/sound_cuts/audit.py --write    also writes data/sound_levels.json (make_sounds/make_generated do)

Per file: phone (dB): its loudness as a phone or laptop speaker plays it (make_sounds.phone_loudness: the band
those speakers give, 300 Hz to 8 kHz, over the moments that sound), the measure every target is in; full (dB):
the same over the whole band, as headphones give it; lost: what a small speaker loses (a deep sound loses most);
peak (dBFS); crest (peak over full: high is spiky); centroid (Hz: where its tone sits); sha256, so sound_test
knows the measures are of the file in the repo. sound_test holds every kind to its target (calls, beds, rain,
music) on both measures, peaks under full scale, and the mix in the game on top.
"""
import hashlib
import json
import pathlib
import sys

import numpy as np
from scipy import signal

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from make_sounds import OUT, SR, full_loudness, load, phone_loudness  # noqa: E402

LEVELS = OUT.parents[1] / "data" / "sound_levels.json"


def db(v: float) -> float:
    return round(20 * float(np.log10(max(v, 1e-9))), 2)


def measure(path: pathlib.Path) -> dict:
    x = load(path, 1)
    f, p = signal.welch(x[:, 0], SR, nperseg=4096)
    phone, full = db(phone_loudness(x)), db(full_loudness(x))
    return {"sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "seconds": round(len(x) / SR, 2),
            "phone_db": phone, "full_db": full, "lost_db": round(full - phone, 2),
            "peak_db": db(np.abs(x).max()), "centroid_hz": int((f * p).sum() / p.sum())}


def main() -> None:
    rows = {str(p.relative_to(OUT)): measure(p) for p in sorted(OUT.rglob("*.ogg"))}
    print(f"{'file':32s} {'sec':>6s} {'phone':>6s} {'full':>6s} {'lost':>5s} {'peak':>6s} {'tone Hz':>7s}")
    for name, r in rows.items():
        print(f"{name:32s} {r['seconds']:6.1f} {r['phone_db']:6.1f} {r['full_db']:6.1f} {r['lost_db']:5.1f}"
              f" {r['peak_db']:6.1f} {r['centroid_hz']:7d}")
    if "--write" in sys.argv:
        doc = "Every sound file's measures (tools/sound_cuts/audit.py --write); sound_test holds them to the targets."
        LEVELS.write_text(json.dumps({"_doc": doc, "files": rows}, indent=1) + "\n")
        print("wrote", LEVELS.relative_to(OUT.parents[1]))


if __name__ == "__main__":
    main()
