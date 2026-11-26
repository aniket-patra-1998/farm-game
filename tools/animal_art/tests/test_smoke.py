"""Smoke tests: run from tools/animal_art with  python3 -m unittest discover -s tests"""
import os
import sys
import unittest

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from animal_art.build import lightest, pieces  # noqa: E402
from animal_art.motion import deform, pose  # noqa: E402
from animal_art import limited  # noqa: E402
from animal_art.registry import GAME, MADE  # noqa: E402
from animal_art.rig import rig_of  # noqa: E402

KINDS = {"cow": "quad", "red chicken": "bird", "turtle": "quad", "bee": "bug"}


class Registry(unittest.TestCase):
    def test_every_game_animal_can_be_built(self):
        missing = [n for names in GAME.values() for n in names if n not in MADE]
        self.assertEqual(missing, [])
        self.assertEqual(sum(len(v) for v in GAME.values()), 73 + sum(len(v) for v in limited.GAME.values()))


class Limited(unittest.TestCase):
    def test_limited_coats_hold_together_and_carry_their_pattern(self):
        for name in ("highland cow", "woolly pig", "galaxy alpaca", "silkie chicken", "golden lamb", "sunset rabbit"):
            with self.subTest(animal=name):
                model = lightest(MADE[name][0])
                self.assertEqual(pieces(model), 1, "fur and tufts are part of the one skin")
                self.assertEqual(len(model["eyes"]), 2)
        stars = np.array(lightest(MADE["galaxy alpaca"][0])["C"])
        self.assertTrue((np.abs(stars - np.array([1.0, 0.914, 0.659])).max(axis=1) < 0.02).any(), "a fluffy coat carries its stars")
        self.assertGreater(len(np.unique(np.round(np.array(lightest(MADE["rainbow pig"][0])["C"]), 2), axis=0)), 12,
                           "a rainbow coat runs through many colours")

    def test_every_limited_family_animal_has_its_baby(self):
        for family, word in limited.BABY_WORDS.items():
            for name in limited.ROWS[family]:
                self.assertIn(limited.baby_name(name, word), MADE)
        self.assertEqual(limited.baby_name("golden ram", "lamb"), "golden lamb")


class Eyes(unittest.TestCase):
    def test_an_eye_on_a_dark_face_has_a_pale_rim(self):
        # (a dark eye on a dark face is lost from the farm's distance: there the rim is pale and the iris amber)
        from animal_art import decal
        rim = np.array(decal.PALE_RIM)
        for name, light in (("tuxedo goose", True), ("sheep", True), ("pig", False), ("rainbow pig", False)):
            with self.subTest(animal=name):
                colours = np.array(lightest(MADE[name][0])["C"])
                self.assertEqual(bool((np.abs(colours - rim).max(axis=1) < 1e-3).any()), light)


