"""Flat drawings laid on the skin (the eye and its lid and lashes, blush, mouth), as thin stacked layers."""
import numpy as np
import math


DARK = (0.16, 0.11, 0.09)


class Mesh:
    def __init__(self, V, T, C):
        self.V, self.T, self.C, self.n = [V], [T], [list(C)], len(V)

    def add(self, verts, tris, col):
        verts = np.array(verts); tris = np.array(tris)
        self.V.append(verts); self.T.append(tris + self.n); self.C.append([col] * len(tris)); self.n += len(verts)

    def done(self):
        return np.vstack(self.V), np.vstack(self.T), sum(self.C, [])


def frame(out, fwd_hint):
    up = np.array([0.0, 1.0, 0.0]); up = up - out * (up @ out); up /= np.linalg.norm(up)
    u = np.cross(up, out)
    if u @ fwd_hint < 0:
        u = -u
    return u, up


PROJ = None   # set by the builder: lays a point of a face drawing onto the animal's own surface


def lay(c, u, up, out, a, b, layer):
    p = c + u * a + up * b
    off = 0.012 + 0.008 * layer
    if PROJ is not None:
        q = PROJ(p, out)
        if q is not None:
            return q + out * off
    return p + out * off


def fan(m, c, u, up, out, pts, layer, col):
    P3 = [lay(c, u, up, out, a, b, layer) for a, b in pts]
    cen = np.mean(P3, 0)
    m.add([cen] + P3, [[0, 1 + i, 1 + (i + 1) % len(P3)] for i in range(len(P3))], col)


def strip(m, c, u, up, out, top, bot, layer, col):
    P3 = [lay(c, u, up, out, a, b, layer) for a, b in list(top) + list(bot)]
    n = len(top)
    m.add(P3, [t for i in range(n - 1) for t in ([i, i + 1, n + i], [i + 1, n + i + 1, n + i])], col)


def ell(a, b, cx=0.0, cy=0.0, n=20):
    return [(cx + a * math.cos(2 * math.pi * i / n), cy + b * math.sin(2 * math.pi * i / n)) for i in range(n)]


def eye(m, c, u, up, out, r, lid_col, lashes=True, lid=0.4, pupil=0.8, lash=1.0, iris=(0.2, 0.12, 0.08)):
    a, b = r, r * 1.16
    fan(m, c, u, up, out, ell(a + 0.035, b + 0.035), 0, DARK)
    fan(m, c, u, up, out, ell(a, b), 1, (1, 1, 1))
    pc = (0.1 * r, -0.1 * r)
    fan(m, c, u, up, out, ell(a * pupil, b * pupil * 0.98, *pc), 2, iris)
    fan(m, c, u, up, out, ell(a * pupil * 0.62, b * pupil * 0.62, pc[0], pc[1] - 0.02 * r), 3, (0.07, 0.05, 0.04))
    fan(m, c, u, up, out, ell(0.25 * r, 0.25 * r, pc[0] + 0.27 * r, pc[1] + 0.36 * r, 12), 4, (1, 1, 1))
    fan(m, c, u, up, out, ell(0.1 * r, 0.1 * r, pc[0] - 0.24 * r, pc[1] - 0.32 * r, 10), 4, (1, 1, 1))
    A, B = a + 0.04, b + 0.04
    vl = lambda x: lid * B - 0.12 * B * (x / A) ** 2 - 0.04 * B * (x / A)
    xs = [A * math.cos(math.pi * i / 24) for i in range(25)]
    top = [(x, max(B * math.sqrt(max(0, 1 - (x / A) ** 2)), vl(x))) for x in xs]
    edge = [(x, vl(x)) for x in xs]
    strip(m, c, u, up, out, top, edge, 5, lid_col)
    th = 0.085 * r * (0.75 + 0.25 * lash)
    strip(m, c, u, up, out, [(x, y + th * 0.5) for x, y in edge], [(x, y - th * 0.5) for x, y in edge], 6, DARK)
    if lashes:
        for k, (fx, dx, dy) in enumerate(((-0.98, -0.34, 0.2), (-0.86, -0.3, 0.34), (-0.66, -0.2, 0.4))):
            x = A * fx; y = vl(x); w = 0.07 * r * (0.6 + 0.4 * lash); dx *= lash; dy *= lash
            P3 = [lay(c, u, up, out, x - w, y - w * 0.3, 7), lay(c, u, up, out, x + w, y + w * 0.3, 7),
                  lay(c, u, up, out, x + dx * r, y + dy * r, 7)]
            m.add(P3, [[0, 1, 2]], DARK)
