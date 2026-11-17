"""Cuts the game's recorded sounds out of the downloaded CC0 recordings (art/sound/SOURCES.md).

python3 tools/sound_cuts/make_sounds.py <folder with the downloads>

Animal calls: each cut is trimmed to its call, faded in and out (no clicks) and kept mono. Ambience beds: a
stretch of each recording, its end cross-faded into its start so it loops without a seam, kept stereo. Every file
is then levelled the same way (`level`): the rumble under its kind's floor taken out, its loudness measured as a
phone's speaker plays it (nothing much under 300 Hz or over 8 kHz, so a deep moo is not counted as loud as it
reads), brought to its kind's target (calls, beds, the rain, music), and sharp peaks rounded off instead of the
whole sound turned down for them. tools/sound_cuts/audit.py prints every file's measures. Everything is written as Ogg Vorbis into art/sound/. Needs ffmpeg and
numpy. The cut list below is the whole recipe: change it and run again.
"""
import pathlib
import subprocess
import sys

import numpy as np
from scipy import signal

SR = 44100
OUT = pathlib.Path(__file__).resolve().parents[2] / "art" / "sound"
# Loudness targets, as a phone plays them (`phone_loudness`); the game's gains set the mix on top (sound_test).
VOICE_RMS_DB = -20.0    # every animal call
BED_RMS_DB = -30.0      # the farm's background beds
RAIN_RMS_DB = -26.0     # the rain: the sound heard while it rains
PEAK_DB = -1.0
KNEE_DB = -6.0          # peaks over this are rounded off, not the whole sound turned down
FULL_OVER_DB = 3.0      # on full-range speakers (laptop, headphones) a sound is never more than this over its target
VOICE_LOW_CUT = 90.0    # Hz: under this a call is only rumble (handling, wind)
BED_LOW_CUT = 120.0     # a bed's wind rumble, unheard on a phone and muddy elsewhere
BED_TARGETS = {"rain": RAIN_RMS_DB}
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


PHONE = (signal.butter(4, 300 / (SR / 2), "high", output="sos"), signal.butter(2, 8000 / (SR / 2), "low", output="sos"))


def phone_loudness(x: np.ndarray) -> float:
    """How loud a sound is through a phone's speaker: its level after the speaker's band (300 Hz to 8 kHz), over
    the 50 ms blocks that sound (within 20 dB of its loudest), so quiet gaps don't count."""
    m = signal.sosfilt(PHONE[1], signal.sosfilt(PHONE[0], x.mean(axis=1)))
    hop = SR // 20
    blocks = np.array([np.sqrt(np.mean(m[i:i + hop] ** 2)) for i in range(0, max(len(m) - hop, 1), hop)])
    heard = blocks[blocks > blocks.max() * 0.1]
    return float(np.sqrt(np.mean(heard ** 2)))


def full_loudness(x: np.ndarray) -> float:
    """phone_loudness over the whole band, as headphones and good laptop speakers give it."""
    m = x.mean(axis=1)
    hop = SR // 20
    blocks = np.array([np.sqrt(np.mean(m[i:i + hop] ** 2)) for i in range(0, max(len(m) - hop, 1), hop)])
    heard = blocks[blocks > blocks.max() * 0.1]
    return float(np.sqrt(np.mean(heard ** 2)))


def soft_peaks(x: np.ndarray) -> np.ndarray:
    """Rounds off what goes over KNEE_DB (a smooth knee, never past full scale)."""
    knee = 10 ** (KNEE_DB / 20)
    a = np.abs(x)
    over = a > knee
    y = x.copy()
    y[over] = np.sign(x[over]) * (knee + (1 - knee) * np.tanh((a[over] - knee) / (1 - knee)))
    return y


def level(x: np.ndarray, rms_db: float, low_cut: float = VOICE_LOW_CUT) -> np.ndarray:
    """The rumble under low_cut taken out, then the sound brought to rms_db as a phone plays it (and no more than
    FULL_OVER_DB over it on full-range speakers), its peaks rounded off; never over PEAK_DB."""
    x = signal.sosfilt(signal.butter(2, low_cut / (SR / 2), "high", output="sos"), x, axis=0)
    target, ceiling = 10 ** (rms_db / 20), 10 ** ((rms_db + FULL_OVER_DB) / 20)
    gain = target / max(phone_loudness(x), 1e-9)
    for _ in range(3):      # rounding the peaks takes a little loudness away: aim again
        y = soft_peaks(x * gain)
        # a deep sound (a moo, a buzz) aimed for a phone would boom on headphones: held under the ceiling
        gain *= min(target / max(phone_loudness(y), 1e-9), ceiling / max(full_loudness(y), 1e-9))
    y = soft_peaks(x * gain)
    return y * min(1.0, 10 ** (PEAK_DB / 20) / max(np.abs(y).max(), 1e-9))


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
    return loop


def main(src: pathlib.Path) -> None:
    for name, (file, cuts) in VOICES.items():
        x = load(src / file, 1)
        for k, (a, b) in enumerate(cuts, 1):
            write(cut_voice(x, a, b), OUT / "voices" / f"{name}_{k}.ogg", 5)
    for name, (file, start, length) in BEDS.items():
        bed = level(make_bed(load(src / file, 2), start, length), BED_TARGETS.get(name, BED_RMS_DB), BED_LOW_CUT)
        write(bed, OUT / "ambience" / f"{name}.ogg", 3)



def stamp() -> None:
    """Records that the sound files are made from these builders now (tools/make_art_versions.py checks it),
    and measures every file into data/sound_levels.json (audit.py), which sound_test holds to the targets."""
    tools = OUT.parents[1] / "tools"
    subprocess.run([sys.executable, str(tools / "make_art_versions.py"), "--exported", "sounds"], check=True)
    subprocess.run([sys.executable, str(tools / "sound_cuts" / "audit.py"), "--write"], check=True)


if __name__ == "__main__":
    main(pathlib.Path(sys.argv[1]))
    stamp()
