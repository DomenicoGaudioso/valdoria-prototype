class_name RealCityBuilder
extends RefCounted

## RealCityBuilder — estratto da GameBootstrap. Stato/utility condivise restano nell'host.

var host: Node


func _init(h: Node = null) -> void:
	host = h


func _city_base_tint(gid: int) -> Color:
	var style: String = host._current_map.get("city_style", "urban_3d")
	if gid >= 176 and gid <= 191:
		return Color(0.38, 0.62, 0.74, 1.0)
	if gid >= 32 and gid <= 47:
		return Color(0.62, 0.60, 0.56, 1.0) if style == "ancient" else Color(0.48, 0.48, 0.49, 1.0)
	if style == "water_city":
		return Color(0.43, 0.55, 0.50, 1.0)
	if style == "dense_3d":
		return Color(0.42, 0.45, 0.48, 1.0)
	return Color(0.50, 0.54, 0.48, 1.0)


func _add_city_overlay_cell(parent: Node, x: int, y: int, bg_gid: int, obj_gid: int, pos: Vector2) -> void:
	if bg_gid >= 176 and bg_gid <= 191:
		_add_iso_diamond(parent, pos, Color(0.04, 0.23, 0.38, 0.92), -8)
	elif bg_gid >= 32 and bg_gid <= 47:
		var style: String = host._current_map.get("city_style", "urban_3d")
		var road_color := Color(0.22, 0.22, 0.23, 0.88)
		if style == "ancient":
			road_color = Color(0.44, 0.37, 0.29, 0.88)
		elif style == "water_city":
			road_color = Color(0.48, 0.42, 0.34, 0.86)
		_add_iso_diamond(parent, pos, road_color, -7)

	if obj_gid > 0 and _should_draw_city_block(x, y) and not _has_city_vector_source():
		var height := 36.0 + float((obj_gid * 13 + x * 7 + y * 5) % 58)
		var style: String = host._current_map.get("city_style", "urban_3d")
		if style == "dense_3d":
			height += 34.0
		elif style == "urban_3d":
			height += 22.0
		elif style == "ancient":
			height *= 0.72
		_add_city_block(parent, pos, height, int((x + y) * 12 + 4))


func _add_city_collision(parent: Node, pos: Vector2, kind: String) -> void:
	var body := StaticBody2D.new()
	body.name = "CityObstacle_" + kind
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0

	var shape := CollisionPolygon2D.new()
	if kind == "water":
		shape.polygon = PackedVector2Array([
			Vector2(96, 12), Vector2(178, 48), Vector2(96, 86), Vector2(14, 48),
		])
	else:
		shape.polygon = PackedVector2Array([
			Vector2(96, 38), Vector2(148, 58), Vector2(96, 82), Vector2(44, 58),
		])
	body.add_child(shape)
	parent.add_child(body)


func _should_draw_city_block(x: int, y: int) -> bool:
	var style: String = host._current_map.get("city_style", "urban_3d")
	if style in ["urban_3d", "dense_3d"]:
		return (x + y) % 2 == 0 or (x * 3 + y * 5) % 7 == 0
	return (x + y) % 3 == 0


func _add_iso_diamond(parent: Node, pos: Vector2, color: Color, z: int) -> void:
	var poly := Polygon2D.new()
	poly.name = "CityGroundOverlay"
	poly.polygon = PackedVector2Array([
		pos + Vector2(96, 6),
		pos + Vector2(184, 48),
		pos + Vector2(96, 91),
		pos + Vector2(8, 48),
	])
	poly.color = color
	poly.z_index = z
	parent.add_child(poly)


func _add_city_block(parent: Node, pos: Vector2, height: float, z: int) -> void:
	var style: String = host._current_map.get("city_style", "urban_3d")
	var half_w := 48.0
	var half_h := 22.0
	if style in ["ancient", "water_city", "gothic"]:
		half_w = 36.0
		half_h = 17.0
		height = min(height, 58.0)
	elif style == "dense_3d":
		half_w = 42.0
		half_h = 20.0

	var center := pos + Vector2(96, 56)
	var top_color := _city_roof_color(style)
	var left_color := _city_wall_color(style, false)
	var right_color := _city_wall_color(style, true)
	var top := Polygon2D.new()
	top.name = "CityBuildingTop"
	top.polygon = PackedVector2Array([
		center + Vector2(0, -half_h - height),
		center + Vector2(half_w, -height),
		center + Vector2(0, half_h - height),
		center + Vector2(-half_w, -height),
	])
	top.color = top_color
	top.z_index = z
	parent.add_child(top)

	var left := Polygon2D.new()
	left.name = "CityBuildingFace"
	left.polygon = PackedVector2Array([
		center + Vector2(-half_w, -height),
		center + Vector2(0, half_h - height),
		center + Vector2(0, half_h),
		center + Vector2(-half_w, 0),
	])
	left.color = left_color
	left.z_index = z - 1
	parent.add_child(left)

	var right := Polygon2D.new()
	right.name = "CityBuildingFace"
	right.polygon = PackedVector2Array([
		center + Vector2(0, half_h - height),
		center + Vector2(half_w, -height),
		center + Vector2(half_w, 0),
		center + Vector2(0, half_h),
	])
	right.color = right_color
	right.z_index = z - 1
	parent.add_child(right)

	if height > 70.0:
		var glow := ColorRect.new()
		glow.name = "CityWindowGlow"
		glow.size = Vector2(18, 4)
		glow.position = center + Vector2(7, -height * 0.55)
		glow.color = Color(1.0, 0.78, 0.34, 0.78)
		glow.z_index = z + 1
		parent.add_child(glow)

	if style in ["ancient", "water_city", "gothic"] and height <= 64.0:
		_add_house_roof_detail(parent, center, half_w, half_h, height, z + 1, style)


func _city_roof_color(style: String) -> Color:
	match style:
		"ancient":
			return Color(0.66, 0.32, 0.18, 1.0)
		"water_city":
			return Color(0.73, 0.38, 0.18, 1.0)
		"gothic":
			return Color(0.24, 0.25, 0.31, 1.0)
		"dense_3d":
			return Color(0.32, 0.36, 0.42, 1.0)
		"urban_3d":
			return Color(0.44, 0.47, 0.50, 1.0)
	return Color(0.56, 0.56, 0.60, 1.0)


