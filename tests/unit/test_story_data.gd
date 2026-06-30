extends SceneTree

func _initialize() -> void:
	var failed: Array[String] = []

	var sd := root.get_node_or_null("StoryData")
	if not sd:
		failed.append("StoryData autoload not found")

	# Heroes: 5 defined, each must have class_ref and archon_rival
	var heroes: Array = sd.get("HEROES") as Array
	if heroes.size() < 5:
		failed.append("expected >=5 heroes, got %d" % heroes.size())

	var hero_ids := ["kael_morvant", "seren_veyra", "brann_kord", "nyra_solen", "elios_var"]
	for hid in hero_ids:
		var h: Dictionary = sd.get_hero(hid)
		if h.is_empty():
			failed.append("get_hero(%s) empty" % hid)
			continue
		if String(h.get("name", "")).is_empty():
			failed.append("%s missing name" % hid)
		if String(h.get("class_ref", "")).is_empty():
			failed.append("%s missing class_ref" % hid)
		if String(h.get("archon_rival", "")).is_empty():
			failed.append("%s missing archon_rival" % hid)
		# Hero->class mapping must exist in ClassData/PlayerData
		var pd := root.get_node_or_null("PlayerData")
		if pd:
			var cr: String = h.get("class_ref", "")
			var hero_class: Dictionary = pd.get_class_info() if pd else {}
			pd.set_class(cr)
			var matched: Dictionary = pd.get_class_info()
			if String(matched.get("id", "")) != cr:
				failed.append("%s class_ref %s not found" % [hid, cr])

	# get_hero_by_class
	var hbc: Dictionary = sd.get_hero_by_class("shadow_blade")
	if String(hbc.get("id", "")) != "seren_veyra":
		failed.append("get_hero_by_class shadow_blade -> %s" % hbc.get("id"))

	hbc = sd.get_hero_by_class("winged_ascendant")
	# No hero for winged_ascendant (expected empty)
	if not hbc.is_empty():
		failed.append("winged_ascendant should have no hero, got %s" % hbc.get("id"))

	# Archons: 5 defined
	var archons: Array = sd.get("ARCHONS") as Array
	if archons.size() < 5:
		failed.append("expected >=5 archons, got %d" % archons.size())
	for a in archons:
		var aid: String = a.get("id", "")
		if String(a.get("name", "")).is_empty():
			failed.append("archon %s missing name" % aid)
		if String(a.get("arena", "")).is_empty():
			failed.append("archon %s missing arena" % aid)

	# get_archon / get_archon_for_hero
	var ga: Dictionary = sd.get_archon("vhar_mor")
	if String(ga.get("name", "")) != "Vhar-Mor":
		failed.append("get_archon vhar_mor -> %s" % ga.get("name"))

	var gah: Dictionary = sd.get_archon_for_hero("kael_morvant")
	if String(gah.get("id", "")) != "vhar_mor":
		failed.append("get_archon_for_hero kael -> %s" % gah.get("id"))

	# Level bands
	for lv in [5, 25, 55, 75, 95]:
		var band: Dictionary = sd.get_level_band(lv)
		if band.is_empty():
			failed.append("no level band for level %d" % lv)

	# Seasons
	var s1: Dictionary = sd.get_season_for_level(10)
	var s5: Dictionary = sd.get_season_for_level(120)
	if s1.is_empty() or s5.is_empty():
		failed.append("get_season_for_level returned empty")

	if failed.is_empty():
		print("test_story_data OK")
		quit(0)
	else:
		push_error("StoryData failures: %s" % ", ".join(failed))
		quit(1)
