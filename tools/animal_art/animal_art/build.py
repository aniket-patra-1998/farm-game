"""From a template to a finished model: skin the shapes, add the hard parts, draw the face; and the lightest version
of it that still holds together (for phones)."""
import numpy as np

from .decal import Mesh
from . import decal
from .face import EYES, face
from .geometry import vnormals
from .look import bake
from .shapes import EDGE_SPLITS, RES, field
from .skin import skin

LIGHT_STEPS = (30, 36, 42, 50)     # cells along the longest side, tried in turn for the phone-weight mesh
LIGHT_SPLITS = 0                   # times the phone-weight mesh is refined along colour borders before they are cut


NORMAL_STEP = 0.02      # how far apart the shapes are read to find which way the skin faces..
NORMAL_WIDE = 0.2       # ..and again, wider: a fleece's curls and a hen's feathers are lit as one soft form
NORMAL_AGREE = 0.0      # the wide reading is used where it agrees this well with the near one (not on an ear or a leg)


def _facing(V, shapes, step):
    g = np.zeros_like(V)
    for k in range(3):
        d = np.zeros(3); d[k] = step
        g[:, k] = field(V + d, shapes) - field(V - d, shapes)
    ln = np.linalg.norm(g, axis=1)
    return g / np.maximum(ln, 1e-9)[:, None], ln > 1e-9


def _true_normals(V, mesh_n, shapes):
    """Which way the skin faces at each point, read off the shapes themselves (smooth however coarse the mesh):
    the mesh's own normal is kept where the shapes give none, or disagree with it (a thin part)."""
    near, ok = _facing(V, shapes, NORMAL_STEP); wide, ok2 = _facing(V, shapes, NORMAL_WIDE)
    n = mesh_n.copy(); n[ok] = near[ok]
    soft = ok & ok2 & ((near * wide).sum(1) > NORMAL_AGREE)
    n[soft] = wide[soft]
    bad = (n * mesh_n).sum(1) < 0.2
    n[bad] = mesh_n[bad]
    return n


def build(template, res=None, splits=None, **more):
    """`template()` gives (shapes, hard parts, face options). Returns the model as a dict:
    V, T, C (points, triangles, a colour per triangle), vn (normals), shapes, wh (how much each soft point is head),
    eyes (each eye's own points, for blinking), and the counts that tell soft skin, hard parts and drawings apart:
    points [0, nsoft) are skin, [nsoft, nvb) hard parts, the rest drawings; triangles [0, nbody) are skin and hard parts."""
    shapes, hard, opt = template()
    opt.update(more)
    res = res or opt.pop("res", None) or RES
    opt.pop("res", None)
    V, T, cols, wh = skin(shapes, res=res, splits=EDGE_SPLITS if splits is None else splits, fine=opt.pop("fine", False))
    Vs, Ts, Cs, n = [V], [T], list(cols), len(V)
    for (hv, ht), col in hard:
        Vs.append(np.array(hv)); Ts.append(np.array(ht) + n); Cs += [tuple(col)] * len(ht); n += len(hv)
    VB, TB = np.vstack(Vs), np.vstack(Ts)
    vn = vnormals(VB, TB); mesh_n = vn[:len(V)].copy()
    vn[:len(V)] = _true_normals(V, vn[:len(V)], shapes)
    m = Mesh(VB, TB, Cs)
    decal.PROJ = None
    EYES.clear()
    face(m, VB, TB, Cs, np.concatenate([wh, np.zeros(len(VB) - len(wh))]), **opt)
    Vf, Tf, C2 = m.done()
    return dict(V=Vf, T=Tf, C=C2, vn=np.vstack([vn, np.zeros((len(Vf) - len(vn), 3))]), shapes=shapes, wh=wh, eyes=list(EYES),
                nsoft=len(V), nvb=len(VB), nbody=len(TB), tris=len(TB), res=res, mesh_n=mesh_n)


def pieces(model):
    """How many separate pieces the soft skin is in (1: it holds together)."""
    from scipy.sparse import coo_matrix
    from scipy.sparse.csgraph import connected_components
    n0 = model["nsoft"]; T = model["T"][:model["nbody"]]; T = T[(T < n0).all(1)]
    e = np.vstack([T[:, [0, 1]], T[:, [1, 2]]])
    return connected_components(coo_matrix((np.ones(len(e)), (e[:, 0], e[:, 1])), shape=(n0, n0)), directed=False)[0]


def lightest(template):
    """The lightest mesh that still holds together: fewer cells, until a thin part (a tail, a leg) would come away.
    Returned with its light painted in."""
    for res in LIGHT_STEPS:
        model = build(template, res=res, splits=LIGHT_SPLITS)
        if pieces(model) == 1:
            break
    return bake(model)