func _city_wall_color(style: String, shaded: bool) -> Color:
	match style:
		"ancient":
			return Color(0.61, 0.51, 0.38, 1.0) if not shaded else Color(0.45, 0.35, 0.25, 1.0)
		"water_city":
			return Color(0.72, 0.62, 0.47, 1.0) if not shaded else Color(0.51, 0.43, 0.34, 1.0)
		"gothic":
			return Color(0.46, 0.45, 0.50, 1.0) if not shaded else Color(0.31, 0.30, 0.35, 1.0)
		"dense_3d":
			return Color(0.34, 0.39, 0.45, 1.0) if not shaded else Color(0.22, 0.25, 0.31, 1.0)
	return Color(0.38, 0.40, 0.44, 1.0) if not shaded else Color(0.26, 0.28, 0.32, 1.0)


func _add_house_roof_detail(parent: Node, center: Vector2, half_w: float, half_h: float, height: float, z: int, style: String) -> void:
	var ridge := Line2D.new()
	ridge.name = "RoofRidge"
	ridge.width = 3.0
	ridge.default_color = Color(0.18, 0.12, 0.08, 0.70) if style != "gothic" else Color(0.08, 0.08, 0.12, 0.80)
	ridge.z_index = z
	ridge.add_point(center + Vector2(0, -half_h - height + 4))
	ridge.add_point(center + Vector2(0, half_h - height - 4))
	parent.add_child(ridge)


func _has_city_vector_source() -> bool:
	var source_path: String = host._current_map.get("osm_source", "")
	return not source_path.is_empty() and FileAccess.file_exists(source_path)


func _load_city_osm() -> Dictionary:
	var source_path: String = host._current_map.get("osm_source", "")
	if source_path.is_empty():
		return {}
	if host._osm_cache.has(source_path):
		return host._osm_cache[source_path] as Dictionary
	var file: FileAccess = FileAccess.open(source_path, FileAccess.READ)
	if file == null:
		push_warning("Could not open OSM source: %s" % source_path)
		return {}
	var text: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Could not parse OSM source: %s" % source_path)
		return {}
	var osm: Dictionary = parsed as Dictionary
	host._osm_cache[source_path] = osm
	return osm


func _has_city_detail_source() -> bool:
	var source_path: String = host._current_map.get("detail_source", "")
	return not source_path.is_empty() and FileAccess.file_exists(source_path)


func _load_city_detail() -> Dictionary:
	var source_path: String = host._current_map.get("detail_source", "")
	if source_path.is_empty():
		return {}
	if host._osm_cache.has(source_path):
		return host._osm_cache[source_path] as Dictionary
	var file: FileAccess = FileAccess.open(source_path, FileAccess.READ)
	if file == null:
		push_warning("Could not open detail city source: %s" % source_path)
		return {}
	var text: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Could not parse detail city source: %s" % source_path)
		return {}
	var detail: Dictionary = parsed as Dictionary
	host._osm_cache[source_path] = detail
	return detail


func _city_detail_limit() -> int:
	match host._current_map_id:
		"roma_centro":
			return 2600
		"venezia_rialto":
			return 2400
		"parigi_cite":
			return 2200
		"berlin_mitte_3d":
			return 2600
		"tokyo_shibuya":
			return 2100
	return 1200


func _draw_city_detail_layer(bbox: Array, collision_body: StaticBody2D, limit: int) -> int:
	var detail: Dictionary = _load_city_detail()
	if detail.is_empty():
		return 0
	var features: Array = detail.get("features", []) as Array
	var drawn: int = 0
	for feature_variant in features:
		if drawn >= limit:
			break
		if typeof(feature_variant) != TYPE_DICTIONARY:
			continue
		var feature: Dictionary = feature_variant as Dictionary
		if _add_detail_building(feature, bbox, collision_body):
			drawn += 1
	return drawn


func _add_detail_building(feature: Dictionary, bbox: Array, collision_body: StaticBody2D) -> bool:
	var points: Array[Vector2] = _detail_feature_points(feature, bbox)
	if points.size() < 4:
		return false
	var levels: float = _variant_float(feature.get("levels", 1.0), 1.0)
	if levels <= 0.0:
		levels = 1.0
	var area: float = _variant_float(feature.get("area", 0.0), 0.0)
	var important: bool = area > 900.0 or levels >= 8.0
	var tags: Dictionary = {
		"building": "yes",
		"building:levels": levels,
		"_detail_source": true,
	}
	if feature.has("height") and feature["height"] != null:
		tags["height"] = _variant_float(feature["height"], 0.0)
	var fake_element: Dictionary = {
		"id": _stable_variant_int(feature.get("id", int(area)), int(area)),
		"tags": tags,
	}
	return _add_osm_building(fake_element, points, collision_body, important)


func _detail_feature_points(feature: Dictionary, bbox: Array) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var rings: Array = feature.get("rings", []) as Array
	if rings.is_empty():
		return points
	var ring: Array = rings[0] as Array
	for coord_variant in ring:
		if typeof(coord_variant) != TYPE_ARRAY:
			continue
		var coord: Array = coord_variant as Array
		if coord.size() < 2:
			continue
		var lat: float = float(coord[0])
		var lon: float = float(coord[1])
		var projected: Vector2 = _project_osm_point(lat, lon, bbox)
		if points.is_empty() or points[points.size() - 1].distance_to(projected) > 1.0:
			points.append(projected)
	return points


func _city_bbox() -> Array:
	var bbox: Array = host._current_map.get("bbox", [])
	if bbox.size() < 4:
		return []
	return bbox


func _city_vector_limits() -> Dictionary:
	match host._current_map_id:
		"roma_centro":
			return {"buildings": 760, "roads": 1300, "parks": 120, "water": 140, "labels": 34}
		"venezia_rialto":
			return {"buildings": 680, "roads": 1150, "parks": 70, "water": 220, "labels": 34}
		"parigi_cite":
			return {"buildings": 620, "roads": 920, "parks": 80, "water": 80, "labels": 30}
		"berlin_mitte_3d":
			return {"buildings": 760, "roads": 1050, "parks": 110, "water": 60, "labels": 32}
		"tokyo_shibuya":
			return {"buildings": 820, "roads": 950, "parks": 70, "water": 50, "labels": 30}
	return {"buildings": 620, "roads": 900, "parks": 70, "water": 70, "labels": 28}


