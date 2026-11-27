# The Play Store listing's pictures

Owner, 27 Nov: picked style B of three shown: a caption band over the game.

- **What is in `store/`.** Eight screenshots (`1_landmarks.jpg` ... `8_market.jpg`, 1920x1080 JPEG, in the
  listing's order) and `feature_graphic.png` (1024x500, no alpha). Google Play wants the feature graphic, at
  least two screenshots (up to eight), and a preview video only as a YouTube link.
- **How they are made.** `tools/store_shots.tscn` takes the raw pictures from the showcase farm with the
  interface hidden (and one of the Market), so they show the game as it is; `tools/make_store_art.py` puts each
  under its caption. Run again whenever the look of the game changes:

      xvfb-run godot --rendering-method gl_compatibility --path . res://tools/store_shots.tscn -- --hour=16
      xvfb-run godot --rendering-method gl_compatibility --path . res://tools/store_shots.tscn -- \
          --hour=20.5 --views=landmarks --suffix=_night
      python3 tools/make_store_art.py

- **Captions** are in `make_store_art.py` (`SHOTS`). They say what is in the picture; Google refuses "best",
  "free", "#1" and the like. They are English only for now.
- **The preview video** (`store/preview.mp4`, 20 seconds, 1280x720, with the game's own music and ambience,
  all CC0 or made here: art/sound/SOURCES.md; not kept in git: upload it to
  YouTube and give Play the link). `tools/store_film.tscn` films slow passes over the showcase farm with Godot's
  movie writer and prints where each scene starts; `tools/make_store_film.py` cuts them under the same captions
  and adds an end card:

      xvfb-run godot --rendering-method gl_compatibility --fixed-fps 30 --resolution 1280x720 \
          --write-movie /tmp/day.avi --path . res://tools/store_film.tscn -- --hour=16
      xvfb-run godot ... --write-movie /tmp/night.avi ... -- --hour=20.5 --scenes=landmarks
      python3 tools/make_store_film.py /tmp/day.avi /tmp/night.avi landmarks=55,crops=180,...,landmarks_night=58

- `store/` has a `.gdignore`: none of it goes into the game.
- **The icon.** `python3 tools/make_app_icon.py` draws it (shapes, not a picture of the game): the barn at
  dusk, its window and open door alight and the light spilling over the field; a windmill, a tree, a cow and a
  horse dark against the setting sun, a sheep and a pig in the field, sunflowers in the near corners. It writes
  `store/icon_512.png` for the listing and `art/app_icon/` for the app itself: `icon.png` (project.godot) and
  the two layers of Android's adaptive icon, set in every export preset. The owner turned down pictures of the
  Barn and two bright cartoon icons (a cow's face; four animals before the barn: "too immature"), and picked
  this style from a sheet of four (27 Nov).
- **Not done.** Pictures for tablets (the same ones are accepted).
