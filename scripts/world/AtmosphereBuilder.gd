class_name AtmosphereBuilder
extends RefCounted

## AtmosphereBuilder — estrae da GameBootstrap la costruzione dell'atmosfera
## scenica (tint, vignette, motes, horizon, dettagli terreno wilderness/endless).
## Stato condiviso e utility (profile/color/noise/iso) restano nell'host.

var host: Node


func _init(h: Node = null) -> void:
	host = h


func build_scene_atmosphere() -> void:
	var mood := get_scene_mood()

	var tint := CanvasModulate.new()
	tint.name = "SceneTint"
	tint.color = mood.get("canvas", Color(0.88, 0.93, 1.0, 1.0))
	host.add_child(tint)

	add_ambient_motes(
		mood.get("mote_color", Color(0.55, 0.82, 1.0, 0.26)),
		int(mood.get("mote_count", 42))
	)
	add_screen_vignette(
		mood.get("top_vignette", Color(0.02, 0.01, 0.04, 0.22)),
		mood.get("bottom_vignette", Color(0.01, 0.0, 0.02, 0.34))
	)
	add_horizon_silhouette(mood.get("horizon", Color(0.02, 0.03, 0.05, 0.28)))


func get_scene_mood() -> Dictionary:
	var style: String = host._current_map.get("city_style", "")
	var profile: Dictionary = host._get_map_visual_profile()
	if host._tileset_type == "dungeon":
		return {
			"canvas": Color(0.70, 0.73, 0.82, 1.0).lerp(profile.get("canvas_tint", Color(0.70, 0.73, 0.82, 1.0)), 0.25),
			"mote_color": profile.get("mote_color", Color(0.76, 0.38, 1.0, 0.34)),
			"mote_count": 30,
			"top_vignette": Color(0.03, 0.0, 0.05, 0.34),
			"bottom_vignette": Color(0.0, 0.0, 0.0, 0.46),
			"horizon": profile.get("horizon_color", Color(0.08, 0.02, 0.12, 0.34)),
		}
	if host._tileset_type == "snowplains":
		return {
			"canvas": Color(0.82, 0.91, 1.0, 1.0),
			"mote_color": profile.get("mote_color", Color(0.78, 0.94, 1.0, 0.30)),
			"mote_count": 54,
			"top_vignette": Color(0.02, 0.08, 0.14, 0.24),
			"bottom_vignette": Color(0.01, 0.03, 0.07, 0.30),
			"horizon": profile.get("horizon_color", Color(0.40, 0.64, 0.78, 0.18)),
		}
	if host._current_map_id in ["cyberpunk", "lowpoly_night"] or style in ["urban_3d", "dense_3d"]:
		return {
			"canvas": Color(0.80, 0.88, 1.0, 1.0),
			"mote_color": profile.get("mote_color", Color(0.22, 0.92, 1.0, 0.30)),
			"mote_count": 48,
			"top_vignette": Color(0.01, 0.03, 0.09, 0.30),
			"bottom_vignette": Color(0.01, 0.0, 0.04, 0.38),
			"horizon": profile.get("horizon_color", Color(0.02, 0.18, 0.28, 0.34)),
		}
	if style in ["ancient", "water_city", "gothic"]:
		return {
			"canvas": Color(0.88, 0.86, 0.78, 1.0),
			"mote_color": profile.get("mote_color", Color(1.0, 0.72, 0.34, 0.24)),
			"mote_count": 36,
			"top_vignette": Color(0.08, 0.04, 0.01, 0.20),
			"bottom_vignette": Color(0.04, 0.02, 0.0, 0.32),
			"horizon": profile.get("horizon_color", Color(0.24, 0.14, 0.08, 0.22)),
		}
	return {
		"canvas": Color(0.84, 0.90, 0.86, 1.0),
		"mote_color": profile.get("mote_color", Color(0.64, 0.90, 0.62, 0.22)),
		"mote_count": 40,
		"top_vignette": Color(0.02, 0.04, 0.03, 0.20),
		"bottom_vignette": Color(0.0, 0.01, 0.0, 0.32),
		"horizon": profile.get("horizon_color", Color(0.04, 0.10, 0.06, 0.18)),
	}


