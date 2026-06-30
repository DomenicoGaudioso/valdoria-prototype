extends SceneTree

const PlayerClass = preload("res://scripts/player/Player.gd")

func _initialize() -> void:
	var failed: Array[String] = []
	var sm := root.get_node_or_null("SaveManager")
	if not sm:
		failed.append("SaveManager autoload not found")
	else:
		# Sanitize account
		var sid: String = sm.sanitize_account_id("Test Account!@#")
		if sid != "test_account___":
			failed.append("sanitize Test Account!@# -> %s (expected test_account___)" % sid)

		# Default account
		if sm.get_current_account() != "local_player":
			failed.append("default account should be local_player: %s" % sm.get_current_account())

		# set_current_account and file path
		sm.set_current_account("unit_test_p0")
		if sm.get_current_account() != "unit_test_p0":
			failed.append("set_current_account not persisted: %s" % sm.get_current_account())
		var spath: String = sm.get_save_path()
		if not spath.contains("unit_test_p0"):
			failed.append("save path wrong: %s" % spath)

		# has_save on account with no file -> false
		sm.delete_save("unit_test_p0")
		if sm.has_save("unit_test_p0"):
			failed.append("has_save should be false for nonexistent save")

		# Serialize / deserialize roundtrip
		var player := PlayerClass.new()
		player.level = 5; player.xp = 200; player.xp_to_next_level = 300
		player.max_hp = 150; player.current_hp = 140
		player.attack_damage = 15; player.move_speed = 220.0
		player.base_hp = 120; player.base_damage = 12; player.base_speed = 200.0
		player.base_defense = 5; player.base_agility = 10
		player.defense = 7; player.agility = 12
		player.gold = 500
		player.ascension_level = 2; player.ascension_points = 3
		player.highest_portal_depth = 10; player.season_level = 3
		player.total_xp_earned = 2500

		sm.save_game(player, "black_oak_city")

		var data: Dictionary = sm.load_game("unit_test_p0")
		if data.is_empty():
			failed.append("load_game returned empty after save")
		else:
			if int(data.get("level", 0)) != 5:
				failed.append("roundtrip level: %d" % int(data.get("level", 0)))
			if int(data.get("gold", 0)) != 500:
				failed.append("roundtrip gold: %d" % int(data.get("gold", 0)))
			if String(data.get("map_id", "")) != "black_oak_city":
				failed.append("roundtrip map_id: %s" % data.get("map_id"))
			if int(data.get("ascension_level", 0)) != 2:
				failed.append("roundtrip ascension: %d" % int(data.get("ascension_level", 0)))

		# Cleanup
		sm.delete_save("unit_test_p0")

		# Restore default account
		sm.set_current_account("local_player")

	if failed.is_empty():
		print("test_save_manager OK")
		quit(0)
	else:
		push_error("SaveManager failures: %s" % ", ".join(failed))
		quit(1)
