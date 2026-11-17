# Where the game's sounds come from

Every sound file in `art/sound/` is either a **CC0** (public domain) recording from Freesound, named below with
its page, uploader and licence, or **made here from scratch** (ours, given away as CC0). Nothing else goes in:
a file is added only with its row here, and `tests/suites/sound_test.gd` fails on any file in `art/sound/` that
has no row, or a row that is neither a Freesound CC0 page nor made here.

How each download was matched to its page (Nov 2026): the files were downloaded by hand from a sample page of
Freesound's CC0 catalogue, so their names are plain (`cow-moo.mp3`); each was matched to its Freesound sound by
its exact length (to the hundredth of a second, the few hundredths an MP3 adds at its start aside) among the
sounds on that page, and the page's licence read: all CC0 1.0. Three farmyard recordings matched no Freesound
sound and could not be traced, so they were dropped and the farmyards made here instead (below).

The cut recordings are made by `tools/sound_cuts/make_sounds.py <folder of the downloads>` (its cut list is the
whole recipe); the rest by `tools/sound_cuts/make_generated.py`.
Both level every file the same way, by how loud it sounds on a phone or laptop speaker, and measure them into
`data/sound_levels.json` (`tools/sound_cuts/audit.py`); the files' sources don't change by levelling.

## CC0 recordings (Freesound)

Licence for every row: [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).

| Game files | Freesound sound | Uploader | Download | Length |
| --- | --- | --- | --- | --- |
| `voices/cow_*` | [513565 Cow moo #8](https://freesound.org/s/513565/) | spurioustransients | cow-moo.mp3 | 10.82 s |
| `voices/calf_*` | [860984 Bovines - Cattle; Calf Bawling, Single](https://freesound.org/s/860984/) | TheKingOfGeeks360 | calf.mp3 | 1.67 s |
| `voices/sheep_*` | [692900 Ewe Shetland Sheep Baa](https://freesound.org/s/692900/) | satoristudios3 | sheep.mp3 | 3.76 s |
| `voices/lamb_*` | [488573 lamb bleet005.wav](https://freesound.org/s/488573/) | pesticideX | lamb.mp3 | 36.09 s |
| `voices/goat_*` | [581240 Single Goat Bleating 2x](https://freesound.org/s/581240/) | Kinoton | goat.mp3 | 4.02 s |
| `voices/kid_*` | [200333 Baby goat bleating](https://freesound.org/s/200333/) | jsbarrett | baby goat.mp3 | 8.08 s |
| `voices/pig_*` | [442906 Pig Oink](https://freesound.org/s/442906/) | qubodup | pig.mp3 | 0.74 s |
| `voices/donkey_*` | [560692 Donkey Bray](https://freesound.org/s/560692/) | StarNinjas37 | donkey.mp3 | 1.81 s |
| `voices/hen_*` | [823065 Chicken Clucking](https://freesound.org/s/823065/) | Filmscore | chicken.mp3 | 11.05 s |
| `voices/rooster_*` | [200339 Rooster crow](https://freesound.org/s/200339/) | jsbarrett | rooster.mp3 | 4.76 s |
| `voices/duck_*` | [558858 Duck quacking.mp3](https://freesound.org/s/558858/) | DigPro120 | duck.mp3 | 1.75 s |
| `voices/turkey_*` | [233123 Turkey - Gobble - 96kHz.wav](https://freesound.org/s/233123/) | JarredGibb | turkey.mp3 | 1.03 s |
| `voices/alpaca_*` | [868310 Camelids - Alpaca; High Moan, Take 2](https://freesound.org/s/868310/) | TheKingOfGeeks360 | alpaca.mp3 | 0.54 s |
| `voices/bee_*` | [846433 Insects - Bee; Honeybee, Buzz, Close](https://freesound.org/s/846433/) | TheKingOfGeeks360 | bee.mp3 | 3.81 s |
| `ambience/morning*` | [488051 Ambience_Farm_Birds_01.wav](https://freesound.org/s/488051/) | BenDrain | morning-bird.mp3 | 63.63 s |
| `ambience/summer*` | [488067 Ambience_Farm_04.wav](https://freesound.org/s/488067/) | BenDrain | summer-ambience.mp3 | 59.53 s |
| `ambience/night*` | [522299 Crickets At Night - Raw sound](https://freesound.org/s/522299/) | Defelozedd94 | cricket-night.mp3 | 222.58 s |
| `ambience/rain*` | [673956 Rain in a village, light rain with wind](https://freesound.org/s/673956/) | felix.blume | rain.mp3 | 143.76 s |

## Made here (ours, CC0)

| Game files | What | How |
| --- | --- | --- |
| `voices/horse_*` | a horse's whinny (two with a snort after) | made here: a buzzing throat through vowel resonances, with breath, the whinny's trill and a lip snort |
| `voices/goose_*` | a goose's honk | made here: the same, nasal and brassy |
| `ambience/farm_day_*` | three farmyards by day | made here: wind and birdsong made in code, with the CC0 calls above heard now and then from across the farm |
| `music/sunny_fields*` | "Sunny Fields": fingerpicked guitar and flute, 100 bpm, G major | made here: written note by note, played by small instrument models (plucked string, flute, reed, shaker) |
| `music/evening_porch*` | "Evening Porch": a waltz, guitar lead, 76 bpm, D major | made here: the same |

A real recording can replace any of these later, with its own row above: put it in `data/sounds.json` (or
`data/soundscape.json`) in its place.