func _add_real_city_vector_layer() -> void:
	var osm: Dictionary = _load_city_osm()
	var bbox: Array = _city_bbox()
	if osm.is_empty() or bbox.is_empty():
		return
	var elements: Array = osm.get("elements", []) as Array
	var buckets: Dictionary = {
		"water": [],
		"park": [],
		"road": [],
		"building": [],
		"poi": [],
	}
	for element_variant in elements:
		if typeof(element_variant) != TYPE_DICTIONARY:
			continue
		var element: Dictionary = element_variant as Dictionary
		var tags: Dictionary = element.get("tags", {}) as Dictionary
		var cls: String = _osm_class(tags)
		if buckets.has(cls):
			(buckets[cls] as Array).append(element)

	var collision_body := StaticBody2D.new()
	collision_body.name = "RealCityFootprintObstacles"
	collision_body.collision_layer = 1
	collision_body.collision_mask = 0
	host._world_node.add_child(collision_body)

	var limits: Dictionary = _city_vector_limits()
	var drawn_water: int = _draw_osm_bucket(buckets["water"] as Array, bbox, collision_body, "water", limits.get("water", 80))
	var drawn_parks: int = _draw_osm_bucket(buckets["park"] as Array, bbox, collision_body, "park", limits.get("parks", 80))
	var drawn_roads: int = _draw_osm_bucket(buckets["road"] as Array, bbox, collision_body, "road", limits.get("roads", 900))
	var label_seen: Dictionary = {}
	var label_count: int = 0
	label_count += _draw_osm_pois(buckets["poi"] as Array, bbox, label_seen, limits.get("labels", 28))
	var drawn_buildings: int = 0
	var detail_kind: String = host._current_map.get("detail_kind", "")
	if _has_city_detail_source():
		drawn_buildings = _draw_city_detail_layer(bbox, collision_body, _city_detail_limit())
	else:
		drawn_buildings = _draw_osm_buildings(buckets["building"] as Array, bbox, collision_body, label_seen, max(0, limits.get("labels", 28) - label_count), limits.get("buildings", 620))
	print("Real city layer: %s detail=%s buildings=%d roads=%d water=%d parks=%d labels=%d" % [host._current_map_id, detail_kind if not detail_kind.is_empty() else "osm", drawn_buildings, drawn_roads, drawn_water, drawn_parks, label_seen.size()])


func _draw_osm_bucket(elements: Array, bbox: Array, collision_body: StaticBody2D, kind: String, limit: int) -> int:
	var drawn: int = 0
	for element_variant in elements:
		if drawn >= limit:
			break
		var element: Dictionary = element_variant as Dictionary
		var points: Array[Vector2] = _element_points(element, bbox)
		if points.size() < 2:
			continue
		var tags: Dictionary = element.get("tags", {}) as Dictionary
		if kind == "water":
			if _add_osm_water(points, tags, collision_body):
				drawn += 1
		elif kind == "park":
			if _add_osm_park(points, tags):
				drawn += 1
		elif kind == "road":
			if _add_osm_road(points, tags):
				drawn += 1
	return drawn


func _draw_osm_pois(elements: Array, bbox: Array, label_seen: Dictionary, limit: int) -> int:
	var labels: int = 0
	for element_variant in elements:
		if labels >= limit:
			break
		var element: Dictionary = element_variant as Dictionary
		var tags: Dictionary = element.get("tags", {}) as Dictionary
		var name: String = _osm_name(tags)
		if name.is_empty():
			continue
		var points: Array[Vector2] = _element_points(element, bbox)
		if points.is_empty():
			continue
		var center: Vector2 = _points_center(points)
		var z: int = int(center.y / 2.5) + 420
		if _add_osm_label(name, center + Vector2(12, -42), _city_label_color(), z, label_seen):
			labels += 1
	return labels


func _draw_osm_buildings(elements: Array, bbox: Array, collision_body: StaticBody2D, label_seen: Dictionary, label_limit: int, building_limit: int) -> int:
	var drawn: int = 0
	var important_drawn: int = 0
	var drawn_ids: Dictionary = {}
	for element_variant in elements:
		if important_drawn >= 150:
			break
		var element: Dictionary = element_variant as Dictionary
		var tags: Dictionary = element.get("tags", {}) as Dictionary
		if not _is_important_osm(tags):
			continue
		var element_id: String = str(element.get("id", "important_%d" % important_drawn))
		var points: Array[Vector2] = _element_points(element, bbox)
		if _add_osm_building(element, points, collision_body, true):
			drawn_ids[element_id] = true
			drawn += 1
			important_drawn += 1
			if label_limit > 0:
				var name: String = _osm_name(tags)
				if not name.is_empty():
					var center: Vector2 = _points_center(points)
					if _add_osm_label(name, center + Vector2(12, -78), _city_label_color(), int(center.y / 2.5) + 520, label_seen):
						label_limit -= 1

	for element_variant in elements:
		if drawn >= building_limit:
			break
		var element: Dictionary = element_variant as Dictionary
		var element_id: String = str(element.get("id", "building_%d" % drawn))
		if drawn_ids.has(element_id):
			continue
		var points: Array[Vector2] = _element_points(element, bbox)
		if _add_osm_building(element, points, collision_body, false):
			drawn_ids[element_id] = true
			drawn += 1
	return drawn


func _osm_class(tags: Dictionary) -> String:
	if tags.has("building"):
		return "building"
	if str(tags.get("natural", "")) == "water" or tags.has("waterway"):
		return "water"
	var leisure: String = str(tags.get("leisure", ""))
	var landuse: String = str(tags.get("landuse", ""))
	if leisure in ["park", "garden", "common", "pitch"] or landuse in ["grass", "forest", "meadow", "recreation_ground", "cemetery"]:
		return "park"
	if tags.has("highway"):
		return "road"
	var amenity: String = str(tags.get("amenity", ""))
	var tourism: String = str(tags.get("tourism", ""))
	if tags.has("historic") or tourism in ["attraction", "museum", "viewpoint"] or amenity in ["place_of_worship", "university", "school", "marketplace", "fountain"]:
		return "poi"
	return "other"


func _project_osm_point(lat: float, lon: float, bbox: Array) -> Vector2:
	var south: float = float(bbox[0])
	var west: float = float(bbox[1])
	var north: float = float(bbox[2])
	var east: float = float(bbox[3])
	var x_norm: float = clamp((lon - west) / max(east - west, 0.0000001), 0.0, 1.0)
	var y_norm: float = clamp((north - lat) / max(north - south, 0.0000001), 0.0, 1.0)
	var gx: float = 5.0 + x_norm * 89.0
	var gy: float = 5.0 + y_norm * 89.0
	return host._iso(gx, gy) + Vector2(96, 48)


func _element_points(element: Dictionary, bbox: Array) -> Array[Vector2]:
	var points: Array[Vector2] = []
	if element.has("geometry"):
		var raw_geometry: Array = element.get("geometry", []) as Array
		for pt_variant in raw_geometry:
			if typeof(pt_variant) != TYPE_DICTIONARY:
				continue
			var pt: Dictionary = pt_variant as Dictionary
			if not pt.has("lat") or not pt.has("lon"):
				continue
			var projected: Vector2 = _project_osm_point(float(pt["lat"]), float(pt["lon"]), bbox)
			if points.is_empty() or points[points.size() - 1].distance_to(projected) > 1.0:
				points.append(projected)
	elif element.has("lat") and element.has("lon"):
		points.append(_project_osm_point(float(element["lat"]), float(element["lon"]), bbox))
	return points


