extends Node
## The start's first measure: the first autoload, naming no other script, so it runs as soon as the engine is up
## and before game.gd and the ~200 scripts it pulls in are compiled. LoadBenchmark reports it as the start's
## "engine" step, which splits a phone's start into the engine's own setup and the game's script compiling.

const META := &"start_clock_ms"   # (an Engine meta: LoadBenchmark reads it without naming this script)


func _init() -> void:
	Engine.set_meta(META, Time.get_ticks_msec())
