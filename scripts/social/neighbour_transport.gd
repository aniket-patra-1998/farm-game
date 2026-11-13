class_name NeighbourTransport
extends RefCounted
## The seam between the inbox and whoever is on the other end. SocialSystem owns the mail and the rules;
## a transport only says who the neighbours are, what they send you over a stretch of time, and how they
## answer something you posted. SimulatedNeighbours is the single-player one; real friends would be another
## class with the same three functions, and nothing else would change.


## The neighbours' names, by index (the index is what `from` and `by` hold).
func roster() -> Array[String]:
	return []


## What neighbours send you between `from_t` and `to_t` (unix seconds): new items without ids, each with its
## own time `t`, oldest first.
func incoming(_from_t: int, _to_t: int) -> Array[Dictionary]:
	return []


## How neighbours will answer `post` posted at `now`: [{by, due, give}], each answer arriving at `due`.
func answers_for(_post: Dictionary, _now: int) -> Array[Dictionary]:
	return []
