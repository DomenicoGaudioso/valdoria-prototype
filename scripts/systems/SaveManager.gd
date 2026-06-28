extends Node
## SaveManager — Autoload per salvataggio/caricamento partita in JSON

const SAVE_PATH := "user://valdoria_save.json"

signal game_saved
signal game_loaded


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game(player, map_id: String) -> void:
	var data := {
		"map_id": map_id,
		"level": player.level,
		"xp": player.xp,
		"xp_to_next": player.xp_to_next_level,
		"max_hp": player.max_hp,
		"current_hp": player.current_hp,
		"base_hp": player.base_hp,
		"base_damage": player.base_damage,
		"base_speed": player.base_speed,
		"attack_damage": player.attack_damage,
		"move_speed": player.move_speed,
		"gold": player.gold,
		"equipment": {},
		"inventory": [],
	}

	# Equipment
	for slot in player.equipment:
		var item = player.equipment[slot]
		if item:
			data["equipment"][slot] = {
				"id": item.id, "name": item.name, "slot": item.slot,
				"rarity": item.rarity, "value": item.value,
				"dmg": item.stat_damage, "hp": item.stat_health, "spd": item.stat_speed,
			}

	# Inventory
	var inv := get_node_or_null("/root/Inventory")
	if inv:
		for item in inv.items:
			data["inventory"].append({
				"id": item.id, "name": item.name, "slot": item.get("slot", ""),
				"rarity": item.get("rarity", "common"), "value": item.value,
				"dmg": item.stat_damage, "hp": item.stat_health, "spd": item.stat_speed,
			})

	var json := JSON.stringify(data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json)
		file.close()
		game_saved.emit()
		print("Game saved to: " + SAVE_PATH)


func load_game() -> Dictionary:
	if not has_save():
		return {}

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return {}

	var text := file.get_as_text()
	file.close()

	var data: Dictionary = JSON.parse_string(text)
	if data == null or data.is_empty():
		return {}

	game_loaded.emit()
	print("Game loaded from: " + SAVE_PATH)
	return data


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
