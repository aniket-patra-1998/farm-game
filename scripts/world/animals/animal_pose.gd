class_name AnimalPose
extends RefCounted
## One frame of an animal's body: where it is in its walk, where its head is, what its eyes, ears, tail
## and wings are doing. AnimalBehaviour writes it every frame; AnimalArt draws from it. A fresh pose is
## the animal standing still, head up, eyes open: what menus, previews and the art references show.

var time := 0.0      ## seconds this animal has been alive on screen (for small idle motions)
var gait := 0.0      ## 0..1 through one walk cycle; advances with distance walked, so feet never slide
var stride := 0.0    ## 0 standing .. 1 walking: blends the legs between rest and the walk cycle
var head := 0.0      ## 0 head up .. 1 head down (grazing, pecking, rooting)
var look := 0.0      ## -1..1: the head tilts up or down a little while the animal looks around
var jaw := 0.0       ## -1..1 chewing
var blink := 0.0     ## 0 open .. 1 shut
var ear := 0.0       ## 0 at rest .. 1 mid-flick
var tail := 0.0      ## radians the tail swings from its rest angle
var breath := 0.0    ## -1..1, the slow rise and fall of the body
var wing := 0.0      ## birds: 0 folded .. 1 fully open
var display := 0.0   ## turkeys: 0 tail down .. 1 fanned out
var hop := 0.0       ## rabbits: 0 on the ground .. 1 top of a hop


## A pose for something shown still: the same for every frame, so pictures can be compared.
static func rest() -> AnimalPose:
	return AnimalPose.new()
