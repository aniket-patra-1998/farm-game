class_name IsoProjection
extends RefCounted
## The one place that knows how the 3D farm lines up with the 2D farm grid.
##
## The 3D world is one unit per tile: a tile at (row, col) covers x in [col, col + 1] and z in [row, row + 1],
## with the ground at y = 0. It's seen by an orthographic camera turned 45 degrees and tilted 30 degrees
## down, which is exactly the 2:1 isometric view the 2D grid uses (FarmGrid.TILE_W x TILE_H diamonds). So
## a point on the farm lands on the same screen pixel in both, and everything 2D (taps, highlights,
## floating coins, count signs) keeps working on top of the 3D world unchanged.

const PITCH := PI / 6.0                      # 30 degrees down: tiles are twice as wide as they are tall
const PX_PER_UNIT := FarmGrid.TILE_W / 1.4142135623730951  # a tile's diagonal is TILE_W pixels
const HEIGHT_PX := PX_PER_UNIT * 0.8660254037844386        # pixels a unit of height rises on screen
const CAMERA_DISTANCE := 80.0


## The direction the camera looks: down and toward the back corner of the farm.
static func forward() -> Vector3:
	return Vector3(-cos(PITCH) / 1.4142135623730951, -sin(PITCH), -cos(PITCH) / 1.4142135623730951)


## A point in FarmGrid's local 2D space, as a point on the 3D ground (y = 0).
static func ground_of(p: Vector2) -> Vector3:
	var u := p.x / (FarmGrid.TILE_W / 2.0)   # col - row
	var v := p.y / (FarmGrid.TILE_H / 2.0)   # col + row
	return Vector3((u + v) / 2.0, 0.0, (v - u) / 2.0)


## A 3D point, as a point in FarmGrid's local 2D space.
static func grid_of(p: Vector3) -> Vector2:
	return Vector2((p.x - p.z) * FarmGrid.TILE_W / 2.0, (p.x + p.z) * FarmGrid.TILE_H / 2.0 - p.y * HEIGHT_PX)


## The centre of a tile on the ground.
static func tile_centre(row: float, col: float) -> Vector3:
	return Vector3(col + 0.5, 0.0, row + 0.5)


## Aims an orthographic camera so it shows what a 2D camera centred on `centre` (FarmGrid local space)
## at `zoom` shows, on a screen `screen_h` pixels high.
static func aim(camera: Camera3D, centre: Vector2, zoom: float, screen_h: float) -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = screen_h / (PX_PER_UNIT * maxf(zoom, 0.0001))
	var target := ground_of(centre)
	camera.look_at_from_position(target - forward() * CAMERA_DISTANCE, target, Vector3.UP)
