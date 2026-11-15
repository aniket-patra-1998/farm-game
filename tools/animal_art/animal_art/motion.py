"""The game's own animation maths (scripts/world3d/animal_3d.gd, AnimalArt, AnimalBehaviour), played on the new models.
Axes here: forward +z, up +y."""
import numpy as np
import math


STRIDE, STANCE, LIFT, SWAY = 0.7, 0.62, 0.3, 0.045          # the game's own numbers


QUAD_PHASE = {"hind_far": 0.5, "fore_far": 0.75, "hind_near": 0.0, "fore_near": 0.25}


BIRD_PHASE = {"far": 0.0, "near": 0.5}


GRAZE_PITCH = 0.9        # how far the head tips down to graze or peck (the game's 1.2 less its resting tilt)


NOSE_CLEAR = 0.1         # the muzzle stops this far above the grass


GRAZE_DIP = 0.07         # how far a four-legged animal's body tips forward while its head is down


PECK_TIP = 0.42          # how far a bird's whole body tips forward to peck (the game uses 0.12; more suits a short neck)


def sstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t)


def foot_offset(u, reach, lift):
    if u < STANCE:
        return (0.5 - u / STANCE) * reach, 0.0
    s = (u - STANCE) / (1 - STANCE)
    return (-0.5 + sstep(0, 1, s)) * reach, math.sin(math.pi * s) * lift


def joint(hip, foot, a, b, bend):
    """Two-bone limb in the side view (forward, up). bend +1: joint behind (hock), -1: in front (knee)."""
    d = foot - hip; L = np.linalg.norm(d); dist = min(max(L, 1e-3), a + b - 1e-3); u = d / max(L, 1e-9)
    along = (a * a - b * b + dist * dist) / (2 * dist); out = math.sqrt(max(0.0, a * a - along * along))
    perp = np.array([u[1], -u[0]])              # for a leg pointing down, this points backward
    return hip + u * along + perp * out * bend


def T4(t):
    M = np.eye(4); M[:3, 3] = t; return M


def R4(R):
    M = np.eye(4); M[:3, :3] = R; return M


def rot(axis, ang):
    axis = np.array(axis, float); axis /= np.linalg.norm(axis); x, y, z = axis; c, s = math.cos(ang), math.sin(ang); C = 1 - c
    return np.array([[c + x * x * C, x * y * C - z * s, x * z * C + y * s], [y * x * C + z * s, c + y * y * C, y * z * C - x * s],
                     [z * x * C - y * s, z * y * C + x * s, c + z * z * C]])


def seg(a0, b0, a1, b1):
    """The move that carries a part lying from a0 to b0 so that it lies from a1 to b1 (turning it, and stretching it
    along its length if the ends are further apart: what the game does to its leg and neck bars)."""
    a0, b0, a1, b1 = (np.array(v, float) for v in (a0, b0, a1, b1))
    d0, d1 = b0 - a0, b1 - a1; l0, l1 = np.linalg.norm(d0), np.linalg.norm(d1); u0, u1 = d0 / l0, d1 / l1
    ax = np.cross(u0, u1); sn = np.linalg.norm(ax); R = np.eye(3) if sn < 1e-9 else rot(ax, math.atan2(sn, u0 @ u1))
    S = np.eye(3) + (l1 / l0 - 1) * np.outer(u0, u0)
    return T4(a1) @ R4(R @ S) @ T4(-a0)