func _add_osm_water(points: Array[Vector2], tags: Dictionary, collision_body: StaticBody2D) -> bool:
	var closed: bool = _is_closed_points(points)
	if closed and points.size() >= 4:
		var polygon_points: Array[Vector2] = _simplify_points(_open_polygon(points), 42)
		if polygon_points.size() < 3 or _polygon_area(polygon_points) < 260.0:
			return false
		var poly := Polygon2D.new()
		poly.name = "OSMWater"
		poly.polygon = _packed_points(polygon_points)
		poly.color = _city_water_color()
		poly.z_index = -5
		host._world_node.add_child(poly)
		_add_water_highlight(polygon_points, -4)
		_add_osm_collision(collision_body, polygon_points, 32)
		return true
	var line_points: Array[Vector2] = _simplify_points(points, 80)
	if line_points.size() < 2:
		return false
	var line := Line2D.new()
	line.name = "OSMWaterway"
	line.points = _packed_points(line_points)
	line.width = 15.0 if tags.has("waterway") else 24.0
	line.default_color = _city_water_color()
	line.z_index = -4
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	host._world_node.add_child(line)
	_add_waterline_glint(line_points, line.width, -3)
	return true


func _add_osm_park(points: Array[Vector2], tags: Dictionary) -> bool:
	if not _is_closed_points(points) or points.size() < 4:
		return false
	var polygon_points: Array[Vector2] = _simplify_points(_open_polygon(points), 34)
	if polygon_points.size() < 3 or _polygon_area(polygon_points) < 220.0:
		return false
	var poly := Polygon2D.new()
	poly.name = "OSMPark"
	poly.polygon = _packed_points(polygon_points)
	poly.color = _city_park_color()
	poly.z_index = -6
	host._world_node.add_child(poly)
	_add_park_texture_marks(polygon_points)
	return true


func _add_osm_road(points: Array[Vector2], tags: Dictionary) -> bool:
	if points.size() < 2:
		return false
	var line_points: Array[Vector2] = _simplify_points(points, 90)
	if line_points.size() < 2:
		return false
	var highway: String = str(tags.get("highway", "road"))
	var casing := Line2D.new()
	casing.name = "OSMRoadCasing"
	casing.points = _packed_points(line_points)
	casing.width = _road_width(highway) + 4.0
	var profile: Dictionary = host._get_map_visual_profile()
	var secondary: Color = profile.get("secondary", Color(0.06, 0.06, 0.06, 1.0))
	casing.default_color = Color(secondary.r * 0.32, secondary.g * 0.32, secondary.b * 0.32, 0.28 + float(profile.get("road_detail", 0.44)) * 0.10)
	casing.z_index = -3
	casing.joint_mode = Line2D.LINE_JOINT_ROUND
	casing.begin_cap_mode = Line2D.LINE_CAP_ROUND
	casing.end_cap_mode = Line2D.LINE_CAP_ROUND
	host._world_node.add_child(casing)

	var line := Line2D.new()
	line.name = "OSMRoad"
	line.points = _packed_points(line_points)
	line.width = _road_width(highway)
	line.default_color = _road_color(highway)
	line.z_index = -2
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	host._world_node.add_child(line)
	_add_road_center_detail(line_points, highway)
	if _road_width(highway) >= 17.0 and float(profile.get("road_detail", 0.44)) > 0.58:
		_add_road_edge_ticks(line_points, highway)
	return true


func _add_water_highlight(points: Array[Vector2], z: int) -> void:
	if points.size() < 3:
		return
	var profile: Dictionary = host._get_map_visual_profile()
	var identity: Color = profile.get("identity", Color(0.46, 0.88, 1.0, 1.0))
	var edge := float(profile.get("water_edge", 0.32))
	var center := _points_center(points)
	var ring := Line2D.new()
	ring.name = "OSMWaterHighlight"
	ring.width = 1.6 + edge * 1.8
	ring.default_color = Color(identity.r, identity.g, identity.b, 0.18 + edge * 0.20)
	ring.z_index = z
	for i in range(points.size()):
		var p := points[i]
		if i % 2 == 0:
			ring.add_point(center.lerp(p, 0.82))
	if ring.get_point_count() >= 3:
		ring.closed = true
		host._world_node.add_child(ring)
	else:
		ring.queue_free()


func _add_waterline_glint(points: Array[Vector2], width: float, z: int) -> void:
	if points.size() < 2:
		return
	var profile: Dictionary = host._get_map_visual_profile()
	var identity: Color = profile.get("identity", Color(0.56, 0.92, 1.0, 1.0))
	var edge := float(profile.get("water_edge", 0.32))
	var glint := Line2D.new()
	glint.name = "OSMWaterGlint"
	glint.points = _packed_points(points)
	glint.width = maxf(2.0, width * (0.16 + edge * 0.12))
	glint.default_color = Color(identity.r, identity.g, identity.b, 0.24 + edge * 0.22)
	glint.z_index = z
	glint.joint_mode = Line2D.LINE_JOINT_ROUND
	glint.begin_cap_mode = Line2D.LINE_CAP_ROUND
	glint.end_cap_mode = Line2D.LINE_CAP_ROUND
	host._world_node.add_child(glint)


func _add_road_center_detail(points: Array[Vector2], highway: String) -> void:
	if points.size() < 2 or highway in ["footway", "path", "steps"]:
		return
	var line := Line2D.new()
	line.name = "OSMRoadCenterLine"
	line.points = _packed_points(points)
	line.width = 1.4 if highway in ["residential", "service", "living_street"] else 2.2
	var accent: Color = host._profile_color("accent", Color(0.92, 0.82, 0.52, 1.0))
	line.default_color = Color(accent.r, accent.g, accent.b, 0.30) if highway in ["primary", "secondary", "tertiary"] else Color(0.82, 0.82, 0.78, 0.22)
	line.z_index = -1
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	host._world_node.add_child(line)


func _add_road_edge_ticks(points: Array[Vector2], highway: String) -> void:
	if points.size() < 2:
		return
	var accent: Color = host._profile_color("identity", Color(0.70, 0.82, 0.92, 1.0))
	var limit := mini(10, points.size() - 1)
	for i in range(limit):
		if i % 2 != 0:
			continue
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		if a.distance_to(b) < 18.0:
			continue
		var mid := a.lerp(b, 0.5)
		var dir := (b - a).normalized()
		var normal := Vector2(-dir.y, dir.x)
		var tick := Line2D.new()
		tick.name = "OSMRoadHierarchyMark"
		tick.width = 1.2
		tick.default_color = Color(accent.r, accent.g, accent.b, 0.18)
		tick.z_index = -1
		tick.add_point(mid - normal * 8.0)
		tick.add_point(mid + normal * 8.0)
		host._world_node.add_child(tick)


