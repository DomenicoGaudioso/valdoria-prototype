extends SceneTree

const MAIN_SCENE = preload("res://scenes/main/Main.tscn")

const REAL_CITY_MAPS: Array[String] = [
	"roma_centro",
	"venezia_rialto",
	"parigi_cite",
	"berlin_mitte_3d",
	"tokyo_shibuya",
]


func _initialize() -> void:
	var failed: Array[String] = []
	for map_id in REAL_CITY_MAPS:
		print("Smoke loading real city gameplay: %s" % map_id)
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
		for i in range(18):
			await process_frame
		_check_city(main, map_id, failed)

		main.queue_free()
		for i in range(4):
			await process_frame

	if failed.is_empty():
		print("Real city gameplay smoke test OK")
		quit(0)
	else:
		push_error("Real city gameplay failures: %s" % ", ".join(failed))
		quit(1)


func _check_city(main: Node, map_id: String, failed: Array[String]) -> void:
	var world := main.get_node_or_null("World")
	var player := main.get_node_or_null("Player")
	var ui := main.get_node_or_null("GameUI")
	var inventory := root.get_node_or_null("Inventory")

	if world == null or world.get_child_count() <= 0:
		failed.append("%s (world not built)" % map_id)
	if player == null:
		failed.append("%s (missing player)" % map_id)
	if ui == null:
		failed.append("%s (missing GameUI)" % map_id)
	if inventory == null:
		failed.append("%s (missing Inventory autoload)" % map_id)

	var enemy_count := 0
	for child in main.get_children():
		if child.is_in_group("enemies") and child.has_method("take_damage"):
			enemy_count += 1
	if enemy_count <= 0:
		failed.append("%s (no enemies spawned)" % map_id)

	if ui and ui.has_method("_toggle_inventory"):
		ui.call("_toggle_inventory")
		var panel := ui.get_node_or_null("InventoryPanel") as Panel
		if panel == null or not panel.visible:
			failed.append("%s (inventory does not open)" % map_id)
		ui.call("_toggle_inventory")
	else:
		failed.append("%s (GameUI cannot toggle inventory)" % map_id)
