# Interface plan (landscape)

A whole-new initiative: the HUD and every panel move to one FarmVille-style look, built from one kit, in code.
Principle as everywhere: first pure FarmVille, then our own touch, clearly marked.

## Decisions (agreed)
- Neighbour bar: no neighbours yet, so the bottom strip stays a placeholder (a quick bar of tools, our own touch).
- Currency: coins and gems. Gems get FarmVille's Farm Cash treatment (a bar with a "+").
- Font: Godot's default; no font files bundled.
- Icons: drawn in code (coin, gem, star, eye, speaker, note, magnifier, camera, arrow, ribbon), sharp at any size.
- Orientation: landscape only for now. Portrait is an open item (see docs/OPEN_ITEMS.md).

## Components: FarmVille against ours
| Component | FarmVille (references) | Ours today | Plan |
|---|---|---|---|
| Coin bar | Gold coin stack icon, number in a green glossy bar, "+ Add Coins & Cash" under it | Yellow text label | Icon + glossy bar, tap opens the Market |
| Cash bar | Green note icon, number in a teal bar | Light-blue text label | Gem icon + teal bar with "+" |
| XP and level | Wide dark bar with white fill, gold star holding the level at its right end | Text "Level N", plain progress bar, numbers | Bar + star badge with the level; numbers on tap |
| Farm name | Brown plaque with a speech-bubble button | None | Plaque with the farm's name (editable in Settings) |
| View toggles | Left column: eye (hide UI), speaker (sound), note (music) | None (Settings panel) | Three small icon buttons, kept in step with Settings |
| Menu | Market and others as bottom buttons | Four text buttons on the top bar | Icon buttons: Market, Collections, Ribbons, Settings |
| Tool panel | Bottom right wooden panel: select arrow, ribbon | Long scrolling row of text buttons | Icon tool panel (select, plow, fertilize, store, move, rotate, sell); helpers and fuel in a second row |
| Zoom | Bottom right: zoom in, zoom out, fit, camera | Pinch and wheel only | Four icon buttons wired to FarmCamera |
| Bottom strip | Neighbour portraits with level and score | None | Placeholder: quick bar of the seeds in use |
| Panels | Wooden frame, tabs, item cards with price badges | Plain cream panels | Same kit: tabs, cards, price badges |
| Toasts and floaters | Floating +coins and +XP from the item | Exists (Feedback colours) | Keep; align to the new bars' positions |

## Phases
1. Spec: this document. Done.
2. Kit (`scripts/ui/ui_kit.gd`, `data/ui_theme.json`): wood panel, glossy bar, star badge, bevelled button, plaque,
   icon drawing (`UiIcons`), all from data (colours, sizes, radii). A test checks every colour/size name exists.
3. Heads-up display: top bars, left toggles, tool panel, zoom buttons, bottom strip; `hud.gd` keeps logic,
   layout moves to `scripts/hud/hud_top.gd` and `hud_tools.gd`. All text through `tr("KEY")`; sounds and buzzes via
   `Feedback.moment`. `coins_target()` / `xp_target()` follow the new bars.
4. Panels: Market, Barn, Collections, Ribbons, Settings, crafting and building panels on the kit.
5. Polish and checks: touch targets at least 48 dp, a layout test at 16:9, 18:9 and 4:3, no overlaps and nothing cut off,
   CI screenshots of the HUD, performance probe (the HUD must add no per-frame cost when idle).

## Rules for this work
- No hard-coded colours or sizes in layout code: everything from `ui_theme.json`.
- The tutorial banner, placing bar and toasts keep working at every step; a test per phase.
- Existing tests (and tap targets used by tests) keep passing; new behaviour gets its own test.