func _add_park_texture_marks(points: Array[Vector2]) -> void:
	if points.size() < 3:
		return
	var center := _points_center(points)
	var profile: Dictionary = host._get_map_visual_profile()
	var identity: Color = profile.get("identity", Color(0.32, 0.62, 0.28, 1.0))
	var count := clampi(int(float(profile.get("park_mark_density", 0.55)) * 18.0), 5, 18)
	var radius := 0.0
	for point in points:
		radius = maxf(radius, center.distance_to(point))
	radius = minf(radius * 0.58, 140.0)
	var seed: int = abs(("park:%s:%s" % [host._current_map_id, str(int(center.x + center.y))]).hash())
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in range(count):
		var mark := Line2D.new()
		mark.name = "OSMParkTexture"
		mark.width = 1.2
		mark.default_color = Color(identity.r, identity.g, identity.b, 0.16)
		mark.z_index = -5
		var p := center + Vector2(rng.randf_range(-radius, radius), rng.randf_range(-radius * 0.55, radius * 0.55))
		mark.add_point(p + Vector2(-8.0, 0.0))
		mark.add_point(p + Vector2(8.0, rng.randf_range(-3.0, 3.0)))
		host._world_node.add_child(mark)


func _add_roof_highlight(points: Array[Vector2], z: int, important: bool) -> void:
	if points.size() < 3:
		return
	var outline := Line2D.new()
	outline.name = "OSMRoofHighlight"
	outline.width = 2.4 if important else 1.4
	var accent: Color = host._profile_color("accent", Color(1.0, 0.92, 0.68, 1.0))
	outline.default_color = Color(accent.r, accent.g, accent.b, 0.22 if not important else 0.40)
	outline.z_index = z
	for point in points:
		outline.add_point(point)
	outline.add_point(points[0])
	host._world_node.add_child(outline)


func _add_osm_building(element: Dictionary, points: Array[Vector2], collision_body: StaticBody2D, important: bool) -> bool:
	if not _is_closed_points(points) or points.size() < 4:
		return false
	var tags: Dictionary = element.get("tags", {}) as Dictionary
	var detailed: bool = tags.has("_detail_source")
	var max_points: int = 18 if important else (12 if detailed else 9)
	var footprint: Array[Vector2] = _simplify_points(_open_polygon(points), max_points)
	if footprint.size() < 3:
		return false
	var area: float = _polygon_area(footprint)
	var min_area: float = 75.0 if important else (45.0 if detailed else 135.0)
	if area < min_area:
		return false
	var style: String = host._current_map.get("city_style", "urban_3d")
	var element_id: int = _stable_variant_int(element.get("id", int(area)), int(area))
	var height: float = _building_height(tags, style, element_id)
	var center: Vector2 = _points_center(footprint)
	var z: int = int(center.y / 2.5) + (36 if important else 18)
	var up := Vector2(0, -height)
	var top_points: Array[Vector2] = _offset_points(footprint, up)

	var shadow := Polygon2D.new()
	shadow.name = "OSMBuildingShadow"
	shadow.polygon = _packed_points(_offset_points(footprint, Vector2(9, 9)))
	shadow.color = Color(0.0, 0.0, 0.0, 0.22)
	shadow.z_index = z - 4
	host._world_node.add_child(shadow)

	var side_count: int = footprint.size()
	for i in range(side_count):
		var p1: Vector2 = footprint[i]
		var p2: Vector2 = footprint[(i + 1) % side_count]
		var mid: Vector2 = (p1 + p2) * 0.5
		if side_count > 5 and mid.y < center.y - 8.0 and not important:
			continue
		var face := Polygon2D.new()
		face.name = "OSMBuildingFace"
		face.polygon = PackedVector2Array([p1, p2, p2 + up, p1 + up])
		face.color = _city_wall_color(style, mid.x > center.x)
		face.z_index = z - 2
		host._world_node.add_child(face)

	var roof := Polygon2D.new()
	roof.name = "OSMBuildingRoof"
	roof.polygon = _packed_points(top_points)
	var roof_base := _city_roof_color(style) if not important else _important_roof_color(style)
	var roof_variation := float(host._get_map_visual_profile().get("roof_variation", 0.10))
	var roof_noise: float = host._stable_map_noise("roof", str(element_id))
	roof.color = host._tinted_color(roof_base, host._profile_color("identity", roof_base), (roof_noise - 0.5) * roof_variation + roof_variation * 0.5)
	roof.z_index = z
	host._world_node.add_child(roof)
	_add_roof_highlight(top_points, z + 1, important)

	var outline_points: Array[Vector2] = top_points.duplicate()
	if not outline_points.is_empty():
		outline_points.append(outline_points[0])
	var outline := Line2D.new()
	outline.name = "OSMBuildingOutline"
	outline.points = _packed_points(outline_points)
	outline.width = 2.0 if important else 1.0
	outline.default_color = Color(0.05, 0.04, 0.03, 0.55)
	outline.z_index = z + 1
	host._world_node.add_child(outline)

	if height > 84.0 or (important and height > 58.0):
		_add_building_window_strips(center, height, z + 2)
	_add_osm_collision(collision_body, footprint, 18 if important else 12)
	return true


func _add_building_window_strips(center: Vector2, height: float, z: int) -> void:
	var profile: Dictionary = host._get_map_visual_profile()
	var strips: int = clampi(int(height / 42.0 * float(profile.get("window_density", 0.55))), 1, 5)
	var glow: Color = profile.get("accent", Color(0.95, 0.78, 0.36, 1.0))
	for i in range(strips):
		var stripe := ColorRect.new()
		stripe.name = "OSMBuildingWindows"
		stripe.size = Vector2(28, 3)
		stripe.position = center + Vector2(8, -height + 20 + i * 25)
		stripe.color = Color(glow.r, glow.g, glow.b, 0.46 + 0.18 * float(i % 2))
		stripe.z_index = z + i
		host._world_node.add_child(stripe)


func _add_osm_collision(collision_body: StaticBody2D, points: Array[Vector2], max_points: int) -> void:
	var collision_points: Array[Vector2] = _simplify_points(points, max_points)
	if collision_points.size() < 3:
		return
	var hull: PackedVector2Array = Geometry2D.convex_hull(_packed_points(collision_points))
	if hull.size() < 3:
		return
	var shape := CollisionPolygon2D.new()
	shape.name = "OSMFootprintCollision"
	shape.polygon = hull
	collision_body.add_child(shape)


func _packed_points(points: Array[Vector2]) -> PackedVector2Array:
	var packed := PackedVector2Array()
	for point in points:
		packed.append(point)
	return packed


