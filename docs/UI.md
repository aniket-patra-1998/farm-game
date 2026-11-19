# Interface plan (landscape)

A whole-new initiative: the HUD and every panel move to one FarmVille-style look, built from one kit, in code.
Principle as everywhere: first pure FarmVille, then our own touch, clearly marked.

## The unified look (paper), Nov 2026
One look for everything the player reads or presses, taken from the building sheet the player picked as the model
(our own touch over FarmVille's wooden frames). Every panel, sheet and floating card follows it; a test holds it.
- **Surface:** one warm paper (`paper`), round corners, a soft shadow, no frame (`UiKit.paper_box`, `panel_box`). The
  tool panel and the name bubbles stand on it too. Inside: flat sections with a thin `divider` line, never a box in
  a box (`UiKit.paper_theme`: plain PanelContainers are see-through on paper).
- **Words by role** (`BookPanel.INK/SOFT/HEAD/GOOD`, `UiTheme` "ink", "soft", "note", "price_short"): ink for what is
  read, soft for what is said beside it, note for a reason something can't be done, red for short of something.
  Every word on the paper reaches 3:1 contrast (`menus_test`); no cream or yellow words from the old wood.
- **Title:** ink, at the left; the same round cross at the right on every panel and sheet (`UiKit.close_button`).
- **Buttons, three kinds:** the one main action, filled with the accent, white words (`UiKit.primary`; at most one
  per panel or sheet); ordinary cream buttons (`FarmHud._panel_button`); quiet text buttons for Move, Turn, Sell
  (`UiKit.quiet_button`). Every button, pill and switch is at least panel_button_height each way to tap (`UiKit.tappable`; the menu sweep checks it).
- **Tabs:** pills on paper, the chosen one in ink (`UiKit.tab_button`).
- **Items:** white cards with a light edge (`CardFace`, "card_face"), contents as picture tiles with counts
  (`UiKit.count_row`), progress as a light track with the accent fill (paper theme's ProgressBar).
- **Text:** never a letter a line (`PanelText`), sizes through `UiTheme.font`, never under the smallest.
- **Motion:** every surface opens and closes in one motion (`UiFx.open` / `close`, `open_with` for its own look):
  it fades in, grows from 0.94 and rises 8 px into place in 0.22 s, eased out; it closes the same way back in
  0.16 s, eased in, and is hidden only then (`is_open` is whether it is up; a closing one takes no taps). Either
  way it turns back from where it is; a tab's page fades in (`UiFx.crossfade`, 0.12 s). A bottom sheet slides
  instead of growing; words over the farm and full-screen cards only fade. A test holds every surface to it.

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
| View toggles | Left column: eye (hide UI), speaker (sound), note (music) | None: sound in Settings, the interface rests on an idle farm, pinch zooms | Removed (fewer things to tap) |
| Menu | Market and others as bottom buttons | Four text buttons on the top bar | Icon buttons: Market, Collections, Ribbons, Settings |
| Tool panel | Bottom right wooden panel: select arrow, ribbon | Long scrolling row of text buttons | Icon tool panel (select, plow, fertilize, store, move, rotate, sell); helpers and fuel in a second row |
| Zoom | Bottom right: zoom in, zoom out, fit, camera | Pinch and wheel only | Four icon buttons wired to FarmCamera |
| Bottom strip | Neighbour portraits with level and score | None | Placeholder: quick bar of the seeds in use |
| Panels | Wooden frame, tabs, item cards with price badges | Plain cream panels | Same kit: tabs, cards, price badges |
| Toasts and floaters | Floating +coins and +XP from the item | Exists (Feedback colours) | Keep; align to the new bars' positions |

## Heads-up display as built (phase 3)
- Top: coin and cash bars (their "+" opens the Market), the farm's name on a plaque (set in Settings) with the season, weather and time under it, the XP bar with the level star (`HudTop`).
- Left: nothing. Sound is in Settings; the interface rests by itself on an idle farm.
- Right: Market, Collections, Ribbons, Neighbours (a placeholder message for now), Settings; zoom in, out and whole farm (`HudSide`).
- Bottom right: seven tools: Select (in hand by default: tap to look, collect or open; press and hold anything to lift and move it), Plow, Plant (opens the seed list, `HudSeeds`), Harvest (gathers what is ready, opens no panels), Fertilise, Store, Sell (`HudTools`).
- Bottom left: nothing until neighbours are real (the inbox holds their mail, behind the Neighbours button).
- Boosts (Fertilize All, Unwither, Farmhand, Arborist, Gardener) and fuel are used from the Barn, as FarmVille's were from the gift box; a vehicle is taken in hand by tapping it. Debug buttons moved to Settings > Testing.

## Phases
1. Spec: this document. Done.
2. Kit (`scripts/ui/ui_kit.gd`, `data/ui_theme.json`): wood panel, glossy bar, star badge, bevelled button, plaque,
   icon drawing (`UiIcons`), all from data (colours, sizes, radii). A test checks every colour/size name exists.
3. Heads-up display (done): top bars, left toggles, tool panel, zoom buttons, bottom strip; `hud.gd` keeps logic,
   layout moves to `scripts/hud/hud_top.gd` and `hud_tools.gd`. All text through `tr("KEY")`; sounds and buzzes via
   `Feedback.moment`. `coins_target()` / `xp_target()` follow the new bars.
4. Panels: Market, Barn, Collections, Ribbons, Settings, crafting and building panels on the kit.
5. Polish and checks: touch targets at least 48 dp, a layout test at 16:9, 18:9 and 4:3, no overlaps and nothing cut off,
   CI screenshots of the HUD, performance probe (the HUD must add no per-frame cost when idle).

## Rules for this work
- No hard-coded colours or sizes in layout code: everything from `ui_theme.json`.
- The tutorial banner, placing bar and toasts keep working at every step; a test per phase.
- Existing tests (and tap targets used by tests) keep passing; new behaviour gets its own test.
