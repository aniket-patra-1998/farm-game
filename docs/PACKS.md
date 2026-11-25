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

## On (20 Nov): the Limited tab's Download
The owner: "a download option in the limited tab... it first downloads everything so that placing is seamless;
other games like BGMI do it". So:
- `data/packs.json` `base_url` is this (public) repository's release "packs"; `.github/workflows/packs.yml` makes
  the packs (`tools/make_packs.tscn`) and uploads them there whenever a limited animal's file or the packer
  changes on main (a pack is named by its hash: a new make is a new file).
- The app leaves `art/models/limited/*` out and may use the internet (`export_presets.cfg`; `packs_test` 584).
- The Market's Limited tab opens with a Download card (`HudMarket.download_card`) until every pack is here:
  Download (`AssetPacks.fetch_all`), then a bar of packs come. Until then a limited animal whose file is away
  can't be bought (`BuildingSystem.Why.DOWNLOAD`, said on its card), so no stand-in is drawn for one bought.
  Once here, packs load as the game starts, and a thing bought is carried once its file is read
  (`AssetRegistry.file_ready`). Limited trees need no download: they are built by code.
- Still fetched on their own when first needed: a limited animal already on a farm (a save from before), and
  the showcase's (its stand-in drawn until its pack comes).

## Online (owner, 25 Nov): the game needs the internet; files come from Cloudflare
The owner: the game runs only online, and its files are hosted in the cloud ("if it's not scalable then what
is the point"). The plan, from the research of 25 Nov, in this order, each pushed and tried on the A05s:
1. **The downloader made safe (done 25 Nov, `packs_test` 624).** A retry's wait is jittered (`JITTER`), so phones
   that lost the network together do not all come back in the same second; a pack is fetched only with room for
   it and its copy (`no_room`, "Your phone is almost full"); the manifest says the oldest app its packs work
   with (`_min_app_code`, from data/packs.json `min_app_code`), and an older app asks its player to update
   instead of fetching (`update_needed`); a pack never holds code (`PackMaker.CODE`: Google Play forbids
   downloading code, so every script ships in the app).
2. **Cloudflare Pages (done 25 Nov)**: free with unlimited downloads and no domain to buy (the owner chose it
   over R2, whose free r2.dev address is rate limited and needs a paid domain for production). CI deploys the
   packs to https://farm-game-packs.pages.dev (packs.yml; the token a GitHub secret, never in the app); a pack
   is named by its hash and cached for good, the manifest a minute (`_headers`). Limits: 20,000 files a site,
   25 MiB a file, 500 deploys a month.
3. **Every item's model in a level pack (done 25 Nov, `packs_test` 584, 625).** tools/make_level_packs.py
   writes data/level_packs.json (precheck checks it): animals, trees and buildings past `starter_level` (5) go in
   a pack for their unlock level; what turns up unbought (strays, finds, rare trees) in `extras_N` (split under
   Pages' 25 MiB); crops, blooms, the farmer and the Barn stay in the app. `fetch_ahead` asks every level up to
   the next one at the start and on each level up, extras last; buying an item whose pack is not here yet says
   "still downloading" and fetches it now. Only the Play Store AAB leaves these files out (its exclude_filter,
   written by the tool); the debug and benchmark APKs keep them, so the phone bench draws the same farm, and a
   pack the app already has is never fetched (`in_app`). About 105 MB of source files leave the AAB.
   Still to do for the AAB: it must not ship the showcase's baked models (res://baked, 138 MB in the APK).
4. **Online-only start** (the manifest fetched to start; a dropped connection carries on with a badge).
5. **Cloud save**: Google Play Games saved games (free, 3 MB a save; ours is about 20 KB), with a conflict choice.

## Tried, and not
- Tried here: the whole path with the limited folder hidden as an exported app has it, from a folder and from
  a local web server (fetch, check, keep, load, redraw; and a second start with no source). Tests:
  `packs_test` 583 and 584.
- Not tried: a real exported Android build, a real web address, a slow or dropping network, a full device.
- Not built: Google Play's own on-demand packs as a source (a `PackSource` for them would slot in; it needs a
  Play plugin and the Play Console), a progress display, fetching ahead of need.
