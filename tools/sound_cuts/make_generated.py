"""Makes the sounds no traceable CC0 recording was found for, from scratch (our own work, so ours to give away:
CC0): a horse's whinny and snort, a goose's honk, the three farmyards by day, and the farm's music. Written into
art/sound/ like the cuts.

python3 tools/sound_cuts/make_generated.py

Calls are made source-filter style, the way a throat makes them: a buzzing source (pulses at the voice's
pitch, which glides and trembles as the animal's does) through resonances (formants) that shape the vowel,
with breath noise. A farmyard is wind and birdsong made here, with the game's own traced CC0 calls
(art/sound/voices, cut by make_sounds.py) heard now and then from across the farm: quieter, duller, to one
side, in the open air; it loops without a seam, as the cut beds do. The music is written out note by note below (MELODIES) and played by small instrument
models: a plucked string (Karplus-Strong) for guitar and bass, a breathy flute, a soft reed pad and a shaker,
in a little room (a made-up reverb). Needs numpy, scipy and ffmpeg. Seeded: the same files every run.
"""
import pathlib

import numpy as np
from scipy import signal

from make_sounds import OUT, SR, VOICE_RMS_DB, level, load, stamp, write

RNG = np.random.default_rng(7)
MUSIC_RMS_DB = -21.0


# ---------------------------------------------------------------- voices


def resonate(x, freq, bw):
    """A two-pole resonance at `freq` (Hz, a number or a curve) with bandwidth `bw` (Hz)."""
    freq = np.broadcast_to(np.asarray(freq, float), x.shape)
    r = np.exp(-np.pi * bw / SR)
    y = np.zeros_like(x)
    y1 = y2 = 0.0
    for i in range(len(x)):
        c = 2 * r * np.cos(2 * np.pi * freq[i] / SR)
        v = x[i] + c * y1 - r * r * y2
        y[i] = v
        y2, y1 = y1, v
    return y * (1 - r)


def pulses(f0):
    """A glottal buzz following the pitch curve f0 (Hz per sample): sharp pulses, rich in harmonics."""
    phase = np.cumsum(f0 / SR)
    frac = phase % 1.0
    return (np.exp(-frac * 9.0) - 0.12) * 1.0


def envelope(n, attack, release):
    e = np.ones(n)
    a, r = int(attack * SR), int(release * SR)
    e[:a] = np.linspace(0, 1, a)
    e[-r:] *= np.linspace(1, 0, r) ** 1.5
    return e


def call(f0, formants, breath=0.08, attack=0.03, release=0.12):
    n = len(f0)
    src = pulses(f0) + breath * RNG.standard_normal(n)
    out = sum(g * resonate(src, f, bw) for f, bw, g in formants)
    return out * envelope(n, attack, release)


def curve(points, n):
    """A smooth curve through (share of the length, value) points."""
    xs, ys = zip(*points)
    return np.interp(np.linspace(0, 1, n), xs, ys)


def whinny(length, top, seed):
    rng = np.random.default_rng(seed)
    n = int(length * SR)
    t = np.arange(n) / SR
    # up fast to a squeal, then down in a shaking trill (the whinny), ending low and rough
    f0 = curve([(0, top * 0.55), (0.1, top), (0.3, top * 0.92), (0.75, top * 0.55), (1, top * 0.32)], n)
    trill = 1 + curve([(0, 0.0), (0.2, 0.02), (0.4, 0.09), (1, 0.12)], n) * np.sin(2 * np.pi * (17 + rng.random() * 4) * t)
    f0 = f0 * trill * (1 + 0.01 * rng.standard_normal(n).cumsum() / np.sqrt(n))
    f1 = curve([(0, 450), (0.25, 700), (1, 800)], n)       # "ee" opening to "aa"
    f2 = curve([(0, 2300), (0.25, 1700), (1, 1250)], n)
    body = call(f0, [(f1, 180, 1.0), (f2, 260, 0.7), (3000, 400, 0.35)], breath=0.22, attack=0.02, release=0.25)
    loud = curve([(0, 0.5), (0.1, 1), (0.6, 0.85), (1, 0.4)], n)
    return body * loud


def snort(length):
    n = int(length * SR)
    noise = RNG.standard_normal(n)
    b, a = signal.butter(2, [180 / (SR / 2), 1400 / (SR / 2)], "band")
    x = signal.lfilter(b, a, noise) * envelope(n, 0.01, length * 0.7)
    flutter = 1 + 0.6 * np.sin(2 * np.pi * 34 * np.arange(n) / SR)    # the lips flapping
    return x * flutter


