shader_type spatial;
// The same grass lit per corner, not per pixel: the ground is flat, so it looks the same at about 27 ms less a
// frame on a low phone (the low quality level).
render_mode cull_disabled, vertex_lighting;
#include "res://shaders/ground3d.gdshaderinc"
