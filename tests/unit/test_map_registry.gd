extends SceneTree

const MapRegistry = preload("res://data/MapRegistry.gd")

func _initialize() -> void:
	var failed: Array[String] = []

	var maps: Array[Dictionary] = MapRegistry.get_all_maps()
	if maps.size() < 35:
		failed.append("expected >=35 maps, got %d" % maps.size())

	# Count unique IDs — no duplicates
	var ids: Dictionary = {}
	var portal_graph: Dictionary = {}  # id -> [target_ids]
	var titles: Dictionary = {}  # title -> count

	for m in maps:
		var mid: String = m["id"]
		if ids.has(mid):
			failed.append("duplicate map id: %s" % mid)
		ids[mid] = true

		var title: String = m.get("title", "")
		if title.is_empty():
			failed.append("%s missing title" % mid)

		if titles.has(title):
			titles[title] += 1
		else:
			titles[title] = 1

		if not m.has("portals"):
			failed.append("%s missing portals" % mid)
			continue
		var portals: Array = m["portals"]
		var targets: Array = []
		for pv in portals:
			var p: Dictionary = pv
			var target: String = p.get("target", "")
			if target.is_empty():
				failed.append("%s portal has no target" % mid)
			if not p.has("pos"):
				failed.append("%s portal missing pos" % mid)
			if not p.has("label"):
				failed.append("%s portal missing label" % mid)
			targets.append(target)
		portal_graph[mid] = targets

		# Each map must have hero_spawn
		var spawn: Vector2 = m.get("hero_spawn", Vector2.ZERO)
		if spawn == Vector2.ZERO:
			failed.append("%s missing hero_spawn" % mid)

		# Data field must exist
		if not m.has("data"):
			failed.append("%s missing data field" % mid)

	# Duplicate titles check (warn only, some procedural maps share titles)
	var dup_titles := 0
	for t in titles:
		if int(titles[t]) > 1:
			dup_titles += 1
	if dup_titles > 12:
		failed.append("too many duplicate titles: %d" % dup_titles)

	# Portal graph checks: every target should exist as a map
	for mid in portal_graph:
		for target in portal_graph[mid]:
			if not ids.has(target) and not target.begins_with("endless_portal_"):
				failed.append("portal %s -> %s (target not found)" % [mid, target])

	# get_map: valid and invalid
	var gm: Dictionary = MapRegistry.get_map("black_oak_farm")
	if String(gm.get("id", "")) != "black_oak_farm":
		failed.append("get_map black_oak_farm: %s" % gm.get("id"))

	var gm2: Dictionary = MapRegistry.get_map("nonexistent")
	if String(gm2.get("id", "")) == "nonexistent":
		failed.append("get_map nonexistent should return first map")

	# Tileset types
	var tilesets: Dictionary = {}
	for m in maps:
		var ts: String = m.get("tileset", "")
		tilesets[ts] = tilesets.get(ts, 0) + 1
	for ts in tilesets:
		if not ts in ["grassland", "snowplains", "dungeon"]:
			failed.append("unknown tileset: %s" % ts)

	if failed.is_empty():
		print("test_map_registry OK")
		quit(0)
	else:
		push_error("MapRegistry failures: %s" % ", ".join(failed))
		quit(1)
