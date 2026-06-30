extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const ItemDataClass := preload("res://scripts/items/ItemData.gd")

var failures: Array[String] = []
var visited: Array[String] = []
var kills := 0
var best_item_name := ""
var best_item_score := -999999
var most_advanced_map := ""
var start_ticks := 0
var report_lines: Array[String] = []


func _initialize() -> void:
	start_ticks = Time.get_ticks_msec()
	var save_manager := root.get_node_or_null("SaveManager")
	if save_manager:
		save_manager.call("set_current_account", "qa_playtest_eldrath_notturno")
		save_manager.call("delete_save", "qa_playtest_eldrath_notturno")
	var inventory := root.get_node_or_null("Inventory")
	if inventory:
		inventory.call("clear")

	var world := MAIN_SCENE.instantiate()
	root.add_child(world)
	for _i in range(12):
		await process_frame

	await _exercise_runtime(world)

	var player := world.get_node_or_null("Player")
	_report("PLAYTEST_RESULT_BEGIN")
	_report("elapsed_sec=%0.2f" % (float(Time.get_ticks_msec() - start_ticks) / 1000.0))
	_report("visited=%s" % ", ".join(visited))
	_report("most_advanced_map=%s" % most_advanced_map)
	_report("kills=%d" % kills)
	if player:
		_report("level=%d" % int(player.get("level")))
		_report("xp=%d/%d" % [int(player.get("xp")), int(player.get("xp_to_next_level"))])
		_report("ascension=%d" % int(player.get("ascension_level")))
		_report("highest_portal_depth=%d" % int(player.get("highest_portal_depth")))
		_report("gold=%d" % int(player.get("gold")))
		_report("hp=%d/%d dead=%s" % [int(player.get("current_hp")), int(player.get("max_hp")), str(player.call("is_dead"))])
		_report("attack=%d defense=%d speed=%d agility=%d" % [
			int(player.get("attack_damage")),
			int(player.get("defense")),
			int(player.get("move_speed")),
			int(player.get("agility")),
		])
	_report("best_item=%s score=%d" % [best_item_name, best_item_score])
	_report("failures=%s" % ("NONE" if failures.is_empty() else " | ".join(failures)))
	_report("PLAYTEST_RESULT_END")
	_write_report_file()

	world.queue_free()
	await process_frame
	quit(1 if failures.size() > 0 else 0)


func _exercise_runtime(world: Node) -> void:
	_check_xp_curve_sanity(world)
	await _visit_map(world, "black_oak_city", 7)
	await _inventory_roundtrip(world)
	await _save_load_roundtrip(world)
	await _death_restart_check(world)
	await _mobile_signal_check(world)

	var route := [
		"roma_centro", "venezia_rialto", "parigi_cite", "berlin_mitte_3d",
		"tokyo_shibuya", "cyberpunk", "lowpoly_night", "postwar_city",
		"ruined_city", "procedural2", "procedural3", "procedural4",
		"procedural5", "procedural6",
	]
	for map_id in route:
		await _visit_map(world, map_id, 5)

	await _endless_progression_probe(world, 118)
	for depth in range(7, 31):
		await _visit_map(world, "endless_portal_%d" % depth, 3)
	await _save_load_roundtrip(world)


func _visit_map(world: Node, map_id: String, kill_limit: int) -> void:
	if not world.has_method("_load_map"):
		failures.append("Main missing _load_map")
		return
	world.call("_load_map", map_id)
	most_advanced_map = map_id
	visited.append(map_id)
	for _i in range(8):
		await process_frame
	var player := world.get_node_or_null("Player")
	if player == null:
		failures.append("%s missing Player" % map_id)
		return
	var enemies := _live_enemies(world)
	if enemies.is_empty():
		failures.append("%s spawned no enemies" % map_id)
	var limit: int = mini(kill_limit, enemies.size())
	for i in range(limit):
		var enemy := enemies[i]
		if not is_instance_valid(enemy):
			continue
		await _kill_enemy_with_simulated_attacks(world, player, enemy)
	await _pickup_and_equip(world, player)
	_check_portals(world, map_id)


