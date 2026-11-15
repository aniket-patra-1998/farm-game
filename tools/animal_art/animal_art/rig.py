"""Joints and weights, measured from the finished model, so any animal can be animated with no joint list written by hand."""
import numpy as np
import math
from .motion import sstep
from .shapes import sdf


# ---------------------------------------------------------------- which part each point follows
def weights(P, rig, a=None):
    """Bones: 0 body, 1 neck, 2 head, 3 tail, then two per leg (upper, lower). From position alone, so it works for
    the skin, the hard parts (horns, beak, feet) and the face drawings alike."""
    n = len(P); nl = len(rig["legs"]); W = np.zeros((n, 4 + 2 * nl))
    chest, head = np.array(rig["chest"], float), np.array(rig["head"], float); d = head - chest; L = np.linalg.norm(d)
    t = ((P - chest) @ d) / (L * L)
    # only the front of the animal can belong to the neck and head (a tall tail or a hump is high up too, but behind)
    front = sstep(chest[2] - 0.85 * rig["r"][2], chest[2] - 0.4 * rig["r"][2], P[:, 2])
    wh = sstep(0.6, 1.12, t) * front; wn = sstep(-0.45, 0.35, t) * front * (1 - wh)
    W[:, 2], W[:, 1] = wh, wn
    # the tail is whatever reaches out behind the body (legs are taken out of it below)
    c = np.array(rig["body"], float); rz = rig["r"][2]; zr = c[2] - 1.02 * rz
    W[:, 3] = sstep(zr, zr - 0.3 * rz, P[:, 2]) * (P[:, 1] > 0.1 * c[1])
    stubs = [s for s in a["shapes"] if s.get("part") == "stub"] if a is not None else []
    if stubs:
        # a shelled animal: its legs are stubs that slide under the shell. What belongs to a stub is told by the
        # template's own shapes (a point is leg where a leg shape is nearer than any other), never by where it
        # stands, because the shell's rim hangs right over the legs
        others = [s for s in a["shapes"] if s.get("part") != "stub"]
        dl = np.min([sdf(P, s) for s in stubs], 0); do = np.min([sdf(P, s) for s in others], 0)
        legness = sstep(-0.1, 0.1, do - dl)
        F = np.array([l["foot"] for l in rig["legs"]]); near = np.argmin(np.hypot(P[:, None, 0] - F[None, :, 0], P[:, None, 2] - F[None, :, 2]), 1)
        for k in range(nl):
            W[:, 4 + 2 * k] = np.where(near == k, legness, 0.0)
    for k, leg in enumerate(rig["legs"] if not stubs else []):
        H, K, F = (np.array(leg[q], float) for q in ("hip", "knee", "foot"))
        f = np.clip((H[1] - P[:, 1]) / max(H[1] - F[1], 1e-6), 0, 1)                 # 0 at the hip .. 1 at the foot
        R = leg["r"] + (leg["rf"] - leg["r"]) * sstep(0.72, 1.0, f)                  # the leg's width, wider at the foot
        kf = (H[1] - K[1]) / (H[1] - F[1])
        axis = np.where((f < kf)[:, None], H + (K - H) * (f / kf)[:, None], K + (F - K) * ((f - kf) / (1 - kf))[:, None])
        hd = np.hypot(P[:, 0] - axis[:, 0], P[:, 2] - axis[:, 2])
        inleg = (1 - sstep(R * 0.85, R * 1.3, hd)) * sstep(H[1] + 0.12, H[1] - 0.3, P[:, 1])
        lo = sstep(kf - 0.12, kf + 0.12, f)
        W[:, 4 + 2 * k] = inleg * (1 - lo); W[:, 5 + 2 * k] = inleg * lo
    legsum = W[:, 4:].sum(1); over = np.maximum(legsum, 1.0); W[:, 4:] /= over[:, None]; legsum = W[:, 4:].sum(1)
    rest = 1 - legsum
    W[:, 1:4] *= rest[:, None]; s3 = W[:, 1:4].sum(1); W[:, 1:4] /= np.maximum(s3 / np.maximum(rest, 1e-9), 1.0)[:, None]
    W[:, 0] = np.clip(1 - W[:, 1:].sum(1), 0, 1)
    return W / W.sum(1, keepdims=True)


def stiffen(W, a):
    """Hard parts (horns, beak, comb, wattle, toes) and the drawings of the face must not bend: each such piece
    follows, whole, the one part it mostly sits on. A bird's leg bar is the exception: its top end follows the
    thigh and its bottom end the shin, so it still reaches from hip to foot."""
    from scipy.sparse import coo_matrix
    from scipy.sparse.csgraph import connected_components
    n0 = a["nsoft"]; T = a["T"]; T = T[(T >= n0).all(1)]
    if not len(T):
        return W
    n = len(W); e = np.vstack([T[:, [0, 1]], T[:, [1, 2]]])
    _k, lab = connected_components(coo_matrix((np.ones(len(e)), (e[:, 0], e[:, 1])), shape=(n, n)), directed=False)
    W = W.copy()
    for l in np.unique(lab[n0:]):
        idx = np.where(lab == l)[0]; idx = idx[idx >= n0]
        dom = W[idx].argmax(1)
        if (dom >= 4).any() and len(np.unique(dom)) > 1:          # a leg bar: each end to its own part
            W[idx] = 0; W[idx, dom] = 1
        else:
            b = W[idx].sum(0).argmax(); W[idx] = 0; W[idx, b] = 1
    return W