func add_screen_vignette(top_color: Color, bottom_color: Color) -> void:
	var layer := CanvasLayer.new()
	layer.name = "AtmosphereOverlay"
	layer.layer = 0
	host.add_child(layer)

	var root := Control.new()
	root.name = "VignetteRoot"
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var top := ColorRect.new()
	top.name = "TopShadow"
	top.anchor_right = 1.0
	top.offset_bottom = 120.0
	top.color = top_color
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)

	var bottom := ColorRect.new()
	bottom.name = "BottomShadow"
	bottom.anchor_top = 1.0
	bottom.anchor_right = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_top = -190.0
	bottom.color = bottom_color
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom)

	for side in [-1, 1]:
		var edge := ColorRect.new()
		edge.name = "SideShadow"
		if side < 0:
			edge.offset_right = 72.0
		else:
			edge.anchor_left = 1.0
			edge.anchor_right = 1.0
			edge.offset_left = -72.0
		edge.anchor_bottom = 1.0
		edge.color = Color(0.0, 0.0, 0.0, 0.18)
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(edge)


func add_horizon_silhouette(color: Color) -> void:
	if not host._world_node or not host._current_map.has("data"):
		return
	var profile: Dictionary = host._get_map_visual_profile()
	var data: Dictionary = host._current_map.data.get_data()
	var width := float(data.get("width", 80))
	var start: Vector2 = host._iso(0.0, 0.0) + Vector2(20.0, -210.0)
	var end: Vector2 = host._iso(width, 0.0) + Vector2(180.0, -210.0)
	var baseline := maxf(start.y, end.y)
	var layer := Node2D.new()
	layer.name = "MapHorizonSilhouette"
	layer.z_index = -24
	host._world_node.add_child(layer)

	var points := PackedVector2Array()
	points.append(Vector2(start.x - 180.0, baseline + 96.0))
	for i in range(18):
		var t := float(i) / 17.0
		var x := lerpf(start.x - 120.0, end.x + 120.0, t)
		var h := 32.0 + float((i * 37 + host._current_map_id.length() * 11) % 78)
		points.append(Vector2(x, baseline - h))
	points.append(Vector2(end.x + 180.0, baseline + 96.0))

	var silhouette := Polygon2D.new()
	silhouette.name = "HorizonMass"
	silhouette.polygon = points
	silhouette.color = color.lerp(profile.get("secondary", color), 0.18)
	layer.add_child(silhouette)

	var family := String(profile.get("family", "grassland"))
	var accent: Color = profile.get("identity", Color(0.38, 0.62, 0.32, 1.0))
	var skyline_count := 6
	if family in ["cyber", "tokyo", "berlin"]:
		skyline_count = 10
	elif family.begins_with("endless"):
		skyline_count = 8
	elif family == "grassland":
		skyline_count = 5
	for i in range(skyline_count):
		var t := (float(i) + 0.5) / float(skyline_count)
		var x := lerpf(start.x - 60.0, end.x + 60.0, t)
		var n: float = host._stable_map_noise("horizon", str(i))
		var h := 28.0 + n * 96.0
		if family in ["cyber", "tokyo", "berlin"]:
			var tower := ColorRect.new()
			tower.name = "HorizonVertical"
			tower.size = Vector2(12.0 + n * 18.0, h)
			tower.position = Vector2(x, baseline - h)
			tower.color = Color(accent.r, accent.g, accent.b, 0.10 + n * 0.10)
			tower.z_index = -23
			layer.add_child(tower)
		else:
			var spike := Polygon2D.new()
			spike.name = "HorizonAccent"
			spike.polygon = PackedVector2Array([
				Vector2(x - 22.0, baseline),
				Vector2(x, baseline - h),
				Vector2(x + 22.0, baseline),
			])
			spike.color = Color(accent.r, accent.g, accent.b, 0.08 + n * 0.08)
			spike.z_index = -23
			layer.add_child(spike)


