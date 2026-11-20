"""Every animal by name: each family's breeds, their babies (one rule per family), and the game's own names."""
from .families.bird import BIRDS, bird_t
from .families.camelid import CAMELIDS, camelid
from .families.cow import COWS, cow
from .families.dog import DOGS, dog
from .families.goat import GOATS, goat_t
from .families.horse import HORSES, horse
from .families.pig import PIGS, pig
from .families.sheep import SHEEP, sheep
from .families.small import bee, rabbit, turtle


from . import limited
from .paint import repaint

MADE = {"rabbit": (rabbit, 0.29), "turtle": (turtle, 0.34), "bee": (bee, 0.2),
        }


for _n, _b in BIRDS.items():
    MADE[_n] = ((lambda bb=_b: bird_t(bb)), _b["rel"])


def young(b, legs=0.66, body=0.76, muzzle=0.68, skull=1.13, tail=0.6, rel=0.6, **more):
    """The baby of any breed, by one rule per family: smaller, with a shorter rounder body, a big head with a short
    muzzle, big eyes and a short tail; how long its legs are is the family's (a puppy's are short, a foal's long).
    Everything else (ears, coat, fur) is the breed's own."""
    y = dict(b); rx, ry, rz = b["body"]; mw, mh, ml = b["muzzle"]
    y.update(body=(rx * 0.97, ry * 0.97, rz * body), legs=b["legs"] * legs, leg_r=b["leg_r"] * 1.12,
             skull=tuple(v * skull for v in b["skull"]), muzzle=(mw * 1.02, mh * 1.02, ml * muzzle), neck=b["neck"] * 1.05,
             tail_len=tail, eye=1.22, rel=b["rel"] * rel)
    for k, f in more.items():
        y[k] = b[k] * f
    return y


for _n, _b in DOGS.items():
    MADE[_n] = ((lambda bb=_b: dog(bb)), _b["rel"])
    _y = young(_b)
    MADE[_n + " pup"] = ((lambda bb=_y: dog(bb)), _y["rel"])


def _cria(b):
    return young(b, legs=0.9, body=0.76, muzzle=0.8, skull=1.1, tail=0.9, rel=0.58, neck_len=0.72)


for _n, _b in CAMELIDS.items():
    MADE[_n] = ((lambda bb=_b: camelid(bb)), _b["rel"])
    _y = _cria(_b)
    MADE["baby " + _n] = ((lambda bb=_y: camelid(bb)), _y["rel"])


def _kid(b):
    y = young(b, legs=0.9, body=0.74, muzzle=0.8, skull=1.1, tail=0.9, rel=0.55)
    y.update(horns=0.0, beard=0.0)
    return y


for _n, _b in GOATS.items():
    MADE[_n] = ((lambda bb=_b: goat_t(bb)), _b["rel"])
    _y = _kid(_b)
    MADE["kid of " + _n] = ((lambda bb=_y: goat_t(bb)), _y["rel"])


def _lamb(b):
    y = young(b, legs=0.92, body=0.74, muzzle=0.8, skull=1.1, tail=0.8, rel=0.55)
    y.update(horns=False, wool=b["wool"] * 0.85)
    return y


for _n, _b in SHEEP.items():
    MADE[_n] = ((lambda bb=_b: sheep(bb)), _b["rel"])
    _y = _lamb(_b)
    MADE["lamb of " + _n] = ((lambda bb=_y: sheep(bb)), _y["rel"])


_y = young(SHEEP["sheep"], legs=0.92, body=0.74, muzzle=0.8, skull=1.1, tail=0.8, rel=0.55)


_y.update(horns=False, wool=0.85, coat="fbf6ec", face="d9cfc0", legs_col="d9cfc0")


MADE["lamb"] = ((lambda bb=_y: sheep(bb)), _y["rel"])


def _piglet(b):
    y = young(b, legs=0.82, body=0.76, muzzle=0.78, skull=1.12, tail=0.8, rel=0.5)
    y.update(seed=8)
    return y


for _n, _b in PIGS.items():
    MADE[_n] = ((lambda bb=_b: pig(bb)), _b["rel"])
    _y = _piglet(_b)
    MADE[_n.replace(" pig", "") + " piglet"] = ((lambda bb=_y: pig(bb)), _y["rel"])


_y = young(PIGS["pink pig"], legs=0.82, body=0.76, muzzle=0.78, skull=1.12, tail=0.8, rel=0.5)


_y.update(coat="f9c8ca", coat2="e79aa0")


MADE["piglet"] = ((lambda bb=_y: pig(bb)), _y["rel"])