# ---------------------------------------------------------------- the pose (the game's maths)
def pose(rig, p):
    """p: gait, stride, head, look, jaw, breath, tail (as the game's AnimalPose). Returns one 4x4 move per bone."""
    c = np.array(rig["body"], float); rx, ry, rz = rig["r"]; bird = rig["kind"] == "bird"
    leg = max([l["hip"][1] for l in rig["legs"]] or [1.0])
    g, st = p.get("gait", 0.0), p.get("stride", 0.0); down = float(sstep(0, 1, p.get("head", 0.0)))
    # "natural": the same head-down, played with weight. The neck swings round its base in an arc and leads; the head
    # tips after it; the front of the body dips to follow; all of it from a sprung value that eases in and settles.
    nat = p.get("natural", False); e_head = down
    if nat:
        hs = p.get("head_s", p.get("head", 0.0)); over = max(0.0, hs - 1.0) * 0.6
        down = float(sstep(0, 1, min(hs * 1.2, 1.0))) + over
        e_head = float(sstep(0, 1, max(0.0, (hs - 0.18) / 0.82))) + over
    if rig.get("shell"):
        # the game's turtle (_pose_turtle): the shell stays level, the four stubs slide to and fro in diagonal pairs,
        # the head comes out as it walks or looks about, dips a little, and turns
        rz = rig["r"][2]; piv, chest = np.array(rig["head"], float), np.array(rig["chest"], float); I = np.eye(4)
        out = min(1.0, 0.55 + 0.45 * max(st, abs(p.get("look", 0.0))))
        head_at = piv + np.array([0.0, -p.get("head", 0.0) * 0.25, 0.35 * rz * (out - 0.55)])
        M = [I, seg(chest, piv, chest, head_at), T4(head_at) @ R4(rot((0, 1, 0), p.get("look", 0.0) * 0.5)) @ T4(-piv)]
        root = np.array(rig["tail"][0], float)
        M.append(T4(root) @ R4(rot((0, 1, 0), p.get("tail", 0.0) * 0.6)) @ T4(-root))
        for l in rig["legs"]:
            ph = 0.0 if l["name"] in ("fore_near", "hind_far") else 0.5
            S = T4([0.0, 0.0, math.sin((g + ph) * math.tau) * 0.25 * st]); M += [S, S]
        return M
    if not rig["legs"]:                                   # a bee: it only hovers (its wings are moved in skin())
        return [T4([0, math.sin(p.get("time", 0.0) * 3.3) * 0.13, 0])] * 4
    hop = p.get("hop", 0.0)
    if bird:
        rise = abs(math.sin(g * math.tau)) * leg * 0.08 * st
        roll = math.sin(g * math.tau) * 0.13 * st if rig.get("waddle") else 0.0
        pitch = PECK_TIP * (down if nat else p.get("head", 0.0))
    else:
        rise = math.sin(g * math.tau * 2) ** 2 * leg * 0.06 * st + p.get("breath", 0.0) * ry * 0.01
        roll = math.sin(g * math.tau) * SWAY * st; pitch = 0.0
        if nat:                                           # the forequarters dip as the head goes down
            pitch = GRAZE_DIP * down; rise -= 0.03 * ry * down
    br = 1 + p.get("breath", 0.0) * 0.012
    rise += hop * leg * 0.55
    B = T4(c + np.array([0, rise, 0])) @ R4(rot((0, 0, 1), roll) @ rot((1, 0, 0), pitch) @ np.diag([br, br, 1.0])) @ T4(-c)
    Bi = np.linalg.inv(B); M = [B]
    # neck and head: up and looking about, or down to graze / peck with the muzzle just clear of the grass
    chest, piv, nose = (np.array(rig[q], float) for q in ("chest", "head", "nose"))
    thrust = ((g * 2) % 1.0 - 0.5) * 0.24 * st if bird else 0.0
    up_at = piv + np.array([0, p.get("look", 0.0) * ry * 0.1 * (1 - down), -thrust])
    ang = GRAZE_PITCH * e_head + (0.05 * p.get("jaw", 0.0) * min(down, 1.0) if nat else 0.0)
    Rh = rot((1, 0, 0), ang)                                              # about the side axis: nose goes down
    nv = Rh @ (nose - piv); nlen = np.linalg.norm(piv - chest)
    graze_world = np.array([0.0, NOSE_CLEAR - (GRAZE_PITCH and (rot((1, 0, 0), GRAZE_PITCH) @ (nose - piv))[1]), chest[2] + min(nlen * 0.8, 1.0 * rz)])
    graze_at = (Bi @ np.append(graze_world, 1))[:3]
    if nat:
        v0, v1 = up_at - chest, graze_at - chest; a0, a1 = math.atan2(v0[1], v0[2]), math.atan2(v1[1], v1[2])
        a_ = a0 + (a1 - a0) * down; L_ = np.linalg.norm(v0) + (np.linalg.norm(v1) - np.linalg.norm(v0)) * down
        head_at = chest + L_ * np.array([0.0, math.sin(a_), math.cos(a_)]) + np.array([0, p.get("jaw", 0.0) * 0.035, 0])
    else:
        head_at = up_at + (graze_at - up_at) * down + np.array([0, p.get("jaw", 0.0) * 0.035, 0])
    yaw = p.get("look", 0.0) * 0.35 * (1 - min(down, 1.0) * 0.7)
    if nat and not bird:                                  # grazing, the head drifts from side to side as it crops
        yaw += 0.13 * math.sin(p.get("time", 0.0) * 2.3) * min(down, 1.0)
    M.append(B @ seg(chest, piv, chest, head_at))
    M.append(B @ T4(head_at) @ R4(rot((0, 1, 0), yaw) @ Rh) @ T4(-piv))
    root = np.array(rig["tail"][0], float)
    M.append(B @ T4(root) @ R4(rot((0, 0, 1), p.get("tail", 0.0) * 0.8)) @ T4(-root))
    # legs: the feet stay planted on the ground whatever the body does above them
    reach, lift = (0.9 * leg, 0.45 * leg) if bird else (STRIDE * leg, LIFT * leg)
    for l in rig["legs"]:
        H, K, F = (np.array(l[q], float) for q in ("hip", "knee", "foot"))
        ph = (BIRD_PHASE if bird else QUAD_PHASE)[l["name"]]
        fwd, up = foot_offset((g + ph) % 1.0, reach, lift); fwd *= st; up *= st
        hg = (B @ np.append(H, 1))[:3]
        foot_w = np.array([hg[0], F[1] + up + hop * leg * 0.4, hg[2] + (F[2] - H[2]) + fwd])
        foot = (Bi @ np.append(foot_w, 1))[:3]
        a_, b_ = np.linalg.norm(K - H), np.linalg.norm(F - K)
        j = joint(np.array([H[2], H[1]]), np.array([foot[2], foot[1]]), a_, b_, -1.0 if l["fore"] else 1.0)
        knee = np.array([H[0], j[1], j[0]])
        M.append(B @ seg(H, K, H, knee)); M.append(B @ seg(K, F, knee, foot))
    return M


