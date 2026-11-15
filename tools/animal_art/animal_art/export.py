"""An animal for the game: one glTF file (.glb) with its finished mesh (colours and painted light in its vertex
colours) at rest, and its moves as blend shapes, each the difference the builder's own motion makes:

    walk_00 .. walk_07   the walk cycle at full stride (the game blends between the two nearest, by its gait)
    head                 head down: grazing, pecking
    jaw                  chewing (four-legged grazers)
    look_left, look_right
    blink
    tail
    breath

The game sets their weights from the same pose values it already works out (scripts/world3d/animal_3d.gd), so
the animal moves as the previews show. Game axes: 1 unit = 1 tile, up +Y, facing +X, standing on y = 0 over its
middle; its length along +X is the animal's size (`rel` in registry.py, a cow ~1)."""
import json
import math
import struct

import numpy as np

from .build import lightest
from .motion import deform, pose
from .registry import MADE
from .rig import rig_of

WALK_FRAMES = 8          # (the game blends between neighbours; more frames add size, not smoothness)


def _rest():
    return dict(time=0.0, breath=0.0, tail=0.0, look=0.0, jaw=0.0, head=0.0, gait=0.0, stride=0.0, blink=0.0, hop=0.0)


def moves():
    """[(name, pose values)] for every blend shape, in file order."""
    out = []
    for k in range(WALK_FRAMES):
        p = _rest(); p.update(gait=k / WALK_FRAMES, stride=1.0); out.append(("walk_%02d" % k, p))
    for name, change in (("head", dict(head=1.0)), ("jaw", dict(head=0.0, jaw=1.0)), ("look_left", dict(look=1.0)), ("look_right", dict(look=-1.0)),
                         ("blink", dict(blink=1.0)), ("tail", dict(tail=1.0)), ("breath", dict(breath=1.0))):
        p = _rest(); p.update(change); out.append((name, p))
    return out


def export(name, path):
    fn, rel = MADE[name]
    a = lightest(fn)
    rig, W = rig_of(a, name)
    V0, N0 = deform(a, W, pose(rig, _rest()), _rest(), rig)
    T = a["T"]; cols = np.array(a["C"], np.float32); bake = a["bake"]
    # one vertex per (point, colour): neighbouring triangles of different colours keep their own edge
    key = {}; src = []; vcol = []; idx = np.zeros(T.shape, np.uint32)
    for ti, t in enumerate(T):
        c = cols[ti]
        for j, v in enumerate(t):
            k = (int(v), c.tobytes())
            if k not in key:
                key[k] = len(src); src.append(int(v)); vcol.append(c * bake[v])
            idx[ti, j] = key[k]
    src = np.array(src)
    # every point needs a normal: a face drawing's points (eyes, blush) have none of their own, so they take the
    # nearest skin point's; then each triangle is wound to face the way its points' normals do, so a drawing on
    # the far side (the other eye) faces out too and is not culled away
    from scipy.spatial import cKDTree
    n0 = a["nsoft"]
    bare = np.linalg.norm(N0, axis=1) < 1e-6
    near = np.arange(len(V0))
    if bare.any():
        near[bare] = cKDTree(V0[:n0]).query(V0[bare])[1]
    fix = lambda N: N[near] if bare.any() else N
    N0 = fix(N0)
    tri = idx.reshape(-1, 3)
    P = V0[src]; Nn = N0[src]
    face = np.cross(P[tri[:, 1]] - P[tri[:, 0]], P[tri[:, 2]] - P[tri[:, 0]])
    flip = (face * (Nn[tri[:, 0]] + Nn[tri[:, 1]] + Nn[tri[:, 2]])).sum(1) < 0
    tri[flip] = tri[flip][:, [0, 2, 1]]
    idx = tri
    # into the game's frame: forward +z here is +X there; standing on y = 0 over the body's middle; sized
    lo, hi = V0.min(0), V0.max(0)
    centre = np.array([(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2])
    scale = rel / max(hi[2] - lo[2], 1e-6)
    turn = lambda P: np.stack([P[:, 2], P[:, 1], -P[:, 0]], 1)
    place = lambda P: turn((P - centre) * scale).astype(np.float32)
    pos = place(V0[src]); nor = turn(N0[src]).astype(np.float32)
    targets = []
    for mname, p in moves():
        V, N = deform(a, W, pose(rig, p), p, rig)
        N = fix(N)
        targets.append((mname, place(V[src]) - pos, turn(N[src]).astype(np.float32) - nor))
    colours = np.c_[np.clip(np.array(vcol, np.float32), 0, 1), np.ones(len(vcol), np.float32)]
    _write(path, name, pos, nor, colours, idx.reshape(-1), targets)
    return dict(name=name, vertices=len(pos), triangles=len(T), targets=[t[0] for t in targets], scale=scale)


def _write(path, name, pos, nor, col, ind, targets):
    blob = bytearray(); views = []; accs = []

    def add(arr, comps, ctype, target=None, minmax=False):
        data = np.ascontiguousarray(arr).tobytes()
        while len(blob) % 4:
            blob.append(0)
        view = dict(buffer=0, byteOffset=len(blob), byteLength=len(data))
        if target:
            view["target"] = target
        blob.extend(data); views.append(view)
        acc = dict(bufferView=len(views) - 1, componentType=ctype, count=int(len(arr) if comps != "SCALAR" else arr.size),
                   type=comps)
        if minmax:
            acc["min"] = [float(x) for x in arr.min(0)]; acc["max"] = [float(x) for x in arr.max(0)]
        accs.append(acc)
        return len(accs) - 1

    FLOAT, UINT = 5126, 5125
    attrs = dict(POSITION=add(pos, "VEC3", FLOAT, 34962, True), NORMAL=add(nor, "VEC3", FLOAT, 34962),
                 COLOR_0=add(col, "VEC4", FLOAT, 34962),
                 TEXCOORD_0=add(np.zeros((len(pos), 2), np.float32), "VEC2", FLOAT, 34962))   # (importers want UVs)
    indices = add(ind.astype(np.uint32), "SCALAR", UINT, 34963)
    # (positions only: a move's change of shading is too small to see, and normals would double the file)
    tgts = [dict(POSITION=add(dp, "VEC3", FLOAT, 34962, True)) for _n, dp, _dn in targets]
    gltf = dict(
        asset=dict(version="2.0", generator="farm-game animal_art"),
        scene=0, scenes=[dict(nodes=[0])], nodes=[dict(name=name.replace(" ", "_"), mesh=0)],
        meshes=[dict(name=name.replace(" ", "_"), primitives=[dict(attributes=attrs, indices=indices, material=0, mode=4,
                                                                  targets=tgts)],
                     weights=[0.0] * len(tgts), extras=dict(targetNames=[t[0] for t in targets]))],
        materials=[dict(name="coat", pbrMetallicRoughness=dict(baseColorFactor=[1, 1, 1, 1], metallicFactor=0.0,
                                                               roughnessFactor=0.9))],
        buffers=[dict(byteLength=0)], bufferViews=views, accessors=accs)
    while len(blob) % 4:
        blob.append(0)
    gltf["buffers"][0]["byteLength"] = len(blob)
    js = json.dumps(gltf, separators=(",", ":")).encode()
    while len(js) % 4:
        js += b" "
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(blob)))
        f.write(struct.pack("<II", len(js), 0x4E4F534A)); f.write(js)
        f.write(struct.pack("<II", len(blob), 0x004E4942)); f.write(bytes(blob))
