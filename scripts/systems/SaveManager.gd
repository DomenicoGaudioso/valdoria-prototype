extends Node
## SaveManager - salvataggi JSON separati per account/profilo.

const SAVE_DIR := "user://account_saves"
const LEGACY_SAVE_PATH := "user://valdoria_save.json"
const DEFAULT_ACCOUNT_ID := "local_player"

signal game_saved(account_id: String, save_path: String)
signal game_loaded(account_id: String, save_path: String)

var current_account_id: String = DEFAULT_ACCOUNT_ID


func _ready() -> void:
	current_account_id = _resolve_start_account_id()
	_ensure_save_dir()


func _resolve_start_account_id() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--account="):
			return sanitize_account_id(arg.get_slice("=", 1))
	var env_account := OS.get_environment("ARCONTI_ACCOUNT_ID")
	if not env_account.is_empty():
		return sanitize_account_id(env_account)
	return DEFAULT_ACCOUNT_ID


func set_current_account(account_id: String) -> void:
	current_account_id = sanitize_account_id(account_id)


func get_current_account() -> String:
	return current_account_id


func sanitize_account_id(account_id: String) -> String:
	var raw := account_id.strip_edges().to_lower()
	if raw.is_empty():
		raw = DEFAULT_ACCOUNT_ID
	var allowed := "abcdefghijklmnopqrstuvwxyz0123456789._-"
	var result := ""
	for i in range(raw.length()):
		var ch := raw.substr(i, 1)
		if allowed.find(ch) >= 0:
			result += ch
		else:
			result += "_"
	return result if not result.is_empty() else DEFAULT_ACCOUNT_ID


func _ensure_save_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))


func get_save_path(account_id: String = "") -> String:
	var safe_id := sanitize_account_id(account_id if not account_id.is_empty() else current_account_id)
	return "%s/%s.json" % [SAVE_DIR, safe_id]


func has_save(account_id: String = "") -> bool:
	var target_account := sanitize_account_id(account_id if not account_id.is_empty() else current_account_id)
	if FileAccess.file_exists(get_save_path(target_account)):
		return true
	return target_account == DEFAULT_ACCOUNT_ID and FileAccess.file_exists(LEGACY_SAVE_PATH)


func save_game(player, map_id: String) -> void:
	_ensure_save_dir()
	var save_path := get_save_path()
	var data := {
		"schema_version": 2,
		"account_id": current_account_id,
		"saved_at_unix": Time.get_unix_time_from_system(),
		"map_id": map_id,
		"level": player.level,
		"xp": player.xp,
		"xp_to_next": player.xp_to_next_level,
		"total_xp_earned": player.get("total_xp_earned"),
		"ascension_level": player.get("ascension_level"),
		"ascension_points": player.get("ascension_points"),
		"highest_portal_depth": player.get("highest_portal_depth"),
		"season_level": player.get("season_level"),
		"max_hp": player.max_hp,
		"current_hp": player.current_hp,
		"base_hp": player.base_hp,
		"base_damage": player.base_damage,
		"base_speed": player.base_speed,
		"base_defense": player.get("base_defense"),
		"base_agility": player.get("base_agility"),
		"attack_damage": player.attack_damage,
		"move_speed": player.move_speed,
		"defense": player.get("defense"),
		"agility": player.get("agility"),
		"gold": player.gold,
		"equipment": {},
		"inventory": [],
	}

	for slot in player.equipment:
		var item = player.equipment[slot]
		if item:
			data["equipment"][slot] = _serialize_item(item)

	var inv := get_node_or_null("/root/Inventory")
	if inv:
		for item in inv.items:
			data["inventory"].append(_serialize_item(item))

	var previous := _read_save_file(save_path)
	if previous.is_empty() and FileAccess.file_exists(LEGACY_SAVE_PATH):
		previous = _read_save_file(LEGACY_SAVE_PATH)
	data = _protect_highest_progress(data, previous)

	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		game_saved.emit(current_account_id, save_path)
		print("Game saved to: " + save_path)


func load_game(account_id: String = "") -> Dictionary:
	var target_account := sanitize_account_id(account_id if not account_id.is_empty() else current_account_id)
	var save_path := get_save_path(target_account)
	if not FileAccess.file_exists(save_path) and target_account == DEFAULT_ACCOUNT_ID and FileAccess.file_exists(LEGACY_SAVE_PATH):
		save_path = LEGACY_SAVE_PATH
	if not FileAccess.file_exists(save_path):
		return {}

	var data := _read_save_file(save_path)
	if data.is_empty():
		return {}

	if account_id.is_empty() and data.has("account_id"):
		current_account_id = sanitize_account_id(str(data.get("account_id", current_account_id)))
	game_loaded.emit(current_account_id, save_path)
	print("Game loaded from: " + save_path)
	return data


func delete_save(account_id: String = "") -> void:
	var save_path := get_save_path(account_id)
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


func _read_save_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed as Dictionary


func _serialize_item(item) -> Dictionary:
	var tint_value = _item_get(item, "visual_tint", Color.WHITE)
	var tint: Color = tint_value if tint_value is Color else Color.WHITE
	return {
		"id": _item_get(item, "id", ""),
		"name": _item_get(item, "name", "Oggetto"),
		"slot": _item_get(item, "slot", ""),
		"rarity": _item_get(item, "rarity", "common"),
		"value": _item_get(item, "value", 0),
		"dmg": _item_get(item, "stat_damage", 0),
		"def": _item_get(item, "stat_armor", 0),
		"hp": _item_get(item, "stat_health", 0),
		"spd": _item_get(item, "stat_speed", 0),
		"agi": _item_get(item, "stat_agility", 0),
		"mat": _item_get(item, "material_tag", ""),
		"tint": [tint.r, tint.g, tint.b, tint.a],
		"effect": _item_get(item, "effect_id", ""),
		"efx_val": _item_get(item, "effect_value", 0.0),
		"flavor": _item_get(item, "flavor_text", ""),
		"corrupt": _item_get(item, "corrupted", false),
		"corr_text": _item_get(item, "corruption_text", ""),
		"set_id": _item_get(item, "set_id", ""),
		"rank": _item_get(item, "rank", "E"),
		"upgrade_level": _item_get(item, "upgrade_level", 0),
		"ascension_power": _item_get(item, "ascension_power", 0),
		"soulbound": _item_get(item, "soulbound", false),
	}


func _item_get(item, property_name: String, default_value = null):
	if item == null:
		return default_value
	var value = item.get(property_name)
	return default_value if value == null else value


func _protect_highest_progress(data: Dictionary, previous: Dictionary) -> Dictionary:
	if previous.is_empty():
		return data

	var previous_level := int(previous.get("level", 1))
	var current_level := int(data.get("level", 1))
	if previous_level > current_level:
		for key in [
			"level", "xp", "xp_to_next", "total_xp_earned",
			"ascension_level", "ascension_points", "highest_portal_depth",
			"season_level", "max_hp", "current_hp", "base_hp",
			"base_damage", "base_speed", "base_defense", "base_agility",
			"attack_damage", "move_speed", "defense", "agility",
			"gold", "equipment", "inventory"
		]:
			if previous.has(key):
				data[key] = previous[key]
		data["map_id"] = data.get("map_id", previous.get("map_id", "black_oak_city"))
	return data