func _kill_enemy_with_simulated_attacks(world: Node, player: Node, enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return
	player.set("global_position", enemy.get("global_position") + Vector2(28.0, 0.0))
	if player.has_method("_on_move_command"):
		player.call("_on_move_command", enemy.get("global_position"))
	await process_frame
	var attacks := 0
	while is_instance_valid(enemy) and enemy.has_method("is_dead") and not enemy.call("is_dead") and attacks < 80:
		player.set("_attack_timer", 0.0)
		if player.has_method("_on_attack_command"):
			player.call("_on_attack_command", enemy)
		for _i in range(3):
			await process_frame
		attacks += 1
	if is_instance_valid(enemy) and enemy.has_method("is_dead") and not enemy.call("is_dead"):
		failures.append("enemy resisted 80 simulated attacks: %s hp=%s" % [enemy.name, str(enemy.get("current_hp"))])
	else:
		kills += 1
	for _i in range(6):
		await process_frame


func _pickup_and_equip(world: Node, player: Node) -> void:
	var dropped := world.get_node_or_null("DroppedItems")
	if dropped:
		for item in dropped.get_children():
			if item == null:
				continue
			item.set("global_position", player.get("global_position"))
			if item.has_signal("body_entered"):
				item.emit_signal("body_entered", player)
	for _i in range(3):
		await process_frame
	var inventory := root.get_node_or_null("Inventory")
	if inventory == null:
		failures.append("missing Inventory autoload")
		return
	for item in inventory.get("items"):
		if item == null:
			continue
		_score_item(item)
		var slot := String(item.get("slot"))
		if slot.is_empty():
			continue
		var equipment: Dictionary = player.get("equipment")
		var current = equipment.get(slot)
		if current == null or _item_score(item) > _item_score(current):
			inventory.call("remove_item", item)
			player.call("equip_item", slot, item)
			await process_frame


func _inventory_roundtrip(world: Node) -> void:
	var player := world.get_node_or_null("Player")
	var ui := world.get_node_or_null("GameUI")
	var inventory := root.get_node_or_null("Inventory")
	if player == null or ui == null or inventory == null:
		failures.append("inventory roundtrip missing node")
		return
	var item = ItemDataClass.create_equipment_from_def({
		"id": "qa_blade",
		"name": "QA Lama",
		"slot": "weapon",
		"rarity": "rare",
		"value": 1,
		"dmg": 12,
		"def": 0,
		"hp": 0,
		"spd": 5,
		"agi": 1,
	})
	inventory.call("add_item", item)
	if ui.has_method("_toggle_inventory"):
		ui.call("_toggle_inventory")
		await process_frame
		var panel := ui.get_node_or_null("InventoryPanel") as Panel
		if panel == null or not panel.visible:
			failures.append("inventory panel did not open")
		ui.call("_toggle_inventory")
	player.call("equip_item", "weapon", item)
	_score_item(item)
	if int(player.get("attack_damage")) < int(player.get("base_damage")) + 12:
		failures.append("equipped weapon damage not applied")


func _save_load_roundtrip(world: Node) -> void:
	var save_manager := root.get_node_or_null("SaveManager")
	var player := world.get_node_or_null("Player")
	var inventory := root.get_node_or_null("Inventory")
	if save_manager == null or player == null:
		failures.append("save/load missing node")
		return
	var before_level := int(player.get("level"))
	var before_gold := int(player.get("gold"))
	var before_ascension := int(player.get("ascension_level"))
	var before_depth := int(player.get("highest_portal_depth"))
	if inventory and inventory.get("items").is_empty():
		var item = ItemDataClass.create_equipment_from_def({
			"id": "qa_save_ring",
			"name": "QA Anello Salvataggio",
			"slot": "ring",
			"rarity": "rare",
			"value": 1,
			"dmg": 0,
			"def": 1,
			"hp": 8,
			"spd": 1,
			"agi": 2,
		})
		inventory.call("add_item", item)
	world.call("_save_current_game", false)
	await process_frame
	var data: Dictionary = save_manager.call("load_game")
	if data.is_empty():
		failures.append("load_game returned empty save")
		return
	if int(data.get("level", -1)) < before_level:
		failures.append("save lost level")
	if int(data.get("gold", -1)) < before_gold:
		failures.append("save lost gold")
	if int(data.get("ascension_level", -1)) != before_ascension:
		failures.append("save lost ascension_level")
	if int(data.get("highest_portal_depth", -1)) != before_depth:
		failures.append("save lost highest_portal_depth")
	if not data.has("equipment") or typeof(data["equipment"]) != TYPE_DICTIONARY:
		failures.append("save missing equipment dictionary")
	if not data.has("inventory") or typeof(data["inventory"]) != TYPE_ARRAY or data["inventory"].is_empty():
		failures.append("save missing inventory contents")


func _death_restart_check(world: Node) -> void:
	var player := world.get_node_or_null("Player")
	var ui := world.get_node_or_null("GameUI")
	if player == null or ui == null:
		failures.append("death check missing node")
		return
	player.call("take_damage", 999999, null)
	await process_frame
	await process_frame
	var overlay := ui.get_node_or_null("GameOverOverlay") as Control
	if overlay == null or not overlay.visible:
		failures.append("death did not show GameOverOverlay")
	paused = false
	world.call("_load_map", "black_oak_city")
	for _i in range(6):
		await process_frame


func _mobile_signal_check(world: Node) -> void:
	var controls := world.get_node_or_null("MobileControls")
	var input_controller := root.get_node_or_null("InputController")
	var player := world.get_node_or_null("Player")
	if controls != null:
		failures.append("MobileControls visible on desktop headless")
	if input_controller == null or player == null:
		failures.append("mobile signal check missing node")
		return
	if input_controller.has_method("_on_joystick_move"):
		input_controller.call("_on_joystick_move", Vector2.RIGHT)
		await process_frame
		input_controller.call("_on_joystick_move", Vector2.ZERO)
	if input_controller.has_method("_on_mobile_attack"):
		input_controller.call("_on_mobile_attack")
	if input_controller.has_method("_on_mobile_inventory"):
		input_controller.call("_on_mobile_inventory")
	await process_frame


func _endless_progression_probe(world: Node, target_level: int) -> void:
	var player := world.get_node_or_null("Player")
	if player == null:
		failures.append("progression probe missing Player")
		return
	while int(player.get("level")) < target_level:
		var needed := int(player.get("xp_to_next_level")) - int(player.get("xp"))
		player.call("gain_xp", maxi(needed, 1))
		await process_frame
	if int(player.get("ascension_level")) <= 0:
		failures.append("level >100 did not grant ascension")
	if int(player.get("xp_to_next_level")) > 500000:
		failures.append("level %d xp_to_next too high: %d" % [target_level, int(player.get("xp_to_next_level"))])
	world.call("_load_map", "endless_portal_30")
	for _i in range(8):
		await process_frame
	player = world.get_node_or_null("Player")
	if player == null:
		failures.append("progression probe lost Player after depth load")
		return
	var enemies := _live_enemies(world)
	if enemies.is_empty():
		failures.append("progression probe depth 30 spawned no enemies")
	else:
		var total_xp := 0
		for enemy in enemies:
			total_xp += int(enemy.get("xp_value"))
		var simulated_kills := 35
		var projected_gain := int(round(float(total_xp) / float(enemies.size()) * float(simulated_kills)))
		if projected_gain < int(player.get("xp_to_next_level")) / 5:
			failures.append("depth 30 projected XP from %d kills too low: %d/%d" % [simulated_kills, projected_gain, int(player.get("xp_to_next_level"))])
	var deep_item = ItemDataClass.generate_random_loot(14)
	var found_infinite := false
	for entry in deep_item:
		if typeof(entry) == TYPE_DICTIONARY and String(entry.get("type", "")) == "equip":
			var item = ItemDataClass.create_equipment_from_def(entry["def"])
			_score_item(item)
			if String(item.get("rarity")) in ["archontic", "infinite"]:
				found_infinite = true
	if not found_infinite:
		failures.append("depth 14 loot did not produce archontic/infinite equipment in probe")


func _check_xp_curve_sanity(world: Node) -> void:
	var player := world.get_node_or_null("Player")
	if player == null:
		failures.append("xp curve sanity missing Player")
		return
	var targets := {
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
			failures.append("xp curve decreased at level %d" % level)
		if targets.has(level) and required > int(targets[level]):
			failures.append("level %d xp_to_next too high: %d > %d" % [level, required, int(targets[level])])
		previous = required


func _check_portals(world: Node, map_id: String) -> void:
	var portals: Array = world.get("_portals")
	if portals.is_empty():
		failures.append("%s has no portals" % map_id)
	for p in portals:
		if not p.has("target") or String(p["target"]).is_empty():
			failures.append("%s portal without target" % map_id)
		if not p.has("node") or p["node"] == null:
			failures.append("%s portal without node" % map_id)


func _live_enemies(world: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in world.get_children():
		if child.is_in_group("enemies") and child.has_method("take_damage"):
			if not child.has_method("is_dead") or not child.call("is_dead"):
				result.append(child)
	return result


func _score_item(item) -> void:
	var score := _item_score(item)
	if score > best_item_score:
		best_item_score = score
		best_item_name = "%s [%s/%s]" % [String(item.get("name")), String(item.get("rarity")), String(item.get("rank"))]


func _item_score(item) -> int:
	if item == null:
		return -999999
	return int(item.get("stat_damage")) * 8 + int(item.get("stat_armor")) * 5 + int(item.get("stat_health")) + int(item.get("stat_speed")) + int(item.get("stat_agility")) * 6 + int(item.get("ascension_power")) * 10


func _report(line: String) -> void:
	report_lines.append(line)
	print(line)


func _write_report_file() -> void:
	var path := ProjectSettings.globalize_path("res://playtest_eldrath_notturno_report.txt")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string("\n".join(report_lines))
		file.close()
