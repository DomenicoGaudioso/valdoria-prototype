class_name PortalSpawner
extends RefCounted

## PortalSpawner — estratto da GameBootstrap. Stato/utility condivise restano nell'host.

var host: Node


func _init(h: Node = null) -> void:
	host = h


func _build_portals() -> void:
	var portal_list: Array = (host._current_map.get("portals", []) as Array).duplicate(true)
	if host._current_map_id == "procedural6":
		portal_list.append({"target": host._get_endless_map_id(host.ENDLESS_START_DEPTH), "pos": Vector2(50, 90), "label": "Portale Infinito %d" % host.ENDLESS_START_DEPTH})
	for pdata in portal_list:
		var pos: Vector2 = host._iso(pdata.pos.x, pdata.pos.y)
		var target: String = pdata.target
		var label: String = pdata.get("label", "???")

		var portal_type_info: Dictionary = host._get_portal_type_for_map(host._current_map_id)
		var type_name: String = portal_type_info.get("tag", "[VARCO]")
		var type_color: Color = portal_type_info.get("color", Color(0.55, 0.92, 1.0))
		var ring_color: Color = portal_type_info.get("ring_tint", Color(0.70, 0.24, 1.0, 0.72))
		var outer_ring_color: Color = portal_type_info.get("portal_tint", Color(0.18, 0.86, 1.0, 0.86))
		var portal_palette := _portal_variant_palette(target, type_color, ring_color, outer_ring_color)
		type_color = portal_palette.get("label", type_color)
		ring_color = portal_palette.get("ring", ring_color)
		outer_ring_color = portal_palette.get("outer", outer_ring_color)

		var portal := Node2D.new(); portal.name = "Rift_" + target; portal.position = pos

		var outer := ColorRect.new()
		outer.size = Vector2(92, 92); outer.position = Vector2(-46, -46)
		outer.color = Color(ring_color.r * 0.18, ring_color.g * 0.18, ring_color.b * 0.18, 0.34); outer.pivot_offset = Vector2(46, 46)
		portal.add_child(outer)

		var inner := ColorRect.new()
		inner.size = Vector2(44, 64); inner.position = Vector2(-22, -32)
		inner.color = Color(outer_ring_color.r, outer_ring_color.g, outer_ring_color.b, 0.36); inner.pivot_offset = Vector2(22, 32)
		portal.add_child(inner)
		portal.add_child(_make_portal_ring(56.0, outer_ring_color, 4.0, 0.64))
		portal.add_child(_make_portal_ring(36.0, ring_color, 3.0, 0.72))
		_add_portal_shards(portal, ring_color, int(portal_palette.get("spark_count", 5)))

		var lb := Label.new(); lb.name = "Label"
		lb.text = type_name + "\n" + label
		lb.position = Vector2(-50, -70)
		lb.add_theme_color_override("font_color", type_color)
		lb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		lb.add_theme_constant_override("outline_size", 3)
		lb.add_theme_font_size_override("font_size", 11)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		portal.add_child(lb)

		var area := Area2D.new(); area.name = "PortalArea"
		area.collision_mask = 2
		var ac := CollisionShape2D.new(); ac.name = "CollisionShape2D"
		var ac2 := CircleShape2D.new(); ac2.radius = 80.0; ac.shape = ac2
		area.add_child(ac)
		area.body_entered.connect(Callable(host, "_on_portal_proximity").bind(target))
		area.input_event.connect(Callable(host, "_on_portal_clicked").bind(target))
		portal.add_child(area)

		host._portals.append({"node": portal, "target": target, "pos": portal.position})
		host.add_child(portal)

		var tw := host.create_tween(); tw.set_loops()
		tw.tween_property(outer, "scale", Vector2(1.3, 1.3), 1.0).set_trans(Tween.TRANS_SINE)
		tw.tween_property(outer, "scale", Vector2(0.7, 0.7), 1.0).set_trans(Tween.TRANS_SINE)

		var tw2 := host.create_tween(); tw2.set_loops()
		tw2.tween_property(outer, "rotation", TAU, 5.0)
		tw2.tween_property(outer, "rotation", 0.0, 0.0)


