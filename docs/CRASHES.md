# Crashes: how we find out

- **CrashWatch** (`scripts/systems/crash_watch.gd`): a flag file (`user://running.flag`) is up while the game is in
  front and removed when it goes away properly (paused, closed). A flag found at start means the last session crashed
  (or was killed while in front). The end of that run's log is kept as `user://logs/last_crash.txt`, counted
  (PlayerSettings `crash`), and sent as one critical error event when GameAnalytics has its keys.
- **The log on the phone**: `debug/file_logging/enable_file_logging=true` (Godot's own rotated log, `user://logs`,
  5 kept), so the last run's log survives the crash.
- **Settings > About > Copy**: copies the crash count, the last crash's log and the end of this run's log, to paste
  into a message (testers, the owner).
- **Play Console, Android vitals**: native crashes and ANRs (freezes) of installs from Play, with stack traces, at no
  cost and with no code of ours. The first stop once the closed test runs.
- Script errors of every session already go to GameAnalytics (Analytics.ErrorTap).
- **Found 28 Nov (start check, 2 GB emulator):** a configuration change Godot's manifest does not list made Android
  remake the game's activity; Godot could not make its Vulkan surface again ("Couldn't create Android Surface",
  "Unable to create DisplayServer") and quit. The phone build now lists every configuration change in the manifest
  (apk.yml, the build template step), so the activity is never remade.
