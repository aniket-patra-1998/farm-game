#!/usr/bin/env bash
# The economy audit: every play-bot style on two seeds and the first hour, each checked against
# data/sim_targets.json. Prints each run's verdict and exits 1 if any target is missed (owner, 19-20 Nov:
# "nothing should get missed by the audit bot"). The Economy audit workflow runs it; locally:
#   tools/audit.sh <godot> [days]        (default 45 days; a run of a style takes a few minutes)
set -u
GODOT="${1:-godot}"
DAYS="${2:-45}"
OUT="${AUDIT_OUT:-audit_out}"
mkdir -p "$OUT"
fail=0
run() {   # name, args...
	local name="$1"; shift
	"$GODOT" --headless --path . res://tools/balance_sim.tscn -- "$@" > "$OUT/$name.log" 2>&1
	local verdict
	verdict=$(grep -E "^(targets: |TARGETS MISSED)" "$OUT/$name.log" | tail -1)
	if [ -z "$verdict" ] || grep -q "SCRIPT ERROR" "$OUT/$name.log"; then
		verdict="TARGETS MISSED: the run did not finish (see $OUT/$name.log)"
	fi
	echo "$name: $verdict"
	case "$verdict" in TARGETS*) fail=1 ;; esac
}
for s in 1 2; do
	run "first_hour_seed$s" --first-hour --seed=$s
	for style in plain goals casual builder crafter; do
		run "${style}_seed$s" --days="$DAYS" --visits=3 --minutes=5 --seed=$s --style=$style
	done
done
exit $fail
