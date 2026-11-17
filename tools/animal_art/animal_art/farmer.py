"""The player's farmer, made the way the animals are: soft shapes melted into one skin, a face drawn on it, light
painted in, and exported as one glTF file with its moves as blend shapes.

FarmVille's proportions: a head nearly half the height on a slim body, large eyes, a small smile, a full head of
hair; a T-shirt under bib overalls, rolled cuffs, round-toed boots.

The file carries no look of its own. Each point's colour is its painted light times a tint, and its first texture
coordinate says whose colour it wears (REGIONS: skin, hair, shirt, overalls, shoes, or its own fixed colour), so
the game colours one file for any look (scripts/world3d/farmer_3d.gd).

Moves (blend shapes, each a limb turned about its joint; the game mixes them):
    leg_l_f, leg_l_b, leg_r_f, leg_r_b     a leg swung forward or back by LEG_SWING
    arm_l_b, arm_r_b                       an arm swung back by ARM_BACK
    arm_l_f1, arm_r_f1, arm_l_f2, arm_r_f2 an arm raised forward by ARM_F1, and by ARM_F2 (working: both arms out)
    blink                                  the eyes shut

Builder axes: up +y, facing +z, x across; lengths in S units a head-to-toe (the animals' scale, so the shared
blending and light behave). Game axes on export: 1 unit = 1 tile, up +Y, facing +X, feet on y = 0."""
import math

import numpy as np
from scipy.spatial import cKDTree

from . import decal
from .decal import Mesh, ell, fan, frame, strip
from .export import _write
from .geometry import cast, vnormals
from .look import bake
from .shapes import C, E, sdf
from .skin import skin

S = 5.0                 # builder units head to toe
HEIGHT = 0.78           # tiles tall in the game
RES = 64                # cells along the farmer's height (one hero figure: finer than an animal)
SHADE = 0.4             # how much of the painted shadow is kept: under so big a head the whole body would go grey
JOIN = 0.03 * S         # how softly body parts melt together
FINE = 0.014 * S        # ..and small features (ears, hair tufts, the nose)
LEG_SWING = 0.7         # radians (farmer_3d.gd STRIDE)
ARM_BACK = 0.5
ARM_F1 = 0.72
ARM_F2 = 1.45
HAIR_STYLES = ("short", "long", "ponytail")
KINDS = ("a", "b")      # the look's `body`: a boy, a girl (her own shoulders, lashes, lips and ways of wearing her hair)

# Marker colours: what each part is built in (the default look's own colours), and whose colour it wears in the
# game with what tint: colour -> (region, tint). Anything else keeps its own colour (region 0).
SKIN, HAIR, SHIRT, OVERALLS, SHOES = (0.945, 0.788, 0.647), (0.353, 0.227, 0.118), (0.851, 0.282, 0.231), \
    (0.247, 0.435, 0.710), (0.357, 0.231, 0.133)
LID, BLUSH, BROW, NOSE, CUFF = (0.84, 0.7, 0.575), (0.95, 0.63, 0.6), (0.2, 0.13, 0.07), (0.88, 0.72, 0.58), \
    (0.2, 0.36, 0.6)
BRASS, MOUTH, IRIS = (0.91, 0.76, 0.29), (0.5, 0.2, 0.17), (0.23, 0.44, 0.72)
LIPS = (0.8, 0.33, 0.36)
PUPIL = (0.12, 0.08, 0.06)   # the button eyes' dark
EYE_R, EYE_X, EYE_Y = 0.034, 0.08, 0.76   # an eye's radius, how far from the middle, how high (of S)
BROW_R = 0.045           # the brows' span, as an eye's would be
MOUTH_Y, SMILE_HALF, SMILE_DEEP = 0.69, 0.04, 0.035   # the open smile: how high, half its width, its depth
REGIONS = ("fixed", "skin", "hair", "shirt", "overalls", "shoes")
WEARS = {SKIN: (1, (1, 1, 1)), HAIR: (2, (1, 1, 1)), SHIRT: (3, (1, 1, 1)), OVERALLS: (4, (1, 1, 1)), SHOES: (5, (1, 1, 1)),
         LID: (1, (0.9, 0.9, 0.9)), BLUSH: (1, (1.0, 0.8, 0.86)), NOSE: (1, (0.93, 0.92, 0.9)), BROW: (2, (0.6, 0.6, 0.6)),
         CUFF: (4, (0.8, 0.8, 0.8))}