def honk(length, pitch):
    n = int(length * SR)
    f0 = curve([(0, pitch * 0.85), (0.2, pitch), (0.8, pitch * 0.97), (1, pitch * 0.8)], n)
    # nasal and brassy: a low first resonance, a strong one high up, and a dip between
    return call(f0, [(700, 120, 1.0), (1500, 200, 0.6), (2600, 260, 0.8), (3600, 300, 0.3)],
                breath=0.05, attack=0.015, release=0.06)


def voices():
    for k, (length, top, extra) in enumerate([(1.25, 950, 0.3), (0.95, 1050, 0.0), (1.5, 880, 0.35)], 1):
        x = whinny(length, top, k)
        if extra:
            gap = np.zeros(int(0.06 * SR))
            x = np.concatenate([x, gap, snort(extra) * 0.5 * np.abs(x).max() / 0.3])
        write(level(x[:, None], VOICE_RMS_DB), OUT / "voices" / f"horse_{k}.ogg", 5)
    for k, honks in enumerate([[(0.22, 400)], [(0.2, 420), (0.24, 380)], [(0.3, 360)]], 1):
        parts = []
        for length, pitch in honks:
            parts += [honk(length, pitch), np.zeros(int(0.09 * SR))]
        write(level(np.concatenate(parts)[:, None], VOICE_RMS_DB), OUT / "voices" / f"goose_{k}.ogg", 5)


# ---------------------------------------------------------------- music


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def pluck(f, length, bright=0.5, decay=0.996):
    """A plucked string (Karplus-Strong): a burst of noise round a delay line one period long, softened on
    each pass, so it rings at the string's pitch and dies away."""
    n = int(length * SR)
    p = SR / f
    d = int(p)
    frac = p - d
    buf = RNG.uniform(-1, 1, d)
    buf = signal.lfilter([bright, 1 - bright], [1], buf)        # the pick: brighter or rounder
    out = np.empty(n)
    prev = 0.0
    for i in range(n):
        j = i % d
        v = buf[j]
        out[i] = v
        nxt = buf[(j + 1) % d]
        new = decay * ((1 - frac) * 0.5 * (v + nxt) + frac * 0.5 * (nxt + prev))
        prev = v
        buf[j] = new
    return out * envelope(n, 0.002, 0.05)


def flute(f, length):
    n = int(length * SR)
    t = np.arange(n) / SR
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.2 * t) * np.clip(t / 0.35 - 0.3, 0, 1)
    ph = 2 * np.pi * np.cumsum(f * vib) / SR
    tone = np.sin(ph) + 0.22 * np.sin(2 * ph) + 0.06 * np.sin(3 * ph)
    b, a = signal.butter(2, [f * 0.8 / (SR / 2), min(f * 4, 9000) / (SR / 2)], "band")
    breath = signal.lfilter(b, a, RNG.standard_normal(n)) * 0.12
    return (tone + breath) * envelope(n, 0.06, min(0.12, length * 0.4))


def reed(f, length):
    """A soft reed pad (a harmonium's chord): a few detuned saws, rounded off, swelling in."""
    n = int(length * SR)
    t = np.arange(n) / SR
    x = sum(signal.sawtooth(2 * np.pi * f * dt * t) for dt in (0.997, 1.0, 1.004))
    b, a = signal.butter(2, min(f * 3, 3000) / (SR / 2))
    return signal.lfilter(b, a, x) / 3 * envelope(n, min(0.4, length * 0.3), min(0.5, length * 0.4))


def shaker(length):
    n = int(length * SR)
    b, a = signal.butter(2, 5000 / (SR / 2), "high")
    return signal.lfilter(b, a, RNG.standard_normal(n)) * envelope(n, 0.004, length * 0.9)


def room(x, seconds=1.8, wet=0.22):
    n = int(seconds * SR)
    ir = RNG.standard_normal((n, 2)) * np.exp(-np.arange(n) / (SR * seconds / 6.0))[:, None]
    ir[: int(0.015 * SR)] = 0
    b, a = signal.butter(1, 4500 / (SR / 2))
    ir = signal.lfilter(b, a, ir, axis=0)
    ir /= np.sqrt((ir ** 2).sum(axis=0))
    tail = np.stack([signal.fftconvolve(x[:, c], ir[:, c])[: len(x)] for c in range(2)], axis=1)
    return x * (1 - wet) + tail * wet


