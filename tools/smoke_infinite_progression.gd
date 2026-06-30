extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const PlayerClass := preload("res://scripts/player/Player.gd")
const ItemDataClass := preload("res://scripts/items/ItemData.gd")


func _initialize() -> void:
	var failed: Array[String] = []
	_check_xp_curve(failed)
	await _check_endless_rewards_and_save(failed)

	if failed.is_empty():
		print("Infinite progression smoke test OK")
		quit(0)
	else:
		push_error("Infinite progression failures: %s" % ", ".join(failed))
		quit(1)


func _check_xp_curve(failed: Array[String]) -> void:
	var player := PlayerClass.new()
	var thresholds := {
		1: 30,
		20: 5000,
		60: 80000,
		100: 250000,
		118: 500000,
		150: 1200000,
		200: 3000000,
	}
	var previous := 30
	for level in range(1, 201):
		var required := previous if level == 1 else int(player.call("_calculate_next_xp_required", level, previous))
		if required < previous and level > 1:
			failed.append("xp requirement decreased at level %d" % level)
		if thresholds.has(level) and required > int(thresholds[level]):
			failed.append("level %d xp_to_next too high: %d" % [level, required])
		previous = required
	player.queue_free()


func _check_endless_rewards_and_save(failed: Array[String]) -> void:
	var save_manager := root.get_node_or_null("SaveManager")
	if save_manager:
		save_manager.call("set_current_account", "qa_infinite_progression")
		save_manager.call("delete_save", "qa_infinite_progression")
	var inventory := root.get_node_or_null("Inventory")
	if inventory:
		inventory.call("clear")

	var world := MAIN_SCENE.instantiate()
	root.add_child(world)
	for _i in range(10):
		await process_frame
	if not world.has_method("_load_map"):
		failed.append("Main missing _load_map")
		world.queue_free()
		await process_frame
		return

	world.call("_load_map", "endless_portal_30")
	for _i in range(10):
		await process_frame
	var current_map: Dictionary = world.get("_current_map")
	if not String(current_map.get("title", "")).contains("Portale Infinito 30 -"):
		failed.append("endless portal title did not include depth variant")
	var player := world.get_node_or_null("Player")
	if player == null:
		failed.append("missing Player")
		world.queue_free()
		await process_frame
		return

	player.set("level", 118)
	player.set("xp", 0)
	player.set("xp_to_next_level", int(player.call("_calculate_next_xp_required", 118, 0)))
	player.set("ascension_level", 18)
	player.set("ascension_points", 18)

	var enemies := _live_enemies(world)
	if enemies.is_empty():
		failed.append("endless_portal_30 spawned no enemies")
	else:
		if enemies.size() < 10:
			failed.append("endless_portal_30 variety wave spawned too few enemies: %d" % enemies.size())
		var total_xp := 0
		for enemy in enemies:
			total_xp += int(enemy.get("xp_value"))
		var projected_35_kills := int(round(float(total_xp) / float(enemies.size()) * 35.0))
		if projected_35_kills < int(player.get("xp_to_next_level")) / 5:
			failed.append("35 depth-30 kills project only %d XP of %d" % [projected_35_kills, int(player.get("xp_to_next_level"))])
		player.call("gain_xp", projected_35_kills)
		if int(player.get("xp")) <= 0 and int(player.get("level")) <= 118:
			failed.append("projected depth reward did not move player progression")

	player.set("level", 200)
	player.set("xp", 0)
	player.set("xp_to_next_level", int(player.call("_calculate_next_xp_required", 200, 0)))
	player.set("ascension_level", 100)
	player.set("ascension_points", 100)
	world.call("_load_map", "procedural6")
	for _i in range(10):
		await process_frame
	player = world.get_node_or_null("Player")
	if player == null:
		failed.append("missing Player after catch-up staging reload")
		world.queue_free()
		await process_frame
		return
	player.set("level", 200)
	player.set("xp", 0)
	player.set("xp_to_next_level", int(player.call("_calculate_next_xp_required", 200, 0)))
	player.set("ascension_level", 100)
	player.set("ascension_points", 100)
	world.call("_load_map", "endless_portal_30")
	for _i in range(10):
		await process_frame
	player = world.get_node_or_null("Player")
	if player == null:
		failed.append("missing Player after level-200 depth-30 reload")
		world.queue_free()
		await process_frame
		return
	player.set("level", 200)
	player.set("xp_to_next_level", int(player.call("_calculate_next_xp_required", 200, 0)))
	player.set("ascension_level", 100)
	player.set("ascension_points", 100)
	var catchup_enemies := _live_enemies(world)
	if catchup_enemies.is_empty():
		failed.append("level-200 depth-30 catch-up spawned no enemies")
	else:
		var catchup_total_xp := 0
		for enemy in catchup_enemies:
			catchup_total_xp += int(enemy.get("xp_value"))
		var catchup_avg_xp := int(round(float(catchup_total_xp) / float(catchup_enemies.size())))
		var projected_kills_to_level := int(ceil(float(player.get("xp_to_next_level")) / maxf(float(catchup_avg_xp), 1.0)))
		if projected_kills_to_level > 120:
			failed.append("level-200 depth-30 catch-up still too slow: %d kills" % projected_kills_to_level)

	if int(player.get("highest_portal_depth")) < 30:
		failed.append("highest_portal_depth did not record real endless map depth")

	var equip = ItemDataClass.create_equipment_from_def({
		"id": "qa_infinite_relic",
		"name": "QA Reliquia Infinita",
		"slot": "relic",
		"rarity": "archontic",
		"value": 1,
		"dmg": 3,
		"def": 3,
		"hp": 12,
		"spd": 1,
		"agi": 2,
		"ascension_power": 4,
	})
	player.call("equip_item", "relic", equip)
	if inventory:
		inventory.call("add_item", ItemDataClass.create_equipment_from_def({
			"id": "qa_infinite_ring",
			"name": "QA Anello Infinito",
			"slot": "ring",
			"rarity": "infinite",
			"value": 1,
			"dmg": 1,
			"def": 1,
			"hp": 8,
			"spd": 1,
			"agi": 2,
		}))

	world.call("_save_current_game", false)
	await process_frame
	if save_manager:
		var data: Dictionary = save_manager.call("load_game")
		if int(data.get("ascension_level", -1)) != int(player.get("ascension_level")):
			failed.append("save/load lost ascension_level")
		if int(data.get("highest_portal_depth", -1)) < 30:
			failed.append("save/load lost highest_portal_depth")
		if typeof(data.get("equipment", null)) != TYPE_DICTIONARY or not (data["equipment"] as Dictionary).has("relic"):
			failed.append("save/load lost equipped relic")
		if typeof(data.get("inventory", null)) != TYPE_ARRAY or (data["inventory"] as Array).is_empty():
			failed.append("save/load lost inventory")

	world.queue_free()
	await process_frame


func _live_enemies(world: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in world.get_children():
		if child.is_in_group("enemies") and child.has_method("take_damage"):
			if not child.has_method("is_dead") or not child.call("is_dead"):
				result.append(child)
	return result
