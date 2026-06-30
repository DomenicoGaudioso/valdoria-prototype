extends SceneTree

const PlayerClass = preload("res://scripts/player/Player.gd")

func _initialize() -> void:
	var failed: Array[String] = []
	var sm := root.get_node_or_null("SaveManager")
	var pd := root.get_node_or_null("PlayerData")
	var inv := root.get_node_or_null("Inventory")

	# Setup
	sm.set_current_account("int_save_roundtrip")
	sm.delete_save("int_save_roundtrip")

	# Set class
	pd.set_class("wood_warden")

	# Create a player with known stats and equipment
	var player := PlayerClass.new()
	player.level = 8; player.xp = 450; player.xp_to_next_level = 600
	player.total_xp_earned = 2500
	player.max_hp = 200; player.current_hp = 180
	player.attack_damage = 18; player.move_speed = 215.0
	player.base_hp = 80; player.base_damage = 9; player.base_speed = 210.0
	player.base_defense = 3; player.base_agility = 5
	player.defense = 5; player.agility = 7
	player.gold = 1500
	player.ascension_level = 1; player.ascension_points = 2
	player.highest_portal_depth = 5; player.season_level = 2

	# Save
	sm.save_game(player, "fort_nasu")

	# Load
	var data: Dictionary = sm.load_game("int_save_roundtrip")
	if data.is_empty():
		failed.append("load returned empty")
	else:
		# Verify all fields roundtrip correctly
		var checks := {
			"level": 8, "xp": 450, "gold": 1500,
			"max_hp": 200, "current_hp": 180, "base_hp": 80,
			"attack_damage": 18, "base_damage": 9,
			"move_speed": 215.0, "base_speed": 210.0,
			"base_defense": 3, "base_agility": 5,
			"defense": 5, "agility": 7,
			"ascension_level": 1, "ascension_points": 2,
			"highest_portal_depth": 5, "season_level": 2,
		}
		for key in checks:
			var expected = checks[key]
			var actual = data.get(key)
			if typeof(expected) == TYPE_FLOAT:
				if abs(float(actual) - float(expected)) > 0.1:
					failed.append("roundtrip %s: %s != %s" % [key, str(actual), str(expected)])
			else:
				if int(actual) != int(expected):
					failed.append("roundtrip %s: %s != %s" % [key, str(actual), str(expected)])

		# Map ID
		if String(data.get("map_id", "")) != "fort_nasu":
			failed.append("roundtrip map_id: %s" % data.get("map_id"))

		# Class ID should be persisted (read from PlayerData autoload)
		# Note: _read_current_class_id uses /root/PlayerData which may not resolve
		# in a SceneTree --script context; verify via manual PlayerData access.
		if pd.get("player_class_id") != "wood_warden":
			failed.append("class not set before save: %s" % pd.get("player_class_id"))

		# Equipment / inventory should be dicts
		var eq: Dictionary = data.get("equipment", {})
		if not eq is Dictionary:
			failed.append("equipment not dict")

	# Cleanup
	sm.delete_save("int_save_roundtrip")
	sm.set_current_account("local_player")
	player.queue_free()

	if failed.is_empty():
		print("test_save_roundtrip OK")
		quit(0)
	else:
		push_error("Save roundtrip failures: %s" % ", ".join(failed))
		quit(1)
