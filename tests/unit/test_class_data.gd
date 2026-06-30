extends SceneTree

const PlayerData = preload("res://scripts/progression/ClassData.gd")

func _initialize() -> void:
	var failed: Array[String] = []

	var all := PlayerData.new().get_all_classes()
	if all.size() != 6:
		failed.append("expected 6 classes, got %d" % all.size())

	var expected := {
		"arena_champion":  {"hp": 120, "dmg": 12, "spd": 190.0},
		"shadow_blade":   {"hp": 75,  "dmg": 8,  "spd": 240.0},
		"wood_warden":    {"hp": 80,  "dmg": 9,  "spd": 210.0},
		"battle_arcanist":{"hp": 70,  "dmg": 7,  "spd": 200.0},
		"crimson_heir":   {"hp": 85,  "dmg": 8,  "spd": 220.0},
		"winged_ascendant":{"hp": 90, "dmg": 9,  "spd": 210.0},
	}

	for cinfo in all:
		var cid: String = cinfo["id"]
		if not expected.has(cid):
			failed.append("unknown class %s" % cid)
			continue
		var exp: Dictionary = expected[cid]
		var bs: Dictionary = cinfo.get("base_stats", {})
		if int(bs.get("max_hp", 0)) != int(exp["hp"]):
			failed.append("%s hp %d != %d" % [cid, int(bs.get("max_hp", 0)), int(exp["hp"])])
		if int(bs.get("attack_damage", 0)) != int(exp["dmg"]):
			failed.append("%s dmg %d != %d" % [cid, int(bs.get("attack_damage", 0)), int(exp["dmg"])])
		if abs(float(bs.get("move_speed", 0)) - float(exp["spd"])) > 0.01:
			failed.append("%s spd %.1f != %.1f" % [cid, float(bs.get("move_speed", 0)), float(exp["spd"])])
		# Verify class has required fields
		if String(cinfo.get("playstyle", "")).is_empty():
			failed.append("%s missing playstyle" % cid)
		if String(cinfo.get("armor_type", "")).is_empty():
			failed.append("%s missing armor_type" % cid)

	# Test set_class / get_class_info
	var pd2 := PlayerData.new()
	pd2.set_class("shadow_blade")
	var info: Dictionary = pd2.get_class_info()
	if String(info.get("id", "")) != "shadow_blade":
		failed.append("set_class shadow_blade -> id=%s" % info.get("id"))
	if String(info.get("name", "")) != "Lama d'Ombra":
		failed.append("set_class name mismatch: %s" % info.get("name"))

	pd2.set_class("arena_champion");
	var info2 := pd2.get_class_info()
	if String(info2.get("name", "")) != "Campione delle Arene":
		failed.append("re-set_class name mismatch: %s" % info2.get("name"))

	# Unknown class should not crash
	pd2.set_class("invalid_class")
	var info3 := pd2.get_class_info()
	if String(info3.get("id", "")) != "arena_champion":
		failed.append("set_class invalid should preserve previous class, got %s" % info3.get("id"))

	if failed.is_empty():
		print("test_class_data OK")
		quit(0)
	else:
		push_error("ClassData failures: %s" % ", ".join(failed))
		quit(1)
