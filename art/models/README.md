Models made as files (glTF `.glb`), one per item, listed in `data/assets.json`. See `docs/ASSETS.md` for the
conventions (1 unit = 1 tile, origin at the footprint's centre on the ground, facing +X, states named
`when_<state>_<value>`) and `docs/ART_BIBLE.md` for the look. Godot makes their levels of detail and shadow
meshes on import.

The crops and trees here are written by the builder: from `tools/animal_art`, run
`python3 -m animal_art export ../../art/models`. They are committed, with their `.import` files, until CI has a
step that builds them (docs/ASSETS.md §11 wants generated files built, not committed).
