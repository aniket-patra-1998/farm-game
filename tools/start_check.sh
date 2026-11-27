#!/bin/sh
# The player APK started on an emulator and watched (CI: apk.yml's start-check, start-check.yml): prints whether it
# is still running after a minute and the log lines that say why it died (crash, memory, script errors).
# docs/CRASHES.md. Needs adb with one device, the APK at $1.
APK="${1:-barnlight-player.apk}"
PKG=com.aniketpatra.barnlight
adb install -r "$APK"
adb logcat -c
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null
sleep 75
adb logcat -d -v time > player-start.log || true
{
  if grep -q "WIN DEATH.*$PKG\|Process $PKG .* has died\|$PKG.*app died" player-start.log; then
    echo "NOT RUNNING: the game died"
  else
    echo "STARTED: the game is still running after 75 s"
  fi
  echo "--- why (crash, memory, errors) ---"
  grep -E "F DEBUG|F libc|Fatal signal|SIGSEGV|SIGABRT|backtrace|#[0-9]+ pc|lmkd|lowmemorykiller|Kill '|killing|OutOfMemory|FATAL|E godot|SCRIPT ERROR|ANR in|has died" player-start.log | grep -v "E godot   :    at:" | head -120
  echo "--- the game's last lines ---"
  grep -E "godot|Godot" player-start.log | tail -40
} | tee start-check.txt
adb shell cat /proc/meminfo | head -3
