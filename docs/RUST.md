# Vehicle rust (our own addition, not FarmVille 2009)

A vehicle rusts with time, wherever it stands; a Garage halves it.

- **Where a vehicle works from**: any vehicle you own can be driven, parked in a Garage or standing on the
  farm (before this, only parked ones). After a job a vehicle standing outside goes straight into a Garage
  that has room; with no Garage it stays out.
- **Pace**: parked in a Garage it gains a level of rust every 14 days; standing outside, every 7. The weather
  makes no difference. Levels 1 to 5.
- **What rust costs**: each level burns 10% more fuel a plot and works 20% fewer plots of the vehicle's area
  (rounded down, never under one). At level 5 it does not work at all.
- **Repair**: coins and time, more at each level: 5%, 12%, 22%, 35% and 50% of the vehicle's price, and 10
  minutes, 30 minutes, 1, 2 and 4 hours. It cannot work while it is being repaired, and comes out with no
  rust.
- **Look**: rust spreads over the vehicle's paint with each level, in the paint it already has.

Rust is worked out from the clock, so it is right after days away. Switch: `Release.on("rust")`. Numbers:
Balance `rust.*`. Rules: `scripts/systems/rust_system.gd`, held by `tests/suites/rust_test.gd`.
