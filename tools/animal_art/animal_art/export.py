"""An animal for the game: one glTF file (.glb) with its finished mesh (colours and painted light in its vertex
colours) at rest, and its moves as blend shapes, each the difference the builder's own motion makes:

    walk_00 .. walk_07   the walk cycle at full stride (the game blends between the two nearest, by its gait)
    head                 head down: grazing, pecking
    jaw                  chewing (four-legged grazers)
    hop                  the top of a hop (hoppers: the rabbit)
    ear_flick            ears turned out (each about its root)
    wing_flap            wings lifted open (birds), or a bee's wings at the top of a beat
    display              a turkey's tail fan tipped up and spread
    look_left, look_right
    blink
    tail
    breath

The game sets their weights from the same pose values it already works out (scripts/world3d/animal_3d.gd), so
the animal moves as the previews show. Game axes: 1 unit = 1 tile, up +Y, facing +X, standing on y = 0 over its
middle; its length along +X is the animal's size (`rel` in registry.py, a cow ~1), drawn closer to a cow's than in
life (`shown`): FarmVille's animals read at farm zoom next to their homes, a chicken half a cow."""
import json
import math
import struct

import numpy as np

from .build import lightest
from .motion import deform, pose
from .geometry import hx
from .paint import coat_colours
from .registry import LIMITED, MADE
from .rig import rig_of

WALK_FRAMES = 8          # (the game blends between neighbours; more frames add size, not smoothness)


def _rest():
    return dict(time=0.0, breath=0.0, tail=0.0, look=0.0, jaw=0.0, head=0.0, gait=0.0, stride=0.0, blink=0.0, hop=0.0)


EAR_FLICK = 0.55         # radians an ear turns at the top of a flick
WING_OPEN = 1.0          # radians a wing lifts open, about its root along the body
FAN_LIFT = 0.45          # radians a turkey's tail fan tips up on display, and it spreads by FAN_SPREAD
FAN_SPREAD = 1.2
BEE_BEAT = (math.pi / 2) / 60.0   # the bee's wing beat's top (motion.deform's wing angle peaks at this time)


def moves():
    """[(name, pose values)] for every blend shape made by the builder's own motion, in file order."""
    out = []
    for k in range(WALK_FRAMES):
        p = _rest(); p.update(gait=k / WALK_FRAMES, stride=1.0); out.append(("walk_%02d" % k, p))
    for name, change in (("head", dict(head=1.0)), ("jaw", dict(head=0.0, jaw=1.0)), ("look_left", dict(look=1.0)), ("look_right", dict(look=-1.0)),
                         ("blink", dict(blink=1.0)), ("tail", dict(tail=1.0)), ("breath", dict(breath=1.0)),
                         ("hop", dict(hop=1.0))):
        p = _rest(); p.update(change); out.append((name, p))
    return out


SIZE_EVEN = 0.6         # sizes are drawn as rel ** SIZE_EVEN: a chicken (0.35) as 0.53, a pig (0.73) 0.83, a horse 1.11
TRUE_SIZE = ("bee",)    # drawn at their own size (a bee by its hive stays a bee)


def shown(name, rel):
    """The length an animal is drawn at, in tiles: its size brought toward a cow's (FarmVille's proportions)."""
    return rel if name in TRUE_SIZE else rel ** SIZE_EVEN