func add_ambient_motes(color: Color, amount: int) -> void:
	if not host._world_node or not host._current_map.has("data"):
		return
	var data: Dictionary = host._current_map.data.get_data()
	var width := float(data.get("width", 80))
	var height := float(data.get("height", 80))
	var layer := Node2D.new()
	layer.name = "AmbientMotes"
	layer.z_index = 4085
	host._world_node.add_child(layer)

	for i in range(amount):
		var mote := Polygon2D.new()
		var r := randf_range(1.2, 3.2)
		mote.name = "Mote"
		mote.polygon = PackedVector2Array([
			Vector2(0.0, -r), Vector2(r, 0.0), Vector2(0.0, r), Vector2(-r, 0.0),
		])
		mote.color = color
		mote.position = host._iso(randf_range(0.0, width), randf_range(0.0, height)) + Vector2(randf_range(-70.0, 70.0), randf_range(-55.0, 55.0))
		mote.modulate.a = randf_range(0.24, 0.62)
		mote.rotation = randf_range(0.0, TAU)
		layer.add_child(mote)

		var start_pos := mote.position
		var start_alpha := mote.modulate.a
		var drift := Vector2(randf_range(-24.0, 24.0), randf_range(-80.0, -34.0))
		var duration := randf_range(4.2, 7.8)
		var tw: Tween = host.create_tween()
		tw.set_loops()
		tw.tween_property(mote, "position", start_pos + drift, duration).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(mote, "modulate:a", 0.0, duration)
		tw.parallel().tween_property(mote, "rotation", mote.rotation + randf_range(-1.2, 1.2), duration)
		tw.tween_callback(func():
			if is_instance_valid(mote):
				mote.position = start_pos
				mote.modulate.a = start_alpha
		)


func add_wilderness_map_details() -> void:
	if not host._world_node or not host._current_map.has("data"):
		return
	var profile: Dictionary = host._get_map_visual_profile()
	var data: Dictionary = host._current_map.data.get_data()
	var width := float(data.get("width", 80))
	var height := float(data.get("height", 80))
	var layer := Node2D.new()
	layer.name = "MapGroundDetails"
	layer.z_index = -10
	host._world_node.add_child(layer)

	var count := int(profile.get("ground_detail_count", 86))
	if host._tileset_type == "dungeon":
		count = mini(count, 46)
	elif host._is_endless_map_id(host._current_map_id):
		count = clampi(count, 96, 132)
	else:
		count = clampi(count, 54, 124)
	var rng := RandomNumberGenerator.new()
	rng.seed = abs((host._current_map_id + ":" + str(host._current_portal_depth)).hash())
	for i in range(count):
		var p: Vector2 = host._iso(rng.randf_range(4.0, width - 4.0), rng.randf_range(4.0, height - 4.0)) + Vector2(96.0, 52.0)
		var family := String(profile.get("family", "grassland"))
		var roll := rng.randf()
		if roll < float(profile.get("crack_density", 0.16)):
			var crack := Line2D.new()
			crack.name = "GroundCrack"
			crack.width = rng.randf_range(1.2, 2.4)
			crack.default_color = ground_detail_color(i)
			crack.z_index = -9
			for j in range(4):
				crack.add_point(p + Vector2(float(j) * rng.randf_range(10.0, 22.0), sin(float(j) * 1.4 + rng.randf()) * rng.randf_range(4.0, 12.0)))
			layer.add_child(crack)
		elif family == "grassland" and roll < 0.46:
			var root := Line2D.new()
			root.name = "RootDetail"
			root.width = rng.randf_range(1.4, 2.8)
			root.default_color = Color(0.16, 0.10, 0.06, 0.22)
			root.z_index = -9
			root.add_point(p)
			root.add_point(p + Vector2(rng.randf_range(18.0, 36.0), rng.randf_range(-8.0, 8.0)))
			layer.add_child(root)
		else:
			var shard := Polygon2D.new()
			shard.name = "GroundDetail"
			var sx := rng.randf_range(7.0, 20.0)
			var sy := rng.randf_range(2.0, 6.0)
			if family == "ruined" and i % 5 == 0:
				sx *= 1.35
				sy *= 1.2
				shard.name = "RubbleDetail"
			elif roll < float(profile.get("rune_density", 0.08)):
				shard.name = "WornRune"
				sx *= 0.72
			shard.polygon = PackedVector2Array([
				Vector2(-sx, 0.0), Vector2(0.0, -sy), Vector2(sx, 0.0), Vector2(0.0, sy),
			])
			shard.position = p
			shard.rotation = rng.randf_range(-0.45, 0.45)
			shard.color = ground_detail_color(i)
			shard.z_index = -9
			layer.add_child(shard)

	if host._is_endless_map_id(host._current_map_id):
		add_endless_variant_details(layer, width, height, profile)
		add_endless_rift_scars(layer, width, height)