HIP = np.array([0.055, 0.33, 0.0]) * S          # a leg's joint (x mirrored for the other)
SHOULDER = {"a": np.array([0.115, 0.525, 0.0]) * S, "b": np.array([0.102, 0.525, 0.0]) * S}   # an arm's, by kind


def _v(x, y, z):
    return (x * S, y * S, z * S)


def _chest(P):
    """A T-shirt with the overalls' bib over its front and their straps over the shoulders, front and back."""
    x, y, z = np.abs(P[:, 0]) / S, P[:, 1] / S, P[:, 2] / S
    bib = (z > 0.012) & (x < 0.068) & (y < 0.515)
    strap = (x > 0.04) & (x < 0.07) & (y >= 0.5)
    waist = y < 0.415
    pocket = (z > 0.02) & (x < 0.036) & (y > 0.425) & (y < 0.468)
    out = np.tile(np.array(SHIRT), (len(P), 1))
    out[bib | strap | waist] = OVERALLS
    out[pocket] = CUFF
    return out


def _leg(P):
    out = np.tile(np.array(OVERALLS), (len(P), 1))
    out[P[:, 1] / S < 0.095] = CUFF     # the rolled cuff
    return out


def shapes(hair="short", kind="a"):
    """The farmer's soft shapes. The body comes first; the head's own are marked."""
    girl = kind == "b"
    wide = 0.092 if girl else 0.105          # the chest's half width; a girl's shoulders are narrower
    arm = wide + 0.01                        # where an arm leaves the shoulder
    out = [E(_v(0, 0.37, 0), _v(0.1 if girl else 0.105, 0.085, 0.078), OVERALLS, k=JOIN),
           E(_v(0, 0.47, 0), _v(wide, 0.105, 0.072 if girl else 0.075), _chest, k=JOIN),
           C(_v(0, 0.555, 0), _v(0, 0.61, 0), (0.031 if girl else 0.035) * S, (0.031 if girl else 0.035) * S, SKIN, k=JOIN)]
    for sx, side in ((-1, "l"), (1, "r")):
        out += [C(_v(sx * 0.055, 0.33, 0), _v(sx * 0.06, 0.065, 0), 0.052 * S, 0.042 * S, _leg, k=JOIN, part="leg_" + side),
                E(_v(sx * 0.062, 0.036, 0.03), _v(0.05, 0.036, 0.085), SHOES, k=FINE, part="leg_" + side),
                E(_v(sx * (arm - 0.003), 0.522, 0), _v(0.04, 0.036, 0.042), SHIRT, k=JOIN),
                C(_v(sx * arm, 0.525, 0), _v(sx * (arm + 0.035), 0.41, 0), 0.034 * S, 0.03 * S, SHIRT, k=FINE, part="arm_" + side),
                C(_v(sx * (arm + 0.035), 0.41, 0), _v(sx * (arm + 0.047), 0.315, 0.01), 0.027 * S, 0.024 * S, SKIN, k=FINE,
                  part="arm_" + side),
                E(_v(sx * (arm + 0.05), 0.285, 0.012), _v(0.03, 0.036, 0.028), SKIN, k=FINE, part="arm_" + side),
                E(_v(sx * 0.055, 0.512, 0.076), _v(0.013, 0.013, 0.01), BRASS, k=0.004 * S),
                E(_v(sx * 0.2, 0.765, 0.0), _v(0.028, 0.045, 0.03), SKIN, head=True, k=FINE)]
    out += [E(_v(0, 0.79, 0.01), _v(0.2, 0.2, 0.185), SKIN, head=True, k=JOIN),
            E(_v(0, 0.645, 0.03), _v(0.1 if girl else 0.105, 0.07, 0.1), SKIN, head=True, k=JOIN),
            E(_v(0, 0.735, 0.2), _v(0.017 if girl else 0.02, 0.016 if girl else 0.018, 0.018 if girl else 0.02), NOSE, head=True, k=FINE),
            # hair: a cap over the top and back, and a fringe in three locks clear of the brows
            E(_v(0, 0.865, -0.03), _v(0.213, 0.155, 0.2), HAIR, k=FINE),
            E(_v(0, 0.79, -0.1), _v(0.2, 0.17, 0.135), HAIR, k=FINE),
            E(_v(-0.1, 0.945, 0.115), _v(0.085, 0.045, 0.075), HAIR, rz=-0.35, k=FINE),
            E(_v(0.1, 0.945, 0.115), _v(0.085, 0.045, 0.075), HAIR, rz=0.35, k=FINE),
            E(_v(0.0, 0.962, 0.135), _v(0.08, 0.042, 0.075), HAIR, k=FINE)]
    if girl:
        # her hair frames the face: a lock down each cheek to the jaw, and a fringe swept to one side
        out += [E(_v(sx * 0.19, 0.76, 0.03), _v(0.045, 0.145, 0.085), HAIR, k=FINE) for sx in (-1, 1)]
        out += [E(_v(-0.06, 0.93, 0.15), _v(0.11, 0.04, 0.06), HAIR, rz=-0.5, k=FINE)]
        if hair == "short":      # a bob, to the chin all round
            out += [E(_v(0, 0.71, -0.09), _v(0.2, 0.15, 0.125), HAIR, k=FINE)]
        elif hair == "long":     # down past the shoulders
            out += [E(_v(0, 0.63, -0.11), _v(0.2, 0.22, 0.095), HAIR, k=FINE)]
            out += [E(_v(sx * 0.175, 0.6, -0.02), _v(0.05, 0.19, 0.08), HAIR, k=FINE) for sx in (-1, 1)]
        else:                    # tied up in a bun, high at the back
            out += [E(_v(0, 0.985, -0.13), _v(0.09, 0.085, 0.09), HAIR, k=FINE),
                    E(_v(0, 0.93, -0.11), _v(0.06, 0.03, 0.06), LIPS, k=0.006 * S)]
    else:
        out += [E(_v(sx * 0.185, 0.82, 0.02), _v(0.04, 0.085, 0.075), HAIR, k=FINE) for sx in (-1, 1)]
        out += [C(_v(0.03, 0.985, 0.1), _v(0.085, 1.03, 0.19), 0.045 * S, 0.012 * S, HAIR, k=FINE)]   # a tuft swept up
        if hair == "long":
            out += [E(_v(0, 0.66, -0.1), _v(0.2, 0.17, 0.1), HAIR, k=FINE)]
            out += [E(_v(sx * 0.17, 0.66, -0.02), _v(0.05, 0.14, 0.08), HAIR, k=FINE) for sx in (-1, 1)]
        elif hair == "ponytail":
            out += [E(_v(0, 0.87, -0.2), _v(0.05, 0.05, 0.05), HAIR, k=FINE),
                    C(_v(0, 0.86, -0.23), _v(0, 0.7, -0.27), 0.05 * S, 0.02 * S, HAIR, k=FINE)]
    return out


