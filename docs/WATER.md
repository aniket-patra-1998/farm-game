# Water (our own touch, beyond FarmVille's flat blue)

Every water on the farm is one material (`DecorMotion.water`, `pond_water`; shaders/water3d.gdshader), so it
all looks and behaves alike and costs nothing to script.

- **Look**: calm and deep. A pond's depth is its colour: pale and clear over the shallows, deep blue in the
  middle (its mesh's UV.x runs from middle to shore). A web of light moves slowly over the bed, a thin line of
  foam laps at the bank, glints blink where the light catches. A basin with no shore (well, fountain,
  birdbath, a decoration's trough) is one depth all over.
- **Weather** (global shader values, set only through `ShaderGlobals`): `rain` (how hard it rains this moment:
  `SurfaceWeather`) fills every water with small rings; `wind` hurries its light and ripples; `snow_cover` over
  about a half freezes it to pale ice; `dark` turns its glints into the moon's glitter.
- **Rings** (`WaterRings`, one draw for all of them, asleep while the water is still): a swimmer's wake, a
  splash where water is tapped (`Objects3D.splash`, from the tap that pokes the thing), a fish's leap.
- **Where a thing's water is**: `Objects3D.water_in` finds the biggest sheet of the kit's water in what is drawn
  for a building or a decoration (files, built models and batched decorations alike), once, when its view is
  built. Nothing lists waters by name: a new thing with water just works.
- **A pond's life** (`PondLife`, one for each pond standing on the farm, never for a picture of one): a frog on
  a lily pad that bobs, two dragonflies by day, fireflies by night (shaders/firefly3d.gdshader), a fish that
  leaps now and then. Only the fish's leap runs in script, and only while it is in the air. On ice there are
  no dragonflies and no fish.
- **Birds that swim**: the animals of a home with a pond (the Duck Pond) float while they are over its water
  (`BuildingFill._swim` sets `Animal3D.afloat`): they sit low, legs under the surface, leave a ring now and
  then, and when they feed they dabble, tipping forward with head under and tail up. Asleep they stay level.
  On a frozen pond they stand on the ice. The small pond's two ducks dabble too (shaders/orbit3d `dip`).
- **Animals that drink**: an animal standing near its yard's water trough (`BuildingModel.troughs`) now and
  then walks up to it and lowers its head to the water (`AnimalBehaviour.drink_at`, `drinking`).

Not the one water, by the draw budget: a harvesting building's yard trough and the Spa's pool are painted
water in the same blue (`BuildingModel.STILL_WATER`). They do not move, take rain or freeze; the real water
would be a draw more than a building's eight.