func _offset_points(points: Array[Vector2], offset: Vector2) -> Array[Vector2]:
	var shifted: Array[Vector2] = []
	for point in points:
		shifted.append(point + offset)
	return shifted


func _simplify_points(points: Array[Vector2], max_points: int) -> Array[Vector2]:
	var count: int = points.size()
	if count <= max_points or max_points <= 0:
		return points.duplicate()
	var simplified: Array[Vector2] = []
	var step: int = max(1, int(ceil(float(count) / float(max_points))))
	for i in range(0, count, step):
		simplified.append(points[i])
	if simplified.size() > max_points:
		simplified.resize(max_points)
	if not points.is_empty() and simplified[simplified.size() - 1].distance_to(points[count - 1]) > 1.0:
		simplified.append(points[count - 1])
	return simplified


func _is_closed_points(points: Array[Vector2]) -> bool:
	return points.size() >= 3 and points[0].distance_to(points[points.size() - 1]) < 2.0


func _open_polygon(points: Array[Vector2]) -> Array[Vector2]:
	var polygon_points: Array[Vector2] = points.duplicate()
	if polygon_points.size() > 1 and polygon_points[0].distance_to(polygon_points[polygon_points.size() - 1]) < 2.0:
		polygon_points.remove_at(polygon_points.size() - 1)
	return polygon_points


func _polygon_area(points: Array[Vector2]) -> float:
	if points.size() < 3:
		return 0.0
	var area: float = 0.0
	for i in range(points.size()):
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % points.size()]
		area += a.x * b.y - b.x * a.y
	return abs(area) * 0.5


func _points_center(points: Array[Vector2]) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var center := Vector2.ZERO
	for point in points:
		center += point
	return center / float(points.size())


func _road_width(highway: String) -> float:
	if highway in ["motorway", "trunk", "primary"]:
		return 22.0
	if highway in ["secondary", "tertiary"]:
		return 17.0
	if highway in ["residential", "unclassified", "living_street"]:
		return 12.0
	if highway in ["pedestrian", "footway", "path", "steps"]:
		return 7.0
	if highway == "service":
		return 8.0
	return 10.0


func _road_color(highway: String) -> Color:
	var style: String = host._current_map.get("city_style", "urban_3d")
	var secondary: Color = host._profile_color("secondary", Color(0.23, 0.24, 0.26, 1.0))
	if highway in ["pedestrian", "footway", "path", "steps"]:
		if style == "water_city":
			return Color(0.66, 0.58, 0.43, 0.92)
		if style == "ancient":
			return Color(0.58, 0.49, 0.36, 0.92)
		return Color(0.60, 0.60, 0.58, 0.90)
	if style == "ancient":
		return Color(0.43, 0.36, 0.27, 0.96)
	if style == "water_city":
		return Color(0.49, 0.43, 0.34, 0.96)
	if style == "gothic":
		return Color(0.32, 0.32, 0.36, 0.95)
	if style in ["urban_3d", "dense_3d"]:
		return Color(secondary.r * 0.82, secondary.g * 0.82, secondary.b * 0.82, 0.96)
	return Color(0.23, 0.24, 0.26, 0.96)


func _city_water_color() -> Color:
	var style: String = host._current_map.get("city_style", "urban_3d")
	var identity: Color = host._profile_color("identity", Color(0.04, 0.24, 0.38, 1.0))
	if style == "water_city":
		return Color(0.03, 0.31, 0.43, 0.94).lerp(identity, 0.22)
	if style == "gothic":
		return Color(0.08, 0.26, 0.45, 0.92).lerp(identity, 0.12)
	return Color(0.04, 0.24, 0.38, 0.92).lerp(identity, 0.12)


func _city_park_color() -> Color:
	var style: String = host._current_map.get("city_style", "urban_3d")
	var identity: Color = host._profile_color("identity", Color(0.18, 0.34, 0.24, 1.0))
	if style == "ancient":
		return Color(0.25, 0.38, 0.24, 0.70).lerp(identity, 0.10)
	if style == "water_city":
		return Color(0.22, 0.42, 0.31, 0.70).lerp(identity, 0.10)
	return Color(0.18, 0.34, 0.24, 0.68).lerp(identity, 0.08)


func _city_label_color() -> Color:
	var style: String = host._current_map.get("city_style", "urban_3d")
	if style == "dense_3d":
		return Color(0.58, 0.95, 1.0, 1.0)
	if style == "gothic":
		return Color(0.80, 0.76, 1.0, 1.0)
	if style == "ancient":
		return Color(1.0, 0.82, 0.50, 1.0)
	return Color(0.95, 0.88, 0.65, 1.0)


func _important_roof_color(style: String) -> Color:
	match style:
		"ancient":
			return Color(0.82, 0.48, 0.24, 1.0)
		"water_city":
			return Color(0.88, 0.54, 0.26, 1.0)
		"gothic":
			return Color(0.36, 0.34, 0.44, 1.0)
		"dense_3d":
			return Color(0.50, 0.62, 0.78, 1.0)
	return Color(0.62, 0.61, 0.56, 1.0)


func _building_height(tags: Dictionary, style: String, element_id: int) -> float:
	var height_m: float = _tag_float(tags, ["height", "est_height"], -1.0)
	var levels: float = _tag_float(tags, ["building:levels", "levels"], -1.0)
	var px: float = 0.0
	if height_m > 0.0:
		px = height_m * 2.1
	elif levels > 0.0:
		px = levels * 18.0
	else:
		var seed: int = abs(element_id * 37 + host._current_map_id.length() * 19)
		match style:
			"ancient":
				px = 24.0 + float(seed % 34)
			"water_city":
				px = 26.0 + float(seed % 42)
			"gothic":
				px = 34.0 + float(seed % 54)
			"urban_3d":
				px = 44.0 + float(seed % 86)
			"dense_3d":
				px = 56.0 + float(seed % 132)
			_:
				px = 34.0 + float(seed % 60)
	if _is_important_osm(tags):
		px *= 1.18
	var max_height: float = 86.0
	if style == "urban_3d":
		max_height = 150.0
	elif style == "dense_3d":
		max_height = 210.0
	elif style == "gothic":
		max_height = 126.0
	return clamp(px, 18.0, max_height)


func _tag_float(tags: Dictionary, keys: Array, fallback: float) -> float:
	for key_variant in keys:
		var key: String = str(key_variant)
		if not tags.has(key):
			continue
		var text: String = str(tags[key]).strip_edges().replace(",", ".").replace("m", "").replace("M", "")
		var parts: PackedStringArray = text.split(";")
		if parts.size() > 0:
			text = parts[0].strip_edges()
		if text.is_valid_float():
			return text.to_float()
	return fallback


