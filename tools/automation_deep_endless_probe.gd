extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const ItemDataClass := preload("res://scripts/items/ItemData.gd")

var failures: Array[String] = []
var warnings: Array[String] = []
var lines: Array[String] = []
var kills := 0
var best_item := ""
var best_score := -999999
var start_ticks := 0


func _initialize() -> void:
	start_ticks = Time.get_ticks_msec()
	var save_manager := root.get_node_or_null("SaveManager")
	if save_manager:
		save_manager.call("set_current_account", "qa_deep_endless_probe")
		save_manager.call("delete_save", "qa_deep_endless_probe")
	var inventory := root.get_node_or_null("Inventory")
	if inventory:
		inventory.call("clear")

	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	for _i in range(12):
		await process_frame

	var player := main.get_node_or_null("Player")
	if player == null:
		failures.append("missing Player")
	else:
		await _prepare_level(player, 200)
		for depth in [30, 50, 75, 100, 150, 200]:
			await _probe_depth(main, player, depth)
			player = main.get_node_or_null("Player")
			if player == null:
				failures.append("lost Player after depth %d" % depth)
				break
		await _save_probe(main)
		if player:
			_check_stat_breakpoints(player)

	_report("DEEP_ENDLESS_PROBE_BEGIN")
	_report("elapsed_sec=%0.2f" % (float(Time.get_ticks_msec() - start_ticks) / 1000.0))
	if player:
		_report("level=%d xp=%d/%d ascension=%d highest_portal_depth=%d" % [
			int(player.get("level")),
			int(player.get("xp")),
			int(player.get("xp_to_next_level")),
			int(player.get("ascension_level")),
			int(player.get("highest_portal_depth")),
		])
		_report("hp=%d/%d attack=%d defense=%d speed=%d agility=%d gold=%d" % [
			int(player.get("current_hp")),
			int(player.get("max_hp")),
			int(player.get("attack_damage")),
			int(player.get("defense")),
			int(player.get("move_speed")),
			int(player.get("agility")),
			int(player.get("gold")),
		])
	_report("kills=%d" % kills)
	_report("best_item=%s score=%d" % [best_item, best_score])
	_report("warnings=%s" % ("NONE" if warnings.is_empty() else " | ".join(warnings)))
	_report("failures=%s" % ("NONE" if failures.is_empty() else " | ".join(failures)))
	_report("DEEP_ENDLESS_PROBE_END")
	_write_report()

	main.queue_free()
	await process_frame
	quit(1 if not failures.is_empty() else 0)


func _prepare_level(player: Node, target_level: int) -> void:
	while int(player.get("level")) < target_level:
		var needed := int(player.get("xp_to_next_level")) - int(player.get("xp"))
		player.call("gain_xp", maxi(needed, 1))
		await process_frame


func _probe_depth(main: Node, player: Node, depth: int) -> void:
	var map_id := "endless_portal_%d" % depth
	main.call("_load_map", map_id)
	for _i in range(10):
		await process_frame
	player = main.get_node_or_null("Player")
	if player == null:
		failures.append("%s lost Player" % map_id)
		return

	var enemies := _live_enemies(main)
	if enemies.is_empty():
		failures.append("%s spawned no enemies" % map_id)
		return
	var total_xp := 0
	var max_hp := 0
	for enemy in enemies:
		total_xp += int(enemy.get("xp_value"))
		max_hp = maxi(max_hp, int(enemy.get("max_hp")))
		_score_enemy_loot(enemy)

	var kill_limit := mini(5, enemies.size())
	for i in range(kill_limit):
		await _kill_enemy(player, enemies[i], depth)
	await _pickup_and_equip(main, player)

	var avg_xp := int(round(float(total_xp) / float(enemies.size())))
	var xp_to_next := maxi(1, int(player.get("xp_to_next_level")))
	var projected_kills := int(ceil(float(xp_to_next) / maxf(float(avg_xp), 1.0)))
	_report("depth=%d enemies=%d killed=%d max_enemy_hp=%d avg_xp=%d projected_kills_to_level=%d player_attack=%d speed=%d best_score=%d" % [
		depth,
		enemies.size(),
		kill_limit,
		max_hp,
		avg_xp,
		projected_kills,
		int(player.get("attack_damage")),
		int(player.get("move_speed")),
		best_score,
	])
	if projected_kills > 90:
		warnings.append("depth %d needs about %d kills for one level" % [depth, projected_kills])
	if projected_kills < 3:
		warnings.append("depth %d levels too quickly: about %d kills" % [depth, projected_kills])