func ground_detail_color(index: int) -> Color:
	var profile: Dictionary = host._get_map_visual_profile()
	var identity: Color = profile.get("identity", Color(0.18, 0.30, 0.17, 1.0))
	var secondary: Color = profile.get("secondary", Color(0.18, 0.30, 0.17, 1.0))
	var alpha := float(profile.get("ground_alpha", 0.24)) + float(index % 4) * 0.025
	if host._tileset_type == "dungeon":
		return Color(0.20, 0.19, 0.24, 0.38)
	if host._tileset_type == "snowplains":
		return Color(0.72, 0.86, 1.0, 0.28)
	if host._current_map_id in ["ruined_city", "postwar_city"]:
		return host._tinted_color(Color(0.25, 0.22, 0.19, alpha), identity, 0.18, minf(alpha + 0.06, 0.42))
	if host._is_endless_map_id(host._current_map_id):
		return host._tinted_color(Color(secondary.r, secondary.g, secondary.b, alpha), identity, 0.32, minf(alpha + 0.04, 0.42))
	return host._tinted_color(Color(0.18, 0.30, 0.17, alpha), identity, 0.18, alpha)


func add_endless_rift_scars(parent: Node2D, width: float, height: float) -> void:
	var profile: Dictionary = host._get_map_visual_profile()
	var rift_layer := Node2D.new()
	rift_layer.name = "EndlessRiftDetails"
	rift_layer.z_index = -8
	parent.add_child(rift_layer)
	var identity: Color = profile.get("identity", Color(0.42, 0.20, 1.0, 1.0))
	var accent: Color = profile.get("accent", Color(0.68, 0.28, 1.0, 1.0))
	var intensity := float(profile.get("rift_intensity", 0.42))
	var count := clampi(7 + int(float(profile.get("rift_density", 0.42)) * 8.0), 7, 16)
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(("rift:%s:%d" % [host._current_map_id, host._current_portal_depth]).hash())
	for i in range(count):
		var scar := Line2D.new()
		scar.name = "EndlessRiftScar"
		scar.width = 1.6 + float(i % 3) + intensity
		scar.default_color = Color(identity.r, identity.g, identity.b, 0.22 + intensity * 0.20)
		scar.z_index = -8
		var origin: Vector2 = host._iso(rng.randf_range(12.0, width - 12.0), rng.randf_range(10.0, height - 10.0)) + Vector2(96.0, 46.0)
		for j in range(5):
			scar.add_point(origin + Vector2(float(j) * rng.randf_range(14.0, 28.0), sin(float(j) * 1.7 + float(i)) * (14.0 + intensity * 18.0)))
		rift_layer.add_child(scar)
		if host._current_portal_depth >= host.ENDLESS_START_DEPTH + 5 and i % 4 == 0:
			var ember := Polygon2D.new()
			ember.name = "DeepRiftPulse"
			ember.position = origin
			ember.polygon = PackedVector2Array([Vector2(0, -8), Vector2(20, 0), Vector2(0, 8), Vector2(-20, 0)])
			ember.color = Color(accent.r, accent.g, accent.b, 0.12 + intensity * 0.12)
			ember.z_index = -7
			rift_layer.add_child(ember)