# ---------------------------------------------------------------- the joints, measured from the model itself
def measure_joints(a):
    """Where an animal's joints are, read off the finished model, so any animal (a new one too) can be animated
    with no joint list written by hand. The one thing asked of a template: its first shape is the body.
      feet: the clumps of points touching the ground (four: a four-legged animal; two: a bird; none: it flies);
      knee: the middle of each leg's column half-way up; hip: where the column meets the underside of the body;
      head: the points the template marked as head; it turns where they begin, on the line from the chest;
      nose: the foremost point of the head (found after the weights, see rig_of)."""
    body = a["shapes"][0]; c = body["c"].copy(); rx, ry, rz = body["r"]
    P = a["V"][:a["nvb"]]; soft = a["V"][:a["nsoft"]]
    g = P[(P[:, 1] < 0.12 * c[1]) & (np.abs(P[:, 0]) > 0.04)]
    legs = []
    if len(g) >= 8:
        zs = np.sort(g[:, 2]); quad = (zs[-1] - zs[0]) > 1.0 * rz
        cut = None
        if quad:
            i = np.argmax(np.diff(zs)); cut = (zs[i] + zs[i + 1]) / 2
        for sx, side in ((-1, "far"), (1, "near")):
            for fore in ((False, True) if quad else (False,)):
                mk = (g[:, 0] * sx > 0) & ((g[:, 2] > cut) == fore if quad else True)
                if mk.sum() < 3:
                    continue
                q = g[mk]; F = np.array([q[:, 0].mean(), 0.0, q[:, 2].mean()])
                rf = float(np.percentile(np.hypot(q[:, 0] - F[0], q[:, 2] - F[2]), 95))
                under = c[1] - ry * math.sqrt(max(0.05, 1 - (F[0] / rx) ** 2 - ((F[2] - c[2]) / rz) ** 2))
                Hy = max(under + 0.15 * ry, 0.35 * c[1])
                col = P[(np.hypot(P[:, 0] - F[0], P[:, 2] - F[2]) < rf * 1.5 + 0.05) & (P[:, 1] > 0.42 * Hy) & (P[:, 1] < 0.58 * Hy)]
                if len(col) >= 4:
                    K = np.array([col[:, 0].mean(), 0.5 * Hy, col[:, 2].mean()])
                    r = float(np.percentile(np.hypot(col[:, 0] - K[0], col[:, 2] - K[2]), 90)) * 1.4 + 0.03
                else:
                    K = np.array([F[0], 0.5 * Hy, F[2] - (0.0 if quad else 0.03)]); r = 0.1 * c[1]
                legs.append(dict(name=(("fore_" if fore else "hind_") + side) if quad else side, fore=fore,
                                 hip=(F[0], Hy, F[2]), knee=tuple(K), foot=tuple(F), r=r, rf=max(rf * 1.15, r)))
    chest = np.array([0.0, c[1] + 0.4 * ry, c[2] + 0.8 * rz])
    Hv = soft[a["wh"] > 0.5]
    if len(Hv) >= 10:
        hc = Hv.mean(0); hc[0] = 0.0; u = (hc - chest) / np.linalg.norm(hc - chest)
        piv = chest + u * max(float(np.percentile((Hv - chest) @ u, 8)), 0.0)
        if np.linalg.norm(piv - chest) < 0.2 * rz:
            chest = piv - u * 0.2 * rz
    else:
        piv = chest + np.array([0.0, 0.1, 0.3])
    return dict(kind="quad" if len(legs) == 4 else ("bird" if len(legs) == 2 else "bug"), body=tuple(c), r=(rx, ry, rz),
                chest=chest, head=piv, nose=piv + np.array([0.0, 0.0, 0.5]), tail=[np.array([0.0, c[1] + 0.4 * ry, c[2] - rz])], legs=legs)


def rig_of(a, name=""):
    """The whole binding for one animal: joints measured, weights worked out, hard parts stiffened, nose found."""
    rig = measure_joints(a); rig["shell"] = any(s.get("part") == "stub" for s in a["shapes"])
    W = stiffen(weights(a["V"], rig, a), a)
    hd = np.where(W[:, 2] > 0.6)[0]
    if len(hd) > 20:
        z = a["V"][hd, 2]; rig["nose"] = a["V"][hd[z >= np.percentile(z, 99.3)]].mean(0) * np.array([0.0, 1.0, 1.0])
    rig["waddle"] = any(k in name for k in ("duck", "goose", "swan"))
    rig["hop"] = "rabbit" in name
    if rig["kind"] == "bug":            # a bee: its wings are the hard plates above its back
        from scipy.sparse import coo_matrix
        from scipy.sparse.csgraph import connected_components
        n0 = a["nsoft"]; T = a["T"]; T = T[(T >= n0).all(1) & (T < a["nvb"]).all(1)]; n = len(a["V"])
        e = np.vstack([T[:, [0, 1]], T[:, [1, 2]]])
        _k, lab = connected_components(coo_matrix((np.ones(len(e)), (e[:, 0], e[:, 1])), shape=(n, n)), directed=False)
        rig["wings"] = []
        for l in np.unique(lab[n0:a["nvb"]]):
            idx = np.where(lab == l)[0]; q = a["V"][idx]
            if q[:, 1].mean() > rig["body"][1] + 0.4 and (q[:, 0].max() - q[:, 0].min()) > 0.5:
                sx = 1.0 if q[:, 0].mean() > 0 else -1.0
                rig["wings"].append((idx, np.array([sx * 0.25, q[:, 1].min(), q[:, 2].mean()]), sx))
    return rig, W
