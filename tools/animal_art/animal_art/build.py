"""From a template to a finished model: skin the shapes, add the hard parts, draw the face; and the lightest version
of it that still holds together (for phones)."""
import numpy as np

from .decal import Mesh
from . import decal
from .face import EYES, face
from .geometry import vnormals
from .look import bake
from .shapes import EDGE_SPLITS, RES
from .skin import skin

LIGHT_STEPS = (30, 36, 42, 50)     # cells along the longest side, tried in turn for the phone-weight mesh


def build(template, res=None, splits=None, **more):
    """`template()` gives (shapes, hard parts, face options). Returns the model as a dict:
    V, T, C (points, triangles, a colour per triangle), vn (normals), shapes, wh (how much each soft point is head),
    eyes (each eye's own points, for blinking), and the counts that tell soft skin, hard parts and drawings apart:
    points [0, nsoft) are skin, [nsoft, nvb) hard parts, the rest drawings; triangles [0, nbody) are skin and hard parts."""
    shapes, hard, opt = template()
    opt.update(more)
    res = res or opt.pop("res", None) or RES
    opt.pop("res", None)
    V, T, cols, wh = skin(shapes, res=res, splits=EDGE_SPLITS if splits is None else splits)
    Vs, Ts, Cs, n = [V], [T], list(cols), len(V)
    for (hv, ht), col in hard:
        Vs.append(np.array(hv)); Ts.append(np.array(ht) + n); Cs += [tuple(col)] * len(ht); n += len(hv)
    VB, TB = np.vstack(Vs), np.vstack(Ts)
    vn = vnormals(VB, TB)
    m = Mesh(VB, TB, Cs)
    decal.PROJ = None
    EYES.clear()
    face(m, VB, TB, Cs, np.concatenate([wh, np.zeros(len(VB) - len(wh))]), **opt)
    Vf, Tf, C2 = m.done()
    return dict(V=Vf, T=Tf, C=C2, vn=np.vstack([vn, np.zeros((len(Vf) - len(vn), 3))]), shapes=shapes, wh=wh, eyes=list(EYES),
                nsoft=len(V), nvb=len(VB), nbody=len(TB), tris=len(TB), res=res)


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
        model = build(template, res=res, splits=1)
        if pieces(model) == 1:
            break
    return bake(model)