def _face(m, V, T, wh, kind="a"):
    """Button eyes (round and dark, a big glint and a small one), soft brows, blush and an open smile, drawn flat
    and seated on the head's own surface (the owner's pick, 17 Nov: the big pale eyes read as staring). Returns
    each eye's points."""
    Th = T[(wh[T] > 0.3).any(1)]
    fwd = np.array([0.0, 0.0, 1.0])

    def seat(x, y):
        q, n, _k = cast(V, Th, np.array([x * S, y * S, 3.0 * S]), -fwd)
        return q, n

    decal.PROJ = lambda P, o: cast(V, Th, P + o * 1.5, -o)[0]
    girl = kind == "b"
    r = EYE_R * S
    eyes = []
    for sx in (-1, 1):
        p, n = seat(sx * EYE_X, EYE_Y)
        out = 0.6 * n + 0.4 * fwd
        out /= np.linalg.norm(out)
        u, up = frame(out, np.array([1.0, 0.0, 0.0]))
        e0 = m.n
        fan(m, p, u, up, out, ell(r, r * 1.12), 1, PUPIL)
        fan(m, p, u, up, out, ell(r * 0.42, r * 0.42, r * 0.28, r * 0.38, 12), 2, (1, 1, 1))
        fan(m, p, u, up, out, ell(r * 0.18, r * 0.18, -r * 0.3, -r * 0.35, 8), 2, (1, 1, 1))
        eyes.append((e0, m.n, p.copy(), up.copy()))
        rb = BROW_R * S
        brow = [(x * rb * 0.8, (1.55 + 0.18 * (1 - x * x)) * rb) for x in np.linspace(-1, 1, 9)]
        thick = (0.05 if girl else 0.07) * rb
        strip(m, p, u, up, out, [(a, b + thick) for a, b in brow], [(a, b - thick) for a, b in brow], 0, BROW)
        fan(m, p, u, up, out, ell(0.025 * S, 0.015 * S, sx * 0.035 * S, -0.0625 * S, 14), 0, BLUSH)
    p, n = seat(0.0, MOUTH_Y)
    u, up = frame(n, np.array([1.0, 0.0, 0.0]))
    half = SMILE_HALF * S
    lip = 0.004 * S
    top = [(x * half, lip) for x in np.linspace(-1, 1, 11)]
    bottom = [(x * half, lip - SMILE_DEEP * S * math.sqrt(max(0.0, 1 - x * x))) for x in np.linspace(-1, 1, 11)]
    strip(m, p, u, up, n, top, bottom, 0, LIPS if girl else MOUTH)
    decal.PROJ = None
    return eyes


