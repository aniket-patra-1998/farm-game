# Weather, season by season: rain first

Status: design for review (nothing built yet). Our own touch throughout: FarmVille (2009) had no weather.
Switch: `Release.on("weather_life")`; every number below lives in data (`data/weather.json`, Balance `weather.*`).

## What we have today

- `Weather` (scripts/weather.gd): one state per 3-hour block (clear, partly cloudy, cloudy, rain, storm, fog,
  snow), a pure function of the date and the region's season odds (data/seasons.json), eased at block edges.
  Because it is pure, any past or future stretch is known: offline time costs nothing to work out.
- Looks: `Weather.LOOKS` in code (cover, dim, desat, rain, fog, lightning); 2D rain streaks and a screen flash
  (weather_layer.gd); in 3D `SurfaceWeather` wets every surface through the `wetness` global; fog is
  `environment.fog_density = 0.012 * fog` (exponential, from the camera).
- Rules: rain while a crop grew adds `seasons.rain_bonus` to its harvest (`Game.rained_between`); butterflies and
  birds keep out of rain (`AmbientLife`).
- Missing: thunder, a lightning bolt, puddles, rain creatures, any reason to care that it rains.

## Why fog is too dense, and the fix

Exponential fog grows with distance from the camera, and our camera sits far above the farm, so the farm
itself, the thing being looked at, is half lost at 0.012 × 0.75. Fix: **depth fog that begins past the farm**
(Godot 4 `fog_mode = FOG_MODE_DEPTH`, `fog_depth_begin` at the farm's far edge, `fog_depth_end` well beyond),
plus a light height fog on the ground only. The farm stays clear; the woods and the meadow fade into a soft
haze, which reads as fog without hiding play. Fog becomes "mist" in the morning after rain (see Afterwards).
Strength and depths come from `data/weather.json`, per state.

## What the others do (and what we take)

- Stardew Valley: rain waters crops; storms bring lightning that can destroy crops and trees, and lightning
  rods catch strikes and turn them into Battery Packs; a Rain Totem calls rain. We take: rain that matters to
  crops, lightning with something to catch it. We leave: losing crops to lightning (too harsh for a cozy farm).
- Animal Crossing: some creatures appear only in rain (snails), others hide (butterflies, many beetles);
  heavy rain darkens the sky more; thunderstorms are cosmetic; villagers carry umbrellas; the music changes;
  flowers are watered. We take: rain-only creatures, umbrellas, a rain music and sound layer, darker heavy rain.
- Real-time rain rendering (fxguide, Realtime Rain VFX breakdown, Godot puddle shaders): wetness darkens and
  shines surfaces, puddles are a noise mask on flat ground, ripples are expanding rings per cell. The costly
  parts are screen-space reflections and many ripple cells per pixel: we skip SSR (a sky tint and a fresnel
  sheen instead) and use one ring per cell, so puddles cost no extra draws on a phone.

## The rain, as the player lives it

Three strengths from the existing states: **drizzle** (rain, eased low), **rain**, **storm** (heavy rain with
lightning). A rain spell has a shape: clouds gather (the sky dims, wind rises, birds leave), first drops, the
full rain, then it eases off, and the farm is wet and alive for a while after.

### While it rains
- Rain falls in 3D around the view (one GPU particle system following the camera, its count by Quality),
  splashes on the ground and rings on ponds and puddles (in the ground and water shaders, not particles).
- Puddles gather on open ground: grass and bare tiles, never on plots in use or under things. They grow as the
  rain goes on and shrink after it (a `puddles` global, 0..1, eased like `wetness`), shaped by a noise mask fixed
  per tile so the same dips fill every time. They ripple while it rains and mirror the sky.
- Rain sounds in two layers (light patter, heavy downpour) by strength; closer to roofs when zoomed in.
- Animals shelter: those out in yards go in (heads at the windows), back out when it stops. The farmer wears a
  raincoat or carries an umbrella. Butterflies and birds leave (as now).
- Frogs come out near puddles and ponds and hop about; snails crawl on fences and decorations; earthworms show
  on plowed plots. All drawn in batches (one MultiMesh per kind), few on low quality.

### Storms (heavy rain)
- Lightning: a branching bolt far out over the meadow (one ribbon mesh, shown for a few frames), the sky and the
  sun light flash white, then **thunder after a delay** that says how far it struck (0.5 to 4 s; near ones a
  crack, far ones a rumble; three or four recorded or synthesised variants, never the same twice in a row).
- Frequency rises and falls with the storm's strength; a strike close to the farm is rare.
- Lightning Rod (decoration, our own touch): a rod on the farm catches strikes; each catch gives a small reward
  (coins, or a material for crafting). Nothing on the farm is ever destroyed by lightning.

### Afterwards
- The farm drips and dries: wetness and puddles ease out over an hour or so; puddles last longest in shade.
- A **rainbow** sometimes, when the sun comes back the same day.
- Morning mist after night rain (the depth fog above, gentle, burning off by mid-morning).
- **Mushrooms** pop up on open grass for a while after rain: tap to pick (coins and XP, or a crafting
  ingredient). A few per rain spell, seeded by the spell, capped per farm, so the same rain always gives the
  same mushrooms and a picked one is saved as picked.

## The rules (what rain changes)

- Rain waters crops (kept: `seasons.rain_bonus` on the harvest of a crop that saw rain while growing).
- **Ripe crops wither faster in the wet** (as asked): time a ripe crop spends in rain counts double against its
  wither window, so a crop ripe all through a rain withers in half its usual time. Worked out from the weather's
  pure function, so offline time is exact and the ready list and the "withers in" bubble stay true.
- **Monsoon finds**: harvesting during rain, or within a few hours after it, raises the chance of rain-loving
  finds, per family in data/finds.json (`rain_boost`): gophers (existing family) more often, and a new **frogs**
  family (tree frog, bullfrog, golden frog: a set for the collections, a pond home later) found only after rain.
- Rain barrel (decoration, our own touch): fills with rain, and a full barrel gives a Watering Can (what
  Mystery Seedlings grow on), so rain feeds the seedling loop. Its fill is worked out from the rain since it was
  last emptied; only that time is saved.
- Helpers and vehicles work in the rain as ever.

## How it is built (scalable, cheap on a phone)

- **One source of truth**: `Weather` stays the pure clock of states. `data/weather.json` takes over `LOOKS` and
  adds per-state rules and life: `wither_rate`, `find_boost`, `puddles`, `creatures` (kinds, counts by Quality),
  `lightning` (strikes a minute, near share), `fog` (density, depth begin and end). A new season's weather
  (snow, heat, wind) is new entries, not new code.
- **`WeatherSystem`** (`Game.weather`, a GameSystem): the rules. `wet_seconds(from, to)`, `wither_at(plot)`,
  `find_boost(family, at)`, `rain_spell_at(t)` (start, end, strength: the spell a mushroom or barrel belongs to),
  `mushrooms_now()`; saves only picked mushrooms and barrels' last emptying. Signals `weather_changed(state)` at
  block edges and `struck(at, near)` for a strike, so the world, sound and HUD listen and never poll.
- **Looks**, all reading the same eased values through `ShaderGlobals` (`wetness`, `puddles`, `rain`, `flash`):
  the ground shader (puddle mask, ripples, sheen) and water shader (rings) do the work with no extra draws;
  `Rainfall3D` (one GPU particle node); `Lightning3D` (one bolt mesh, the flash on the lights);
  `RainLife` (frogs, snails, worms) beside `AmbientLife`, batched, spots chosen by `SpaceFit` on open tiles;
  `Mushrooms` drawn as one batch; sounds by `Feedback.moment("thunder_near")`, loops by `Feedback.hum("rain")`.
- **Quality** (data/quality.json): rain particle count, creatures shown, ripples on or off, puddle reflections,
  lightning bolt mesh on mid and up (low gets the flash and thunder only).
- **Offline**: everything is worked out from time (rain spells, wither, mushrooms, barrels), so coming back after
  a day away shows the right puddles, withered crops and mushrooms with nothing simulated in between.
- **Tests**: wither in rain is half the window, exactly, across block edges; finds boosted only in and after
  rain; mushrooms the same for the same spell and never more than the cap; the perf budget holds with a storm
  on the showcase farm on mid and low; every weather sound and moment exists.

## Build order

1. Fog fix (depth fog), thunder and the lightning bolt and flash; the rain sound layers.
2. Rules: wither in the wet, monsoon finds, the frogs family; `WeatherSystem` and data/weather.json.
3. Puddles and ripples in the ground and water shaders; rain particles in 3D.
4. Rain life: frogs, snails, worms; animals sheltering; the farmer's umbrella.
5. Afterwards: mushrooms, rainbow, morning mist; Lightning Rod and rain barrel.

## Open questions

- Should tapping a frog do anything (a ribbit and a small chance of a coin), or are they scenery only?
- Lightning Rod's reward: coins, or a new crafting material (and in which recipes)?
- Monsoon region (South Asia): longer, heavier rain spells in its monsoon season, with more frogs and finds?
</content>
</invoke>
