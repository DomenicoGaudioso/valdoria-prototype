extends SceneTree

const BossLoreClass = preload("res://data/BossLore.gd")

func _initialize() -> void:
	var failed: Array[String] = []

	# Bosses defined
	var bosses := BossLoreClass.BOSSES
	if bosses.size() < 5:
		failed.append("expected >=5 bosses, got %d" % bosses.size())

	for bid in ["skeleton_odran", "crystal_queen", "forge_golem", "void_predator", "library_keeper"]:
		var b: Dictionary = BossLoreClass.get_boss(bid)
		if b.is_empty():
			failed.append("get_boss(%s) empty" % bid)
			continue
		if String(b.get("name", "")).is_empty():
			failed.append("%s missing name" % bid)
		if (b.get("phases") as Array).size() < 1:
			failed.append("%s no phases" % bid)
		if (b.get("loot_table") as Dictionary).is_empty():
			failed.append("%s no loot_table" % bid)
		# Each boss has suggested_maps
		if (b.get("suggested_maps") as Array).is_empty():
			failed.append("%s no suggested_maps" % bid)

	# get_boss_by_map
	var bm: Array = BossLoreClass.get_boss_by_map("black_oak_farm")
	if bm.is_empty():
		failed.append("get_boss_by_map black_oak_farm returned empty")

	# get_bosses_by_category
	var bc: Array = BossLoreClass.get_bosses_by_category("non_morti")
	if bc.size() < 2:
		failed.append("get_bosses_by_category non_morti: %d" % bc.size())

	# World bosses
	var wb: Dictionary = BossLoreClass.get_world_boss("ancient_dragon")
	if String(wb.get("name", "")) != "Drago Primordiale":
		failed.append("get_world_boss ancient_dragon -> %s" % wb.get("name"))

	# Mirror clones: 1 per class (6 total)
	var clones := BossLoreClass.MIRROR_CLONES
	if clones.size() < 6:
		failed.append("expected >=6 mirror clones, got %d" % clones.size())
	for class_id in clones:
		var mc: Dictionary = BossLoreClass.get_mirror_clone(class_id)
		if String(mc.get("name", "")).is_empty():
			failed.append("mirror clone %s missing name" % class_id)

	# generate_boss_from_enemy
	var gen: Dictionary = BossLoreClass.generate_boss_from_enemy("skeleton_odran", 1.0)
	if gen.is_empty():
		failed.append("generate_boss_from_enemy skeleton_odran failed")
	else:
		if not gen.has("current_phase"):
			failed.append("generated boss missing current_phase")
		if int(gen.get("current_phase", -1)) != 0:
			failed.append("generated boss current_phase != 0")

	if failed.is_empty():
		print("test_boss_lore OK")
		quit(0)
	else:
		push_error("BossLore failures: %s" % ", ".join(failed))
		quit(1)
