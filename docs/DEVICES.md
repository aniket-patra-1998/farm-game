# Which phones get the game (owner, 25 Nov: "we should have a min requirement... research and come up with the
best solution")

## What the phones measured (Firebase Test Lab, the benchmark build of 25 Nov)
| Phone | Chip, graphics | Quality chosen | Play frame | Opening own farm | Start |
|---|---|---|---|---|---|
| Galaxy A05s (low-end) | Snapdragon 680, Adreno 610 | low | 103 ms (~10 fps) | 5.2 s | 19 s |
| Galaxy A53 5G (mid) | Exynos 1280, Mali-G68 | mid | 35 ms (~29 fps), p95 42 | 4.2 s | 22 s |

The A53 meets the 30 fps bar at mid quality; the A05s is a third of it at low.

## The rule for the beta (set in Play Console when the app is created)
1. **Android 10 or newer** (`min_sdk` 29 in the Play Store preset). Play has no Android-version rule; the manifest
   decides. The Mobile renderer runs on Vulkan, whose drivers before Android 10 are the least reliable, and the
   phones below it are old and slow anyway.
2. **Device catalog, rule-based exclusions** (Release > Reach and devices > Device catalog): Play's rules can
   use RAM and the system on chip.
   - **RAM**: exclude devices with less than 3.5 GB total (Play counts total memory, not the branded "4 GB").
   - **System on chip**: exclude the entry chips of the A05s's class and below: Snapdragon 4xx, 662/665/680/685,
     MediaTek Helio G35 to G88 and P-series, Unisoc (T606, T612, T616, T618), Exynos 850. The A53's class (Exynos
     1280, Snapdragon 695 and up, Dimensity 700 and up, Helio G99) stays in.
   - **Android Go**: exclude.
3. **Loosen it as the speed work lands**: when the A05s holds 30 fps at low quality on the nightly bench, the
   chip rule comes off; the RAM rule stays.

Notes: rules apply to new devices joining the catalog too; they do not apply to internal testers (who can install
on anything). Google's terms ask that exclusions be technical, not commercial: excluding phones that cannot run the
game at a playable rate is what the rules are meant for.
