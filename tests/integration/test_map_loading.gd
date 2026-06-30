extends SceneTree

const MAIN_SCENE = preload("res://scenes/main/Main.tscn")
const MAPS: Array[String] = ["black_oak_farm", "fort_nasu", "grot_lagoon", "roma_centro", "endless_portal_7"]

func _initialize() -> void:
	var failed: Array[String] = []

	for map_id in MAPS:
		var main := MAIN_SCENE.instantiate()
		root.add_child(main)

		# Force new game by calling load_map directly
		for i in range(8):
			await process_frame

		if main.has_method("_load_map"):
			main.call("_load_map", map_id)
			for i in range(16):
				await process_frame

			# World must be built with tiles
			var world := main.get_node_or_null("World") as Node2D
			if world == null or world.get_child_count() <= 0:
				failed.append("%s (world not built)" % map_id)

			# Player must exist and have stats
			var player := main.get_node_or_null("Player")
			if player == null:
				failed.append("%s (missing player)" % map_id)
			else:
				if int(player.get("max_hp")) <= 0:
					failed.append("%s (invalid player hp)" % map_id)
				if float(player.get("move_speed")) <= 0.0:
					failed.append("%s (invalid player speed)" % map_id)

			# Enemies must spawn
			var enemy_count := 0
			for child in main.get_children():
				if child.is_in_group("enemies") and child.has_method("take_damage"):
					enemy_count += 1
			if enemy_count <= 0:
				failed.append("%s (no enemies spawned)" % map_id)

			# Portal nodes (Rift_*)
			var portal_count := 0
			for child in main.get_children():
				if child is Node2D and String(child.name).begins_with("Rift_"):
					portal_count += 1
			if portal_count <= 0:
				failed.append("%s (no portals)" % map_id)

			# Atmosphere layers
			var has_atmo := false
			for child in world.get_children():
				if String(child.name) in ["MapHorizonSilhouette", "MapGroundDetails", "AmbientMotes"]:
					has_atmo = true
					break
			if not has_atmo:
				failed.append("%s (missing atmosphere layers)" % map_id)

		main.queue_free()
		for i in range(4):
			await process_frame

	if failed.is_empty():
		print("test_map_loading OK")
		quit(0)
	else:
		push_error("Map loading failures: %s" % ", ".join(failed))
		quit(1)
