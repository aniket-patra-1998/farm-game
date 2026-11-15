"""Smoke tests: run from tools/animal_art with  python3 -m unittest discover -s tests"""
import os
import sys
import unittest

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from animal_art.build import lightest, pieces  # noqa: E402
from animal_art.motion import deform, pose  # noqa: E402
from animal_art.registry import GAME, MADE  # noqa: E402
from animal_art.rig import rig_of  # noqa: E402

KINDS = {"cow": "quad", "red chicken": "bird", "turtle": "quad", "bee": "bug"}


class Registry(unittest.TestCase):
    def test_every_game_animal_can_be_built(self):
        missing = [n for names in GAME.values() for n in names if n not in MADE]
        self.assertEqual(missing, [])
        self.assertEqual(sum(len(v) for v in GAME.values()), 73)


class BuildAndMove(unittest.TestCase):
    def test_models_hold_together_bind_and_pose(self):
        for name, kind in KINDS.items():
            with self.subTest(animal=name):
                model = lightest(MADE[name][0])
                self.assertEqual(pieces(model), 1, "the skin is in one piece")
                self.assertEqual(len(model["eyes"]), 2, "two eyes, each able to blink")
                rig, W = rig_of(model, name)
                self.assertEqual(rig["kind"], kind)
                self.assertTrue(np.allclose(W.sum(1), 1.0), "every point's weights add up to one")
                p = dict(gait=0.3, stride=1.0, head=0.7, look=0.3, tail=0.2, blink=1.0, time=0.4)
                V, N = deform(model, W, pose(rig, p), p, rig)
                self.assertTrue(np.isfinite(V).all() and np.isfinite(N).all())

    def test_a_turtle_moves_only_its_legs_head_and_tail(self):
        model = lightest(MADE["turtle"][0])
        rig, W = rig_of(model, "turtle")
        self.assertTrue(rig["shell"])
        p = dict(gait=0.25, stride=1.0)
        V, _n = deform(model, W, pose(rig, p), p, rig)
        still = W[:, 0] >= 1.0 - 1e-9    # points that are wholly shell
        self.assertGreater(still.sum(), 1000, "most of a turtle is shell")
        self.assertTrue(np.allclose(V[still], model["V"][still]), "the shell does not move when the legs do")


if __name__ == "__main__":
    unittest.main()