func _make_portal_ring(radius: float, color: Color, width: float, squash: float) -> Line2D:
	var ring := Line2D.new()
	ring.name = "PortalRing"
	ring.closed = true
	ring.width = width
	ring.default_color = color
	ring.z_index = 3050
	for i in range(48):
		var a := TAU * float(i) / 48.0
		ring.add_point(Vector2(cos(a) * radius, sin(a) * radius * squash))
	return ring


func _portal_variant_palette(target: String, type_color: Color, ring_color: Color, outer_ring_color: Color) -> Dictionary:
	var variant_name := ""
	if host._is_endless_map_id(target):
		variant_name = String(host._get_endless_variant(host._parse_endless_depth(target)).get("name", "")).to_lower()
	elif host._is_endless_map_id(host._current_map_id):
		variant_name = String(host._get_endless_variant(host._current_portal_depth).get("name", "")).to_lower()
	if variant_name.is_empty():
		return {"label": type_color, "ring": ring_color, "outer": outer_ring_color, "spark_count": 5}
	var label := type_color
	var ring := ring_color
	var outer := outer_ring_color
	if variant_name.contains("eclisse"):
		label = Color(0.84, 0.58, 1.0, 1.0)
		ring = Color(0.58, 0.25, 1.0, 0.78)
		outer = Color(0.28, 0.18, 0.88, 0.84)
	elif variant_name.contains("ferale"):
		label = Color(0.62, 1.0, 0.38, 1.0)
		ring = Color(0.32, 0.82, 0.26, 0.78)
		outer = Color(0.74, 0.48, 0.16, 0.82)
	elif variant_name.contains("mirmidone"):
		label = Color(0.88, 0.76, 0.42, 1.0)
		ring = Color(0.78, 0.62, 0.26, 0.78)
		outer = Color(0.18, 0.76, 0.82, 0.82)
	elif variant_name.contains("draconico"):
		label = Color(1.0, 0.64, 0.28, 1.0)
		ring = Color(1.0, 0.32, 0.18, 0.78)
		outer = Color(1.0, 0.72, 0.22, 0.82)
	elif variant_name.contains("guerra"):
		label = Color(0.96, 0.30, 0.24, 1.0)
		ring = Color(0.70, 0.16, 0.14, 0.78)
		outer = Color(0.70, 0.68, 0.62, 0.82)
	var depth: int = host._parse_endless_depth(target) if host._is_endless_map_id(target) else host._current_portal_depth
	var spark_count := clampi(6 + int(maxi(depth - host.ENDLESS_START_DEPTH, 0) / 3), 6, 12)
	return {"label": label, "ring": ring, "outer": outer, "spark_count": spark_count}


func _add_portal_shards(portal: Node2D, color: Color = Color(0.68, 0.24, 1.0, 0.42), spark_count: int = 5) -> void:
	for i in range(5):
		var shard := Polygon2D.new()
		shard.name = "PortalShard"
		var a := TAU * float(i) / 5.0
		var p := Vector2(cos(a) * 64.0, sin(a) * 42.0)
		shard.position = p
		shard.rotation = a
		shard.polygon = PackedVector2Array([Vector2(-4, 0), Vector2(0, -15), Vector2(5, 2), Vector2(0, 8)])
		shard.color = Color(color.r, color.g, color.b, 0.42)
		shard.z_index = 3049
		portal.add_child(shard)
	var sparks := Node2D.new()
	sparks.name = "PortalVariantSparks"
	sparks.z_index = 3051
	portal.add_child(sparks)
	for i in range(clampi(spark_count, 3, 12)):
		var spark := Line2D.new()
		spark.name = "PortalSpark"
		var a := TAU * float(i) / float(maxi(spark_count, 1))
		var inner := Vector2(cos(a) * 42.0, sin(a) * 27.0)
		var outer := Vector2(cos(a) * 68.0, sin(a) * 43.0)
		spark.add_point(inner)
		spark.add_point(outer)
		spark.width = 1.4
		spark.default_color = Color(color.r, color.g, color.b, 0.34)
		spark.z_index = 3051
		sparks.add_child(spark)


