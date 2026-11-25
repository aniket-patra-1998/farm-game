"""From shapes to one skin: the blended field is meshed (marching cubes), relaxed, coloured by the nearest shape,
and refined along colour borders so a patch or a belt has a clean edge."""
import numpy as np
from skimage import measure
from .shapes import EDGE_SPLITS, RES, field, sdf

SAME = 0.02        # colours closer than this are one colour


HARD = 0.1         # colours further apart than this meet at a border (cut clean); nearer ones are a wash


STEP_SHARE = 0.6   # of HARD that the colour must still step by, right at a border, to be one


WASH = 64          # a wash's colour is kept to this many steps a channel, so its triangles share their points


CUT_STEPS = 7      # halvings that find where a colour border crosses a side


def skin(shapes, res=RES, splits=EDGE_SPLITS, fine=False):
    """`fine`: a coat drawn finer than the mesh (a shell's plates and seams) has every triangle its colour turns on
    split once first, so a seam between two points of the mesh is still found."""
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
    if fine:
        V, T, cols, wh = _refine(V, T, cols, wh, classify, SAME)
    for _ in range(splits):
        V, T, cols, wh = _refine(V, T, cols, wh, classify)
    return _cut(V, T, cols, wh, classify)


def _differ(a, b, by=HARD):
    return np.abs(a - b).max(-1) > by


def _wash(c):
    return [tuple(v) for v in np.round(np.asarray(c) * WASH) / WASH]


def _refine(V, T, cols, wh, classify, by=HARD):
    """The triangles where two colours meet, split in four (finer, before the border is cut)."""
    tc = cols[T]; mixed = _differ(tc, tc[:, [1, 2, 0]], by).any(1)
    if not mixed.any():
        return V, T, cols, wh
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
    return np.vstack([V, nv]), np.vstack(T2), np.vstack([cols, nc]), np.concatenate([wh, nw])


def _cut(V, T, cols, wh, classify):
    """Where two colours meet (a patch, a sock, a belt), each triangle the border crosses is cut along it: the
    border's own place on each of its sides is found (by halving, CUT_STEPS times), so the border is a clean line
    and not a staircase the size of the mesh. Returns V, T, a colour per triangle, wh."""
    tc = cols[T]; mixed = _differ(tc, tc[:, [1, 2, 0]]).any(1)      # (any two of its corners)
    whole = _differ(tc, tc[:, :1], SAME).any(1)      # (a wash: its corners differ a little)
    tcol = [tuple(c) for c in tc.mean(1)]
    for k in np.nonzero(whole & ~mixed)[0]:
        tcol[k] = _wash(tc[k].mean(0)[None, :])[0]
    if not mixed.any():
        return V, T, tcol, wh
    Tm = T[mixed]
    pairs = np.vstack([Tm[:, [0, 1]], Tm[:, [1, 2]], Tm[:, [2, 0]]]); pairs = np.unique(np.sort(pairs, 1), axis=0)
    pairs = pairs[_differ(cols[pairs[:, 0]], cols[pairs[:, 1]])]
    lo, hi = V[pairs[:, 0]].copy(), V[pairs[:, 1]].copy(); ci, cj = cols[pairs[:, 0]], cols[pairs[:, 1]]
    for _ in range(CUT_STEPS):
        m = (lo + hi) / 2; cm = classify(m)[0]
        first = np.abs(cm - ci).max(-1) <= np.abs(cm - cj).max(-1)      # nearer the first corner's colour
        lo[first] = m[first]; hi[~first] = m[~first]
    # a border is where the colour steps: where it only turns steeply (a wash across one triangle) the two sides
    # of the place found are still one colour, and nothing is cut
    real = _differ(classify(lo)[0], classify(hi)[0], HARD * STEP_SHARE)
    pairs, lo, hi = pairs[real], lo[real], hi[real]
    at = {(int(a), int(b)): len(V) + k for k, (a, b) in enumerate(pairs)}
    cut_side = lambda i, j: ((i, j) if i < j else (j, i)) in at
    keep = np.array([any(cut_side(int(t[k]), int(t[(k + 1) % 3])) for k in range(3)) for t in Tm])
    back = np.nonzero(mixed)[0][~keep]
    for k in back:
        tcol[k] = _wash(tc[k].mean(0)[None, :])[0]
    mixed = mixed.copy(); mixed[back] = False; Tm = T[mixed]
    if not mixed.any():
        return V, T, tcol, wh
    newV = [(lo + hi) / 2]; n = len(V) + len(pairs)
    mid = lambda i, j: at[(i, j) if i < j else (j, i)]
    out_t, out_c = [T[~mixed]], [tcol[k] for k in np.nonzero(~mixed)[0]]
    more_t = []
    for t in Tm:
        v = [int(t[0]), int(t[1]), int(t[2])]; c = cols[v]
        d = [cut_side(v[k], v[(k + 1) % 3]) for k in range(3)]       # is the side from corner k to the next cut?
        if sum(d) == 2:
            k = d.index(False); p, q, r = v[k], v[(k + 1) % 3], v[(k + 2) % 3]   # p and q share a colour; r stands alone
            qr, rp = mid(q, r), mid(r, p)
            more_t += [[qr, r, rp], [p, q, qr], [p, qr, rp]]
            out_c += [tuple(cols[r]), tuple(cols[p]), tuple(cols[p])]
        else:
            g = n; n += 1; newV.append(V[v].mean(0)[None, :])
            for k in range(3):
                a, b, c0 = v[k], v[(k + 1) % 3], v[(k + 2) % 3]
                e1 = mid(a, b) if d[k] else None; e2 = mid(c0, a) if d[(k + 2) % 3] else None
                ring = [a] + ([e1] if e1 is not None else []) + [g] + ([e2] if e2 is not None else [])
                if e1 is None:      # (a side the border does not cross stays whole, with the centre)
                    more_t.append([a, b, g]); out_c.append(tuple(cols[a]))
                for j in range(1, len(ring) - 1):
                    more_t.append([ring[0], ring[j], ring[j + 1]]); out_c.append(tuple(cols[a]))
    nv = np.vstack(newV); _nc, nw = classify(nv)
    return np.vstack([V, nv]), np.vstack(out_t + [np.array(more_t)]), out_c, np.concatenate([wh, nw])
