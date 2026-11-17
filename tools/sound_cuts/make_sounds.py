"""Cuts the game's recorded sounds out of the downloaded CC0 recordings (art/sound/SOURCES.md).

python3 tools/sound_cuts/make_sounds.py <folder with the downloads>

Animal calls: each cut is trimmed to its call, faded in and out (no clicks), brought to one loudness and kept
mono. Ambience beds: a stretch of each recording, its end cross-faded into its start so it loops without a seam,
brought to a quieter loudness, kept stereo. Everything is written as Ogg Vorbis into art/sound/. Needs ffmpeg and
numpy. The cut list below is the whole recipe: change it and run again.
"""
import pathlib
import subprocess
import sys

import numpy as np

SR = 44100
OUT = pathlib.Path(__file__).resolve().parents[2] / "art" / "sound"
VOICE_RMS_DB = -18.0    # the loudness every call is brought to (of its loud part)
BED_RMS_DB = -26.0      # ambience sits well under the effects
PEAK_DB = -1.0
FADE_IN, FADE_OUT = 0.008, 0.05
BED_XFADE = 3.0

# name -> (source file, [(start s, end s), ...]); each cut becomes <name>_<n>.ogg
VOICES = {
    "cow": ("cow-moo.mp3", [(3.0, 5.2)]),
    "calf": ("calf.mp3", [(0.0, 1.72)]),
    "sheep": ("sheep.mp3", [(0.05, 1.85), (2.38, 3.55)]),
    "lamb": ("lamb.mp3", [(23.4, 24.95), (33.85, 34.9), (6.65, 7.95), (30.8, 32.35)]),
    "goat": ("goat.mp3", [(0.32, 1.15), (2.07, 2.92)]),
    "kid": ("baby goat.mp3", [(1.29, 2.15), (4.75, 5.48), (5.95, 6.9), (0.0, 0.85)]),
    "pig": ("pig.mp3", [(0.0, 0.78)]),
    "donkey": ("donkey.mp3", [(0.12, 1.4)]),
    "hen": ("chicken.mp3", [(5.14, 5.58), (8.3, 8.86), (4.12, 4.6), (9.07, 9.53), (0.13, 0.48)]),
    "rooster": ("rooster.mp3", [(1.2, 3.3)]),
    "duck": ("duck.mp3", [(0.15, 0.78), (0.85, 1.28), (0.15, 1.28)]),
    "turkey": ("turkey.mp3", [(0.0, 1.05)]),
    "alpaca": ("alpaca.mp3", [(0.0, 0.6)]),
    "bee": ("bee.mp3", [(0.22, 2.4)]),
}
# name -> (source file, start s, length s)
BEDS = {
    "morning": ("morning-bird.mp3", 1.0, 60.0),
    "summer": ("summer-ambience.mp3", 0.0, 58.0),
    "night": ("cricket-night.mp3", 20.0, 75.0),
    "rain": ("rain.mp3", 20.0, 75.0),
}


def load(path: pathlib.Path, channels: int) -> np.ndarray:
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-ac", str(channels), "-ar", str(SR),
                          "-f", "f32le", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).reshape(-1, channels).copy()


def level(x: np.ndarray, rms_db: float) -> np.ndarray:
    """Brings the loud part (the top fifth of 10 ms blocks) to rms_db, never peaking over PEAK_DB."""
    hop = SR // 100
    blocks = [np.sqrt(np.mean(x[i:i + hop] ** 2)) for i in range(0, max(len(x) - hop, 1), hop)]
    loud = np.sort(blocks)[-max(1, len(blocks) // 5):].mean()
    gain = 10 ** (rms_db / 20) / max(loud, 1e-6)
    gain = min(gain, 10 ** (PEAK_DB / 20) / max(np.abs(x).max(), 1e-6))
    return x * gain


def write(x: np.ndarray, path: pathlib.Path, quality: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", str(x.shape[1]), "-i", "-",
                    "-c:a", "libvorbis", "-q:a", str(quality), str(path)],
                   input=x.astype(np.float32).tobytes(), check=True)


def cut_voice(x: np.ndarray, a: float, b: float) -> np.ndarray:
    y = x[int(a * SR):int(b * SR)].copy()
    n_in, n_out = int(FADE_IN * SR), int(FADE_OUT * SR)
    y[:n_in] *= np.linspace(0, 1, n_in)[:, None]
    y[-n_out:] *= np.linspace(1, 0, n_out)[:, None]
    return level(y, VOICE_RMS_DB)


def make_bed(x: np.ndarray, start: float, length: float) -> np.ndarray:
    n, c = int(length * SR), int(BED_XFADE * SR)
    y = x[int(start * SR):int(start * SR) + n + c].copy()
    n = len(y) - c
    # equal-power cross-fade: the stretch after the end is laid over the start, so the loop point is seamless
    t = np.linspace(0, np.pi / 2, c)[:, None]
    loop = y[:n].copy()
    loop[:c] = y[:c] * np.sin(t) + y[n:n + c] * np.cos(t)
    return level(loop, BED_RMS_DB)


def main(src: pathlib.Path) -> None:
    for name, (file, cuts) in VOICES.items():
        x = load(src / file, 1)
        for k, (a, b) in enumerate(cuts, 1):
            write(cut_voice(x, a, b), OUT / "voices" / f"{name}_{k}.ogg", 5)
    for name, (file, start, length) in BEDS.items():
        write(make_bed(load(src / file, 2), start, length), OUT / "ambience" / f"{name}.ogg", 3)



def stamp() -> None:
    """Records that the sound files are made from these builders now (tools/make_art_versions.py checks it)."""
    import subprocess
    subprocess.run([sys.executable, str(OUT.parents[1] / "tools" / "make_art_versions.py"), "--exported", "sounds"], check=True)


if __name__ == "__main__":
    main(pathlib.Path(sys.argv[1]))
    stamp()