func add_endless_variant_details(parent: Node2D, width: float, height: float, profile: Dictionary) -> void:
	var layer := Node2D.new()
	layer.name = "EndlessVariantDetails"
	layer.z_index = -9
	parent.add_child(layer)
	var variant := String(host._get_endless_variant(host._current_portal_depth).get("name", "")).to_lower()
	var identity: Color = profile.get("identity", Color(0.72, 0.36, 1.0, 1.0))
	var accent: Color = profile.get("accent", Color(0.40, 0.24, 0.92, 1.0))
	var amount := clampi(14 + int(float(profile.get("rift_density", 0.42)) * 18.0), 16, 34)
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(("variant:%s:%d" % [variant, host._current_portal_depth]).hash())
	for i in range(amount):
		var p: Vector2 = host._iso(rng.randf_range(8.0, width - 8.0), rng.randf_range(8.0, height - 8.0)) + Vector2(96.0, 50.0)
		if variant.contains("mirmidone"):
			var hex := Line2D.new()
			hex.name = "MyrmidonPattern"
			hex.closed = true
			hex.width = 1.2
			hex.default_color = Color(accent.r, accent.g, accent.b, 0.22)
			hex.z_index = -9
			for j in range(6):
				var a := TAU * float(j) / 6.0
				hex.add_point(p + Vector2(cos(a) * 18.0, sin(a) * 9.0))
			layer.add_child(hex)
		elif variant.contains("ferale"):
			var thorn := Line2D.new()
			thorn.name = "FeralThorn"
			thorn.width = 2.0
			thorn.default_color = Color(identity.r, identity.g, identity.b, 0.22)
			thorn.z_index = -9
			thorn.add_point(p)
			thorn.add_point(p + Vector2(rng.randf_range(16.0, 34.0), rng.randf_range(-18.0, -4.0)))
			thorn.add_point(p + Vector2(rng.randf_range(28.0, 42.0), rng.randf_range(3.0, 18.0)))
			layer.add_child(thorn)
		else:
			var mark := Polygon2D.new()
			mark.name = "EndlessVariantMark"
			var sx := rng.randf_range(8.0, 20.0)
			var sy := rng.randf_range(3.0, 9.0)
			if variant.contains("draconico"):
				mark.name = "DraconicScale"
				mark.polygon = PackedVector2Array([Vector2(-sx, sy), Vector2(0, -sy * 1.8), Vector2(sx, sy), Vector2(0, sy * 0.4)])
			elif variant.contains("guerra"):
				mark.name = "WarIronScar"
				mark.polygon = PackedVector2Array([Vector2(-sx, -sy), Vector2(sx, -sy * 0.4), Vector2(sx * 0.8, sy), Vector2(-sx * 0.8, sy * 0.4)])
			else:
				mark.name = "EclipseRune"
				mark.polygon = PackedVector2Array([Vector2(0, -sy * 2.0), Vector2(sx, 0), Vector2(0, sy * 2.0), Vector2(-sx, 0)])
			mark.position = p
			mark.rotation = rng.randf_range(-0.7, 0.7)
			mark.color = Color(identity.r, identity.g, identity.b, 0.14 + rng.randf() * 0.08)
			mark.z_index = -9
			layer.add_child(mark)