class Sleep(unittest.TestCase):
    def test_each_family_sleeps_its_own_way(self):
        # (owner, 20 Nov: not every animal with its head hung low, and never a water bird's head in the water:
        # docs/ANIMAL_SLEEP.md has how each sleeps and where that was read)
        from animal_art.registry import sleep_of
        ways = {"cow": "lie", "sheep": "lie", "goat": "lie", "llama": "kush", "horse": "stand", "donkey": "stand",
                "pig": "side", "rabbit": "loaf", "chicken": "roost", "turkey": "roost", "duck": "tuck", "swan": "tuck",
                "goose": "tuck", "turtle": "shell", "galaxy cow": "lie", "rainbow duck": "tuck"}
        for name, way in ways.items():
            with self.subTest(animal=name):
                model = lightest(MADE[name][0]); rig, W = rig_of(model, name)
                self.assertEqual(rig["sleep"], way); self.assertEqual(sleep_of(name, rig), way)
                rest, _n = deform(model, W, pose(rig, {}), {}, rig)
                p = dict(sleep=1.0); V, _n = deform(model, W, pose(rig, p), p, rig)
                self.assertTrue(np.isfinite(V).all())
                top0, top1 = rest[:, 1].max(), V[:, 1].max()
                nose0 = np.array(rig["nose"], float); nose1 = (pose(rig, p)[2] @ np.append(nose0, 1.0))[:3]
                if way in ("lie", "kush", "side", "loaf", "roost"):
                    self.assertLess(top1, top0 * 0.93, "it is down on the ground")
                if way in ("stand", "tuck"):
                    body = model["V"][W[:, 0] > 0.9]
                    self.assertLess(abs((V[W[:, 0] > 0.9][:, 1] - body[:, 1]).mean()), 0.03 * top0, "it stays on its feet")
                if way in ("tuck", "roost"):
                    self.assertLess(nose1[2], nose0[2] - 0.3 * rig["r"][2], "its bill is turned back onto its back")
                    self.assertGreater(nose1[1], rig["body"][1], "and is above its body: never down in the water")
                if way == "stand":
                    self.assertLess(nose1[1], nose0[1], "its head hangs")
                    self.assertGreater(nose1[1], 0.3 * nose0[1], "but nowhere near the ground")
                # half asleep is half way there, as the game's blend shape is
                half = dict(sleep=0.5); H, _n = deform(model, W, pose(rig, half), half, rig)
                self.assertTrue(np.allclose(H, (rest + V) / 2, atol=1e-6) or way == "loaf")

    def test_a_bee_has_no_sleeping_pose(self):
        from animal_art.export import moves
        model = lightest(MADE["bee"][0]); rig, _W = rig_of(model, "bee")
        self.assertIn("sleep", [m[0] for m in moves()])
        self.assertFalse(rig["legs"] or rig.get("shell"), "(the export leaves its sleep move out)")


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



class Bones(unittest.TestCase):
    def test_a_file_s_bones_make_every_move_the_builder_s_motion_makes(self):
        # (export._rigged: a move is where each bone goes, never a second copy of the mesh; the bones must put every
        # point where motion.deform does, for each move alone, the parts that move on their own included.)
        from animal_art import export as E
        for name in ("cow", "red chicken", "rabbit", "turkey", "bee", "turtle"):
            with self.subTest(animal=name):
                a = lightest(MADE[name][0]); rig, W = rig_of(a, name)
                V0, _ = deform(a, W, pose(rig, E._rest()), E._rest(), rig)
                Wn, rest, changes = E._rigged(a, rig, W, V0)
                names = [m for m, _c in changes]
                self.assertLess(np.abs(E.posed(a, Wn, rest, changes, {}) - V0).max(), 1e-9)
                for m, p in E.moves():
                    if m in names:
                        V, _ = deform(a, W, pose(rig, p), p, rig)
                        self.assertLess(np.abs(E.posed(a, Wn, rest, changes, {m: 1.0}) - V).max(), 1e-9, m)
                self.assertIn("blink", names)
                self.assertEqual(len([m for m in names if m.startswith("walk_")]), E.WALK_FRAMES)
                # (the game reads four bones a point: what is left out is a sliver of the weight)
                self.assertLess((1.0 - np.sort(Wn, 1)[:, -E.BONES_EACH:].sum(1)).max(), 0.12)
        self.assertIn("display", [m for m, _c in E._rigged(*self._turkey())[2]])

    def test_the_farmer_s_bones_make_its_moves(self):
        from animal_art import farmer as F
        from animal_art.export import posed
        a = F.build("short", "a"); Wn, rest, changes = F.rigged(a)
        tall = a["V"][:, 1].max() - a["V"][:, 1].min()
        self.assertAlmostEqual(float(np.abs(Wn.sum(1) - 1.0).max()), 0.0, places=9)
        for m, V in F.moves(a).items():   # (a limb's joint is held in F.RAMP steps: to a thousandth of its height)
            self.assertLess(np.abs(posed(a, Wn, rest, changes, {m: 1.0}) - V).max() / tall, 0.002, m)

    def _turkey(self):
        from animal_art import export as E
        a = lightest(MADE["turkey"][0]); rig, W = rig_of(a, "turkey")
        return a, rig, W, deform(a, W, pose(rig, E._rest()), E._rest(), rig)[0]


if __name__ == "__main__":
    unittest.main()
