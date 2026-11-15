"""Small geometry helpers: hard parts (cone, bar, ring, ball), ray casting onto a mesh, normals, the camera turn, colours."""
import numpy as np
import math


def cone(a, b, r, n=10):
    a, b = np.array(a, float), np.array(b, float); d = b - a; d /= np.linalg.norm(d)
    u = np.cross(d, [0, 1, 0] if abs(d[1]) < 0.9 else [1, 0, 0]); u /= np.linalg.norm(u); w = np.cross(d, u)
    ring = [a + r * (math.cos(2 * math.pi * i / n) * u + math.sin(2 * math.pi * i / n) * w) for i in range(n)]
    return np.array(ring + [b, a]), np.array([[i, (i + 1) % n, n] for i in range(n)] + [[(i + 1) % n, i, n + 1] for i in range(n)])


def tube(a, b, ra, rb, n=8):
    """A straight round bar that can narrow: legs of birds, long horns."""
    a, b = np.array(a, float), np.array(b, float); d = b - a; d /= np.linalg.norm(d)
    u = np.cross(d, [0, 1, 0] if abs(d[1]) < 0.9 else [1, 0, 0]); u /= np.linalg.norm(u); w = np.cross(d, u)
    ring = lambda c, r: [c + r * (math.cos(2 * math.pi * i / n) * u + math.sin(2 * math.pi * i / n) * w) for i in range(n)]
    T = []
    for i in range(n):
        j = (i + 1) % n
        T += [[i, j, n + i], [j, n + j, n + i], [j, i, 2 * n], [n + i, n + j, 2 * n + 1]]
    return np.array(ring(a, ra) + ring(b, rb) + [a, b]), np.array(T)


def torus(c, R, r, n=14, k=6):
    vs, ts = [], []
    for i in range(n):
        a = 2 * math.pi * i / n
        for j in range(k):
            bb = 2 * math.pi * j / k
            vs.append([c[0] + (R + r * math.cos(bb)) * math.cos(a), c[1] + (R + r * math.cos(bb)) * math.sin(a), c[2] + r * math.sin(bb)])
    for i in range(n):
        for j in range(k):
            a0, a1, b0, b1 = i * k + j, i * k + (j + 1) % k, ((i + 1) % n) * k + j, ((i + 1) % n) * k + (j + 1) % k
            ts += [[a0, b0, a1], [a1, b0, b1]]
    return np.array(vs), np.array(ts)


def hx(h):
    h = h.lstrip("#"); return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def cast(V, T, org, d):
    a, b, c = V[T[:, 0]], V[T[:, 1]], V[T[:, 2]]
    e1, e2 = b - a, c - a
    h = np.cross(np.broadcast_to(d, e2.shape), e2); det = (e1 * h).sum(1)
    ok = np.abs(det) > 1e-9; inv = np.where(ok, 1 / np.where(ok, det, 1), 0)
    sv = org - a; u = (sv * h).sum(1) * inv
    q = np.cross(sv, e1); v = (q * d).sum(1) * inv; t = (e2 * q).sum(1) * inv
    hit = ok & (u >= 0) & (v >= 0) & (u + v <= 1) & (t > 0)
    if not hit.any():
        return None, None, -1
    k = np.where(hit)[0][np.argmin(t[hit])]
    n = np.cross(e1[k], e2[k]); n = n / np.linalg.norm(n)
    if n @ d > 0:
        n = -n
    return org + d * t[k], n, k


def vnormals(V, T):
    n = np.cross(V[T[:, 1]] - V[T[:, 0]], V[T[:, 2]] - V[T[:, 0]])
    out = np.zeros_like(V)
    for k in range(3):
        np.add.at(out, T[:, k], n)
    return out / np.maximum(np.linalg.norm(out, axis=1, keepdims=True), 1e-9)


def view_rot(yaw, pitch):
    cy, sy, cp, sp = math.cos(yaw), math.sin(yaw), math.cos(pitch), math.sin(pitch)
    Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    Rx = np.array([[1, 0, 0], [0, cp, -sp], [0, sp, cp]])
    return Rx @ Ry


def sphere(center, radii, basis=None, n=10):
    vs, ts = [], []
    for i in range(n + 1):
        th = math.pi * i / n
        for j in range(2 * n):
            ph = math.pi * j / n
            vs.append([math.sin(th) * math.cos(ph), math.cos(th), math.sin(th) * math.sin(ph)])
    for i in range(n):
        for j in range(2 * n):
            a = i * 2 * n + j; b = i * 2 * n + (j + 1) % (2 * n); c2 = a + 2 * n; d = b + 2 * n
            ts += [[a, b, c2], [b, d, c2]]
    vs = np.array(vs) * np.array(radii)
    if basis is not None:
        vs = vs @ np.array(basis)
    return vs + np.array(center), np.array(ts)