def deform(a, W, M, p=None, rig=None):
    V = a["V"]
    p = p or {}
    if p.get("blink", 0.0) > 0:           # a blink: each eye's drawing closes to a line across its middle
        V = V.copy()
        for s, e, c, up in a["eyes"]:
            V[s:e] -= np.outer((V[s:e] - c) @ up, up) * 0.93 * p["blink"]
    if rig is not None and rig.get("wings"):
        V = V.copy(); ang = 0.2 + math.sin(p.get("time", 0.0) * 60.0) * 0.32
        for idx, piv, sx in rig["wings"]:
            V[idx] = (V[idx] - piv) @ rot((0, 0, 1), sx * ang).T + piv
    Vh = np.c_[V, np.ones(len(V))]; out = np.zeros_like(V); N = np.zeros_like(a["vn"])
    for i, Mi in enumerate(M):
        w = W[:, i:i + 1]
        if not w.any():
            continue
        out += w * (Vh @ Mi.T)[:, :3]; N += w * (a["vn"] @ Mi[:3, :3].T)
    ln = np.linalg.norm(N, axis=1, keepdims=True)
    return out, N / np.maximum(ln, 1e-9)


# ---------------------------------------------------------------- the little film: walk, stop, graze, look up
def script(t, rig):
    """The game's pose values over time for a short show: walk (or hop, or hover), stand and look with a blink, head
    down to graze or peck, head up."""
    bird = rig["kind"] == "bird"
    p = dict(time=t, breath=math.sin(t * 1.6), tail=0.0, look=0.0, jaw=0.0, head=0.0, gait=0.0, stride=0.0, blink=0.0, hop=0.0)
    cyc = 0.62 if bird else 1.15                     # seconds per walk cycle
    if t < 2.6:
        on = float(sstep(0, 0.35, t) * (1 - sstep(2.25, 2.6, t)))
        if rig.get("hop"):
            p["hop"] = max(0.0, math.sin(t / 0.55 * math.tau)) * on; p["stride"] = 0.5 * on; p["gait"] = (t / 0.55) % 1.0
        else:
            p["stride"] = on; p["gait"] = (t / cyc) % 1.0
    elif t < 3.2:
        p["look"] = math.sin((t - 2.6) / 0.6 * math.pi) * 0.8
        p["blink"] = 1.0 if 2.8 <= t < 2.97 else 0.0
    else:
        u = t - 3.2
        if bird:                                     # three quick pecks
            p["head"] = max(0.0, math.sin(u / 0.75 * math.pi)) ** 0.7 if u < 2.25 else 0.0
        else:                                        # down, chew, up
            p["head"] = float(sstep(0, 0.7, u) * (1 - sstep(2.1, 2.7, u)))
            p["jaw"] = math.sin(u * 11) if 0.7 < u < 2.1 else 0.0
    p["tail"] = math.sin(t * 2.4) * 0.35 * (1 if not bird else 0.4)
    return p


class Driver:
    """Feeds the head-down value as the game does (AnimalBehaviour: it moves straight to its target, 3.2 a second
    going down and 5 coming up; birds peck 2.6 times a second), and also through a spring of the kind the game's
    AnimalMotion already uses for its other body motion, so it eases in, overshoots a little and settles."""
    def __init__(self, bird):
        self.bird = bird; self.h = 0.0; self.x = 0.0; self.v = 0.0; self.t = 0.0

    def step(self, t, grazing):
        while self.t < t - 1e-9:
            dt = min(1 / 120.0, t - self.t); self.t += dt
            if grazing(self.t):
                to = (1.0 if math.sin(self.t * 2.6 * math.tau) > 0.35 else 0.15) if self.bird else 1.0
            else:
                to = 0.0
            rate = 3.2 if to > self.h else 5.0
            self.h += max(-rate * dt, min(rate * dt, to - self.h))
            f, z = (4.5, 0.55) if self.bird else (1.35, 0.72)
            w = math.tau * f; self.v += (w * w * (self.h - self.x) - 2 * z * w * self.v) * dt; self.x += self.v * dt
        return self.h, self.x