def export(name, path):
    fn, rel = MADE[name]
    a = lightest(fn)
    rig, W = rig_of(a, name)
    V0, N0 = deform(a, W, pose(rig, _rest()), _rest(), rig)
    T = a["T"]; cols = np.array(a["C"], np.float32); bake = a["bake"]
    # one vertex per (point, colour): neighbouring triangles of different colours keep their own edge
    key = {}; src = []; vcol = []; raw = []; idx = np.zeros(T.shape, np.uint32)
    for ti, t in enumerate(T):
        c = cols[ti]
        for j, v in enumerate(t):
            k = (int(v), c.tobytes())
            if k not in key:
                key[k] = len(src); src.append(int(v)); vcol.append(c * bake[v]); raw.append(c)
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
    scale = shown(name, rel) / max(hi[2] - lo[2], 1e-6)
    turn = lambda P: np.stack([P[:, 2], P[:, 1], -P[:, 0]], 1)
    place = lambda P: turn((P - centre) * scale).astype(np.float32)
    pos = place(V0[src]); nor = turn(N0[src]).astype(np.float32)
    targets = []
    for mname, p in moves():
        if mname == "hop" and not rig.get("hop"):
            continue   # (only a hopper hops)
        V, N = deform(a, W, pose(rig, p), p, rig)
        N = fix(N)
        targets.append((mname, place(V[src]) - pos, turn(N[src]).astype(np.float32) - nor))
    if rig.get("wings"):          # a bee: its wings at the top of a beat (the builder's motion beats them by time)
        p = _rest(); p["time"] = BEE_BEAT
        V, N = deform(a, W, pose(rig, p), p, rig)
        targets.append(("wing_flap", place(V[src]) - pos, np.zeros_like(nor)))
    # moves of parts the builder's motion doesn't turn: ears flick, wings open, a turkey's fan
    for mname, V in _part_moves(a, rig, V0).items():
        targets.append((mname, place(V[src]) - pos, np.zeros_like(nor)))
    uv = uv2 = None
    row = LIMITED.get(name)
    if row is not None and row.get("touch"):
        uv, uv2 = _touch_points(a, row, src, np.array(raw))
        if row["touch"] == "shake":
            for mname, V in _shake_moves(a, V0).items():
                targets.append((mname, place(V[src]) - pos, np.zeros_like(nor)))
    colours = np.c_[np.clip(np.array(vcol, np.float32), 0, 1), np.ones(len(vcol), np.float32)]
    _write(path, name, pos, nor, colours, idx.reshape(-1), targets, uv=uv, uv2=uv2)
    return dict(name=name, vertices=len(pos), triangles=len(T), targets=[t[0] for t in targets], scale=scale)


def _head_of(a):
    """How much of each point is the head (0..1): the skin's own measure, and for the hard parts the skin nearest them."""
    from scipy.spatial import cKDTree
    n0 = a["nsoft"]; wh = np.clip(np.asarray(a["wh"], float) * 1.6, 0, 1); rest = a["V"][n0:]
    return np.concatenate([wh, wh[cKDTree(a["V"][:n0]).query(rest)[1]]]) if len(rest) else wh


def _touch_points(a, row, src, raw):
    """What a limited coat's touch needs to know of each point, carried in the file's two UV sets (the game's shader
    reads them: shaders/coat_touch.gdshaderinc). UV: how far along the animal the point is (0 at the nose, 1 at the
    tail), and whether it is part of what the touch moves (the stars of a starry coat; otherwise the painted coat).
    UV2: how much of the point is the head, and a number of the point's own (a star's place in the twinkling; how
    high up the animal the point is, for embers)."""
    P = a["V"][src]; z = a["V"][:, 2]; top = a["V"][:, 1].max()
    along = (z.max() - P[:, 2]) / max(z.max() - z.min(), 1e-6)
    if row["touch"] == "stars":
        mark = np.abs(raw - np.array(hx(row["paint"]["c2"]))).max(axis=1) < 0.02
        own = np.modf(np.abs(np.floor(P[:, 0] * 3.1) * 0.37 + np.floor(P[:, 2] * 2.3) * 0.61 + np.floor(P[:, 1] * 2.7) * 0.83))[0]
    else:
        mark = np.abs(raw[:, None, :] - coat_colours(row)[None, :, :]).max(axis=2).min(axis=1) < 0.02
        own = P[:, 1] / max(top, 1e-6)
    return (np.stack([along, mark.astype(float)], 1).astype(np.float32),
            np.stack([_head_of(a)[src], own], 1).astype(np.float32))


SHAKE = dict(turn=0.2, locks=0.22, late=1.1, waves=7.5)   # a coat's shake: radians, the locks' extra and delay, waves along it