def _calf(b):
    y = young(b, legs=0.86, body=0.72, muzzle=0.82, skull=1.1, tail=0.7, rel=0.6)
    y.update(horns="none", udder=False, hump=0.0, seed=b.get("seed", 1) + 3)
    return y


for _n, _b in COWS.items():
    MADE[_n] = ((lambda bb=_b: cow(bb)), _b["rel"])
    if _n not in ("bull", "ox"):
        _y = _calf(_b)
        MADE[_n.replace(" cow", "") + " calf"] = ((lambda bb=_y: cow(bb)), _y["rel"])


def _foal(b):
    y = young(b, legs=0.9, body=0.7, muzzle=0.78, skull=1.08, tail=0.55, rel=0.62, mane=0.45)
    y.update(seed=5)
    return y


for _n, _b in HORSES.items():
    MADE[_n] = ((lambda bb=_b: horse(bb)), _b["rel"])
    if _n != "donkey":
        _y = _foal(_b)
        MADE[_n + " foal"] = ((lambda bb=_y: horse(bb)), _y["rel"])


# limited coats (limited.py): each a row of its family, made as the family makes its breeds and then painted, with its
# baby by the family's rule
def _made(fn, row):
    """A limited animal's maker: the family's template on its row, then the pattern and tufts the row asks for."""
    def make():
        shapes, hard, face = fn(row)
        return repaint(shapes, row), hard, face
    return make


LIMITED = {}   # a limited animal's name -> its row (the export reads its touch and its coat from it)
for _rows, _fn, _baby, _word in ((limited.COWS, cow, _calf, "calf"), (limited.HORSES, horse, _foal, "foal"), (limited.PIGS, pig, _piglet, "piglet"),
                                 (limited.SHEEP, sheep, _lamb, "lamb"), (limited.GOATS, goat_t, _kid, "kid"),
                                 (limited.CAMELIDS, camelid, _cria, "cria"), (limited.BIRDS, bird_t, None, "")):
    for _n, _b in _rows.items():
        MADE[_n] = (_made(_fn, _b), _b["rel"])
        LIMITED[_n] = _b
        if _baby:
            _y = _baby(_b)
            MADE[limited.baby_name(_n, _word)] = (_made(_fn, _y), _y["rel"])
            LIMITED[limited.baby_name(_n, _word)] = _y
for _n, _b in limited.RABBITS.items():
    MADE[_n] = (_made((lambda row: rabbit(row["coat"], row["pale"])), _b), 0.29)
    LIMITED[_n] = _b


# the game's own names for animals built under a longer name here
for _a, _n in (("cow", "dairy cow"), ("calf", "dairy calf"), ("pig", "pink pig"), ("foal", "horse foal"), ("gray foal", "gray horse foal"),
               ("stallion", "white stallion")):
    if _n in MADE:
        MADE[_a] = MADE[_n]


# ---------------------------------------------------------------- what the game has, and what is parked
GAME = {
    "cow": ["cow", "brown cow", "pink cow", "jersey cow", "longhorn", "hereford cow", "gelbvieh cow", "galician blond cow", "red cow",
            "belted cow", "bull", "calf", "brown calf", "pink calf", "jersey calf", "longhorn calf", "hereford calf", "gelbvieh calf",
            "galician blond calf", "red calf", "belted calf"],
    "ox": ["ox"],
    "horse": ["horse", "pony", "stallion", "gray horse", "black pony", "mustang", "foal", "gray foal", "mustang foal"],
    "donkey": ["donkey"],
    "pig": ["pig", "berkshire pig", "tamworth pig", "spotted pig", "kunekune pig", "boar", "saddleback pig", "piglet"],
    "sheep": ["sheep", "ram", "black sheep", "mouflon sheep", "lamb"],
    "goat": ["goat", "boer goat", "arapawa goat"],
    "camelid": ["llama", "alpaca"],
    "dog": ["indie dog", "brown dog", "spotted dog", "black lab", "golden retriever"],
    "chicken": ["chicken", "brown chicken", "red chicken", "grey chicken", "black chicken", "golden chicken", "cornish chicken"],
    "turkey": ["turkey", "wild turkey", "baby turkey"],
    "duck": ["duck", "belted duck", "swan", "ugly duckling"],
    "goose": ["goose"],
    "rabbit": ["rabbit"],
    "turtle": ["turtle"],
    "bee": ["bee"],
}
for _k, _names in limited.GAME.items():
    GAME[_k] = GAME[_k] + _names
_IN_GAME = {n for names in GAME.values() for n in names} | {"dairy cow", "dairy calf", "pink pig", "pink piglet", "horse foal", "gray horse foal",
                                                            "white stallion"}
PARKED = sorted(n for n in MADE if n not in _IN_GAME)      # built, but not in the game: optional additions
