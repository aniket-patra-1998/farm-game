"""An animal for the game: one glTF file (.glb) with its finished mesh (colours and painted light in its vertex
colours), the bones it hangs on, and its moves, each as where every bone goes:

    walk_00 .. walk_07   the walk cycle at full stride (the game blends between the two nearest, by its gait)
    head                 head down: grazing, pecking
    jaw                  chewing (four-legged grazers)
    hop                  the top of a hop (hoppers: the rabbit)
    sleep                asleep, its family's own way (motion.asleep): lying, tucked, dozing on its feet
    ear_flick            ears turned out (each about its root)
    wing_flap            wings lifted open (birds), or a bee's wings at the top of a beat
    display              a turkey's tail fan tipped up and spread
    look_left, look_right
    blink
    tail
    breath

A move is stored as bones, not as every point's new place (17 copies of the mesh were most of a file): each point
follows up to four bones (`weights`), a move says how far each bone goes from where it rests (`_rigged`), and the
game adds the moves it wants, bone by bone, exactly as it added the points before. A part that moves on its own
(an eye closing, an ear, a wing, a fan) gets bones of its own. Only a long coat's shake, which no bone can
make, is still stored point by point (`_shake_moves`).

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
                         ("hop", dict(hop=1.0)), ("sleep", dict(sleep=1.0))):
        p = _rest(); p.update(change); out.append((name, p))
    return out


SIZE_EVEN = 0.6         # sizes are drawn as rel ** SIZE_EVEN: a chicken (0.35) as 0.53, a pig (0.73) 0.83, a horse 1.11
TRUE_SIZE = ("bee",)    # drawn at their own size (a bee by its hive stays a bee)


def shown(name, rel):
    """The length an animal is drawn at, in tiles: its size brought toward a cow's (FarmVille's proportions)."""
    return rel if name in TRUE_SIZE else rel ** SIZE_EVEN


VIVID = 1.12            # a coat's colour is drawn this much stronger than its row gives (greys and whites stay)


def _vivid(c):
    grey = float(np.mean(c))
    return np.clip(grey + (c - grey) * VIVID, 0.0, 1.0)


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
                key[k] = len(src); src.append(int(v)); vcol.append(_vivid(c) * bake[v]); raw.append(c)
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
    Wn, rest, changes = _rigged(a, rig, W, V0)
    bones, follow = _follows(Wn)
    built = a["vn"] / np.maximum(np.linalg.norm(a["vn"], axis=1, keepdims=True), 1e-9)
    pos = place(a["V"][src]); nor = turn(fix(built)[src]).astype(np.float32)
    # into the game's frame, each bone's 4x4 too
    G = np.eye(4); G[:3, :3] = np.array([[0, 0, 1], [0, 1, 0], [-1, 0, 0]], float) * scale; G[:3, 3] = -G[:3, :3] @ centre
    Gi = np.linalg.inv(G); there = lambda M: G @ M @ Gi
    stands = place(V0[src])   # (the box of the animal as it stands: the game's taps and sizes are measured by it)
    targets = []
    uv = uv2 = None
    row = LIMITED.get(name)
    if row is not None and row.get("touch"):
        uv, uv2 = _touch_points(a, row, src, np.array(raw))
        if row["touch"] == "shake":
            for mname, V in _shake_moves(a, V0).items():
                targets.append((mname, place(V[src]) - place(V0[src]), None))
    colours = np.c_[np.clip(np.array(vcol, np.float32), 0, 1), np.ones(len(vcol), np.float32)]
    rigging = dict(bones=bones[src], follow=follow[src], rest=[_flat(there(R)) for R in rest],
                   moves={m: {str(k): _flat(G @ D @ Gi) for k, D in c.items()} for m, c in changes},
                   box=[[round(float(v), 6) for v in stands.min(0)], [round(float(v), 6) for v in stands.max(0)]])
    _write(path, name, pos, nor, colours, idx.reshape(-1), targets, uv=uv, uv2=uv2, rigging=rigging)
    return dict(name=name, vertices=len(pos), triangles=len(T), targets=[m for m, _c in changes] + [t[0] for t in targets],
                bones=len(rest), scale=scale, nose=_sleeping_nose(rig, place))


def _flat(M):
    """A 4x4 as the game reads it: its three axes, then where it moves to (12 numbers)."""
    return [round(float(v), 6) for v in np.concatenate([M[:3, 0], M[:3, 1], M[:3, 2], M[:3, 3]])]


def _sleeping_nose(rig, place):
    """Where the animal's nose is when it sleeps, in the game's frame (tiles from its middle on the ground, facing +X):
    its little "z z z" rises from there (data/animal_sleep.json). None for one with no sleeping pose (a bee)."""
    if not (rig["legs"] or rig.get("shell")):
        return None
    p = _rest(); p["sleep"] = 1.0
    at = (pose(rig, p)[2] @ np.append(np.array(rig["nose"], float), 1.0))[:3]
    return [round(float(v), 4) for v in place(at[None, :])[0]]


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


def _about(pivot, axis, ang, grow=1.0):
    """The move that turns points about `pivot` (and spreads them from it by `grow`), as one 4x4."""
    from .motion import R4, T4, rot
    return T4(pivot) @ R4(rot(axis, ang) * grow) @ T4(-np.array(pivot, float))


def _part_moves(a, rig, V0):
    """[(move, its points, the 4x4 that moves them)] for the parts that move on their own, as the animal stands:
    each ear turns out about its root, each wing lifts open about its root along the body, a turkey's fan tips up
    and spreads."""
    out = []
    own = _owner(a); parts = np.array([s.get("part") or "" for s in a["shapes"]])[own]
    head = np.array(rig["head"], float); body = np.array(rig["body"], float)
    for part, name in (("ear", "ear_flick"), ("wing", "wing_flap")):
        idx = np.where(parts == part)[0]
        if len(idx) < 10:
            continue
        for side in (-1.0, 1.0):
            one = idx[np.sign(V0[idx, 0]) == side]
            if len(one) < 5:
                continue
            if part == "ear":       # its root: its point nearest the head's middle; it turns out and back about the body's length
                root = V0[one][np.argmin(np.linalg.norm(V0[one] - head, axis=1))]
                out.append((name, one, _about(root, (0, 0, 1), side * EAR_FLICK)))
            else:                   # its root: along its top edge nearest the body's middle line
                q = V0[one]; root = np.array([q[np.argmin(np.abs(q[:, 0])), 0], q[:, 1].max(), q[:, 2].mean()])
                out.append((name, one, _about(root, (0, 0, 1), side * WING_OPEN)))
    fan = np.where(parts == "fan")[0]
    if len(fan) >= 10:
        q = V0[fan]; base = q[np.argmin(np.linalg.norm(q - body, axis=1))]
        out.append(("display", fan, _about(base, (1, 0, 0), FAN_LIFT, FAN_SPREAD)))
    return out


BLINK = 0.93             # how far an eye's drawing closes to a line (motion.deform)
BONES_EACH = 4           # the bones a point may follow (what the game's renderer reads without a second set)
STILL = 1e-6             # a bone that a move carries less than this is not written for it


def _own_moves(a, rig):
    """[(points, {move: 4x4}, the 4x4 at rest or None)] for what motion.deform moves by hand before the bones do:
    each eye closing, a rabbit's ears lying back as it sleeps, a bee's wings beating."""
    from .motion import EARS_BACK, R4, T4, rot
    out = []
    for s, e, c, up in a["eyes"]:
        A = np.eye(4); A[:3, :3] -= BLINK * np.outer(up, up); A[:3, 3] = BLINK * np.array(up, float) * float(np.dot(up, c))
        out.append((np.arange(s, e), {"blink": A}, None))
    if rig.get("ears") and rig.get("sleep") in EARS_BACK:
        for idx, at in rig["ears"]:
            out.append((np.asarray(idx), {"sleep": _about(at, (1, 0, 0), -EARS_BACK[rig["sleep"]])}, None))
    for idx, piv, sx in rig.get("wings") or []:
        beat = lambda t: _about(piv, (0, 0, 1), sx * (0.2 + math.sin(t * 60.0) * 0.32))
        out.append((np.asarray(idx), {"wing_flap": beat(BEE_BEAT)}, beat(0.0)))
    return out


def _rigged(a, rig, W, V0):
    """The animal's bones and moves. A point follows the rig's bones by `W`; a part that also moves on its own (an
    eye, an ear, a wing, a fan) gets its own copy of each bone it follows, so its move is that bone's too. Returns
    (weights per point over all bones, each bone's 4x4 at rest, [(move, {bone: 4x4 change})]): a point's place is
    the sum over its bones of weight x (rest + each wanted move's change x its strength) x the point as built,
    which is what the builder's own motion gives for every move alone and what the game's sums gave before."""
    n = len(a["V"]); own = _own_moves(a, rig); parts = _part_moves(a, rig, V0)
    touched = np.zeros((n, len(own) + len(parts)), bool)
    for k, (idx, _m, _r) in enumerate(own):
        touched[idx, k] = True
    for k, (_name, idx, _m) in enumerate(parts):
        touched[idx, len(own) + k] = True
    kinds, kind_of = np.unique(touched, axis=0, return_inverse=True); kind_of = kind_of.reshape(-1)
    kinds = [tuple(np.where(row)[0]) for row in kinds]
    order = sorted(range(len(kinds)), key=lambda g: len(kinds[g]))   # (the bones of the body first, as rig.weights numbers them)
    nb = W.shape[1]; bones = []; Wn = []
    for g in order:
        mine = kind_of == g
        for b in range(nb):
            col = np.where(mine, W[:, b], 0.0)
            if kinds[g] and not (col > STILL).any():
                continue
            bones.append((g, b)); Wn.append(col)
    Wn = np.stack(Wn, 1)

    def before(g, move):
        """What the animal's own parts in `g` do before the bones move them, for `move` (None: at rest)."""
        A = np.eye(4)
        for k in kinds[g]:
            if k < len(own):
                at_rest = own[k][2] if own[k][2] is not None else np.eye(4)
                A = A @ own[k][1].get(move, at_rest)
        return A

    M0 = pose(rig, _rest())
    rest = [M0[b] @ before(g, None) for g, b in bones]
    made = []
    for mname, p in moves():
        if mname == "hop" and not rig.get("hop"):
            continue   # (only a hopper hops)
        if mname == "sleep" and not (rig["legs"] or rig.get("shell")):
            continue   # (a bee has no pose of its own to sleep in)
        made.append((mname, p))
    if rig.get("wings"):          # a bee: its wings at the top of a beat (the builder's motion beats them by time)
        p = _rest(); p["time"] = BEE_BEAT; made.append(("wing_flap", p))
    out = []
    for mname, p in made:
        M = pose(rig, p)
        out.append((mname, {k: M[b] @ before(g, mname) - rest[k] for k, (g, b) in enumerate(bones)}))
    for mname in dict.fromkeys(name for name, _i, _m in parts):   # (ears flick, wings open, a turkey's fan)
        change = {}
        for k, (g, _b) in enumerate(bones):
            P = np.eye(4)
            for t in kinds[g]:
                if t >= len(own) and parts[t - len(own)][0] == mname:
                    P = parts[t - len(own)][2] @ P
            change[k] = (P - np.eye(4)) @ rest[k]
        out.append((mname, change))
    return Wn, rest, [(m, {k: D for k, D in c.items() if np.abs(D).max() > STILL}) for m, c in out]


def posed(a, Wn, rest, changes, strengths):
    """Every point where the bones put it: `strengths` {move: how much of it} (none: as the animal stands)."""
    Vh = np.c_[a["V"], np.ones(len(a["V"]))]; out = np.zeros_like(a["V"]); by = dict(changes)
    for k, R in enumerate(rest):
        w = Wn[:, k:k + 1]
        if not w.any():
            continue
        M = R + sum((by[m].get(k, 0.0) * s for m, s in strengths.items()), np.zeros((4, 4)))
        out += w * (Vh @ M.T)[:, :3]
    return out


def _follows(Wn):
    """Each point's strongest BONES_EACH bones and how much it follows each (summing to 1)."""
    top = np.argsort(-Wn, axis=1)[:, :BONES_EACH]; w = np.take_along_axis(Wn, top, 1)
    w = w / w.sum(1, keepdims=True); top = np.where(w > 0, top, 0)
    return top.astype(np.uint16), w.astype(np.float32)


def _write(path, name, pos, nor, col, ind, targets, uv=None, uv2=None, rigging=None):
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

    FLOAT, UINT, USHORT = 5126, 5125, 5123
    attrs = dict(POSITION=add(pos, "VEC3", FLOAT, 34962, True), NORMAL=add(nor, "VEC3", FLOAT, 34962),
                 COLOR_0=add(col, "VEC4", FLOAT, 34962),
                 TEXCOORD_0=add(np.zeros((len(pos), 2), np.float32) if uv is None else uv, "VEC2", FLOAT,
                                34962))   # (importers want UVs; the farmer's say whose colour a point wears)
    if uv2 is not None:
        attrs["TEXCOORD_1"] = add(uv2, "VEC2", FLOAT, 34962)   # (a limited coat's touch: _touch_points)
    node = dict(name=name.replace(" ", "_"), mesh=0)
    nodes = [node]; skins = []
    if rigging is not None:   # (the bones: nodes with nothing of their own; the game places them, move by move)
        attrs["JOINTS_0"] = add(rigging["bones"].astype(np.uint16), "VEC4", USHORT, 34962)
        attrs["WEIGHTS_0"] = add(rigging["follow"].astype(np.float32), "VEC4", FLOAT, 34962)
        count = len(rigging["rest"])
        nodes += [dict(name="rig", children=list(range(2, 2 + count)))]
        nodes += [dict(name="bone_%02d" % k) for k in range(count)]
        skins = [dict(joints=list(range(2, 2 + count)), skeleton=1)]
        node["skin"] = 0
        node["extras"] = dict(rest=rigging["rest"], moves=rigging["moves"], box=rigging["box"])
    indices = add(ind.astype(np.uint32), "SCALAR", UINT, 34963)
    # (positions only: a move's change of shading is too small to see, and normals would double the file)
    tgts = [dict(POSITION=add(dp, "VEC3", FLOAT, 34962, True)) for _n, dp, _dn in targets]
    gltf = dict(
        asset=dict(version="2.0", generator="farm-game animal_art"),
        scene=0, scenes=[dict(nodes=[0, 1] if skins else [0])], nodes=nodes,
        meshes=[dict(name=name.replace(" ", "_"), primitives=[dict(attributes=attrs, indices=indices, material=0, mode=4,
                                                                  targets=tgts)],
                     weights=[0.0] * len(tgts), extras=dict(targetNames=[t[0] for t in targets]))],
        materials=[dict(name="coat", pbrMetallicRoughness=dict(baseColorFactor=[1, 1, 1, 1], metallicFactor=0.0,
                                                               roughnessFactor=0.9))],
        buffers=[dict(byteLength=0)], bufferViews=views, accessors=accs)
    if skins:
        gltf["skins"] = skins
    if not tgts:
        del gltf["meshes"][0]["primitives"][0]["targets"], gltf["meshes"][0]["weights"], gltf["meshes"][0]["extras"]
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