# A piece: tempo, beats per bar, its bars as (chord, melody); chords are root midi + kind; the melody is
# (midi or None for a rest, beats). The form repeats sections; the guitar fingerpicks every chord.
CHORDS = {"": [0, 4, 7], "m": [0, 3, 7]}
SUNNY = {
    "bpm": 100, "bar": 4, "lead": "flute",
    "sections": {
        "A": [("G", [(74, 1), (71, .5), (74, .5), (76, 1), (74, 1)]), ("G", [(71, 1.5), (69, .5), (67, 2)]),
              ("C", [(76, 1), (79, 1), (76, 1), (74, 1)]), ("G", [(71, 3), (None, 1)]),
              ("Em", [(71, 1), (74, .5), (76, .5), (79, 1), (76, 1)]), ("C", [(74, 1.5), (71, .5), (69, 2)]),
              ("D", [(69, 1), (71, .5), (69, .5), (66, 1), (69, 1)]), ("G", [(67, 3), (None, 1)])],
        "B": [("C", [(76, .5), (76, .5), (79, 1), (76, 1), (72, 1)]), ("D", [(74, 1), (78, 1), (81, 1.5), (79, .5)]),
              ("G", [(79, 2), (74, 2)]), ("Em", [(76, 1), (74, 1), (71, 2)]),
              ("C", [(72, 1), (76, 1), (79, 1), (76, 1)]), ("D", [(78, 1), (76, .5), (74, .5), (69, 2)]),
              ("G", [(71, 1), (74, 1), (79, 1), (71, 1)]), ("G", [(67, 4)])],
        "I": [("G", []), ("C", []), ("G", []), ("D", [])],
    },
    "form": ["I", "A", "B", "A", "I"],
}
PORCH = {
    "bpm": 76, "bar": 3, "lead": "pluck",
    "sections": {
        "A": [("D", [(78, 2), (76, 1)]), ("A", [(73, 2), (69, 1)]), ("Bm", [(74, 1.5), (73, .5), (71, 1)]),
              ("G", [(71, 3)]), ("D", [(69, 1), (74, 1), (78, 1)]), ("G", [(79, 2), (78, 1)]),
              ("A", [(76, 1), (73, 1), (69, 1)]), ("D", [(74, 3)])],
        "B": [("G", [(71, 1), (74, 1), (79, 1)]), ("D", [(78, 2), (74, 1)]), ("Em", [(76, 1.5), (78, .5), (79, 1)]),
              ("A", [(81, 2), (76, 1)]), ("D", [(78, 1), (76, 1), (74, 1)]), ("Bm", [(71, 2), (74, 1)]),
              ("A", [(73, 2), (76, 1)]), ("D", [(74, 3)])],
        "I": [("D", []), ("G", []), ("D", []), ("A", [])],
    },
    "form": ["I", "A", "B", "A", "B", "I"],
}
ROOTS = {"C": 48, "D": 50, "E": 52, "F": 53, "G": 55, "A": 57, "B": 59}


def chord_notes(name):
    root = ROOTS[name[0]]
    return root, [root + k for k in CHORDS[name[1:]]]


def place(track, sound, at, gain, pan):
    end = min(len(track), at + len(sound))
    g = np.array([np.cos(pan * np.pi / 2), np.sin(pan * np.pi / 2)]) * gain
    track[at:end] += sound[: end - at, None] * g


def piece(score):
    beat = 60.0 / score["bpm"]
    bars = [b for s in score["form"] for b in score["sections"][s]]
    total = len(bars) * score["bar"] * beat + 3.0
    mix = np.zeros((int(total * SR), 2))
    for k, (chord, melody) in enumerate(bars):
        start = k * score["bar"] * beat
        root, notes = chord_notes(chord)
        last = k == len(bars) - 1
        # the fingerpicked guitar: thumb on the root and fifth, fingers on the chord between
        for b in range(score["bar"]):
            t0 = int((start + b * beat) * SR)
            bass = root - 12 + (7 if b % 2 and score["bar"] == 4 else 0)
            place(mix, pluck(hz(bass), 1.6, 0.35, 0.995), t0, 0.5, 0.45)
            if last and b > 0:
                continue
            for h, note in enumerate(notes[1:] + [notes[0] + 12]):
                if score["bar"] == 3 and h > 1:
                    break
                at = int((start + (b + 0.5 + 0.12 * h * (score["bar"] == 4)) * beat) * SR)
                place(mix, pluck(hz(note + 12), 1.4, 0.55, 0.993), at, 0.24, 0.62)
        # the reed holds the chord under it all
        for note in notes:
            place(mix, reed(hz(note + 12), score["bar"] * beat + 0.3), int(start * SR), 0.05, 0.3)
        if score["bar"] == 4:
            for e in range(8):
                place(mix, shaker(0.07), int((start + e * beat / 2) * SR), 0.035 if e % 2 else 0.02, 0.75)
        at = start
        for note, beats in melody:
            if note is not None:
                length = beats * beat
                if score["lead"] == "flute":
                    place(mix, flute(hz(note), length * 0.95), int(at * SR), 0.32, 0.5)
                else:
                    place(mix, pluck(hz(note), length + 0.8, 0.7, 0.997), int(at * SR), 0.42, 0.5)
            at += beats * beat
    return room(mix)


