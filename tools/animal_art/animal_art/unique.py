"""Unique coats (pilot): five new varieties for each kind, each a row made from one of the family's own breeds with a new
coat, a painted pattern (paint.py) or more or less fur. Rows join the families' tables, so their babies follow."""
from .families.bird import BIRDS
from .families.camelid import CAMELIDS
from .families.dog import DOGS
from .families.goat import GOATS
from .families.horse import HORSES
from .families.pig import PIGS
from .families.sheep import SHEEP

PASTEL = ["f7a8b8", "f9d08a", "f6ef9a", "a8e0a8", "9ac8f0", "c0a8e8"]
SUNSET = ["f7c84a", "f79a5a", "f0708a", "b060b0"]
STARS = dict(kind="stars", c2="ffe9a8", c3="7a3aa8")

HORSES.update({
    "candy horse": dict(HORSES["white stallion"], coat="f7b5d0", points="6ac8f0"),
    "zebra horse": dict(HORSES["horse"], coat="f6f2ea", points="2b2624", dark_legs=False, paint=dict(kind="stripes", c2="2b2624")),
    "galaxy horse": dict(HORSES["horse"], coat="2a2a6e", points="c9a8ff", dark_legs=False, mane=1.2, tail=1.3, paint=dict(STARS, seed=2)),
    "dapple horse": dict(HORSES["gray horse"], coat="f6f2ea", points="4a4a52", dark_legs=False, paint=dict(kind="dots", c2="8a8a94", seed=5, n=34)),
    "feather horse": dict(HORSES["draft horse"], coat="2b2624", points="f6f2ea", mane=1.5, tail=1.45),
})
PIGS.update({
    "blueberry pig": dict(PIGS["pink pig"], coat="8f9be8", coat2="6a74c8", paint=dict(kind="dots", c2="4a54a8", seed=3)),
    "bumblebee pig": dict(PIGS["pink pig"], coat="f8d030", coat2="d9a520", paint=dict(kind="stripes", c2="2b2624", f=7.0)),
    "woolly pig": dict(PIGS["pink pig"], coat="efe2c8", coat2="d9c4a0", ears="up", tufts=1),
    "rainbow pig": dict(PIGS["pink pig"], coat="f7a8b8", coat2="e79aa0", paint=dict(kind="rainbow", hues=PASTEL)),
    "golden pig": dict(PIGS["pink pig"], coat="f2c230", coat2="d99a1c", paint=dict(kind="dip", c2="e08a1c")),
})
SHEEP.update({
    "cloud sheep": dict(SHEEP["woolly sheep"], wool=1.5, coat="f4f8ff", paint=dict(kind="dip", c2="9ad0f5")),
    "shorn sheep": dict(SHEEP["sheep"], wool=0.3, coat="f6e6da"),
    "cotton candy sheep": dict(SHEEP["woolly sheep"], coat="f9b8d4", face="fbe3ea", legs_col="f9b8d4", paint=dict(kind="patches", c2="9ad4f5", seed=2)),
    "rainbow sheep": dict(SHEEP["sheep"], coat="f7a8b8", paint=dict(kind="rainbow", hues=PASTEL)),
    "golden ram": dict(SHEEP["ram"], coat="f2c230", face="3a2a20", legs_col="3a2a20", paint=dict(kind="dip", c2="e0a01c")),
})
GOATS.update({
    "angora goat": dict(GOATS["billy goat"], horns=0.9, beard=0.7, ears="droop", coat="f8f4ea", coat2="e6dcc8", tufts=1),
    "lavender goat": dict(GOATS["goat"], coat="c0a8e8", coat2="6a4aa8"),
    "dalmatian goat": dict(GOATS["goat"], coat="f6f2ea", coat2="3a2f27", paint=dict(kind="dots", c2="3a2f27", seed=4)),
    "sunset goat": dict(GOATS["goat"], coat="f79a5a", coat2="8a3a5a", paint=dict(kind="rainbow", hues=SUNSET)),
    "tuxedo goat": dict(GOATS["goat"], coat="2b2624", coat2="f6f2ea", paint=dict(kind="band", c2="f6f2ea")),
})
CAMELIDS.update({
    "cotton candy alpaca": dict(CAMELIDS["alpaca"], coat="f9b8d4", coat2="f9b8d4"),
    "mint alpaca": dict(CAMELIDS["alpaca"], coat="a8e6cf", coat2="a8e6cf", paint=dict(kind="patches", c2="f6f2ea", seed=3)),
    "galaxy alpaca": dict(CAMELIDS["alpaca"], coat="2a2a6e", coat2="2a2a6e", paint=dict(STARS, seed=4)),
    "rainbow llama": dict(CAMELIDS["llama"], coat="f7a8b8", coat2="f7a8b8", pattern="solid", paint=dict(kind="rainbow", hues=PASTEL)),
    "cocoa llama": dict(CAMELIDS["brown llama"], coat="4a2e20", coat2="f3d9a8", paint=dict(kind="dots", c2="e0a860", seed=6)),
})
DOGS.update({
    "snow dog": dict(DOGS["indie dog"], fur=0.6, coat="8a98b0", coat2="f6f6fa", pattern="bib"),
    "brindle dog": dict(DOGS["brown dog"], coat="b8743a", coat2="e0c090", paint=dict(kind="stripes", c2="3a2418", f=11.0)),
    "merle dog": dict(DOGS["black lab"], coat="9aa8c0", coat2="9aa8c0", paint=dict(kind="patches", c2="3a3f52", seed=5)),
    "pink poodle": dict(DOGS["golden retriever"], coat="f9b8d4", coat2="fbe3ea", tufts=1),
    "sheepdog": dict(DOGS["golden retriever"], coat="f6f2ea", coat2="f6f2ea", paint=dict(kind="half", c2="8a8f9a")),
})
BIRDS.update({
    "silkie chicken": dict(BIRDS["chicken"], feathers=0.5, tufts=1),
    "peacock chicken": dict(BIRDS["chicken"], coat="1f8a8a", wing="2a5ad0", tail_col="2fbf71", tail_k=1.4),
    "flame chicken": dict(BIRDS["chicken"], coat="e0452a", wing="f08a2a", tail_col="f8d030", paint=dict(kind="dip", c2="f8c030")),
    "bubblegum chicken": dict(BIRDS["grey chicken"], coat="f9b8d4", coat2="e06aa0", tail_col="c04a88"),
    "galaxy chicken": dict(BIRDS["chicken"], coat="2a2a6e", wing="3a2a8a", tail_col="7a3aa8", paint=dict(STARS, seed=7, n=22)),
    "rubber duck": dict(BIRDS["duck"], coat="f8d030", wing="f0c020"),
    "mandarin duck": dict(BIRDS["duck"], coat="d9702a", wing="3a5ad0", paint=dict(kind="dip", c2="7a3a8a")),
    "rainbow duck": dict(BIRDS["duck"], coat="f7a8b8", wing="9ac8f0", paint=dict(kind="rainbow", hues=PASTEL)),
    "mint duck": dict(BIRDS["duck"], coat="a8e6cf", wing="7ad0b0"),
    "galaxy duck": dict(BIRDS["duck"], coat="2a2a6e", wing="3a2a8a", paint=dict(STARS, seed=8, n=22)),
    "peacock turkey": dict(BIRDS["turkey"], coat="1f6fa8", wing="1f8a8a", fan_tip="2fbf71", head_col="2a5ad0"),
    "royal turkey": dict(BIRDS["turkey"], coat="f6f2ea", wing="ece8dc", fan_tip="f2c230"),
    "autumn turkey": dict(BIRDS["turkey"], coat="c8642a", wing="a8401e", fan_tip="f8d030", paint=dict(kind="dip", c2="8a2a1e")),
    "bubblegum turkey": dict(BIRDS["turkey"], coat="f9b8d4", wing="e88ab8", fan_tip="9ad4f5"),
    "midnight turkey": dict(BIRDS["turkey"], coat="2a2a6e", wing="3a2a8a", fan_tip="ffe9a8", paint=dict(STARS, seed=9, n=22)),
    "golden goose": dict(BIRDS["goose"], coat="f2c230", wing="e0a81c"),
    "storm goose": dict(BIRDS["goose"], coat="7a8aa0", wing="5a6a80", paint=dict(kind="dip", c2="f6f2ea")),
    "rainbow goose": dict(BIRDS["goose"], coat="f7a8b8", wing="9ac8f0", paint=dict(kind="rainbow", hues=PASTEL)),
    "pink goose": dict(BIRDS["goose"], coat="f9b8d4", wing="e88ab8"),
    "tuxedo goose": dict(BIRDS["goose"], coat="2b2624", wing="2b2624", paint=dict(kind="band", c2="f6f2ea")),
})
# a rabbit has no table: (coat, pale, paint)
RABBITS = {
    "cocoa rabbit": ("6a4a32", "e0c8a8", None),
    "dutch rabbit": ("2b2624", "f6f2ea", dict(kind="half", c2="f6f2ea")),
    "galaxy rabbit": ("2a2a6e", "c9b8e8", dict(STARS, seed=5, n=22)),
    "strawberry rabbit": ("f9c4d2", "fbe3ea", dict(kind="dots", c2="e8456b", seed=2, n=20)),
    "sunset rabbit": ("f79a5a", "fbe6c8", dict(kind="rainbow", hues=SUNSET)),
}
