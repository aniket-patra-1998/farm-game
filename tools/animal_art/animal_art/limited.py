"""Limited coats: new varieties of the families' own animals, each a row made from one of the family's breeds with a
new coat, a painted pattern (paint.py) or more or less fur. The registry gives each its baby by the family's rule.
In the game these are the limited animals (data/catalog/animals.json, "limited")."""
from .families.bird import BIRDS as _BIRDS
from .families.camelid import CAMELIDS as _CAMELIDS
from .families.cow import COWS as _COWS
from .families.goat import GOATS as _GOATS
from .families.horse import HORSES as _HORSES
from .families.pig import PIGS as _PIGS
from .families.sheep import SHEEP as _SHEEP

PASTEL = ["f7a8b8", "f9d08a", "f6ef9a", "a8e0a8", "9ac8f0", "c0a8e8"]
SUNSET = ["f7c84a", "f79a5a", "f0708a", "b060b0"]
STARS = dict(kind="stars", c2="ffe9a8", c3="7a3aa8")

_COW = _COWS["red cow"]
COWS = {
    "strawberry cow": dict(_COW, coat="f9c4d2", coat2="e8456b", pattern="spots", seed=4, tuft="e8456b"),
    "highland cow": dict(_COW, coat="c8742e", coat2="8a4a1c", fur="shaggy", horns="long", leg_r=0.32, body=(1.06, 1.06, 1.7), udder=False),
    "galaxy cow": dict(_COW, coat="2a2a6e", coat2="7a3aa8", tuft="ffe9a8", muzzle_col="c9b8e8", paint=dict(STARS, seed=3)),
    "tiger cow": dict(_COW, coat="f2a23a", coat2="3a2418", muzzle_col="f6ead8", paint=dict(kind="stripes", c2="3a2418")),
    "panda cow": dict(_COW, coat="f6f2ea", coat2="2b2624", pattern="panda"),
    "rainbow cow": dict(_COW, coat="f7a8b8", coat2="fff6e0", muzzle_col="fff6e0", paint=dict(kind="rainbow", hues=PASTEL)),
}
HORSES = {
    "candy horse": dict(_HORSES["white stallion"], coat="f7b5d0", points="6ac8f0"),
    "zebra horse": dict(_HORSES["horse"], coat="f6f2ea", points="2b2624", dark_legs=False, paint=dict(kind="stripes", c2="2b2624")),
    "galaxy horse": dict(_HORSES["horse"], coat="2a2a6e", points="c9a8ff", dark_legs=False, mane=1.2, tail=1.3, paint=dict(STARS, seed=2)),
    "dapple horse": dict(_HORSES["gray horse"], coat="f6f2ea", points="4a4a52", dark_legs=False, paint=dict(kind="dots", c2="8a8a94", seed=5, n=34)),
    "feather horse": dict(_HORSES["draft horse"], coat="2b2624", points="f6f2ea", mane=1.5, tail=1.45),
}
PIGS = {
    "blueberry pig": dict(_PIGS["pink pig"], coat="8f9be8", coat2="6a74c8", paint=dict(kind="dots", c2="4a54a8", seed=3)),
    "bumblebee pig": dict(_PIGS["pink pig"], coat="f8d030", coat2="d9a520", paint=dict(kind="stripes", c2="2b2624", f=7.0)),
    "woolly pig": dict(_PIGS["pink pig"], coat="efe2c8", coat2="d9c4a0", ears="up", tufts=1),
    "rainbow pig": dict(_PIGS["pink pig"], coat="f7a8b8", coat2="e79aa0", paint=dict(kind="rainbow", hues=PASTEL)),
    "golden pig": dict(_PIGS["pink pig"], coat="f2c230", coat2="d99a1c", paint=dict(kind="dip", c2="e08a1c")),
}
SHEEP = {
    "cloud sheep": dict(_SHEEP["woolly sheep"], wool=1.5, coat="f4f8ff", paint=dict(kind="dip", c2="9ad0f5")),
    "shorn sheep": dict(_SHEEP["sheep"], wool=0.3, coat="f6e6da"),
    "cotton candy sheep": dict(_SHEEP["woolly sheep"], coat="f9b8d4", face="fbe3ea", legs_col="f9b8d4", paint=dict(kind="patches", c2="9ad4f5", seed=2)),
    "rainbow sheep": dict(_SHEEP["sheep"], coat="f7a8b8", paint=dict(kind="rainbow", hues=PASTEL)),
    "golden ram": dict(_SHEEP["ram"], coat="f2c230", face="3a2a20", legs_col="3a2a20", paint=dict(kind="dip", c2="e0a01c")),
}
GOATS = {
    "angora goat": dict(_GOATS["billy goat"], horns=0.9, beard=0.7, ears="droop", coat="f8f4ea", coat2="e6dcc8", tufts=1),
    "lavender goat": dict(_GOATS["goat"], coat="c0a8e8", coat2="6a4aa8"),
    "dalmatian goat": dict(_GOATS["goat"], coat="f6f2ea", coat2="3a2f27", paint=dict(kind="dots", c2="3a2f27", seed=4)),
    "sunset goat": dict(_GOATS["goat"], coat="f79a5a", coat2="8a3a5a", paint=dict(kind="rainbow", hues=SUNSET)),
    "tuxedo goat": dict(_GOATS["goat"], coat="2b2624", coat2="f6f2ea", paint=dict(kind="band", c2="f6f2ea")),
}
CAMELIDS = {
    "cotton candy alpaca": dict(_CAMELIDS["alpaca"], coat="f9b8d4", coat2="f9b8d4"),
    "mint alpaca": dict(_CAMELIDS["alpaca"], coat="a8e6cf", coat2="a8e6cf", paint=dict(kind="patches", c2="f6f2ea", seed=3)),
    "galaxy alpaca": dict(_CAMELIDS["alpaca"], coat="2a2a6e", coat2="2a2a6e", paint=dict(STARS, seed=4)),
    "rainbow llama": dict(_CAMELIDS["llama"], coat="f7a8b8", coat2="f7a8b8", pattern="solid", paint=dict(kind="rainbow", hues=PASTEL)),
    "cocoa llama": dict(_CAMELIDS["brown llama"], coat="4a2e20", coat2="f3d9a8", paint=dict(kind="dots", c2="e0a860", seed=6)),
}
CHICKENS = {
    "silkie chicken": dict(_BIRDS["chicken"], feathers=0.5, tufts=1),
    "peacock chicken": dict(_BIRDS["chicken"], coat="1f8a8a", wing="2a5ad0", tail_col="2fbf71", tail_k=1.4),
    "flame chicken": dict(_BIRDS["chicken"], coat="e0452a", wing="f08a2a", tail_col="f8d030", paint=dict(kind="dip", c2="f8c030")),
    "bubblegum chicken": dict(_BIRDS["grey chicken"], coat="f9b8d4", coat2="e06aa0", tail_col="c04a88"),
    "galaxy chicken": dict(_BIRDS["chicken"], coat="2a2a6e", wing="3a2a8a", tail_col="7a3aa8", paint=dict(STARS, seed=7, n=22)),
}
DUCKS = {
    "rubber duck": dict(_BIRDS["duck"], coat="f8d030", wing="f0c020"),
    "mandarin duck": dict(_BIRDS["duck"], coat="d9702a", wing="3a5ad0", paint=dict(kind="dip", c2="7a3a8a")),
    "rainbow duck": dict(_BIRDS["duck"], coat="f7a8b8", wing="9ac8f0", paint=dict(kind="rainbow", hues=PASTEL)),
    "mint duck": dict(_BIRDS["duck"], coat="a8e6cf", wing="7ad0b0"),
    "galaxy duck": dict(_BIRDS["duck"], coat="2a2a6e", wing="3a2a8a", paint=dict(STARS, seed=8, n=22)),
}
TURKEYS = {
    "peacock turkey": dict(_BIRDS["turkey"], coat="1f6fa8", wing="1f8a8a", fan_tip="2fbf71", head_col="2a5ad0"),
    "royal turkey": dict(_BIRDS["turkey"], coat="f6f2ea", wing="ece8dc", fan_tip="f2c230"),
    "autumn turkey": dict(_BIRDS["turkey"], coat="c8642a", wing="a8401e", fan_tip="f8d030", paint=dict(kind="dip", c2="8a2a1e")),
    "bubblegum turkey": dict(_BIRDS["turkey"], coat="f9b8d4", wing="e88ab8", fan_tip="9ad4f5"),
    "midnight turkey": dict(_BIRDS["turkey"], coat="2a2a6e", wing="3a2a8a", fan_tip="ffe9a8", paint=dict(STARS, seed=9, n=22)),
}
GEESE = {
    "golden goose": dict(_BIRDS["goose"], coat="f2c230", wing="e0a81c"),
    "storm goose": dict(_BIRDS["goose"], coat="7a8aa0", wing="5a6a80", paint=dict(kind="dip", c2="f6f2ea")),
    "rainbow goose": dict(_BIRDS["goose"], coat="f7a8b8", wing="9ac8f0", paint=dict(kind="rainbow", hues=PASTEL)),
    "pink goose": dict(_BIRDS["goose"], coat="f9b8d4", wing="e88ab8"),
    "tuxedo goose": dict(_BIRDS["goose"], coat="2b2624", wing="2b2624", paint=dict(kind="band", c2="f6f2ea")),
}
BIRDS = {**CHICKENS, **DUCKS, **TURKEYS, **GEESE}
# a rabbit has no table: (coat, pale, paint)
RABBITS = {
    "cocoa rabbit": ("6a4a32", "e0c8a8", None),
    "dutch rabbit": ("2b2624", "f6f2ea", dict(kind="half", c2="f6f2ea")),
    "galaxy rabbit": ("2a2a6e", "c9b8e8", dict(STARS, seed=5, n=22)),
    "strawberry rabbit": ("f9c4d2", "fbe3ea", dict(kind="dots", c2="e8456b", seed=2, n=20)),
    "sunset rabbit": ("f79a5a", "fbe6c8", dict(kind="rainbow", hues=SUNSET)),
}


def baby_name(name, word):
    """A limited animal's baby: its coat's name and the family's word for a baby ("strawberry cow" -> "strawberry calf")."""
    return name.rsplit(" ", 1)[0] + " " + word


BABY_WORDS = {"cow": "calf", "horse": "foal", "pig": "piglet", "sheep": "lamb", "goat": "kid", "camelid": "cria"}
IN_GAME_BABIES = ("cow", "horse", "pig", "sheep")   # the homes that have births in the game; the other babies are built, not shipped
ROWS = {"cow": COWS, "horse": HORSES, "pig": PIGS, "sheep": SHEEP, "goat": GOATS, "camelid": CAMELIDS, "chicken": CHICKENS, "duck": DUCKS,
        "turkey": TURKEYS, "goose": GEESE, "rabbit": RABBITS}
# every limited animal by the game's family, adults then babies (the registry adds these to its GAME lists)
GAME = {k: list(rows) + [baby_name(n, BABY_WORDS[k]) for n in rows if k in IN_GAME_BABIES] for k, rows in ROWS.items()}