func _kill_enemy(player: Node, enemy: Node, depth: int) -> void:
	if not is_instance_valid(enemy):
		return
	player.set("global_position", enemy.get("global_position") + Vector2(30.0, 0.0))
	var attacks := 0
	var limit := 120
	while is_instance_valid(enemy) and enemy.has_method("is_dead") and not enemy.call("is_dead") and attacks < limit:
		player.set("_attack_timer", 0.0)
		player.call("_on_attack_command", enemy)
		for _i in range(3):
			await process_frame
		attacks += 1
	if is_instance_valid(enemy) and enemy.has_method("is_dead") and not enemy.call("is_dead"):
		failures.append("depth %d enemy resisted %d attacks: hp=%d attack=%d" % [
			depth,
			limit,
			int(enemy.get("current_hp")),
			int(player.get("attack_damage")),
		])
	else:
		kills += 1


func _pickup_and_equip(main: Node, player: Node) -> void:
	var dropped := main.get_node_or_null("DroppedItems")
	if dropped:
		for item in dropped.get_children():
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


func _save_probe(main: Node) -> void:
	main.call("_save_current_game", false)
	await process_frame
	var save_manager := root.get_node_or_null("SaveManager")
	if save_manager == null:
		failures.append("missing SaveManager")
		return
	var data: Dictionary = save_manager.call("load_game")
	if data.is_empty():
		failures.append("deep probe save was empty")
	if int(data.get("highest_portal_depth", -1)) < 200:
		failures.append("save lost depth 200")


func _check_stat_breakpoints(player: Node) -> void:
	if int(player.get("move_speed")) > 1800:
		warnings.append("move_speed exceeds controllable range: %d" % int(player.get("move_speed")))
	if int(player.get("attack_damage")) > 2500:
		warnings.append("attack damage likely trivializes combat: %d" % int(player.get("attack_damage")))


func _live_enemies(main: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in main.get_children():
		if child.is_in_group("enemies") and child.has_method("take_damage"):
			if not child.has_method("is_dead") or not child.call("is_dead"):
				result.append(child)
	return result


func _score_item(item) -> void:
	var score := _item_score(item)
	if score > best_score:
		best_score = score
		best_item = "%s [%s/%s +%d]" % [
			String(item.get("name")),
			String(item.get("rarity")),
			String(item.get("rank")),
			int(item.get("upgrade_level")),
		]


func _score_enemy_loot(enemy: Node) -> void:
	for entry in enemy.get("loot_table"):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if String(entry.get("type", "")) != "equip":
			continue
		var def = entry.get("def", {})
		if typeof(def) != TYPE_DICTIONARY:
			continue
		var item = ItemDataClass.create_equipment_from_def(def)
		_score_item(item)


func _item_score(item) -> int:
	if item == null:
		return -999999
	return int(item.get("stat_damage")) * 8 + int(item.get("stat_armor")) * 5 + int(item.get("stat_health")) + int(item.get("stat_speed")) + int(item.get("stat_agility")) * 6 + int(item.get("ascension_power")) * 10


func _report(line: String) -> void:
	lines.append(line)
	print(line)


func _write_report() -> void:
	var file := FileAccess.open(ProjectSettings.globalize_path("res://playtest_eldrath_deep_probe_report.txt"), FileAccess.WRITE)
	if file:
		file.store_string("\n".join(lines))
		file.close()
