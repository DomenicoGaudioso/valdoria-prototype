extends SceneTree

const MAIN_SCENE = preload("res://scenes/main/Main.tscn")
const LOCAL_WORLD = preload("res://scenes/real_world/LocalGltfWorld.tscn")


func _initialize() -> void:
	var failed: Array[String] = []
	var save_manager := root.get_node_or_null("SaveManager")
	if save_manager:
		save_manager.call("set_current_account", "qa_game_over_restart")
		save_manager.call("delete_save", "qa_game_over_restart")
	await _check_classic_game_over(failed)
	await _check_local_3d_game_over(failed)

	paused = false
	if failed.is_empty():
		print("Game over restart smoke test OK")
		quit(0)
	else:
		push_error("Game over restart failures: %s" % ", ".join(failed))
		quit(1)


func _check_classic_game_over(failed: Array[String]) -> void:
	var world := MAIN_SCENE.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	if world.has_method("_load_map"):
		world.call("_load_map", "black_oak_city")
		for _i in range(6):
			await process_frame

	var player := world.get_node_or_null("Player")
	if player == null:
		failed.append("classic missing Player")
	else:
		player.call("take_damage", 999999, null)
		for _i in range(4):
			await process_frame

	var ui := world.get_node_or_null("GameUI")
	_check_overlay(ui, "classic", failed)
	paused = false
	world.queue_free()
	await process_frame


func _check_local_3d_game_over(failed: Array[String]) -> void:
	var world := LOCAL_WORLD.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	if world.has_method("_damage_player"):
		world.call("_damage_player", 9999)
	else:
		failed.append("local 3d missing _damage_player")

	var ui := world.get_node_or_null("LocalMapUI")
	_check_overlay(ui, "local 3d", failed)
	paused = false
	world.queue_free()
	await process_frame


func _check_overlay(ui: Node, label: String, failed: Array[String]) -> void:
	if ui == null:
		failed.append("%s missing UI" % label)
		return
	var overlay := ui.get_node_or_null("GameOverOverlay") as Control
	if overlay == null:
		failed.append("%s missing GameOverOverlay" % label)
		return
	if not overlay.visible:
		failed.append("%s GameOverOverlay not visible" % label)
	var title := overlay.get_node_or_null("Center/VBoxContainer/Title") as Label
	var restart := overlay.get_node_or_null("Center/VBoxContainer/RestartButton") as Button
	if title == null or title.text != "GAME OVER":
		failed.append("%s missing GAME OVER title" % label)
	if restart == null or restart.text != "Riavvia":
		failed.append("%s missing Riavvia button" % label)
	if title and restart and restart.get_index() <= title.get_index():
		failed.append("%s Riavvia button is not below title" % label)
