"""The one-off small animals: rabbit, turtle, bee."""
import numpy as np
import math
from ..geometry import cone, hx, sphere, tube
from ..shapes import C, E, both, rotm


def rabbit():
    c, pale, pink = np.array(hx("d9cfc1")), np.array(hx("f5efe6")), np.array(hx("f0b4b8"))
    bodyc = lambda P: np.where(((P[:, 1] < 0.8) & (np.abs(P[:, 0]) < 0.62))[:, None], pale[None, :], c[None, :])
    s = [E((0, 1.25, -0.1), (0.95, 1.0, 1.25), bodyc), E((0, 1.08, -0.55), (1.02, 0.96, 0.9), bodyc), E((0, 1.35, 0.72), (0.76, 0.82, 0.7), bodyc),
         E((0, 2.3, 1.2), (0.8, 0.76, 0.86), tuple(c), head=True), E((0, 2.05, 1.9), (0.46, 0.38, 0.4), tuple(pale), head=True),
         E((0, 1.35, -1.45), (0.4, 0.4, 0.4), (1, 1, 1), k=0.08)]
    s += both(E, (0.46, 2.0, 1.66), (0.34, 0.3, 0.36), tuple(pale), head=True, k=0.14)
    s += both(E, (0.62, 0.85, -0.55), (0.5, 0.74, 0.8), tuple(c)) + both(E, (0.62, 0.2, -0.2), (0.28, 0.2, 0.66), tuple(pale), k=0.1)
    s += both(C, (0.4, 1.0, 0.85), (0.4, 0.22, 1.05), 0.26, 0.2, tuple(c)) + both(E, (0.4, 0.16, 1.12), (0.23, 0.16, 0.3), tuple(pale), k=0.08)

    def earc(sx):
        def f(P):
            t = np.clip((P[:, 1] - 2.8) / 1.5, 0, 1); ax = sx * (0.3 + 0.15 * t); az = 0.9 - 0.4 * t
            inner = (P[:, 2] - az > 0.06) & (np.abs(P[:, 0] - ax) < 0.14) & (P[:, 1] > 3.0) & (P[:, 1] < 4.4)
            return np.where(inner[:, None], pink[None, :], (c * 0.86)[None, :])
        return f
    for sx in (-1, 1):
        s.append(C((sx * 0.3, 2.8, 0.9), (sx * 0.45, 4.3, 0.5), 0.26, 0.22, earc(sx), k=0.14, part="ear"))
    nose = (sphere((0, 2.2, 2.28), (0.11, 0.08, 0.07), None, 6), tuple(pink * 0.85))
    return s, [nose], dict(eye_k=1.2, nostril=False, cleft=True, lid=0.56, wrap=True)


def turtle():
    shell, tan, skin_c, rim, under = np.array(hx("4a7a3a")), np.array(hx("c8b070")), hx("7fae5a"), hx("c8b070"), hx("e6d9a8")
    S = np.array([(0.0, 0.0)] + [(0.8 * math.cos(a), 0.95 * math.sin(a)) for a in np.arange(6) * math.pi / 3 + math.pi / 6]
                 + [(1.32 * math.cos(a), 1.58 * math.sin(a)) for a in np.arange(12) * math.pi / 6])

    def pat(P):
        # the plates of the shell: each one tan in the middle and green at its edge, with a dark seam between plates
        d = np.sort(np.linalg.norm(P[:, None, [0, 2]] - S[None], axis=2), axis=1)
        g = np.clip(d[:, 0] / 0.42, 0, 1)[:, None]
        col = tan[None, :] * (1 - g) * 0.85 + shell[None, :] * (0.15 + 0.85 * g)
        return np.where(((d[:, 1] - d[:, 0]) < 0.08)[:, None], (shell * 0.55)[None, :], col)

    s = [E((0, 1.0, 0), (1.35, 0.92, 1.6), pat, k=0.08), E((0, 0.58, 0), (1.5, 0.28, 1.75), rim, k=0.06), E((0, 0.46, 0), (1.2, 0.3, 1.45), under, k=0.08),
         C((0, 0.85, 1.3), (0, 1.3, 2.0), 0.36, 0.34, skin_c), E((0, 1.46, 2.26), (0.56, 0.53, 0.62), skin_c, head=True),
         C((0, 0.5, -1.6), (0, 0.36, -2.1), 0.17, 0.06, skin_c)]
    for z in (1.0, -1.0):
        s += both(C, (1.05, 0.55, z), (1.32, 0.22, z * 1.14), 0.34, 0.3, skin_c, k=0.12, part="stub")
        s += both(E, (1.36, 0.14, z * 1.16 + 0.1), (0.33, 0.14, 0.38), tuple(np.array(skin_c) * 0.88), k=0.08, part="stub")
    return s, [], dict(eye_k=1.3, lid=0.5, wrap=True)


def bee():
    y, d, fuzz = hx("f2c230"), (0.2, 0.15, 0.1), hx("f9df7a")

    def stripes(P):
        b = (np.sin(P[:, 2] * 7.5 + 1.2) > 0.1)[:, None]
        return np.where(b, np.array(y)[None, :], np.array(d)[None, :])

    s = [E((0, 2.6, -0.7), (0.78, 0.75, 1.0), stripes), E((0, 2.65, 0.45), (0.66, 0.64, 0.62), fuzz),
         E((0, 2.62, 1.3), (0.62, 0.6, 0.56), hx("f7d55a"), head=True), C((0, 2.5, -1.6), (0, 2.45, -2.0), 0.12, 0.02, d, k=0.08)]
    hard = []
    for sx in (-1, 1):
        hard.append((sphere((sx * 0.8, 3.38, 0.05), (0.6, 0.05, 1.0), rotm(0, 0, sx * 0.5).T, 8), (0.9, 0.96, 1.0)))
        hard.append((sphere((sx * 0.7, 3.2, -0.75), (0.42, 0.04, 0.7), rotm(0, 0, sx * 0.4).T, 8), (0.84, 0.92, 0.98)))
        hard.append((cone((sx * 0.22, 3.1, 1.5), (sx * 0.42, 3.7, 1.82), 0.045, 6), d))
        hard.append((sphere((sx * 0.42, 3.72, 1.83), (0.09, 0.09, 0.09), None, 5), d))
        for z in (0.75, 0.35, -0.1):
            hard.append((tube((sx * 0.4, 2.2, z), (sx * 0.62, 1.72, z + 0.08), 0.055, 0.04, 6), d))
    return s, hard, dict(nostril=False, eye_k=1.25, lid=0.5, wrap=True)
