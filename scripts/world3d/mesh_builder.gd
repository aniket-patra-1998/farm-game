class_name MeshBuilder
extends RefCounted
## Builds one mesh out of many small shapes, each with its own vertex colour: boxes, ellipsoids, cones,
## blades. Used where many shapes should cost one draw (a crop plant drawn hundreds of times through a
## MultiMesh). Every triangle is wound so its front faces out (Godot draws clockwise-from-outside
## fronts), with smooth or flat normals as each shape needs.

var _st := SurfaceTool.new()
var _empty := true


func _init() -> void:
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)


func commit() -> ArrayMesh:
	if _empty:
		# An empty mesh can't be drawn: give it one invisible, degenerate triangle.
		tri(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.UP, Color(0, 0, 0, 0))
	return _st.commit()


## One triangle with a flat normal `n`, wound to face along it. `col.a` is free for the shader's use.
func tri(a: Vector3, b: Vector3, c: Vector3, n: Vector3, col: Color) -> void:
	_empty = false
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
	for v: Vector3 in [a, b, c]:
		_st.set_color(col)
		_st.set_normal(n)
		_st.add_vertex(v)


## A triangle with its own normal at each corner (for smooth shapes), wound to face along their mean.
func tri_smooth(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, col: Color) -> void:
	_empty = false
	var n := na + nb + nc
	var verts := [[a, na], [b, nb], [c, nc]]
	if (b - a).cross(c - a).dot(n) > 0.0:
		verts = [[a, na], [c, nc], [b, nb]]
	for v: Array in verts:
		_st.set_color(col)
		_st.set_normal(v[1])
		_st.add_vertex(v[0])


## A box from `xf` (its basis scales a unit cube centred on the origin).
func box(xf: Transform3D, col: Color) -> void:
	var c := [Vector3(-0.5, -0.5, -0.5), Vector3(0.5, -0.5, -0.5), Vector3(0.5, 0.5, -0.5), Vector3(-0.5, 0.5, -0.5),
		Vector3(-0.5, -0.5, 0.5), Vector3(0.5, -0.5, 0.5), Vector3(0.5, 0.5, 0.5), Vector3(-0.5, 0.5, 0.5)]
	var quads := [[0, 1, 2, 3, Vector3.FORWARD], [4, 5, 6, 7, Vector3.BACK], [0, 4, 7, 3, Vector3.LEFT],
		[1, 5, 6, 2, Vector3.RIGHT], [3, 2, 6, 7, Vector3.UP], [0, 1, 5, 4, Vector3.DOWN]]
	for q: Array in quads:
		var n: Vector3 = (xf.basis * q[4]).normalized()
		var p := [xf * (c[q[0]] as Vector3), xf * (c[q[1]] as Vector3), xf * (c[q[2]] as Vector3), xf * (c[q[3]] as Vector3)]
		tri(p[0], p[1], p[2], n, col)
		tri(p[0], p[2], p[3], n, col)


## An ellipsoid centred on `c` with half-sizes `r`, smooth shaded.
func ellipsoid(c: Vector3, r: Vector3, col: Color, seg := 8, rings := 5) -> void:
	for i in rings:
		var t0 := PI * i / rings
		var t1 := PI * (i + 1) / rings
		for j in seg:
			var p0 := TAU * j / seg
			var p1 := TAU * (j + 1) / seg
			var u := [_sph(t0, p0), _sph(t0, p1), _sph(t1, p1), _sph(t1, p0)]
			var v := []
			var n := []
			for d: Vector3 in u:
				v.append(c + d * r)
				n.append((d / r).normalized() if r.x > 0.0 and r.y > 0.0 and r.z > 0.0 else d)
			if i > 0:
				tri_smooth(v[0], v[1], v[2], n[0], n[1], n[2], col)
			if i < rings - 1:
				tri_smooth(v[0], v[2], v[3], n[0], n[2], n[3], col)


static func _sph(theta: float, phi: float) -> Vector3:
	return Vector3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi))


## A cone (or a tapered cylinder) standing on `base`, `h` tall, radius `r0` at the bottom and `r1` on top.
func cone(base: Vector3, r0: float, r1: float, h: float, col: Color, seg := 7, top_col := Color(0, 0, 0, -1)) -> void:
	var tc := col if top_col.a < 0.0 else top_col
	var slope := (r0 - r1) / maxf(h, 0.0001)
	for j in seg:
		var a0 := TAU * j / seg
		var a1 := TAU * (j + 1) / seg
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var n0 := (d0 + Vector3(0, slope, 0)).normalized()
		var n1 := (d1 + Vector3(0, slope, 0)).normalized()
		var b0 := base + d0 * r0
		var b1 := base + d1 * r0
		var t0 := base + Vector3(0, h, 0) + d0 * r1
		var t1 := base + Vector3(0, h, 0) + d1 * r1
		_st_quad_smooth(b0, b1, t1, t0, n0, n1, n1, n0, col, tc)


func _st_quad_smooth(a: Vector3, b: Vector3, c: Vector3, d: Vector3, na: Vector3, nb: Vector3, nc: Vector3,
		nd: Vector3, col: Color, top: Color) -> void:
	_empty = false
	var outward := na + nb + nc + nd
	var verts := [[a, na, col], [b, nb, col], [c, nc, top], [a, na, col], [c, nc, top], [d, nd, top]]
	if (b - a).cross(c - a).dot(outward) > 0.0:
		verts = [[a, na, col], [c, nc, top], [b, nb, col], [a, na, col], [d, nd, top], [c, nc, top]]
	for v: Array in verts:
		_st.set_color(v[2])
		_st.set_normal(v[1])
		_st.add_vertex(v[0])


## A leaf or blade: a flat, double-sided strip from `base` toward `tip`, `w` wide at its widest, curving
## by `bend` (sideways sag); its colour shades from `col` at the base to `tip_col`.
func blade(base: Vector3, tip: Vector3, w: float, col: Color, tip_col: Color, bend := Vector3.ZERO) -> void:
	var axis := tip - base
	var side := axis.cross(Vector3.UP)
	if side.length() < 0.001:
		side = Vector3.RIGHT
	side = side.normalized() * w / 2.0
	var mid := base + axis * 0.5 + bend
	var n := side.cross(axis).normalized()
	var pts := [base, mid + side, tip, mid - side]
	var cols := [col, col.lerp(tip_col, 0.5), tip_col, col.lerp(tip_col, 0.5)]
	for face_n: Vector3 in [n, -n]:
		for t: Array in [[0, 1, 2], [0, 2, 3]]:
			var a: Vector3 = pts[t[0]]
			var b: Vector3 = pts[t[1]]
			var c: Vector3 = pts[t[2]]
			var order := [t[0], t[1], t[2]]
			if (b - a).cross(c - a).dot(face_n) > 0.0:
				order = [t[0], t[2], t[1]]
			for k: int in order:
				_st.set_color(cols[k])
				_st.set_normal(face_n)
				_st.add_vertex(pts[k])
	_empty = false