def build(hair="short", kind="a", res=RES):
    """The finished model: points, triangles, a colour per triangle, the painted light, and what each point follows."""
    sh = shapes(hair, kind)
    V, T, cols, wh = skin(sh, res=res, splits=2)
    vn = vnormals(V, T)
    m = Mesh(V, T, cols)
    eyes = _face(m, V, T, wh, kind)
    Vf, Tf, Cf = m.done()
    a = dict(V=Vf, T=Tf, C=Cf, vn=np.vstack([vn, np.zeros((len(Vf) - len(V), 3))]), shapes=sh, wh=wh, eyes=eyes,
             nsoft=len(V), nvb=len(V), nbody=len(T), tris=len(T), res=res)
    bake(a)
    a["bake"] = 1.0 - SHADE * (1.0 - a["bake"])
    # what each skin point follows: the limb whose shape it lies on
    D = np.stack([sdf(V, s) for s in sh], 1)
    a["part"] = [sh[i]["part"] for i in D.argmin(1)]
    a["kind"] = kind
    return a


def _ramp(x, lo, hi):
    t = np.clip((x - lo) / (hi - lo), 0, 1)
    return t * t * (3 - 2 * t)


def _swing(V, w, pivot, ang):
    """Points turned about the across axis through `pivot` by `ang` forward (toward +z), each by its own share `w`."""
    th = -ang * w
    d = V - pivot
    c, s = np.cos(th), np.sin(th)
    out = V.copy()
    out[:, 1] = pivot[1] + d[:, 1] * c - d[:, 2] * s
    out[:, 2] = pivot[2] + d[:, 1] * s + d[:, 2] * c
    return out


