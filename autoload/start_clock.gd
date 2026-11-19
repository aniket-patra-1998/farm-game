class_name StartMarks
extends Node
## The start's first measure: the first autoload, naming no other script, so it runs as soon as the engine is up
## and before game.gd and the ~200 scripts it pulls in are compiled. LoadBenchmark reports it as the start's
## "engine" step, which splits a phone's start into the engine's own setup and the game's script compiling.
## The start's later steps are marked here too (`mark`), so the start-up scripts never name the debug tools
## (LoadBenchmark), which the first screen does not need compiled (docs/PERF_RUN.md, the start).

const META := &"start_clock_ms"   # (an Engine meta: LoadBenchmark reads it without naming this script)
const BENCHMARK := "res://scripts/debug/load_benchmark.gd"   # loaded by path, only by the benchmark build
const BENCHMARK_FEATURE := "benchmark"   # not-ui (the export feature tag of the build that measures itself)

## When the start's steps were done, in ms since the engine began (mark): see LoadBenchmark.start_marks.
static var _marks := {}


func _init() -> void:
	Engine.set_meta(META, Time.get_ticks_msec())


## Notes that the start reached `step` now, the first time only (a farm made again later is not the start; a
## few calls, cheap, every build).
static func mark(step: String) -> void:
	if not _marks.has(step):
		_marks[step] = Time.get_ticks_msec()


## The start's steps so far, with the engine's own ("engine").
static func marks() -> Dictionary:
	var out := _marks.duplicate()
	if Engine.has_meta(META):
		out["engine"] = int(Engine.get_meta(META))
	return out


## Whether this build runs the benchmark by itself on start (the benchmark APK).
static func benchmark_wanted() -> bool:
	return OS.has_feature(BENCHMARK_FEATURE)
