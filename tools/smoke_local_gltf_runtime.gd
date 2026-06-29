extends SceneTree

const LOCAL_MAPS = preload("res://data/LocalGltfMapRegistry.gd")
const LOCAL_WORLD = preload("res://scenes/real_world/LocalGltfWorld.tscn")


func _initialize() -> void:
	var world := LOCAL_WORLD.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	var failed: Array[String] = []
	for map_id in LOCAL_MAPS.get_ids():
		print("Runtime loading local map: %s" % map_id)
		if not world.has_method("load_local_map"):
			failed.append("%s (controller missing load_local_map)" % map_id)
			continue
		world.load_local_map(map_id)
		await process_frame
		await process_frame
		await physics_frame
		var map_root := world.get_node_or_null("ImportedLocalMap")
		var player := world.get_node_or_null("Player")
		if map_root == null:
			failed.append("%s (missing ImportedLocalMap)" % map_id)
		elif map_root.get_child_count() == 0:
			failed.append("%s (empty ImportedLocalMap)" % map_id)
		if player == null:
			failed.append("%s (missing Player)" % map_id)
		if world.has_method("get_spawn_count") and world.get_spawn_count() <= 0:
			failed.append("%s (no gameplay spawn points)" % map_id)
		if world.has_method("get_collision_count") and world.get_collision_count() <= 0:
			failed.append("%s (no blocking collisions)" % map_id)
		var expected_enemies: int = int(LOCAL_MAPS.get_map(map_id).get("enemy_count", 6))
		if world.has_method("get_enemy_count"):
			var enemy_count: int = world.get_enemy_count()
			if enemy_count < expected_enemies:
				failed.append("%s (enemy count %d/%d)" % [map_id, enemy_count, expected_enemies])
		else:
			failed.append("%s (controller missing enemy counter)" % map_id)
		if world.has_method("debug_gameplay_probe"):
			var probe: Dictionary = world.debug_gameplay_probe()
			if not bool(probe.get("ok", false)):
				failed.append("%s (gameplay probe failed: %s)" % [map_id, str(probe)])
			elif not bool(probe.get("attack_started", false)):
				failed.append("%s (attack did not start)" % map_id)
			elif not bool(probe.get("player_moved", false)):
				failed.append("%s (player did not move during gameplay probe)" % map_id)
			print("Runtime map OK: %s spawns=%d enemies=%d collisions=%d hp=%d" % [
				map_id,
				int(probe.get("spawn_count", 0)),
				int(probe.get("enemy_count", 0)),
				int(probe.get("collision_count", 0)),
				int(probe.get("player_hp", 0)),
			])
		else:
			failed.append("%s (controller missing gameplay probe)" % map_id)

	world.queue_free()
	await process_frame

	if failed.is_empty():
		print("Local glTF runtime smoke test OK")
		quit(0)
	else:
		push_error("Local glTF runtime failures: %s" % ", ".join(failed))
		quit(1)