def music():
    for name, score in [("sunny_fields", SUNNY), ("evening_porch", PORCH)]:
        write(level(piece(score), MUSIC_RMS_DB), OUT / "music" / f"{name}.ogg", 5)


# ---------------------------------------------------------------- farmyards

YARD_SECONDS = 60.0
YARD_RMS_DB = -26.0          # the cut beds' loudness (make_sounds.BED_RMS_DB)
# name -> (seed, the calls heard and how often each, relative; seconds between calls, least and most)
YARDS = {
    "farm_day_a": (11, {"cow": 3, "hen": 4, "rooster": 0.4, "duck": 1}, (2.5, 6.0)),
    "farm_day_b": (12, {"sheep": 3, "goat": 2, "kid": 1, "duck": 2, "hen": 2}, (2.5, 6.5)),
    "farm_day_c": (13, {"cow": 2, "pig": 2, "hen": 2, "donkey": 0.4, "sheep": 1}, (3.5, 8.0)),
}


def wind(n, rng):
    """Air moving over open fields: soft low noise, each side its own, swelling and easing slowly."""
    b, a = signal.butter(2, 380 / (SR / 2))
    out = np.empty((n, 2))
    for c in range(2):
        x = signal.lfilter(b, a, rng.standard_normal(n))
        gust = signal.lfilter([1.0], [1, -0.99997], rng.standard_normal(n))
        gust = 0.55 + 0.45 * np.tanh(gust / (np.abs(gust).max() + 1e-9) * 2.5)
        out[:, c] = x * gust
    return out / np.abs(out).max() * 0.25


def chirp(rng):
    """One small bird's call: a few quick whistles sliding up or down."""
    notes = []
    base = rng.uniform(2600, 4800)
    for k in range(rng.integers(2, 6)):
        length = rng.uniform(0.04, 0.12)
        m = int(length * SR)
        t = np.arange(m) / SR
        slide = rng.uniform(-0.35, 0.35)
        f = base * (1 + slide * t / length) * (1 + 0.04 * np.sin(2 * np.pi * rng.uniform(25, 60) * t))
        notes += [np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * t / length) ** 2,
                  np.zeros(int(rng.uniform(0.03, 0.09) * SR))]
        base *= rng.uniform(0.85, 1.15)
    return np.concatenate(notes)


def far_off(x, rng):
    """A call from across the farm: duller (the air takes the highs), quieter, to one side."""
    b, a = signal.butter(1, rng.uniform(2200, 4200) / (SR / 2))
    y = signal.lfilter(b, a, x) * 10 ** (rng.uniform(-15, -6) / 20)
    pan = rng.uniform(0.15, 0.85)
    return np.stack([y * np.cos(pan * np.pi / 2), y * np.sin(pan * np.pi / 2)], axis=1)


def farmyard(seed, calls, gap):
    rng = np.random.default_rng(seed)
    xfade = int(3.0 * SR)
    n = int(YARD_SECONDS * SR) + xfade
    mix = wind(n, rng)
    t = rng.uniform(0, 0.8)
    while t < YARD_SECONDS + 3.0:             # birds all through
        c = chirp(rng)[:, None] * rng.uniform(0.04, 0.12)
        at = int(t * SR)
        mix[at:at + len(c)] += c[: max(0, n - at)] * np.array([rng.uniform(0.3, 1), rng.uniform(0.3, 1)])
        t += rng.exponential(1.1)
    takes = {name: sorted((OUT / "voices").glob(f"{name}_*.ogg")) for name in calls}
    names, weights = list(calls), np.array(list(calls.values()), float)
    t = rng.uniform(0.5, 2.0)
    while t < YARD_SECONDS:
        name = names[rng.choice(len(names), p=weights / weights.sum())]
        voice = far_off(load(takes[name][rng.integers(len(takes[name]))], 1)[:, 0], rng)
        at = int(t * SR)
        end = min(n, at + len(voice))
        mix[at:end] += voice[: end - at]
        t += rng.uniform(*gap)
    mix = room(mix, 1.2, 0.18)
    loop = mix[: n - xfade].copy()
    w = np.linspace(0, np.pi / 2, xfade)[:, None]
    loop[:xfade] = mix[:xfade] * np.sin(w) + mix[n - xfade:] * np.cos(w)
    return level(loop, YARD_RMS_DB)


def farmyards():
    for name, (seed, calls, gap) in YARDS.items():
        write(farmyard(seed, calls, gap), OUT / "ambience" / f"{name}.ogg", 3)


if __name__ == "__main__":
    voices()
    music()
    farmyards()   # last: the music and calls keep the same random draws, so they come out the same
    stamp()