def moves(a):
    """{name: the model's points in that pose}."""
    V = a["V"]
    n0 = a["nsoft"]
    part = np.array(a["part"] + [None] * (len(V) - n0), dtype=object)
    out = {}
    for sx, side in ((-1, "l"), (1, "r")):
        hip = HIP * np.array([sx, 1, 1])
        w = (part == "leg_" + side) * _ramp(hip[1] - V[:, 1], 0.0, 0.07 * S)
        out["leg_%s_f" % side] = _swing(V, w, hip, LEG_SWING)
        out["leg_%s_b" % side] = _swing(V, w, hip, -LEG_SWING)
        sho = SHOULDER[a["kind"]] * np.array([sx, 1, 1])
        w = (part == "arm_" + side) * _ramp(np.linalg.norm(V - sho, axis=1), 0.015 * S, 0.07 * S)
        out["arm_%s_b" % side] = _swing(V, w, sho, -ARM_BACK)
        out["arm_%s_f1" % side] = _swing(V, w, sho, ARM_F1)
        out["arm_%s_f2" % side] = _swing(V, w, sho, ARM_F2)
    shut = V.copy()
    for e0, e1, p, up in a["eyes"]:
        d = shut[e0:e1] - p
        shut[e0:e1] = p + d - np.outer(d @ up, up) * 0.92     # an eye's drawing squeezed flat along its height
    out["blink"] = shut
    return out


def export(path, hair="short", kind="a"):
    a = build(hair, kind)
    V0, T, n0 = a["V"], a["T"], a["nsoft"]
    cols = np.array(a["C"], np.float32)
    light = a["bake"]
    # one vertex per (point, colour): neighbouring triangles of different colours keep their own edge
    key, src, vcol, vreg = {}, [], [], []
    idx = np.zeros(T.shape, np.uint32)
    for ti, t in enumerate(T):
        c = tuple(round(float(x), 3) for x in cols[ti])
        region, tint = WEARS.get(c, (0, c))
        for j, v in enumerate(t):
            k = (int(v), c)
            if k not in key:
                key[k] = len(src)
                src.append(int(v))
                vcol.append(np.array(tint) * light[v])
                vreg.append(region)
            idx[ti, j] = key[k]
    src = np.array(src)
    N0 = a["vn"].copy()
    bare = np.linalg.norm(N0, axis=1) < 1e-6      # a drawing's points take the nearest skin point's normal
    N0[bare] = N0[:n0][cKDTree(V0[:n0]).query(V0[bare])[1]]
    tri = idx.reshape(-1, 3)
    P, Nn = V0[src], N0[src]
    face = np.cross(P[tri[:, 1]] - P[tri[:, 0]], P[tri[:, 2]] - P[tri[:, 0]])
    flip = (face * (Nn[tri[:, 0]] + Nn[tri[:, 1]] + Nn[tri[:, 2]])).sum(1) < 0
    tri[flip] = tri[flip][:, [0, 2, 1]]
    lo, hi = V0.min(0), V0.max(0)
    centre = np.array([0.0, lo[1], 0.0])
    scale = HEIGHT / (hi[1] - lo[1])
    turn = lambda Q: np.stack([Q[:, 2], Q[:, 1], -Q[:, 0]], 1)
    place = lambda Q: turn((Q - centre) * scale).astype(np.float32)
    pos = place(V0[src])
    nor = turn(N0[src]).astype(np.float32)
    targets = [(name, place(Vm[src]) - pos, np.zeros_like(nor)) for name, Vm in moves(a).items()]
    colours = np.c_[np.clip(np.array(vcol, np.float32), 0, 1), np.ones(len(vcol), np.float32)]
    uv = np.zeros((len(pos), 2), np.float32)
    uv[:, 0] = (np.array(vreg) + 0.5) / 8.0
    name = "farmer_%s_%s" % (kind, hair)
    _write(path, name, pos, nor, colours, tri.reshape(-1), targets, uv=uv)
    return dict(name=name, vertices=len(pos), triangles=len(tri), targets=[t[0] for t in targets])
