extends SceneTree

## Verifica che le mappe wilderness (grassland), dungeon e snowplains si carichino
## correttamente dopo l'estrazione modulare (TilesetMapper + AtmosphereBuilder).

const MAIN_SCENE = preload("res://scenes/main/Main.tscn")

const MAPS: Array[String] = [
	"black_oak_farm",   # grassland
	"fort_nasu",        # dungeon
	"grot_lagoon",      # snowplains
	"st_maria_3",       # dungeon profondo
]


func _initialize() -> void:
	var failed: Array[String] = []
	for map_id in MAPS:
		print("Smoke loading map: %s" % map_id)
		var main := MAIN_SCENE.instantiate()
		root.add_child(main)
		for i in range(10):
			await process_frame

		if not main.has_method("_load_map"):
			failed.append("%s (missing _load_map)" % map_id)
			main.queue_free()
			await process_frame
			continue
		main.call("_load_map", map_id)
		for i in range(16):
			await process_frame
		_check_map(main, map_id, failed)
		main.queue_free()
		for i in range(4):
			await process_frame

	if failed.is_empty():
		print("Wilderness/dungeon/snowplains smoke test OK")
		quit(0)
	else:
		push_error("Map load failures: %s" % ", ".join(failed))
		quit(1)


func _check_map(main: Node, map_id: String, failed: Array[String]) -> void:
	var world := main.get_node_or_null("World")
	var player := main.get_node_or_null("Player")
	if world == null or world.get_child_count() <= 0:
		failed.append("%s (world not built)" % map_id)
	if player == null:
		failed.append("%s (missing player)" % map_id)

	var enemy_count := 0
	for child in main.get_children():
		if child.is_in_group("enemies") and child.has_method("take_damage"):
			enemy_count += 1
	if enemy_count <= 0:
		failed.append("%s (no enemies spawned)" % map_id)

	# La mappa deve avere almeno un portale visivo (Rift_*) e dettagli terreno.
	if not _has_descendant_named(world, "MapGroundDetails") and not _has_descendant_named(world, "AmbientMotes"):
		failed.append("%s (missing atmosphere layers)" % map_id)
	var has_portal := false
	for child in main.get_children():
		if child is Node2D and String(child.name).begins_with("Rift_"):
			has_portal = true
			break
	if not has_portal:
		failed.append("%s (no portals spawned)" % map_id)


func _has_descendant_named(node: Node, expected_name: String) -> bool:
	if node.name == expected_name:
		return true
	for child in node.get_children():
		if _has_descendant_named(child, expected_name):
			return true
	return false
