"""From shapes to one skin: the blended field is meshed (marching cubes), relaxed, coloured by the nearest shape,
and refined along colour borders so a patch or a belt has a clean edge."""
import numpy as np
from skimage import measure
from .shapes import EDGE_SPLITS, RES, field, sdf


def skin(shapes, res=RES, splits=EDGE_SPLITS):
    lo = np.min([(s["c"] - s["r"].max()) if s["kind"] == "ell" else np.minimum(s["a"], s["b"]) - max(s["ra"], s["rb"]) for s in shapes], 0) - 0.3
    hi = np.max([(s["c"] + s["r"].max()) if s["kind"] == "ell" else np.maximum(s["a"], s["b"]) + max(s["ra"], s["rb"]) for s in shapes], 0) + 0.3
    h = (hi - lo).max() / res
    ax = [np.arange(lo[i], hi[i] + h, h) for i in range(3)]
    G = np.stack(np.meshgrid(*ax, indexing="ij"), -1).reshape(-1, 3)
    F = field(G, shapes).reshape(len(ax[0]), len(ax[1]), len(ax[2]))
    V, T, _n, _v = measure.marching_cubes(F, 0.0, spacing=(h, h, h))
    V = V + lo
    # relax, so the grid's steps round off without thin parts shrinking
    S = np.zeros_like(V); cnt = np.zeros(len(V))
    ed = np.vstack([T[:, [0, 1]], T[:, [1, 2]], T[:, [2, 0]]]); ed = np.vstack([ed, ed[:, ::-1]])
    np.add.at(cnt, ed[:, 0], 1)
    for _ in range(3):
        for lam in (0.5, -0.53):
            S[:] = 0; np.add.at(S, ed[:, 0], V[ed[:, 1]]); V = V + lam * (S / cnt[:, None] - V)

    def classify(P):
        D = np.stack([sdf(P, s) for s in shapes], 1); near = D.argmin(1)
        cols = np.zeros((len(P), 3)); wh = np.zeros(len(P))
        for i, s in enumerate(shapes):
            mk = near == i
            if mk.any():
                cols[mk] = s["col"](P[mk]) if callable(s["col"]) else s["col"]
        # what counts as "the head" (for measuring it and placing the face) is everything lying on the head's own
        # shapes, even where a neck or a fleece shape is nominally nearer: so a neck that joins from below, or wool
        # on the cheeks, never eats half the head out of the measure
        hs = [i for i, s in enumerate(shapes) if s["head"]]
        if hs:
            wh = (D[:, hs].min(1) < 0.07).astype(float)
        return cols, wh

    cols, wh = classify(V)
    # where two colours meet (a patch, a sock, a belt) the triangles are split finer, twice, so the border is a
    # smooth line and not a staircase the size of the mesh
    for _ in range(splits):
        tc = cols[T]; mixed = np.abs(tc - tc[:, :1]).max((1, 2)) > 0.02
        if not mixed.any():
            break
        edge, newV = {}, []

        def mid(i, j):
            k = (i, j) if i < j else (j, i)
            if k not in edge:
                edge[k] = len(V) + len(newV); newV.append((V[i] + V[j]) / 2)
            return edge[k]

        T2 = [T[~mixed]]
        for t in T[mixed]:
            a0, b0, c0 = int(t[0]), int(t[1]), int(t[2]); ab, bc, ca = mid(a0, b0), mid(b0, c0), mid(c0, a0)
            T2.append(np.array([[a0, ab, ca], [ab, b0, bc], [ca, bc, c0], [ab, bc, ca]]))
        nv = np.array(newV); nc, nw = classify(nv)
        V = np.vstack([V, nv]); cols = np.vstack([cols, nc]); wh = np.concatenate([wh, nw]); T = np.vstack(T2)
    tc = cols[T]; mixed = np.abs(tc - tc[:, :1]).max((1, 2)) > 0.02
    tcol = tc.mean(1)
    if mixed.any():
        tcol[mixed] = classify(V[T[mixed]].mean(1))[0]
    return V, T, [tuple(c) for c in tcol], wh
