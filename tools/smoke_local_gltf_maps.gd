extends SceneTree

const LOCAL_MAPS = preload("res://data/LocalGltfMapRegistry.gd")


func _initialize() -> void:
	var failed: Array[String] = []
	for map_id in LOCAL_MAPS.get_ids():
		var map_data: Dictionary = LOCAL_MAPS.get_map(map_id)
		var model_path: String = map_data.get("model_path", "")
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var err: Error = document.append_from_file(model_path, state)
		if err != OK:
			failed.append("%s (%s)" % [map_id, error_string(err)])
			continue
		var scene := document.generate_scene(state)
		if scene:
			scene.free()
		print("Local glTF OK: %s" % map_id)
	if failed.is_empty():
		print("Local glTF smoke test OK")
		quit(0)
	else:
		push_error("Local glTF failed: %s" % ", ".join(failed))
		quit(1)
