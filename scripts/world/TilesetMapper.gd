class_name TilesetMapper
extends RefCounted

## TilesetMapper — estratto da GameBootstrap. Stato/utility condivise restano nell'host.

var host: Node


func _init(h: Node = null) -> void:
	host = h


func _tile_params(gid: int) -> Dictionary:
	var r := {"tex": null, "region": Rect2(), "ox": 0, "oy": 0, "type": "ground"}
	if gid == 0:
		return r

	var prefix: String = host._tileset_type  # "grassland" or "snowplains"

	if host._tileset_type == "snowplains":
		if gid >= 744:
			r.tex = host._get_tex("res://assets/flare/tilesets/snowplains_rottentower.png")
			r.region = Rect2(0, 0, 1074, 1074)
			r.oy = -1074 + 144; r.type = "tall"
		elif gid >= 520:
			var idx = gid - 520
			r.tex = host._get_tex("res://assets/flare/tilesets/snowplains_other.png")
			r.region = Rect2((idx % 16) * 192, int(idx / 16) * 384, 192, 384)
			r.oy = 96; r.type = "ground"
		elif gid >= 296:
			var idx = gid - 296
			r.tex = host._get_tex("res://assets/flare/tilesets/snowplains_ice.png")
			r.region = Rect2((idx % 16) * 192, int(idx / 16) * 384, 192, 384)
			r.oy = 96; r.type = "ground"
		elif gid >= 264:
			var idx = gid - 264
			r.tex = host._get_tex("res://assets/flare/tilesets/snowplains_2x2.png")
			r.region = Rect2((idx % 4) * 384, int(idx / 4) * 192, 384, 192)
			r.oy = 48; r.type = "ground"
		elif gid >= 240:
			var idx = gid - 240
			r.tex = host._get_tex("res://assets/flare/tilesets/snowplains_trees.png")
			r.region = Rect2((idx % 8) * 384, int(idx / 8) * 768, 384, 768)
			r.ox = -96; r.oy = -290; r.type = "tall"
		elif gid >= 208:
			var idx = gid - 208
			r.tex = host._get_tex("res://assets/flare/tilesets/snowplains_structures.png")
			r.region = Rect2((idx % 16) * 192, int(idx / 16) * 768, 192, 768)
			r.oy = -580; r.type = "tall"
		elif gid >= 144:
			var idx = gid - 144
			r.tex = host._get_tex("res://assets/flare/tilesets/snowplains_water.png")
			r.region = Rect2((idx % 16) * 192, int(idx / 16) * 192, 192, 192)
			r.oy = 96; r.type = "water"
		elif gid >= 16:
			var idx = gid - 16
			r.tex = host._get_tex("res://assets/flare/tilesets/snowplains.png")
			r.region = Rect2((idx % 16) * 192, int(idx / 16) * 384, 192, 384)
			r.type = "ground"

	elif host._tileset_type == "dungeon":
		if gid >= 284:
			var idx = gid - 284
			r.tex = host._get_tex("res://assets/flare/tilesets/dungeon_stairs.png")
			r.region = Rect2((idx % 4) * 768, int(idx / 4) * 768, 768, 768)
			r.oy = -768 + 144; r.type = "tall"
		elif gid >= 282:
			var idx = gid - 282
			r.tex = host._get_tex("res://assets/flare/tilesets/dungeon_door_right.png")
			r.region = Rect2((idx % 2) * 192, int(idx / 2) * 384, 192, 384)
			r.ox = 48; r.oy = -24; r.type = "tall"
		elif gid >= 280:
			var idx = gid - 280
			r.tex = host._get_tex("res://assets/flare/tilesets/dungeon_door_left.png")
			r.region = Rect2((idx % 2) * 192, int(idx / 2) * 384, 192, 384)
			r.ox = -48; r.oy = -24; r.type = "tall"
		elif gid >= 264:
			var idx = gid - 264
			r.tex = host._get_tex("res://assets/flare/tilesets/dungeon_2x2.png")
			r.region = Rect2((idx % 4) * 384, int(idx / 4) * 192, 384, 192)
			r.oy = 48; r.type = "ground"
		elif gid >= 16:
			var idx = gid - 16
			r.tex = host._get_tex("res://assets/flare/tilesets/dungeon.png")
			r.region = Rect2((idx % 16) * 192, int(idx / 16) * 384, 192, 384)
			r.type = "ground"

	else:
		# Grassland
		if gid >= 296:
			r.tex = host._get_tex("res://assets/flare/tilesets/grassland_rottentower.png")
			r.region = Rect2(0, 0, 1074, 1074)
			r.oy = -1074 + 144; r.type = "tall"
		elif gid >= 264:
			var idx = gid - 264
			r.tex = host._get_tex("res://assets/flare/tilesets/grassland_2x2.png")
			r.region = Rect2((idx % 4) * 384, int(idx / 4) * 192, 384, 192)
			r.oy = 48; r.type = "ground"
		elif gid >= 240:
			var idx = gid - 240
			r.tex = host._get_tex("res://assets/flare/tilesets/grassland_trees.png")
			r.region = Rect2((idx % 8) * 384, int(idx / 8) * 768, 384, 768)
			r.ox = -96; r.oy = -290; r.type = "tall"
		elif gid >= 208:
			var idx = gid - 208
			r.tex = host._get_tex("res://assets/flare/tilesets/grassland_structures.png")
			r.region = Rect2((idx % 16) * 192, int(idx / 16) * 768, 192, 768)
			r.oy = -580; r.type = "tall"
		elif gid >= 144:
			var idx = gid - 144
			r.tex = host._get_tex("res://assets/flare/tilesets/grassland_water.png")
			r.region = Rect2((idx % 16) * 192, int(idx / 16) * 192, 192, 192)
			r.oy = 96; r.type = "water"
		elif gid >= 16:
			var idx = gid - 16
			r.tex = host._get_tex("res://assets/flare/tilesets/grassland.png")
			r.region = Rect2((idx % 16) * 192, int(idx / 16) * 384, 192, 384)
			r.type = "ground"

	return r


