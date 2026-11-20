# Asset packs: files fetched when first needed

The limited animals (docs/LIMITED.md) are 77 files, about 90 MB. The owner's rule (19 Nov 2026): a player
should not download what they cannot use, so those files stay out of the app and each arrives when it is first
needed, as other games do. `AssetPacks` (`scripts/systems/asset_packs.gd`) does this.

## How it works
- **A pack** is a Godot pack file with what the importer made of a few items' files: one pack for each limited
  animal, with its baby (56 packs, 0.6 to 2.7 MB each).
- **In the app** those files are missing. The first time one is to be drawn, `AssetRegistry` asks
  `AssetPacks.want`; the animal is drawn by its stand-in (the animal built by code) meanwhile.
- **Fetching**: the pack comes from the source (`PackSource`: the web, `HttpPackSource`; or a folder,
  `FolderPackSource`), is checked against the source's `manifest.json` (its size and SHA-256), kept under
  `user://packs`, and loaded. `arrived` then says which files are there, and the farm draws those animals
  again from their own files (`Objects3D.remake`), on the farm and in homes.
- **Kept**: packs on the device are loaded as the game starts, with no network. A pack is named by its own
  hash, so a new make of it is a new file; the old one is removed when the new one arrives.
- **No network, or a bad file**: the fetch is tried again after 30 seconds, doubling to 10 minutes; the player
  is told once a session ("Some animals are still on their way"). Nothing else waits on it.
- **Market pictures** do not need the files: every item's picture is made ahead of time and is in the app.
  A picture that does have to be drawn on the device never fetches a pack (`AssetRegistry.fetches`: only what
  the player owns is worth a download): it shows the stand-in, is not kept, and is made again from the file
  when its pack arrives (`remake` in `scripts/ui/icon_maker.gd`).

## Off until there is an address
`data/packs.json` `base_url` is empty: nothing is fetched and every file ships in the app, as before. To turn
it on (one switch, three places; `packs_test` 584 fails if they disagree):
1. Make the packs: `godot --headless --path . res://tools/make_packs.tscn -- --out=<folder>`, and put the
   folder's contents (the packs and `manifest.json`) anywhere that serves files over https.
2. Set `base_url` in `data/packs.json` to that address.
3. In `export_presets.cfg`, add `art/models/limited/*` to each preset's `exclude_filter` and set
   `permissions/internet=true`.
Make the packs again whenever a limited animal's file changes, and upload them before the app that expects
them is released (old apps keep working: their manifest entries are replaced, and kept packs stay valid).

## Tried, and not
- Tried here: the whole path with the limited folder hidden as an exported app has it, from a folder and from
  a local web server (fetch, check, keep, load, redraw; and a second start with no source). Tests:
  `packs_test` 583 and 584.
- Not tried: a real exported Android build, a real web address, a slow or dropping network, a full device.
- Not built: Google Play's own on-demand packs as a source (a `PackSource` for them would slot in; it needs a
  Play plugin and the Play Console), a progress display, fetching ahead of need.
