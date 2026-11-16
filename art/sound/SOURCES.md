# Where the game's recorded sounds come from

Every recording here is **CC0** (public domain): free to ship, change and keep in this public repository, no
credit needed. They were picked by ear on a sample page from Freesound's CC0 catalogue (Nov 2026), downloaded,
and cut into the game's files by `tools/sound_cuts/make_sounds.py` (the cut list there is the whole recipe; run it
on the folder of downloads to make them again). Nothing from licences that forbid redistribution (Mixkit,
Pixabay...) goes in here.

| Game files | Download | What |
| --- | --- | --- |
| voices/cow_1 | cow-moo.mp3 | a cow's moo |
| voices/calf_1 | calf.mp3 | a calf bawling |
| voices/sheep_1-2 | sheep.mp3 | a ewe's baa, two takes |
| voices/lamb_1-4 | lamb.mp3 | a lamb's bleats |
| voices/goat_1-2 | goat.mp3 | a goat's bleat |
| voices/kid_1-4 | baby goat.mp3 | a baby goat |
| voices/pig_1 | pig.mp3 | a pig's oink |
| voices/donkey_1 | donkey.mp3 | a donkey's bray |
| voices/hen_1-5 | chicken.mp3 | hens clucking |
| voices/rooster_1 | rooster.mp3 | a rooster's crow (the dawn) |
| voices/duck_1-3 | duck.mp3 | a duck's quacks (geese use them lower) |
| voices/turkey_1 | turkey.mp3 | a turkey's gobble |
| voices/alpaca_1 | alpaca.mp3 | an alpaca's hum |
| voices/bee_1 | bee.mp3 | a honeybee's buzz |
| ambience/farm_day_a, b, c | farm-sound.wav, farm-sound-3.wav, farm-son-2.mp3 | farmyards by day |
| ambience/morning | morning-bird.mp3 | morning birds |
| ambience/summer | summer-ambience.mp3 | a summer day |
| ambience/night | cricket-night.mp3 | crickets at night |
| ambience/rain | rain.mp3 | rain, laid over the bed when it rains |

## Made from scratch (ours, CC0)

No CC0 recording was found for these, so `tools/sound_cuts/make_generated.py` makes them: the calls source-filter
style (a buzzing throat through vowel resonances, with breath), the music written out note by note and played by
small instrument models (plucked-string guitar and bass, flute, reed pad, shaker, a made-up room).

| Game files | What |
| --- | --- |
| voices/horse_1-3 | a horse's whinny (two with a snort after) |
| voices/goose_1-3 | a goose's honk |
| music/sunny_fields | "Sunny Fields": fingerpicked guitar and flute, 100 bpm, G major, 80 s |
| music/evening_porch | "Evening Porch": a waltz, guitar lead, 76 bpm, D major, 98 s |

A real recording can replace any of these later: put it in `data/sounds.json` (or `data/soundscape.json`) in its place.
