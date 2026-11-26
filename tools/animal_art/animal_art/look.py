"""Light painted into the colour, once, per point: shadow in creases and near the ground, lighter backs, darker undersides."""
import numpy as np
from .shapes import field


BG = np.array([111, 168, 68], np.float32)


SHADOW_TINT = np.array([0.56, 0.47, 0.6])    # shadows lean cool and keep their colour, like a painted shadow


AO_STRENGTH = 1.9


LIT_COL, SHADE_COL = np.array([1.0, 0.985, 0.95], np.float32), np.array([0.8, 0.78, 0.9], np.float32)


LIGHT_TOP, LIGHT_UNDER = 1.05, 0.72          # backs a little lighter, undersides a little darker


def bake(a):
    """Painted light, per vertex: how shut-in each point is (a crease, an armpit, close to the ground) is read off the
    animal's own shapes, and turned into a soft coloured shadow; backs are lightened and undersides darkened."""
    V, n0 = a["V"], a["nsoft"]; P = V[:n0]; N = a.get("mesh_n", a["vn"])[:n0].copy()   # (the mesh's own facing: shadow is read gently)
    fp, fm = field(P + N * 0.04, a["shapes"]), field(P - N * 0.04, a["shapes"])
    flip = fp < fm; N[flip] *= -1
    # the shapes' own measure of distance runs slow or fast from place to place; read its local rate at each point,
    # so open skin counts as open everywhere and only real creases count as shut in
    g = np.clip(np.abs(fp - fm) / 0.08, 0.25, 1.5)
    sc = P[:, 1].max() / 4.0; occ = np.zeros(n0)
    for h, w in ((0.12, 0.3), (0.28, 0.3), (0.55, 0.22), (0.95, 0.18)):
        hh = h * sc; Q = P + N * hh
        free = np.minimum(field(Q, a["shapes"]) / (g * hh), (Q[:, 1] + 0.03) / hh)
        occ += w * np.clip(1 - free, 0, 1)
    occ = np.clip((occ - 0.06) / 0.94, 0, 1)
    # soften over the surface, so the shadow is a wash and not a speckle
    T = a["T"][:a["tris"]]; T = T[(T < n0).all(1)]
    ed = np.vstack([T[:, [0, 1]], T[:, [1, 2]], T[:, [2, 0]]]); ed = np.vstack([ed, ed[:, ::-1]])
    cnt = np.zeros(n0); np.add.at(cnt, ed[:, 0], 1); cnt = np.maximum(cnt, 1)
    for _ in range(7):
        acc = np.zeros(n0); np.add.at(acc, ed[:, 0], occ[ed[:, 1]]); occ = 0.5 * occ + 0.5 * acc / cnt
    k = np.clip(occ * AO_STRENGTH, 0, 1)
    light = LIGHT_UNDER + (LIGHT_TOP - LIGHT_UNDER) * (0.5 + 0.5 * N[:, 1])
    B = np.ones((len(V), 3))
    B[:n0] = light[:, None] * (1 - k[:, None] * (1 - SHADOW_TINT[None, :]))
    a["bake"] = B; a["N"] = N
    return a
