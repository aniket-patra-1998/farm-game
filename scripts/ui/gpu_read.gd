class_name GpuRead
extends RefCounted
## Reading a drawn SubViewport back without stopping the frame (our own engineering): on the Forward+ and Mobile
## renderers the picture is copied off the graphics chip in the background (RenderingDevice's async read) and
## `done` gets the Image a frame or two later; on the Compatibility renderer (no RenderingDevice) it is read at
## once (`get_image`, which waits for the chip), as before. A plain `get_image` there stalls the whole frame.

const MAX_WAIT := 30   # frames a background read may take before the picture is read the plain way


## Reads `vp`'s last drawing; `done` (Image or null) is called later, or at once without a RenderingDevice.
static func take(vp: SubViewport, done: Callable) -> void:
	var rd := RenderingServer.get_rendering_device()
	var rid := RenderingServer.texture_get_rd_texture(vp.get_texture().get_rid()) if rd != null else RID()
	if rd == null or not rid.is_valid():
		done.call(vp.get_texture().get_image())
		return
	var fmt := rd.texture_get_format(rid)
	if not fmt.format in [RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM, RenderingDevice.DATA_FORMAT_R8G8B8A8_SRGB]:
		done.call(vp.get_texture().get_image())   # (an unusual format: read the plain way)
		return
	var w := int(fmt.width)
	var h := int(fmt.height)
	var state := {"done": false}   # (whichever comes first, the read or the wait running out, answers)
	var err := rd.texture_get_data_async(rid, 0, func(data: PackedByteArray) -> void:
		if state["done"]:
			return
		state["done"] = true
		done.call(Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data) if data.size() == w * h * 4 else null))
	if err != OK:
		state["done"] = true
		done.call(vp.get_texture().get_image())
		return
	_fall_back(vp, done, state)


## A read that hasn't come after MAX_WAIT frames is taken the plain way, so a picture is never left blank.
static func _fall_back(vp: SubViewport, done: Callable, state: Dictionary) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for i in MAX_WAIT:
		await tree.process_frame
		if state["done"]:
			return
	state["done"] = true
	done.call(vp.get_texture().get_image() if is_instance_valid(vp) else null)