func _variant_float(value: Variant, fallback: float) -> float:
	match typeof(value):
		TYPE_FLOAT:
			return value
		TYPE_INT:
			return float(value)
		TYPE_STRING:
			var text: String = str(value).strip_edges().replace(",", ".").replace("m", "").replace("M", "")
			var parts: PackedStringArray = text.split(";")
			if parts.size() > 0:
				text = parts[0].strip_edges()
			if text.is_valid_float():
				return text.to_float()
	return fallback


func _stable_variant_int(value: Variant, fallback: int) -> int:
	match typeof(value):
		TYPE_INT:
			return value
		TYPE_FLOAT:
			return int(value)
		TYPE_STRING:
			var text: String = str(value).strip_edges()
			if text.is_valid_int():
				return text.to_int()
			if not text.is_empty():
				return abs(text.hash())
	return fallback


func _osm_name(tags: Dictionary) -> String:
	var name: String = str(tags.get("name", ""))
	if name.length() > 34:
		return name.substr(0, 31) + "..."
	return name


func _is_important_osm(tags: Dictionary) -> bool:
	var name: String = str(tags.get("name", "")).to_lower()
	if tags.has("historic") or str(tags.get("tourism", "")) in ["attraction", "museum", "viewpoint"] or str(tags.get("amenity", "")) == "place_of_worship":
		return true
	var keywords: Array = []
	match host._current_map_id:
		"roma_centro":
			keywords = ["colosseo", "colosseum", "foro", "forum", "palatino", "pantheon", "tevere"]
		"venezia_rialto":
			keywords = ["rialto", "san marco", "salute", "fenice", "marco polo"]
		"parigi_cite":
			keywords = ["notre", "dame", "conciergerie", "sainte", "chapelle", "seine"]
		"berlin_mitte_3d":
			keywords = ["brandenburg", "reichstag", "unter den linden", "mauer", "berliner"]
		"tokyo_shibuya":
			keywords = ["shibuya", "hachiko", "miyashita", "sky", "109", "渋谷"]
	for keyword_variant in keywords:
		var keyword: String = str(keyword_variant)
		if name.contains(keyword):
			return true
	return false


func _add_osm_label(text: String, pos: Vector2, color: Color, z: int, label_seen: Dictionary) -> bool:
	if text.is_empty() or label_seen.has(text):
		return false
	label_seen[text] = true
	var lb := Label.new()
	lb.name = "OSMNamedFeature"
	lb.text = text
	lb.position = pos
	lb.add_theme_color_override("font_color", color)
	lb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	lb.add_theme_constant_override("outline_size", 3)
	lb.add_theme_font_size_override("font_size", 11)
	lb.z_index = z
	host._world_node.add_child(lb)
	return true


func _add_city_landmarks() -> void:
	var title: String = host._current_map.get("title", "Real City")
	var style: String = host._current_map.get("city_style", "urban_3d")
	var markers: Array[Dictionary] = []
	match host._current_map_id:
		"roma_centro":
			markers = [
				{"label": "COLOSSEO", "pos": Vector2(58, 54), "color": Color(0.82, 0.62, 0.38, 1.0)},
				{"label": "TEVERE", "pos": Vector2(28, 46), "color": Color(0.25, 0.72, 1.0, 1.0)},
				{"label": "FORI", "pos": Vector2(51, 50), "color": Color(0.9, 0.76, 0.50, 1.0)},
			]
		"venezia_rialto":
			markers = [
				{"label": "RIALTO", "pos": Vector2(48, 47), "color": Color(0.95, 0.82, 0.45, 1.0)},
				{"label": "CANALI", "pos": Vector2(58, 56), "color": Color(0.25, 0.78, 1.0, 1.0)},
				{"label": "SAN MARCO", "pos": Vector2(70, 61), "color": Color(0.90, 0.72, 0.46, 1.0)},
			]
		"parigi_cite":
			markers = [
				{"label": "NOTRE-DAME", "pos": Vector2(56, 51), "color": Color(0.78, 0.68, 0.92, 1.0)},
				{"label": "SENNA", "pos": Vector2(41, 48), "color": Color(0.30, 0.70, 1.0, 1.0)},
			]
		"berlin_mitte_3d":
			markers = [
				{"label": "MITTE", "pos": Vector2(49, 50), "color": Color(0.82, 0.88, 0.96, 1.0)},
				{"label": "BRANDENBURG", "pos": Vector2(35, 46), "color": Color(0.94, 0.82, 0.54, 1.0)},
			]
		"tokyo_shibuya":
			markers = [
				{"label": "SHIBUYA", "pos": Vector2(52, 50), "color": Color(0.9, 0.38, 1.0, 1.0)},
				{"label": "SKYLINE", "pos": Vector2(62, 45), "color": Color(0.30, 0.95, 1.0, 1.0)},
			]

	var header := Label.new()
	header.name = "RealCityHeader"
	header.text = "REAL CITY / GIS - " + String(title).to_upper()
	header.position = host._iso(39, 31) + Vector2(-70, -190)
	header.add_theme_color_override("font_color", host._profile_color("identity", Color(0.88, 0.94, 1.0)))
	header.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	header.add_theme_constant_override("outline_size", 5)
	header.add_theme_font_size_override("font_size", 22)
	header.z_index = 3000
	host._world_node.add_child(header)

	for marker in markers:
		var p: Vector2 = marker["pos"]
		var world: Vector2 = host._iso(p.x, p.y)
		var beacon := Polygon2D.new()
		beacon.name = "LandmarkVisual"
		beacon.polygon = PackedVector2Array([Vector2(0, -42), Vector2(14, 0), Vector2(0, 14), Vector2(-14, 0)])
		beacon.position = world + Vector2(96, -28)
		var marker_color: Color = marker["color"]
		beacon.color = Color(marker_color.r, marker_color.g, marker_color.b, 0.78)
		beacon.z_index = 3002
		host._world_node.add_child(beacon)

		var lb := Label.new()
		lb.name = "CityLandmarkLabel"
		lb.text = marker["label"]
		lb.position = world + Vector2(42, -104)
		lb.add_theme_color_override("font_color", marker["color"])
		lb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		lb.add_theme_constant_override("outline_size", 3)
		lb.add_theme_font_size_override("font_size", 12 if style != "dense_3d" else 14)
		lb.z_index = 3003
		host._world_node.add_child(lb)

	_add_city_specific_monuments()


