"""Measuring a head, so a face can be placed by proportion on any animal: its long axis, its depth along it,
where the muzzle starts, and the spot on its side where an eye belongs."""
import numpy as np
from .geometry import cast


EYE_SIZE = 0.96


LASH = 1.55


# Where the face goes, as shares of the head itself (the same for every animal): the eye sits EYE_T of the way from
# the back of the head to the nose and EYE_S of the way up its side; its size is a share of the head's depth there.
EYE_T, EYE_S, EYE_K = 0.36, 0.66, 0.151


MOUTH = [(0.95, 0.26), (0.89, 0.21), (0.82, 0.22), (0.76, 0.29), (0.72, 0.4)]


class Head:
    """The head's own measure: its long axis runs from the middle of the head to the tip of the nose (the point
    furthest forward), so a face can be placed by proportion on any animal: a level cow's head, a horse's sloping
    one, a pig's deep one. Ears that stick out sideways are left out of the measure."""

    def __init__(self, V, T, wh, pivot):
        hv = V[wh > 0.5]
        self.half = np.percentile(np.abs(hv[:, 0]), 60)
        hv = hv[np.abs(hv[:, 0]) < self.half * 1.6]
        P2 = hv[:, [2, 1]]
        tip = P2[P2[:, 0] > np.percentile(P2[:, 0], 96)].mean(0)
        mu = P2.mean(0); d = tip - mu; d = d / np.linalg.norm(d)
        e = np.array([-d[1], d[0]])
        if e[1] < 0:
            e = -e
        pr = (P2 - mu) @ d
        self.mu, self.d, self.e, self.pr, self.ps = mu, d, e, pr, (P2 - mu) @ e
        self.lo, self.hi = np.percentile(pr, 3), (tip - mu) @ d
        self.d3 = np.array([0.0, d[1], d[0]]); self.e3 = np.array([0.0, e[1], e[0]])

    def span(self, t):
        """The head's lower and upper edge at a point along it. Read from the head's points near there; where those
        are too few to trust (a head half sunk in a neck or under fleece leaves gaps), from a wider stretch, and
        failing that from the whole head, so a sparse patch can never make the head look thin."""
        whole = np.percentile(self.ps, 3), np.percentile(self.ps, 97); need = 0.75 * (whole[1] - whole[0])
        x = self.lo + t * (self.hi - self.lo)
        for wdt in (0.12, 0.3):
            m = np.abs(self.pr - x) < wdt * (self.hi - self.lo)
            if m.sum() >= 4:
                a, b = np.percentile(self.ps[m], 3), np.percentile(self.ps[m], 97)
                if b - a >= need:
                    return a, b
        return whole

    def at(self, t, s):
        a, b = self.span(t); q = self.mu + self.d * (self.lo + t * (self.hi - self.lo)) + self.e * (a + s * (b - a))
        return q[1], q[0]                                                  # (y, z)

    def depth(self, t):
        a, b = self.span(t); return b - a

    def stop(self):
        """Where the skull ends and the muzzle begins, as a share of the head's length: the first place the head's
        depth falls clearly below the skull's (on a wedge-shaped head that is simply part-way down the wedge)."""
        ts = np.arange(0.1, 0.96, 0.05); d = np.array([self.depth(t) for t in ts])
        top = d[ts <= 0.6].max()
        for i in range(1, len(ts)):
            if ts[i] >= 0.25 and d[i] < STOP_DROP * top:
                f = (d[i - 1] - STOP_DROP * top) / max(d[i - 1] - d[i], 1e-9)
                return float(ts[i - 1] + np.clip(f, 0, 1) * 0.05)
        return 1.0

    def eye_t(self):
        return float(np.clip(EYE_BEHIND_STOP * self.stop(), 0.3, 0.6))


def side_hit(V, T, hd, sx, t, s, Th=None):
    """The point on the side of the head at (t along it, s up it). With `Th` (the head's own triangles) the point is
    taken on the head itself, and refused when something else stands in front of it there (an ear, wool, a horn),
    so a face is never drawn underneath fleece."""
    y, z = hd.at(t, s)
    org, d = np.array([sx * 12.0, y, z]), np.array([-float(sx), 0.0, 0.0])
    p, out, k = cast(V, T if Th is None else Th, org, d)
    if p is None or abs(out[0]) < 0.4 or abs(p[0]) > hd.half * 1.6 or p[0] * sx <= 0:
        return None
    if Th is not None:
        q, _n, _k = cast(V, T, org, d)
        if q is not None and abs(q[0]) > abs(p[0]) + 0.05:
            return None
        k = int(np.where((T == Th[k]).all(1))[0][0])
    return p, out, k


STOP_DROP = 0.72        # the muzzle starts where the head is this share of the skull's depth


EYE_BEHIND_STOP = 0.8   # the eye sits this share of the way from the back of the head to that point


EYE_FACING = 0.38   # an eye must look out sideways: where the head's side tilts skyward more than this, it moves down


def find_eye(V, T, hd, sx, t0=None, Th=None, s0=None):
    """The eye's spot by proportion of the head. Two things can move it: if the spot lands on nothing sound (an ear,
    a gap) it goes to the nearest spot that does, and on a round skull, where that high up the surface already
    faces the sky, it comes down to where the side faces outward (so it never rides up onto the top of the head)."""
    t0 = EYE_T if t0 is None else t0
    best, loose = None, None
    for dt in (0, 0.05, -0.05, 0.1, -0.1, 0.15):
        for ds in (0, -0.06, -0.12, -0.18, -0.24, -0.3, 0.08, 0.16):
            h = side_hit(V, T, hd, sx, t0 + dt, (EYE_S if s0 is None else s0) + ds, Th)
            if h is None:
                continue
            cost = abs(dt) + abs(ds)
            if loose is None or cost < loose[0]:
                loose = (cost, h)
            if h[1][1] <= EYE_FACING and (best is None or cost < best[0]):
                best = (cost, h)
    pick = best or loose
    return None if pick is None else pick[1]
