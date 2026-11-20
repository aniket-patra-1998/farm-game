class_name HttpPackSource
extends PackSource
## Asset packs from the web: each file is downloaded straight to its place on the device.

const TIMEOUT := 60.0   # seconds a download may stall before it is given up (AssetPacks tries again later)

var base: String
var _host: Node   # the node the requests live under


func _init(base_url: String, host: Node) -> void:
	base = base_url.trim_suffix("/")
	_host = host


func fetch(name: String, to: String, done: Callable) -> void:
	var request := HTTPRequest.new()
	request.download_file = to
	request.timeout = TIMEOUT
	_host.add_child(request)
	request.request_completed.connect(
		func(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
			request.queue_free()
			done.call(result == HTTPRequest.RESULT_SUCCESS and code == HTTPClient.RESPONSE_OK))
	if request.request("%s/%s" % [base, name]) != OK:
		request.queue_free()
		done.call(false)