func _add_city_specific_monuments() -> void:
	match host._current_map_id:
		"roma_centro":
			_add_colosseum(host._iso(58, 54) + Vector2(96, 52), 3520)
			_add_ruin_columns(host._iso(51, 50) + Vector2(96, 50), 3515)
		"venezia_rialto":
			_add_rialto_bridge(host._iso(48, 47) + Vector2(96, 48), 3520)
			_add_bell_tower(host._iso(70, 61) + Vector2(96, 48), 3530, Color(0.74, 0.50, 0.32))
		"parigi_cite":
			_add_notre_dame(host._iso(56, 51) + Vector2(96, 48), 3530)
		"berlin_mitte_3d":
			_add_brandenburg_gate(host._iso(35, 46) + Vector2(96, 48), 3530)
		"tokyo_shibuya":
			_add_shibuya_crossing(host._iso(52, 50) + Vector2(96, 48), 3510)
			_add_skyscraper_cluster(host._iso(62, 45) + Vector2(96, 48), 3530)


func _add_monument_collision(center: Vector2, radius_x: float, radius_y: float) -> void:
	var body := StaticBody2D.new()
	body.name = "MonumentObstacle"
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionPolygon2D.new()
	shape.polygon = PackedVector2Array([
		Vector2(0, -radius_y), Vector2(radius_x, 0), Vector2(0, radius_y), Vector2(-radius_x, 0),
	])
	body.add_child(shape)
	host._world_node.add_child(body)


func _ellipse_points(rx: float, ry: float, count: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(count):
		var a := TAU * float(i) / float(count)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _add_colosseum(center: Vector2, z: int) -> void:
	var outer := Polygon2D.new()
	outer.name = "Colosseum"
	outer.position = center
	outer.polygon = _ellipse_points(92, 42, 48)
	outer.color = Color(0.66, 0.52, 0.36, 1.0)
	outer.z_index = z
	host._world_node.add_child(outer)

	var inner := Polygon2D.new()
	inner.name = "ColosseumArena"
	inner.position = center + Vector2(0, -4)
	inner.polygon = _ellipse_points(55, 24, 40)
	inner.color = Color(0.30, 0.22, 0.18, 1.0)
	inner.z_index = z + 1
	host._world_node.add_child(inner)

	for i in range(10):
		var arch := ColorRect.new()
		arch.name = "ColosseumArch"
		arch.size = Vector2(10, 14)
		var a := TAU * float(i) / 10.0
		arch.position = center + Vector2(cos(a) * 68 - 5, sin(a) * 30 - 7)
		arch.color = Color(0.16, 0.11, 0.08, 0.85)
		arch.z_index = z + 2
		host._world_node.add_child(arch)
	_add_monument_collision(center, 92, 44)


func _add_ruin_columns(center: Vector2, z: int) -> void:
	for i in range(6):
		var col := ColorRect.new()
		col.name = "ForumColumn"
		col.size = Vector2(12, 54 + (i % 3) * 10)
		col.position = center + Vector2((i - 3) * 24, -col.size.y)
		col.color = Color(0.74, 0.66, 0.52, 1.0)
		col.z_index = z + i
		host._world_node.add_child(col)
	_add_monument_collision(center, 88, 28)


func _add_rialto_bridge(center: Vector2, z: int) -> void:
	var bridge := Polygon2D.new()
	bridge.name = "RialtoBridge"
	bridge.position = center
	bridge.polygon = PackedVector2Array([
		Vector2(-90, 14), Vector2(-28, -26), Vector2(32, -28), Vector2(94, 14),
		Vector2(66, 38), Vector2(0, 12), Vector2(-66, 38),
	])
	bridge.color = Color(0.78, 0.66, 0.48, 1.0)
	bridge.z_index = z
	host._world_node.add_child(bridge)
	_add_monument_collision(center, 88, 32)


func _add_bell_tower(center: Vector2, z: int, color: Color) -> void:
	var tower := ColorRect.new()
	tower.name = "BellTower"
	tower.size = Vector2(42, 150)
	tower.position = center + Vector2(-21, -150)
	tower.color = color
	tower.z_index = z
	host._world_node.add_child(tower)
	var roof := Polygon2D.new()
	roof.name = "BellTowerRoof"
	roof.position = center + Vector2(0, -160)
	roof.polygon = PackedVector2Array([Vector2(0, -42), Vector2(32, 0), Vector2(0, 20), Vector2(-32, 0)])
	roof.color = Color(0.28, 0.42, 0.34, 1.0)
	roof.z_index = z + 1
	host._world_node.add_child(roof)
	_add_monument_collision(center, 34, 30)


func _add_notre_dame(center: Vector2, z: int) -> void:
	var nave := Polygon2D.new()
	nave.name = "NotreDameNave"
	nave.position = center
	nave.polygon = PackedVector2Array([Vector2(-82, 24), Vector2(0, -30), Vector2(92, 18), Vector2(16, 58)])
	nave.color = Color(0.42, 0.39, 0.44, 1.0)
	nave.z_index = z
	host._world_node.add_child(nave)
	for x in [-46, 22]:
		var tower := ColorRect.new()
		tower.name = "NotreDameTower"
		tower.size = Vector2(38, 110)
		tower.position = center + Vector2(x, -112)
		tower.color = Color(0.34, 0.34, 0.39, 1.0)
		tower.z_index = z + 1
		host._world_node.add_child(tower)
	_add_monument_collision(center, 92, 46)


func _add_brandenburg_gate(center: Vector2, z: int) -> void:
	for i in range(6):
		var column := ColorRect.new()
		column.name = "BrandenburgColumn"
		column.size = Vector2(13, 82)
		column.position = center + Vector2(-58 + i * 23, -82)
		column.color = Color(0.72, 0.64, 0.48, 1.0)
		column.z_index = z
		host._world_node.add_child(column)
	var cap := ColorRect.new()
	cap.name = "BrandenburgCap"
	cap.size = Vector2(158, 24)
	cap.position = center + Vector2(-76, -104)
	cap.color = Color(0.64, 0.56, 0.42, 1.0)
	cap.z_index = z + 1
	host._world_node.add_child(cap)
	_add_monument_collision(center, 88, 32)


func _add_shibuya_crossing(center: Vector2, z: int) -> void:
	for rot in [0.0, PI / 4.0, -PI / 4.0]:
		var line := Line2D.new()
		line.name = "ShibuyaCrosswalk"
		line.width = 8
		line.default_color = Color(0.92, 0.92, 0.86, 0.86)
		line.z_index = z
		line.rotation = rot
		line.position = center
		line.add_point(Vector2(-86, 0))
		line.add_point(Vector2(86, 0))
		host._world_node.add_child(line)


func _add_skyscraper_cluster(center: Vector2, z: int) -> void:
	for i in range(5):
		var h := 120.0 + float(i * 28)
		_add_city_block(host._world_node, center + Vector2((i - 2) * 58, (i % 2) * 18), h, z + i * 3)
	_add_monument_collision(center, 120, 52)


