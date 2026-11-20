# How the animals sleep

Owner, 20 Nov 2026: at night every animal hung its head low, so the ducks on the pond slept with their heads in the
water. Each family now sleeps the way its animals do, read up first; and a small "z z z" rises from each sleeper's
nose.

## What each family does, and where that was read
| Family | Asleep in the game | In life |
|---|---|---|
| Duck, swan, goose | On its feet or afloat, head turned back with the bill in the back feathers, one leg drawn up. Never down in the water. | Waterfowl sleep on the water or standing at its edge, the head turned back and tucked under a wing, often on one leg. [1][2][3] |
| Chicken, turkey | Down on its feet as on a roost, head turned back and tucked. | Fowl roost for the night and tuck the head into the feathers of the back. [2][4] |
| Cow, ox, sheep, goat (and their young) | Lying on the chest, legs folded under, head curled round to rest by a foreleg. | Ruminants lie on the chest, not the side (the stomach has to stay upright); in deep sleep the head is turned back to rest on the flank or laid down. They doze on their feet but lie down for deep sleep. [5][6][7] |
| Llama, alpaca | Sitting folded ("kush"), neck laid out in front. | Camelids fold their legs under them to rest and stretch the neck out in front in deep sleep. [8] |
| Horse, pony, donkey | Dozing on its feet: head and neck low, a hip let go, one hind foot resting on its toe. | Horses doze standing, the legs locked by the stay apparatus, one hind leg relaxed; they lie down only briefly for deep sleep. [9][10] |
| Pig | Flat on its side. | Comfortable pigs mostly lie on the side; on the chest when cold. [11] |
| Rabbit | A loaf: legs tucked under, ears laid back. | The "loaf" is the common relaxed sleeping position. [12] |
| Turtle | Head and legs drawn in under the shell. | (As turtles rest.) |
| Bee | No pose of its own, and no z. | Bees sleep still, antennae drooping, mostly in the hive. [13] Not shown yet. |

Sources: [1] birdfact.com/articles/swan-sleeping-behavior · [2] birds.cornell.edu/k12/do-birds-sleep ·
[3] allaboutbirds.org/news/do-birds-sleep-and-how · [4] a-z-animals.com/blog/how-and-where-do-turkeys-sleep ·
[5] news.uzh.ch/en/articles/2019/Resting-Postures.html · [6] pure.sruc.ac.uk (Lying posture does not accurately
indicate sleep stage in dairy cows) · [7] nationalgeographic.com/science/article/150711-animals-science-sleep-horses-bison-moose ·
[8] animal-world.com/how-do-llamas-sleep · [9] horseandhound.co.uk (Do horses sleep standing up) ·
[10] britannica.com/story/why-do-horses-sleep-standing-up · [11] thepigsite.com (Normal and abnormal behaviours of
swine) · [12] hepper.com/rabbit-sleeping-positions · [13] vice.com (weird animal sleep habits).

## How it is built
- **The pose** is one more move in each animal's file, `sleep` (`tools/animal_art`: `motion.asleep`, the way per
  family in `registry.SLEEP`). The game blends it in with `AnimalPose.sleep`, as it does every other move, over about
  half a second. The pose places the head, so a sleeper's head is no longer hung low as well.
- **Who sleeps this way**: an animal whose file has the move (`Animal3D.sleeps_its_own_way`; its mind is told:
  `AnimalBehaviour.lies`). One built by code (the stand-in while a pack is on its way) hangs its head as before.
- **The z z z** (`SleepMarks`, `shaders/sleep3d.gdshader`): one draw for the whole farm. Each animal asleep in its
  pose is in `Animal3D.sleepers`; its nose asleep is in `data/animal_sleep.json`, written with its file by the art
  tool's export. White with a dark edge, hidden by what stands in front.
- **Not changed**: when animals sleep (night, 85% of their choices; one stirs now and then), their breathing and
  shut eyes, and where they sleep (where they stand; a pond's birds on the water).

## Adding or changing a way of sleeping
Change `motion.asleep` or `registry.SLEEP`, look at it with the art tool (`poses`, or a sheet), then
`bash tools/remake_animals.sh <godot>`: every file, the noses and the strides are made again. The art tool's `Sleep`
tests and `sleep_test` 610 to 612 hold it.

## Measured
Showcase farm at night, 45 sleepers, 900 frames at a time: scripts 7.7 to 8.9 ms a frame, no frame over 33 ms (the
same as by day before this). The z z z are one draw.