def _shake_moves(a, V0):
    """A long coat's shake as two moves the game blends in turn (weights sin and cos of the shake's time: together a
    twist that runs from the shoulders to the rump). Everything above the hooves turns about the spine, the long hair
    on the flanks further and a beat late; the head stays still."""
    rest = a["V"]; body = a["shapes"][0]
    spine = float(body["c"][1]) if body["kind"] == "ell" else float((body["a"][1] + body["b"][1]) / 2)
    wide = float(body["r"][0]) if body["kind"] == "ell" else float(body["ra"]); long = rest[:, 2].max() - rest[:, 2].min()
    y = rest[:, 1]; hold = np.clip((y - 0.13 * spine) / (0.3 * spine), 0, 1) * (1.0 - _head_of(a))
    locks = np.clip((np.abs(rest[:, 0]) - 0.55 * wide) / (0.3 * wide), 0, 1) * np.clip((spine - y) / (0.45 * spine), 0, 1)
    kz = SHAKE["waves"] * rest[:, 2] / long
    turns = {"shake_a": hold * (SHAKE["turn"] * np.cos(kz) + SHAKE["locks"] * locks * np.cos(kz + SHAKE["late"])),
             "shake_b": -hold * (SHAKE["turn"] * np.sin(kz) + SHAKE["locks"] * locks * np.sin(kz + SHAKE["late"]))}
    out = {}
    for mname, ang in turns.items():
        c, s = np.cos(ang), np.sin(ang); V = V0.copy(); x, yy = V0[:, 0], V0[:, 1] - spine
        V[:, 0] = x * c - yy * s; V[:, 1] = spine + x * s + yy * c
        out[mname] = V
    return out


def _owner(a):
    """Each skin point's own shape (the nearest), so a part's points (an ear, a wing) can be moved on their own."""
    from .shapes import sdf
    P = a["V"][:a["nsoft"]]
    D = np.stack([sdf(P, s) for s in a["shapes"]], 1)
    return np.argmin(D, 1)


def _turned(V, idx, pivot, axis, ang, grow=1.0):
    from .motion import rot
    out = V.copy()
    out[idx] = (V[idx] - pivot) @ rot(axis, ang).T * grow + pivot
    return out


def _part_moves(a, rig, V0):
    """{move: points} for the parts that move on their own: each ear turns out about its root, each wing lifts
    open about its root along the body, a turkey's fan tips up and spreads, a bee's wings beat."""
    out = {}
    own = _owner(a); parts = np.array([s.get("part") or "" for s in a["shapes"]])[own]
    n0 = a["nsoft"]; head = np.array(rig["head"], float); body = np.array(rig["body"], float)
    for part, name in (("ear", "ear_flick"), ("wing", "wing_flap")):
        idx = np.where(parts == part)[0]
        if len(idx) < 10:
            continue
        V = V0.copy()
        for side in (-1.0, 1.0):
            one = idx[np.sign(V0[idx, 0]) == side]
            if len(one) < 5:
                continue
            if part == "ear":       # its root: its point nearest the head's middle; it turns out and back about the body's length
                root = V0[one][np.argmin(np.linalg.norm(V0[one] - head, axis=1))]
                V = _turned(V, one, root, (0, 0, 1), side * EAR_FLICK)
            else:                   # its root: along its top edge nearest the body's middle line
                q = V0[one]; root = np.array([q[np.argmin(np.abs(q[:, 0])), 0], q[:, 1].max(), q[:, 2].mean()])
                V = _turned(V, one, root, (0, 0, 1), side * WING_OPEN)
        out[name] = V
    fan = np.where(parts == "fan")[0]
    if len(fan) >= 10:
        q = V0[fan]; base = q[np.argmin(np.linalg.norm(q - body, axis=1))]
        out["display"] = _turned(V0, fan, base, (1, 0, 0), FAN_LIFT, FAN_SPREAD)
    return out


def _write(path, name, pos, nor, col, ind, targets, uv=None, uv2=None):
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
                 TEXCOORD_0=add(np.zeros((len(pos), 2), np.float32) if uv is None else uv, "VEC2", FLOAT,
                                34962))   # (importers want UVs; the farmer's say whose colour a point wears)
    if uv2 is not None:
        attrs["TEXCOORD_1"] = add(uv2, "VEC2", FLOAT, 34962)   # (a limited coat's touch: _touch_points)
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
