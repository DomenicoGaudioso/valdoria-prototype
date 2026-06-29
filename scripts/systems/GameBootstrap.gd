extends Node2D

## Eldrath. Dark fantasy ARPG with shadow rifts.
## 37+ maps. Story: 5 heroes, 5 archons, infinite portals.

const MAP_REGISTRY: GDScript = preload("res://data/MapRegistry.gd")
const ItemDataClass: GDScript = preload("res://scripts/items/ItemData.gd")
const ItemEffectsClass: GDScript = preload("res://scripts/items/ItemEffects.gd")
const PortalTypesClass: GDScript = preload("res://data/PortalTypes.gd")
const BossLoreClass: GDScript = preload("res://data/BossLore.gd")
const SkillTreeClass: GDScript = preload("res://scripts/progression/SkillTree.gd")
const EVAL_START_MAP: String = "black_oak_city"
const FORCE_REAL_CITY_START: bool = false

var _current_map_id: String = EVAL_START_MAP
var _current_map: Dictionary = {}
var _portals: Array = []  # [{pos, target, label, sprite}]
var _player_node: CharacterBody2D = null
var _cam: Camera2D = null
var _world_node: Node2D = null
var _hero_line_cooldown: float = 0.0
var _last_enemy_count: int = 0
var _osm_cache: Dictionary = {}
var _autosave_pending: bool = false
var _system_ui_connected: bool = false

func _ready() -> void:
	randomize()
	var requested_map: String = _get_requested_start_map()
	if not requested_map.is_empty():
		_current_map_id = requested_map
	print("=== ELDRATH - Multi-World ===")
	
	# During map-visual evaluation, start directly in the real-city network.
	var sm := get_node_or_null("/root/SaveManager")
	if not FORCE_REAL_CITY_START and sm and sm.has_save():
		var data: Dictionary = sm.load_game() as Dictionary
		if not data.is_empty():
			_current_map_id = data.get("map_id", "black_oak_farm")
			_load_map(_current_map_id)
			await get_tree().process_frame
			_apply_loaded_data(data)
			print("=== READY (loaded) ===")
			return
	
	_load_map(_current_map_id)
	print("=== READY ===")


func _get_requested_start_map() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--start-map="):
			var map_id: String = arg.get_slice("=", 1)
			for map_data in MAP_REGISTRY.get_all_maps():
				if String(map_data.get("id", "")) == map_id:
					return map_id
			push_warning("Mappa richiesta non trovata: %s" % map_id)
	return ""


func _apply_loaded_data(data: Dictionary) -> void:
	if not _player_node: return
	_player_node.set("level", data.get("level", 1))
	_player_node.set("xp", data.get("xp", 0))
	_player_node.set("xp_to_next_level", data.get("xp_to_next", 30))
	_player_node.set("total_xp_earned", data.get("total_xp_earned", 0))
	_player_node.set("ascension_level", data.get("ascension_level", 0))
	_player_node.set("ascension_points", data.get("ascension_points", 0))
	_player_node.set("highest_portal_depth", data.get("highest_portal_depth", 1))
	_player_node.set("season_level", data.get("season_level", 1))
	_player_node.set("base_hp", data.get("base_hp", 100))
	_player_node.set("base_damage", data.get("base_damage", 10))
	_player_node.set("base_speed", data.get("base_speed", 200.0))
	_player_node.set("base_defense", data.get("base_defense", 0))
	_player_node.set("base_agility", data.get("base_agility", 0))
	_player_node.set("max_hp", data.get("max_hp", 100))
	_player_node.set("current_hp", max(data.get("current_hp", 100), 1))
	_player_node.set("attack_damage", data.get("attack_damage", 10))
	_player_node.set("move_speed", data.get("move_speed", 200.0))
	_player_node.set("defense", data.get("defense", 0))
	_player_node.set("agility", data.get("agility", 0))
	_player_node.set("gold", data.get("gold", 0))
	_player_node.health_changed.emit(_player_node.current_hp, _player_node.max_hp)
	_player_node.xp_changed.emit(_player_node.xp, _player_node.xp_to_next_level)
	_player_node.gold_changed.emit(_player_node.gold)
	
	# Restore equipment
	var ItemDataClass = preload("res://scripts/items/ItemData.gd")
	var eq: Dictionary = data.get("equipment", {})
	for slot in eq:
		var def := eq[slot] as Dictionary
		var item = ItemDataClass.create_equipment_from_def({
			"id": def.id, "name": def["name"], "slot": def.slot,
			"rarity": def.rarity, "value": def.value,
			"dmg": def.dmg, "def": def.get("def", 0), "hp": def.hp, "spd": def.spd, "agi": def.get("agi", 0),
			"mat": def.get("mat", ""), "tint": def.get("tint", []),
			"effect": def.get("effect", ""), "efx_val": def.get("efx_val", 0.0),
			"flavor": def.get("flavor", ""), "corrupt": def.get("corrupt", false),
			"corr_text": def.get("corr_text", ""), "set_id": def.get("set_id", ""),
			"rank": def.get("rank", "E"), "upgrade_level": def.get("upgrade_level", 0),
			"ascension_power": def.get("ascension_power", 0), "soulbound": def.get("soulbound", false),
		})
		_player_node.equipment[slot] = item
		if _player_node.has_method("_apply_item_effects"):
			_player_node._apply_item_effects(item, true)
	_player_node._recalc_equip_stats()
	if _player_node.has_method("_update_equipment_visuals"):
		_player_node._update_equipment_visuals()
	
	# Restore inventory
	var inv := get_node_or_null("/root/Inventory")
	if inv:
		inv.clear()
		var items: Array = data.get("inventory", [])
		for idata in items:
			var def := idata as Dictionary
			if def.get("slot", "").is_empty(): continue
			var item = ItemDataClass.create_equipment_from_def({
				"id": def.id, "name": def["name"], "slot": def.slot,
				"rarity": def.get("rarity","common"), "value": def.get("value",0),
				"dmg": def.get("dmg",0), "def": def.get("def",0),
				"hp": def.get("hp",0), "spd": def.get("spd",0), "agi": def.get("agi",0),
				"mat": def.get("mat", ""), "tint": def.get("tint", []),
				"effect": def.get("effect", ""), "efx_val": def.get("efx_val", 0.0),
				"flavor": def.get("flavor", ""), "corrupt": def.get("corrupt", false),
				"corr_text": def.get("corr_text", ""), "set_id": def.get("set_id", ""),
				"rank": def.get("rank", "E"), "upgrade_level": def.get("upgrade_level", 0),
				"ascension_power": def.get("ascension_power", 0), "soulbound": def.get("soulbound", false),
			})
			inv.add_item(item)


func _load_tex(path: String) -> Texture2D:
	# Load raw PNGs first to avoid ResourceLoader errors for assets that are
	# intentionally present on disk but not imported in the local .godot cache.
	var absolute_path := ProjectSettings.globalize_path(path)
	var img := Image.load_from_file(absolute_path)
	if img:
		return ImageTexture.create_from_image(img)
	var tex: Texture2D = load(path) as Texture2D
	if tex:
		return tex
	return null


func _iso(xx: float, yy: float) -> Vector2:
	var TW: float = 192.0; var MW: int = 100
	return Vector2((xx - yy) * TW * 0.5 + MW * TW * 0.3, (xx + yy) * TW * 0.25 + 50)


func _add_sprite(parent: Node, tex: Texture2D, rect: Rect2, pos: Vector2, z: int, scl: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex; s.region_enabled = true; s.region_rect = rect
	s.position = pos; s.z_index = z; s.scale = scl; s.centered = false
	parent.add_child(s)
	return s


# ===== MAP LOADER =====

func _load_map(map_id: String) -> void:
	_current_map_id = map_id
	_current_map = MAP_REGISTRY.get_map(map_id)
	_tileset_type = _current_map.get("tileset", "grassland")
	print("Loading: %s — %s [%s]" % [map_id, _current_map.title, _tileset_type])

	# Clear existing world, enemies, portals
	_clear_world()

	# Build new world
	_build_world()
	_build_scene_atmosphere()
	_build_player()
	_build_enemies()
	_build_portals()
	_build_ui()
	_connect_input()
	_register_system_map_change(map_id)

	if has_node("GameUI") and $GameUI.has_method("show_debug_message"):
		var story_line: String = _story_map_flavor(map_id)
		if not story_line.is_empty():
			$GameUI.show_debug_message(story_line)
		else:
			$GameUI.show_debug_message("[%s] %s" % [_current_map.title, _current_map.desc])


func _story_map_flavor(map_id: String) -> String:
	match map_id:
		"book_of_the_dead":
			return "La Biblioteca dei Portali custodisce segreti che uccidono. Ogni libro e un varco."
		"stormrock_ruins":
			return "Rovine maledette dove gli Arconti hanno combattuto la loro prima guerra."
		"st_maria_1":
			return "Cripta di St. Maria — Livello I. I morti qui non riposano mai."
		"st_maria_2":
			return "Cripta di St. Maria — Livello II. L'oscurita si infittisce."
		"st_maria_3":
			return "Cripta di St. Maria — Livello III. Il boss finale ti attende nel cuore della cripta."
		"fort_nasu":
			return "Fortezza sotterranea. Si dice che Ghoran abbia forgiato qui le prime rune."
		"black_oak_city":
			return "La citta fortificata resiste all'Eclisse. L'ultimo baluardo prima dei Portali."
		"grot_lagoon":
			return "Laguna ghiacciata. Le bestie fuse di Maelyra cacciano sotto il ghiaccio."
		"new_york":
			return "New York City — La metropoli e caduta. I grattacieli sono nidi di creature."
		"manhattan":
			return "Manhattan Skyline — Draghi e viverni volteggiano tra i grattacieli."
		"cyberpunk":
			return "Cyberpunk City — Neon e oscurita. Tecnologia corrotta dai Portali."
		"postwar_city":
			return "Citta del dopoguerra — Macerie e silenzio. I non-morti regnano."
		"ruined_city":
			return "Rovine urbane — Qui gli Arconti hanno aperto il primo varco su Eldrath."
		"procedural6":
			return "Ultimo blocco del Portale. Il boss ti aspetta in cima."
		_:
			return ""


func _clear_world() -> void:
	for child in get_children():
		if child.name not in ["InputController"]:
			remove_child(child)
			child.queue_free()
	_clear_tweens()
	_portals.clear()
	_world_node = null


func _clear_tweens() -> void:
	for tw in get_tree().get_processed_tweens():
		tw.kill()


# ===== TMX MAP RENDERER =====

var _tex_cache: Dictionary = {}

func _get_tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = _load_tex(path)
	return _tex_cache[path]


var _tileset_type: String = "grassland"

func _tile_params(gid: int) -> Dictionary:
	var r := {"tex": null, "region": Rect2(), "ox": 0, "oy": 0, "type": "ground"}
	if gid == 0:
		return r

	var prefix := _tileset_type  # "grassland" or "snowplains"

	if _tileset_type == "snowplains":
		if gid >= 744:
			r.tex = _get_tex("res://assets/flare/tilesets/snowplains_rottentower.png")
			r.region = Rect2(0, 0, 1074, 1074)
			r.oy = -1074 + 144; r.type = "tall"
		elif gid >= 520:
			var idx = gid - 520
			r.tex = _get_tex("res://assets/flare/tilesets/snowplains_other.png")
			r.region = Rect2((idx % 16) * 192, int(idx / 16) * 384, 192, 384)
			r.oy = 96; r.type = "ground"
		elif gid >= 296:
			var idx = gid - 296
			r.tex = _get_tex("res://assets/flare/tilesets/snowplains_ice.png")
			r.region = Rect2((idx % 16) * 192, int(idx / 16) * 384, 192, 384)
			r.oy = 96; r.type = "ground"
		elif gid >= 264:
			var idx = gid - 264
			r.tex = _get_tex("res://assets/flare/tilesets/snowplains_2x2.png")
			r.region = Rect2((idx % 4) * 384, int(idx / 4) * 192, 384, 192)
			r.oy = 48; r.type = "ground"
		elif gid >= 240:
			var idx = gid - 240
			r.tex = _get_tex("res://assets/flare/tilesets/snowplains_trees.png")
			r.region = Rect2((idx % 8) * 384, int(idx / 8) * 768, 384, 768)
			r.ox = -96; r.oy = -290; r.type = "tall"
		elif gid >= 208:
			var idx = gid - 208
			r.tex = _get_tex("res://assets/flare/tilesets/snowplains_structures.png")
			r.region = Rect2((idx % 16) * 192, int(idx / 16) * 768, 192, 768)
			r.oy = -580; r.type = "tall"
		elif gid >= 144:
			var idx = gid - 144
			r.tex = _get_tex("res://assets/flare/tilesets/snowplains_water.png")
			r.region = Rect2((idx % 16) * 192, int(idx / 16) * 192, 192, 192)
			r.oy = 96; r.type = "water"
		elif gid >= 16:
			var idx = gid - 16
			r.tex = _get_tex("res://assets/flare/tilesets/snowplains.png")
			r.region = Rect2((idx % 16) * 192, int(idx / 16) * 384, 192, 384)
			r.type = "ground"

	elif _tileset_type == "dungeon":
		if gid >= 284:
			var idx = gid - 284
			r.tex = _get_tex("res://assets/flare/tilesets/dungeon_stairs.png")
			r.region = Rect2((idx % 4) * 768, int(idx / 4) * 768, 768, 768)
			r.oy = -768 + 144; r.type = "tall"
		elif gid >= 282:
			var idx = gid - 282
			r.tex = _get_tex("res://assets/flare/tilesets/dungeon_door_right.png")
			r.region = Rect2((idx % 2) * 192, int(idx / 2) * 384, 192, 384)
			r.ox = 48; r.oy = -24; r.type = "tall"
		elif gid >= 280:
			var idx = gid - 280
			r.tex = _get_tex("res://assets/flare/tilesets/dungeon_door_left.png")
			r.region = Rect2((idx % 2) * 192, int(idx / 2) * 384, 192, 384)
			r.ox = -48; r.oy = -24; r.type = "tall"
		elif gid >= 264:
			var idx = gid - 264
			r.tex = _get_tex("res://assets/flare/tilesets/dungeon_2x2.png")
			r.region = Rect2((idx % 4) * 384, int(idx / 4) * 192, 384, 192)
			r.oy = 48; r.type = "ground"
		elif gid >= 16:
			var idx = gid - 16
			r.tex = _get_tex("res://assets/flare/tilesets/dungeon.png")
			r.region = Rect2((idx % 16) * 192, int(idx / 16) * 384, 192, 384)
			r.type = "ground"

	else:
		# Grassland
		if gid >= 296:
			r.tex = _get_tex("res://assets/flare/tilesets/grassland_rottentower.png")
			r.region = Rect2(0, 0, 1074, 1074)
			r.oy = -1074 + 144; r.type = "tall"
		elif gid >= 264:
			var idx = gid - 264
			r.tex = _get_tex("res://assets/flare/tilesets/grassland_2x2.png")
			r.region = Rect2((idx % 4) * 384, int(idx / 4) * 192, 384, 192)
			r.oy = 48; r.type = "ground"
		elif gid >= 240:
			var idx = gid - 240
			r.tex = _get_tex("res://assets/flare/tilesets/grassland_trees.png")
			r.region = Rect2((idx % 8) * 384, int(idx / 8) * 768, 384, 768)
			r.ox = -96; r.oy = -290; r.type = "tall"
		elif gid >= 208:
			var idx = gid - 208
			r.tex = _get_tex("res://assets/flare/tilesets/grassland_structures.png")
			r.region = Rect2((idx % 16) * 192, int(idx / 16) * 768, 192, 768)
			r.oy = -580; r.type = "tall"
		elif gid >= 144:
			var idx = gid - 144
			r.tex = _get_tex("res://assets/flare/tilesets/grassland_water.png")
			r.region = Rect2((idx % 16) * 192, int(idx / 16) * 192, 192, 192)
			r.oy = 96; r.type = "water"
		elif gid >= 16:
			var idx = gid - 16
			r.tex = _get_tex("res://assets/flare/tilesets/grassland.png")
			r.region = Rect2((idx % 16) * 192, int(idx / 16) * 384, 192, 384)
			r.type = "ground"

	return r


func _build_world() -> void:
	_world_node = Node2D.new(); _world_node.name = "World"; add_child(_world_node)
	var data: Dictionary = _current_map.data.get_data()
	var w: int = data.width; var h: int = data.height

	var default_grass_tex := _get_tex("res://assets/flare/tilesets/grassland.png")
	var default_grass_rect := Rect2(0, 0, 192, 384)
	
	if _tileset_type == "dungeon":
		default_grass_tex = _get_tex("res://assets/flare/tilesets/dungeon.png")
		default_grass_rect = Rect2(0, 0, 192, 384)  # Stone floor tile

	for y in h:
		var bg_row = data.background[y]
		var obj_row = data.object[y]
		for x in w:
			var pos = _iso(x, y)
			var bg_gid = bg_row[x]
			if bg_gid > 0:
				var p = _tile_params(bg_gid)
				if p.tex == null: continue
				var z = -20 if p.type != "water" else -19
				var ground_sprite := _add_sprite(_world_node, p.tex, p.region, Vector2(pos.x + p.ox, pos.y + p.oy), z, Vector2.ONE)
				if _is_real_city():
					ground_sprite.modulate = _city_base_tint(bg_gid)
			else:
				var ground_sprite := _add_sprite(_world_node, default_grass_tex, default_grass_rect, pos, -20, Vector2.ONE)
				if _is_real_city():
					ground_sprite.modulate = Color(0.48, 0.54, 0.48, 1.0)

			var obj_gid = obj_row[x]
			if obj_gid > 0:
				if not _is_real_city():
					var p = _tile_params(obj_gid)
					if p.tex == null: continue
					var z = (x + y) * 12
					_add_sprite(_world_node, p.tex, p.region, Vector2(pos.x + p.ox, pos.y + p.oy), z, Vector2.ONE)

				if _is_real_city():
					_add_city_overlay_cell(_world_node, x, y, bg_gid, obj_gid, pos)
					if _has_city_vector_source():
						continue
					elif bg_gid >= 176 and bg_gid <= 191:
						_add_city_collision(_world_node, pos, "water")
					elif obj_gid > 0 and _should_draw_city_block(x, y):
						_add_city_collision(_world_node, pos, "building")

	if _is_real_city():
		if _has_city_vector_source():
			_add_real_city_vector_layer()
		_add_city_landmarks()


func _build_scene_atmosphere() -> void:
	var mood := _get_scene_mood()

	var tint := CanvasModulate.new()
	tint.name = "SceneTint"
	tint.color = mood.get("canvas", Color(0.88, 0.93, 1.0, 1.0))
	add_child(tint)

	_add_ambient_motes(
		mood.get("mote_color", Color(0.55, 0.82, 1.0, 0.26)),
		int(mood.get("mote_count", 42))
	)
	_add_screen_vignette(
		mood.get("top_vignette", Color(0.02, 0.01, 0.04, 0.22)),
		mood.get("bottom_vignette", Color(0.01, 0.0, 0.02, 0.34))
	)


func _get_scene_mood() -> Dictionary:
	var style: String = _current_map.get("city_style", "")
	if _tileset_type == "dungeon":
		return {
			"canvas": Color(0.70, 0.73, 0.82, 1.0),
			"mote_color": Color(0.76, 0.38, 1.0, 0.34),
			"mote_count": 30,
			"top_vignette": Color(0.03, 0.0, 0.05, 0.34),
			"bottom_vignette": Color(0.0, 0.0, 0.0, 0.46),
		}
	if _tileset_type == "snowplains":
		return {
			"canvas": Color(0.82, 0.91, 1.0, 1.0),
			"mote_color": Color(0.78, 0.94, 1.0, 0.30),
			"mote_count": 54,
			"top_vignette": Color(0.02, 0.08, 0.14, 0.24),
			"bottom_vignette": Color(0.01, 0.03, 0.07, 0.30),
		}
	if _current_map_id in ["cyberpunk", "lowpoly_night"] or style in ["urban_3d", "dense_3d"]:
		return {
			"canvas": Color(0.80, 0.88, 1.0, 1.0),
			"mote_color": Color(0.22, 0.92, 1.0, 0.30),
			"mote_count": 48,
			"top_vignette": Color(0.01, 0.03, 0.09, 0.30),
			"bottom_vignette": Color(0.01, 0.0, 0.04, 0.38),
		}
	if style in ["ancient", "water_city", "gothic"]:
		return {
			"canvas": Color(0.88, 0.86, 0.78, 1.0),
			"mote_color": Color(1.0, 0.72, 0.34, 0.24),
			"mote_count": 36,
			"top_vignette": Color(0.08, 0.04, 0.01, 0.20),
			"bottom_vignette": Color(0.04, 0.02, 0.0, 0.32),
		}
	return {
		"canvas": Color(0.84, 0.90, 0.86, 1.0),
		"mote_color": Color(0.64, 0.90, 0.62, 0.22),
		"mote_count": 40,
		"top_vignette": Color(0.02, 0.04, 0.03, 0.20),
		"bottom_vignette": Color(0.0, 0.01, 0.0, 0.32),
	}


func _add_screen_vignette(top_color: Color, bottom_color: Color) -> void:
	var layer := CanvasLayer.new()
	layer.name = "AtmosphereOverlay"
	layer.layer = 0
	add_child(layer)

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


func _add_ambient_motes(color: Color, amount: int) -> void:
	if not _world_node or not _current_map.has("data"):
		return
	var data: Dictionary = _current_map.data.get_data()
	var width := float(data.get("width", 80))
	var height := float(data.get("height", 80))
	var layer := Node2D.new()
	layer.name = "AmbientMotes"
	layer.z_index = 4085
	_world_node.add_child(layer)

	for i in range(amount):
		var mote := Polygon2D.new()
		var r := randf_range(1.2, 3.2)
		mote.name = "Mote"
		mote.polygon = PackedVector2Array([
			Vector2(0.0, -r), Vector2(r, 0.0), Vector2(0.0, r), Vector2(-r, 0.0),
		])
		mote.color = color
		mote.position = _iso(randf_range(0.0, width), randf_range(0.0, height)) + Vector2(randf_range(-70.0, 70.0), randf_range(-55.0, 55.0))
		mote.modulate.a = randf_range(0.24, 0.62)
		mote.rotation = randf_range(0.0, TAU)
		layer.add_child(mote)

		var start_pos := mote.position
		var start_alpha := mote.modulate.a
		var drift := Vector2(randf_range(-24.0, 24.0), randf_range(-80.0, -34.0))
		var duration := randf_range(4.2, 7.8)
		var tw := create_tween()
		tw.set_loops()
		tw.tween_property(mote, "position", start_pos + drift, duration).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(mote, "modulate:a", 0.0, duration)
		tw.parallel().tween_property(mote, "rotation", mote.rotation + randf_range(-1.2, 1.2), duration)
		tw.tween_callback(func():
			if is_instance_valid(mote):
				mote.position = start_pos
				mote.modulate.a = start_alpha
		)


func _is_real_city() -> bool:
	return _current_map.get("real_city", false)


func _city_base_tint(gid: int) -> Color:
	var style: String = _current_map.get("city_style", "urban_3d")
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
		var style: String = _current_map.get("city_style", "urban_3d")
		var road_color := Color(0.22, 0.22, 0.23, 0.88)
		if style == "ancient":
			road_color = Color(0.44, 0.37, 0.29, 0.88)
		elif style == "water_city":
			road_color = Color(0.48, 0.42, 0.34, 0.86)
		_add_iso_diamond(parent, pos, road_color, -7)

	if obj_gid > 0 and _should_draw_city_block(x, y) and not _has_city_vector_source():
		var height := 36.0 + float((obj_gid * 13 + x * 7 + y * 5) % 58)
		var style: String = _current_map.get("city_style", "urban_3d")
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
	var style: String = _current_map.get("city_style", "urban_3d")
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
	var style: String = _current_map.get("city_style", "urban_3d")
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
	var source_path: String = _current_map.get("osm_source", "")
	return not source_path.is_empty() and FileAccess.file_exists(source_path)


func _load_city_osm() -> Dictionary:
	var source_path: String = _current_map.get("osm_source", "")
	if source_path.is_empty():
		return {}
	if _osm_cache.has(source_path):
		return _osm_cache[source_path] as Dictionary
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
	_osm_cache[source_path] = osm
	return osm


func _has_city_detail_source() -> bool:
	var source_path: String = _current_map.get("detail_source", "")
	return not source_path.is_empty() and FileAccess.file_exists(source_path)


func _load_city_detail() -> Dictionary:
	var source_path: String = _current_map.get("detail_source", "")
	if source_path.is_empty():
		return {}
	if _osm_cache.has(source_path):
		return _osm_cache[source_path] as Dictionary
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
	_osm_cache[source_path] = detail
	return detail


func _city_detail_limit() -> int:
	match _current_map_id:
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
	var bbox: Array = _current_map.get("bbox", [])
	if bbox.size() < 4:
		return []
	return bbox


func _city_vector_limits() -> Dictionary:
	match _current_map_id:
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
	_world_node.add_child(collision_body)

	var limits: Dictionary = _city_vector_limits()
	var drawn_water: int = _draw_osm_bucket(buckets["water"] as Array, bbox, collision_body, "water", limits.get("water", 80))
	var drawn_parks: int = _draw_osm_bucket(buckets["park"] as Array, bbox, collision_body, "park", limits.get("parks", 80))
	var drawn_roads: int = _draw_osm_bucket(buckets["road"] as Array, bbox, collision_body, "road", limits.get("roads", 900))
	var label_seen: Dictionary = {}
	var label_count: int = 0
	label_count += _draw_osm_pois(buckets["poi"] as Array, bbox, label_seen, limits.get("labels", 28))
	var drawn_buildings: int = 0
	var detail_kind: String = _current_map.get("detail_kind", "")
	if _has_city_detail_source():
		drawn_buildings = _draw_city_detail_layer(bbox, collision_body, _city_detail_limit())
	else:
		drawn_buildings = _draw_osm_buildings(buckets["building"] as Array, bbox, collision_body, label_seen, max(0, limits.get("labels", 28) - label_count), limits.get("buildings", 620))
	print("Real city layer: %s detail=%s buildings=%d roads=%d water=%d parks=%d labels=%d" % [_current_map_id, detail_kind if not detail_kind.is_empty() else "osm", drawn_buildings, drawn_roads, drawn_water, drawn_parks, label_seen.size()])


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
	return _iso(gx, gy) + Vector2(96, 48)


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
		_world_node.add_child(poly)
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
	_world_node.add_child(line)
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
	_world_node.add_child(poly)
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
	casing.default_color = Color(0.06, 0.06, 0.06, 0.34)
	casing.z_index = -3
	casing.joint_mode = Line2D.LINE_JOINT_ROUND
	casing.begin_cap_mode = Line2D.LINE_CAP_ROUND
	casing.end_cap_mode = Line2D.LINE_CAP_ROUND
	_world_node.add_child(casing)

	var line := Line2D.new()
	line.name = "OSMRoad"
	line.points = _packed_points(line_points)
	line.width = _road_width(highway)
	line.default_color = _road_color(highway)
	line.z_index = -2
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_world_node.add_child(line)
	return true


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
	var style: String = _current_map.get("city_style", "urban_3d")
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
	_world_node.add_child(shadow)

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
		_world_node.add_child(face)

	var roof := Polygon2D.new()
	roof.name = "OSMBuildingRoof"
	roof.polygon = _packed_points(top_points)
	roof.color = _city_roof_color(style) if not important else _important_roof_color(style)
	roof.z_index = z
	_world_node.add_child(roof)

	var outline_points: Array[Vector2] = top_points.duplicate()
	if not outline_points.is_empty():
		outline_points.append(outline_points[0])
	var outline := Line2D.new()
	outline.name = "OSMBuildingOutline"
	outline.points = _packed_points(outline_points)
	outline.width = 2.0 if important else 1.0
	outline.default_color = Color(0.05, 0.04, 0.03, 0.55)
	outline.z_index = z + 1
	_world_node.add_child(outline)

	if height > 84.0:
		_add_building_window_strips(center, height, z + 2)
	_add_osm_collision(collision_body, footprint, 18 if important else 12)
	return true


func _add_building_window_strips(center: Vector2, height: float, z: int) -> void:
	var strips: int = clampi(int(height / 42.0), 2, 5)
	for i in range(strips):
		var stripe := ColorRect.new()
		stripe.name = "OSMBuildingWindows"
		stripe.size = Vector2(28, 3)
		stripe.position = center + Vector2(8, -height + 20 + i * 25)
		stripe.color = Color(0.95, 0.78, 0.36, 0.68)
		stripe.z_index = z + i
		_world_node.add_child(stripe)


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
	var style: String = _current_map.get("city_style", "urban_3d")
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
	return Color(0.23, 0.24, 0.26, 0.96)


func _city_water_color() -> Color:
	var style: String = _current_map.get("city_style", "urban_3d")
	if style == "water_city":
		return Color(0.03, 0.31, 0.43, 0.94)
	if style == "gothic":
		return Color(0.08, 0.26, 0.45, 0.92)
	return Color(0.04, 0.24, 0.38, 0.92)


func _city_park_color() -> Color:
	var style: String = _current_map.get("city_style", "urban_3d")
	if style == "ancient":
		return Color(0.25, 0.38, 0.24, 0.70)
	if style == "water_city":
		return Color(0.22, 0.42, 0.31, 0.70)
	return Color(0.18, 0.34, 0.24, 0.68)


func _city_label_color() -> Color:
	var style: String = _current_map.get("city_style", "urban_3d")
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
		var seed: int = abs(element_id * 37 + _current_map_id.length() * 19)
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
	match _current_map_id:
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
	lb.add_theme_constant_override("outline_size", 4)
	lb.add_theme_font_size_override("font_size", 12)
	lb.z_index = z
	_world_node.add_child(lb)
	return true


func _add_city_landmarks() -> void:
	var title: String = _current_map.get("title", "Real City")
	var style: String = _current_map.get("city_style", "urban_3d")
	var markers: Array[Dictionary] = []
	match _current_map_id:
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
	header.position = _iso(39, 31) + Vector2(-70, -190)
	header.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0))
	header.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	header.add_theme_constant_override("outline_size", 5)
	header.add_theme_font_size_override("font_size", 26)
	header.z_index = 3600
	_world_node.add_child(header)

	for marker in markers:
		var p: Vector2 = marker["pos"]
		var world := _iso(p.x, p.y)
		var beacon := Polygon2D.new()
		beacon.name = "CityLandmarkBeacon"
		beacon.polygon = PackedVector2Array([Vector2(0, -55), Vector2(18, 0), Vector2(0, 18), Vector2(-18, 0)])
		beacon.position = world + Vector2(96, -28)
		beacon.color = marker["color"]
		beacon.z_index = 3650
		_world_node.add_child(beacon)

		var lb := Label.new()
		lb.name = "CityLandmarkLabel"
		lb.text = marker["label"]
		lb.position = world + Vector2(42, -104)
		lb.add_theme_color_override("font_color", marker["color"])
		lb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		lb.add_theme_constant_override("outline_size", 4)
		lb.add_theme_font_size_override("font_size", 14 if style != "dense_3d" else 16)
		lb.z_index = 3651
		_world_node.add_child(lb)

	_add_city_specific_monuments()


func _add_city_specific_monuments() -> void:
	match _current_map_id:
		"roma_centro":
			_add_colosseum(_iso(58, 54) + Vector2(96, 52), 3520)
			_add_ruin_columns(_iso(51, 50) + Vector2(96, 50), 3515)
		"venezia_rialto":
			_add_rialto_bridge(_iso(48, 47) + Vector2(96, 48), 3520)
			_add_bell_tower(_iso(70, 61) + Vector2(96, 48), 3530, Color(0.74, 0.50, 0.32))
		"parigi_cite":
			_add_notre_dame(_iso(56, 51) + Vector2(96, 48), 3530)
		"berlin_mitte_3d":
			_add_brandenburg_gate(_iso(35, 46) + Vector2(96, 48), 3530)
		"tokyo_shibuya":
			_add_shibuya_crossing(_iso(52, 50) + Vector2(96, 48), 3510)
			_add_skyscraper_cluster(_iso(62, 45) + Vector2(96, 48), 3530)


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
	_world_node.add_child(body)


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
	_world_node.add_child(outer)

	var inner := Polygon2D.new()
	inner.name = "ColosseumArena"
	inner.position = center + Vector2(0, -4)
	inner.polygon = _ellipse_points(55, 24, 40)
	inner.color = Color(0.30, 0.22, 0.18, 1.0)
	inner.z_index = z + 1
	_world_node.add_child(inner)

	for i in range(10):
		var arch := ColorRect.new()
		arch.name = "ColosseumArch"
		arch.size = Vector2(10, 14)
		var a := TAU * float(i) / 10.0
		arch.position = center + Vector2(cos(a) * 68 - 5, sin(a) * 30 - 7)
		arch.color = Color(0.16, 0.11, 0.08, 0.85)
		arch.z_index = z + 2
		_world_node.add_child(arch)
	_add_monument_collision(center, 92, 44)


func _add_ruin_columns(center: Vector2, z: int) -> void:
	for i in range(6):
		var col := ColorRect.new()
		col.name = "ForumColumn"
		col.size = Vector2(12, 54 + (i % 3) * 10)
		col.position = center + Vector2((i - 3) * 24, -col.size.y)
		col.color = Color(0.74, 0.66, 0.52, 1.0)
		col.z_index = z + i
		_world_node.add_child(col)
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
	_world_node.add_child(bridge)
	_add_monument_collision(center, 88, 32)


func _add_bell_tower(center: Vector2, z: int, color: Color) -> void:
	var tower := ColorRect.new()
	tower.name = "BellTower"
	tower.size = Vector2(42, 150)
	tower.position = center + Vector2(-21, -150)
	tower.color = color
	tower.z_index = z
	_world_node.add_child(tower)
	var roof := Polygon2D.new()
	roof.name = "BellTowerRoof"
	roof.position = center + Vector2(0, -160)
	roof.polygon = PackedVector2Array([Vector2(0, -42), Vector2(32, 0), Vector2(0, 20), Vector2(-32, 0)])
	roof.color = Color(0.28, 0.42, 0.34, 1.0)
	roof.z_index = z + 1
	_world_node.add_child(roof)
	_add_monument_collision(center, 34, 30)


func _add_notre_dame(center: Vector2, z: int) -> void:
	var nave := Polygon2D.new()
	nave.name = "NotreDameNave"
	nave.position = center
	nave.polygon = PackedVector2Array([Vector2(-82, 24), Vector2(0, -30), Vector2(92, 18), Vector2(16, 58)])
	nave.color = Color(0.42, 0.39, 0.44, 1.0)
	nave.z_index = z
	_world_node.add_child(nave)
	for x in [-46, 22]:
		var tower := ColorRect.new()
		tower.name = "NotreDameTower"
		tower.size = Vector2(38, 110)
		tower.position = center + Vector2(x, -112)
		tower.color = Color(0.34, 0.34, 0.39, 1.0)
		tower.z_index = z + 1
		_world_node.add_child(tower)
	_add_monument_collision(center, 92, 46)


func _add_brandenburg_gate(center: Vector2, z: int) -> void:
	for i in range(6):
		var column := ColorRect.new()
		column.name = "BrandenburgColumn"
		column.size = Vector2(13, 82)
		column.position = center + Vector2(-58 + i * 23, -82)
		column.color = Color(0.72, 0.64, 0.48, 1.0)
		column.z_index = z
		_world_node.add_child(column)
	var cap := ColorRect.new()
	cap.name = "BrandenburgCap"
	cap.size = Vector2(158, 24)
	cap.position = center + Vector2(-76, -104)
	cap.color = Color(0.64, 0.56, 0.42, 1.0)
	cap.z_index = z + 1
	_world_node.add_child(cap)
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
		_world_node.add_child(line)


func _add_skyscraper_cluster(center: Vector2, z: int) -> void:
	for i in range(5):
		var h := 120.0 + float(i * 28)
		_add_city_block(_world_node, center + Vector2((i - 2) * 58, (i % 2) * 18), h, z + i * 3)
	_add_monument_collision(center, 120, 52)


# ===== PLAYER =====

func _build_player() -> void:
	var p := CharacterBody2D.new(); p.name = "Player"
	var spawn: Vector2 = _current_map.get("hero_spawn", Vector2(50, 50)) as Vector2
	p.position = _iso(spawn.x, spawn.y)
	p.collision_layer = 2
	p.collision_mask = 1 | 4
	p.set_script(load("res://scripts/player/Player.gd"))

	# Restore player stats if re-spawning from portal
	if _player_node and is_instance_valid(_player_node) and _player_node.has_method("is_dead") and not _player_node.is_dead():
		p.set("max_hp", _player_node.get("max_hp"))
		p.set("current_hp", _player_node.get("current_hp"))
		p.set("move_speed", _player_node.get("move_speed"))
		p.set("attack_damage", _player_node.get("attack_damage"))
		p.set("xp", _player_node.get("xp"))
		p.set("xp_to_next_level", _player_node.get("xp_to_next_level"))
		p.set("level", _player_node.get("level"))
		p.set("total_xp_earned", _player_node.get("total_xp_earned"))
		p.set("ascension_level", _player_node.get("ascension_level"))
		p.set("ascension_points", _player_node.get("ascension_points"))
		p.set("highest_portal_depth", _player_node.get("highest_portal_depth"))
		p.set("season_level", _player_node.get("season_level"))
		p.set("base_hp", _player_node.get("base_hp"))
		p.set("base_damage", _player_node.get("base_damage"))
		p.set("base_speed", _player_node.get("base_speed"))
		p.set("base_defense", _player_node.get("base_defense"))
		p.set("base_agility", _player_node.get("base_agility"))
		p.set("defense", _player_node.get("defense"))
		p.set("agility", _player_node.get("agility"))
		p.set("gold", _player_node.get("gold"))
		p.set("equipment", (_player_node.get("equipment") as Dictionary).duplicate())
	else:
		p.set("max_hp", 120); p.set("current_hp", 120)
		p.set("move_speed", 220.0); p.set("attack_damage", 12)
		p.set("base_hp", 120); p.set("base_damage", 12); p.set("base_speed", 220.0)
		p.set("base_defense", 0); p.set("base_agility", 0)
		p.set("defense", 0); p.set("agility", 0)
		p.set("total_xp_earned", 0)
		p.set("ascension_level", 0)
		p.set("ascension_points", 0)
		p.set("highest_portal_depth", 1)
		p.set("season_level", 1)
		p.set("gold", 0)

	_player_node = p

	var cs := CollisionShape2D.new(); cs.name = "CollisionShape2D"
	var c := CircleShape2D.new(); c.radius = 24.0; cs.shape = c; p.add_child(cs)

	var sh := Sprite2D.new(); sh.name = "Shadow"
	sh.texture = _load_tex("res://assets/placeholders/shadow.png")
	sh.position = Vector2(0, 38); sh.z_index = -1; sh.scale = Vector2(1.5, 1.5); p.add_child(sh)

	var sp := Sprite2D.new(); sp.name = "Sprite2D"
	sp.texture = _load_tex("res://assets/flare/characters/hero/hero_full.png")
	sp.position = Vector2(0, -42); sp.scale = Vector2(1.5, 1.5); p.add_child(sp)

	var glow := Sprite2D.new()
	glow.name = "SpriteGlow"
	glow.texture = sp.texture
	glow.position = sp.position
	glow.scale = Vector2(1.62, 1.62)
	glow.region_enabled = true
	glow.region_rect = Rect2(0, 0, 128, 128)
	glow.z_index = -1
	glow.modulate = Color(0.30, 0.72, 1.0, 0.22)
	p.add_child(glow)

	var aa := Area2D.new(); aa.name = "AttackArea"; p.add_child(aa)
	var ac := CollisionShape2D.new(); ac.name = "CollisionShape2D"
	var ac2 := CircleShape2D.new(); ac2.radius = 64.0; ac.shape = ac2; aa.add_child(ac)

	add_child(p)
	if p.has_signal("speech_requested"):
		p.speech_requested.connect(_show_combat_line)
	if p.has_signal("equipment_changed"):
		p.equipment_changed.connect(func(_slot, _item):
			_play_audio_cue("equip")
			_queue_autosave()
		)
	if p.has_signal("leveled_up"):
		p.leveled_up.connect(func(_level: int):
			_play_audio_cue("level_up")
			_queue_autosave()
		)
	if p.has_signal("gold_changed"):
		p.gold_changed.connect(func(_gold: int): _queue_autosave())
	if p.has_signal("died"):
		p.died.connect(func(): _queue_autosave())
	_bind_system_to_player(p)

	_cam = Camera2D.new(); _cam.name = "Camera2D"
	_cam.enabled = true
	_cam.position_smoothing_enabled = true; _cam.position_smoothing_speed = 5.0
	_cam.zoom = Vector2(0.75, 0.75)
	p.add_child(_cam)
	_cam.add_to_group("cameras")
	_cam.make_current()


# ===== ENEMIES =====

var _enemy_types := {
	"skeleton": {"name":"Scheletro","tex":"res://assets/flare/characters/skeleton_grid.png",
		"hp":30,"spd":85,"dmg":5,"cd":1.2,"det":300,"atk":50,"sc":1.2,"cr":20,
		"xp":12,"loot":"Frammento d'osso","rarity":"common","tier":1},
	"skeleton_a":{"name":"Arciere Schel.","tex":"res://assets/flare/characters/skeleton_grid.png",
		"hp":25,"spd":70,"dmg":8,"cd":0.9,"det":380,"atk":200,"sc":1.2,"cr":18,
		"xp":16,"loot":"Arco di Ossa","rarity":"uncommon","tier":2},
	"goblin":  {"name":"Goblin","tex":"res://assets/flare/characters/goblin_grid.png",
		"hp":18,"spd":130,"dmg":3,"cd":0.7,"det":280,"atk":40,"sc":1.5,"cr":15,
		"xp":8,"loot":"Frammento d'osso","rarity":"common","tier":1},
	"orc":     {"name":"Orco Guerriero","tex":"res://assets/flare/characters/goblin_grid.png",
		"hp":90,"spd":95,"dmg":14,"cd":1.1,"det":300,"atk":55,"sc":2.2,"cr":28,
		"xp":40,"loot":"Ascia da Guerra","rarity":"rare","tier":3},
	"orc_b":   {"name":"Orco Campione","tex":"res://assets/flare/characters/goblin_grid.png",
		"hp":150,"spd":80,"dmg":22,"cd":1.3,"det":350,"atk":60,"sc":2.5,"cr":34,
		"xp":65,"loot":"Martello del Campione","rarity":"epic","tier":4},
	"goblin_e":{"name":"Goblin Sciamano","tex":"res://assets/flare/characters/goblin_grid.png",
		"hp":45,"spd":110,"dmg":8,"cd":0.9,"det":320,"atk":45,"sc":1.5,"cr":17,
		"xp":22,"loot":"Frammento mistico","rarity":"uncommon","tier":2},
	"myrm_scout":{"name":"Mirmide Scout","tex":"res://assets/flare/characters/goblin_grid.png",
		"hp":26,"spd":165,"dmg":6,"cd":0.55,"det":340,"atk":42,"sc":1.25,"cr":16,
		"xp":18,"loot":"Scheggia di chitina","rarity":"uncommon","tier":2,
		"tint":Color(0.12,0.95,0.70,1.0),"bar":Color(0.15,0.95,0.62),"insect":true,
		"voice":Color(0.46,1.0,0.78),
		"spawn_lines":["Odore caldo.","La colonia vede.","Prede."],
		"attack_lines":["Morde.","Taglia.","Per la nidiata."],
		"hurt_lines":["Crepa.","Sangue acido."],
		"death_lines":["La nidiata..."]},
	"myrm_soldier":{"name":"Mirmide Soldato","tex":"res://assets/flare/characters/goblin_grid.png",
		"hp":72,"spd":112,"dmg":13,"cd":0.9,"det":330,"atk":52,"sc":1.75,"cr":24,
		"xp":34,"loot":"Carapace","rarity":"rare","tier":3,
		"tint":Color(0.18,0.55,0.42,1.0),"bar":Color(0.20,0.85,0.45),"insect":true,
		"voice":Color(0.62,1.0,0.60),
		"spawn_lines":["Scudi su.","La linea avanza.","Niente fuga."],
		"attack_lines":["Schiaccia.","Tieni fermo.","Guscio e lama."],
		"hurt_lines":["Carapace rotto.","Indietro no."],
		"death_lines":["Linea spezzata."]},
	"myrm_elite":{"name":"Mirmide Elite","tex":"res://assets/flare/characters/goblin_grid.png",
		"hp":145,"spd":128,"dmg":24,"cd":0.85,"det":400,"atk":60,"sc":2.15,"cr":30,
		"xp":72,"loot":"Mandibola nera","rarity":"epic","tier":4,
		"tint":Color(0.46,0.18,0.78,1.0),"bar":Color(0.82,0.25,1.0),"insect":true,
		"voice":Color(0.88,0.52,1.0),
		"spawn_lines":["Silenzio nel tunnel.","La regina ordina.","In ginocchio."],
		"attack_lines":["Esecuzione.","Artigli aperti.","Cedi."],
		"hurt_lines":["La corazza regge.","Dolore inutile."],
		"death_lines":["Regina... vendica."]},
	"myrm_queen":{"name":"Regina Mirmide","tex":"res://assets/flare/characters/wyvern_grid.png",
		"hp":360,"spd":78,"dmg":38,"cd":1.55,"det":520,"atk":78,"sc":2.6,"cr":46,
		"xp":190,"loot":"Chitina Regina","rarity":"legendary","tier":5,
		"tint":Color(0.72,0.12,0.88,1.0),"bar":Color(1.0,0.32,0.86),"insect":true,
		"voice":Color(1.0,0.56,0.92),
		"spawn_lines":["Figli, divorate.","Il varco e mio.","La fame regna."],
		"attack_lines":["Piegati.","Nutri la corona.","Sento il tuo cuore."],
		"hurt_lines":["Osi colpirmi.","Il nido urla."],
		"death_lines":["Il nido... cade."]},
	"zombie":  {"name":"Zombie","tex":"res://assets/flare/characters/zombie_grid.png",
		"hp":55,"spd":55,"dmg":10,"cd":1.8,"det":250,"atk":48,"sc":1.5,"cr":22,
		"xp":18,"loot":"Frammento marcio","rarity":"common","tier":1},
	"werewolf": {"name":"Licantropo","tex":"res://assets/flare/characters/zombie_grid.png",
		"hp":110,"spd":150,"dmg":16,"cd":0.8,"det":350,"atk":52,"sc":2.2,"cr":28,
		"xp":45,"loot":"Pelliccia Maledetta","rarity":"rare","tier":3},
	"werewolf_a":{"name":"Licantropo Alfa","tex":"res://assets/flare/characters/zombie_grid.png",
		"hp":200,"spd":130,"dmg":24,"cd":1.0,"det":400,"atk":58,"sc":2.5,"cr":34,
		"xp":75,"loot":"Zanna dell'Alfa","rarity":"epic","tier":4},
	"wyvern":  {"name":"Viverna","tex":"res://assets/flare/characters/wyvern_grid.png",
		"hp":80,"spd":95,"dmg":15,"cd":2.0,"det":350,"atk":55,"sc":1.8,"cr":28,
		"fw":128,"fh":128,"sprite_y":-52,"shadow_y":42,"shadow_scale_x":2.35,"shadow_scale_y":0.95,
		"bar_w":58,"bar_y":-76,
		"xp":35,"loot":"Frammento antico","rarity":"rare","tier":3},
	"wyvern_a":{"name":"Viverna Alata","tex":"res://assets/flare/characters/wyvern_air_grid.png",
		"hp":120,"spd":120,"dmg":20,"cd":1.5,"det":400,"atk":60,"sc":1.08,"cr":36,
		"fw":256,"fh":256,"sprite_y":-82,"shadow_y":46,"shadow_scale_x":2.55,"shadow_scale_y":0.98,
		"bar_w":66,"bar_y":-104,"glow":Color(0.25,0.55,1.0,0.20),"glow_scale":1.08,
		"xp":50,"loot":"Frammento celestiale","rarity":"rare","tier":3},
	"dragon":  {"name":"Drago Antico","tex":"res://assets/flare/characters/wyvern_air_grid.png",
		"hp":400,"spd":70,"dmg":45,"cd":2.5,"det":560,"atk":105,"sc":1.42,"cr":62,
		"fw":256,"fh":256,"sprite_y":-104,"shadow_y":56,"shadow_scale_x":3.45,"shadow_scale_y":1.18,
		"bar_w":96,"bar_y":-146,"glow":Color(1.0,0.18,0.04,0.27),"glow_scale":1.12,
		"xp":200,"loot":"Scaglia di Drago","rarity":"legendary","tier":5},
	"dragon_b":{"name":"Drago Supremo","tex":"res://assets/flare/characters/wyvern_grid.png",
		"hp":250,"spd":100,"dmg":35,"cd":2.0,"det":500,"atk":92,"sc":2.65,"cr":58,
		"fw":128,"fh":128,"sprite_y":-86,"shadow_y":54,"shadow_scale_x":3.15,"shadow_scale_y":1.08,
		"bar_w":86,"bar_y":-126,"glow":Color(0.08,0.92,1.0,0.24),"glow_scale":1.10,
		"xp":120,"loot":"Artiglio di Drago","rarity":"epic","tier":4},
	"mage":     {"name":"Mago Oscuro","tex":"res://assets/flare/characters/zombie_grid.png",
		"hp":60,"spd":80,"dmg":18,"cd":1.3,"det":350,"atk":150,"sc":1.5,"cr":18,
		"xp":30,"loot":"Grimorio Proibito","rarity":"rare","tier":3},
	"lich":     {"name":"Lich Supremo","tex":"res://assets/flare/characters/skeleton_grid.png",
		"hp":180,"spd":65,"dmg":28,"cd":1.5,"det":400,"atk":130,"sc":2.0,"cr":28,
		"xp":80,"loot":"Anima Dannata","rarity":"epic","tier":4},
	"minotaur": {"name":"Minotauro","tex":"res://assets/flare/characters/skeleton_grid.png",
		"hp":300,"spd":55,"dmg":55,"cd":2.2,"det":350,"atk":65,"sc":3.0,"cr":40,
		"xp":180,"loot":"Corna del Toro","rarity":"legendary","tier":5},
}


func _build_enemies() -> void:
	match _current_map_id:
		"black_oak_farm":
			_spawn("skeleton",_iso(12,14)); _spawn("skeleton",_iso(10,16)); _spawn("skeleton",_iso(14,18))
			_spawn("skeleton",_iso(8,12)); _spawn("skeleton",_iso(16,10))
			_spawn("goblin",_iso(35,40)); _spawn("goblin",_iso(37,38)); _spawn("goblin",_iso(38,42))
			_spawn("goblin",_iso(40,39)); _spawn("goblin",_iso(42,37)); _spawn("goblin",_iso(36,44))
			_spawn("myrm_scout",_iso(47,48)); _spawn("myrm_scout",_iso(49,50)); _spawn("myrm_soldier",_iso(51,49))
			_spawn("goblin_e",_iso(55,55)); _spawn("goblin_e",_iso(58,52))
			_spawn("zombie",_iso(60,70)); _spawn("zombie",_iso(62,72)); _spawn("zombie",_iso(65,68))
			_spawn("wyvern",_iso(80,30)); _spawn("wyvern_a",_iso(85,25))
			_spawn("mage",_iso(70,45))
			_spawn("dragon_b",_iso(90,55)); _spawn("dragon",_iso(30,80))
			_spawn("lich",_iso(50,80))

		"black_oak_city":
			_spawn("goblin",_iso(30,40)); _spawn("goblin",_iso(32,38)); _spawn("goblin",_iso(34,42))
			_spawn("goblin_e",_iso(50,50)); _spawn("goblin_e",_iso(55,55))
			_spawn("mage",_iso(60,40)); _spawn("mage",_iso(65,45)); _spawn("mage",_iso(70,50))
			_spawn("wyvern_a",_iso(45,30)); _spawn("wyvern",_iso(50,25))
			_spawn("lich",_iso(40,60))
			_spawn("dragon",_iso(80,70)); _spawn("dragon_b",_iso(25,75))
			_spawn("zombie",_iso(70,20)); _spawn("zombie",_iso(75,25))

		"roma_centro":
			# Centro storico: non-morti tra le rovine, maghi presso i Fori
			_spawn("skeleton",_iso(42,50)); _spawn("skeleton",_iso(48,55)); _spawn("skeleton",_iso(55,42))
			_spawn("skeleton_a",_iso(52,48)); _spawn("skeleton_a",_iso(45,58))
			_spawn("mage",_iso(57,47)); _spawn("mage",_iso(50,60))
			_spawn("goblin_e",_iso(62,58)); _spawn("goblin",_iso(40,52))
			_spawn("lich",_iso(35,64))
			_spawn("zombie",_iso(48,44)); _spawn("zombie",_iso(54,50))
			_spawn("wyvern",_iso(60,42))
			_spawn("minotaur",_iso(44,56))

		"venezia_rialto":
			# Canali e calli: zombie emergono dall'acqua, goblin sui ponti
			_spawn("zombie",_iso(45,42)); _spawn("zombie",_iso(55,55)); _spawn("zombie",_iso(50,50))
			_spawn("zombie",_iso(42,58)); _spawn("zombie",_iso(58,46))
			_spawn("goblin",_iso(60,43)); _spawn("goblin",_iso(38,60))
			_spawn("goblin_e",_iso(52,44))
			_spawn("mage",_iso(38,58)); _spawn("mage",_iso(62,52))
			_spawn("werewolf",_iso(48,62)); _spawn("werewolf_a",_iso(55,40))
			_spawn("lich",_iso(50,48))

		"parigi_cite":
			# Ile de la Cite: gargoyle, lich nella cattedrale, wyvern sui tetti
			_spawn("skeleton",_iso(40,46)); _spawn("skeleton",_iso(44,42)); _spawn("skeleton",_iso(50,55))
			_spawn("skeleton_a",_iso(48,52)); _spawn("skeleton_a",_iso(55,45))
			_spawn("mage",_iso(52,52)); _spawn("mage",_iso(42,58)); _spawn("mage",_iso(58,44))
			_spawn("lich",_iso(60,45)); _spawn("lich",_iso(38,50))
			_spawn("wyvern",_iso(45,62)); _spawn("wyvern_a",_iso(56,38))
			_spawn("zombie",_iso(50,48)); _spawn("zombie",_iso(42,50))
			_spawn("goblin_e",_iso(54,42))
			_spawn("dragon_b",_iso(48,56))

		"berlin_mitte_3d":
			# Berlino densa: goblin e maghi tra i palazzi
			_spawn("goblin",_iso(42,42)); _spawn("goblin",_iso(45,48)); _spawn("goblin",_iso(52,44))
			_spawn("goblin_e",_iso(50,48)); _spawn("goblin_e",_iso(44,54))
			_spawn("mage",_iso(58,54)); _spawn("mage",_iso(40,46))
			_spawn("wyvern_a",_iso(63,38))
			_spawn("skeleton",_iso(48,50)); _spawn("skeleton",_iso(56,42))
			_spawn("werewolf",_iso(52,52))
			_spawn("lich",_iso(46,58))

		"tokyo_shibuya":
			# Shibuya: creature veloci tra la folla, draghi sulla skyline
			_spawn("goblin",_iso(45,50)); _spawn("goblin",_iso(55,48)); _spawn("goblin",_iso(48,44))
			_spawn("goblin_e",_iso(50,54)); _spawn("goblin_e",_iso(58,50))
			_spawn("werewolf",_iso(62,55)); _spawn("werewolf",_iso(42,52))
			_spawn("werewolf_a",_iso(56,48))
			_spawn("mage",_iso(48,62)); _spawn("mage",_iso(54,44))
			_spawn("dragon_b",_iso(68,42))
			_spawn("dragon",_iso(44,56))
			_spawn("wyvern",_iso(52,58))

		"nazia_highlands":
			_spawn("wyvern",_iso(20,30)); _spawn("wyvern",_iso(25,25)); _spawn("wyvern",_iso(30,35))
			_spawn("wyvern_a",_iso(15,20)); _spawn("wyvern_a",_iso(35,15))
			_spawn("dragon_b",_iso(50,40)); _spawn("dragon",_iso(60,30))
			_spawn("mage",_iso(40,50)); _spawn("lich",_iso(55,55))
			_spawn("goblin",_iso(10,50)); _spawn("goblin",_iso(12,52))

		"merrimead_swamp":
			_spawn("zombie",_iso(20,30)); _spawn("zombie",_iso(22,28)); _spawn("zombie",_iso(25,32))
			_spawn("zombie",_iso(18,35)); _spawn("zombie",_iso(30,25))
			_spawn("goblin_e",_iso(40,40)); _spawn("goblin_e",_iso(42,45))
			_spawn("lich",_iso(50,50))
			_spawn("dragon_b",_iso(60,60))
			_spawn("wyvern",_iso(35,55))

		"southern_ridge":
			_spawn("skeleton",_iso(20,20)); _spawn("skeleton",_iso(15,25)); _spawn("skeleton",_iso(25,15))
			_spawn("lich",_iso(35,35)); _spawn("lich",_iso(40,40))
			_spawn("mage",_iso(50,30)); _spawn("mage",_iso(55,35))
			_spawn("dragon",_iso(60,60)); _spawn("dragon_b",_iso(45,55))

		"salted_field":
			_spawn("zombie",_iso(15,20)); _spawn("zombie",_iso(20,25))
			_spawn("skeleton",_iso(25,15)); _spawn("skeleton",_iso(30,20))
			_spawn("wyvern",_iso(40,30))
			_spawn("dragon_b",_iso(35,45))

		"stonewood":
			_spawn("goblin",_iso(30,25)); _spawn("goblin",_iso(35,30))
			_spawn("goblin_e",_iso(40,20))
			_spawn("wyvern_a",_iso(60,40)); _spawn("wyvern",_iso(55,35))
			_spawn("lich",_iso(50,60))
			_spawn("dragon",_iso(70,70))

		"oasis":
			_spawn("goblin",_iso(30,40)); _spawn("goblin",_iso(35,45))
			_spawn("wyvern",_iso(50,30)); _spawn("wyvern_a",_iso(55,25))
			_spawn("dragon_b",_iso(70,60))
			_spawn("lich",_iso(40,60))

		"river_trail":
			_spawn("goblin",_iso(20,15)); _spawn("goblin",_iso(25,10))
			_spawn("zombie",_iso(40,12)); _spawn("zombie",_iso(45,15))
			_spawn("wyvern",_iso(60,10))
			_spawn("mage",_iso(30,25))

		"lochport":
			_spawn("skeleton",_iso(15,30)); _spawn("skeleton",_iso(12,35))
			_spawn("zombie",_iso(20,25)); _spawn("zombie",_iso(25,20))
			_spawn("goblin_e",_iso(30,35))
			_spawn("dragon_b",_iso(35,40))
			_spawn("lich",_iso(20,45))

		"perdition_harbor":
			_spawn("zombie",_iso(15,15)); _spawn("zombie",_iso(10,20))
			_spawn("skeleton",_iso(20,10)); _spawn("skeleton",_iso(25,15))
			_spawn("lich",_iso(20,25))
			_spawn("dragon",_iso(30,25))

		# === SNOWPLAINS ===
		"grot_lagoon":
			_spawn("wyvern",_iso(30,40)); _spawn("wyvern",_iso(35,45))
			_spawn("wyvern_a",_iso(50,50)); _spawn("wyvern_a",_iso(55,55))
			_spawn("dragon_b",_iso(70,60)); _spawn("dragon",_iso(80,80))
			_spawn("werewolf",_iso(40,30)); _spawn("werewolf",_iso(45,35))
			_spawn("werewolf_a",_iso(60,70))
			_spawn("mage",_iso(90,40)); _spawn("lich",_iso(25,80))
			_spawn("orc",_iso(80,30)); _spawn("orc",_iso(85,35))

		"lake_kuuma":
			_spawn("dragon",_iso(60,60)); _spawn("dragon",_iso(65,65))
			_spawn("dragon_b",_iso(40,50)); _spawn("dragon_b",_iso(80,70))
			_spawn("wyvern_a",_iso(30,30)); _spawn("wyvern_a",_iso(90,40))
			_spawn("wyvern",_iso(50,80)); _spawn("wyvern",_iso(70,90))
			_spawn("werewolf_a",_iso(50,40)); _spawn("werewolf_a",_iso(55,45))
			_spawn("orc_b",_iso(100,50)); _spawn("orc_b",_iso(20,100))
			_spawn("minotaur",_iso(66,50))

		# === DUNGEONS ===
		"fort_nasu":
			_spawn("skeleton",_iso(30,30)); _spawn("skeleton",_iso(35,28)); _spawn("skeleton",_iso(28,35))
			_spawn("skeleton_a",_iso(40,40)); _spawn("skeleton_a",_iso(45,45))
			_spawn("lich",_iso(50,50)); _spawn("lich",_iso(60,60))
			_spawn("mage",_iso(70,30)); _spawn("mage",_iso(30,70))
			_spawn("dragon_b",_iso(50,80))
			_spawn("minotaur",_iso(80,50))

		"fort_amir":
			_spawn("orc",_iso(20,25)); _spawn("orc",_iso(25,20)); _spawn("orc",_iso(22,30))
			_spawn("orc_b",_iso(35,35))
			_spawn("myrm_elite",_iso(46,46)); _spawn("myrm_soldier",_iso(42,44))
			_spawn("mage",_iso(50,30)); _spawn("mage",_iso(55,35))
			_spawn("dragon",_iso(60,40))
			_spawn("minotaur",_iso(40,60)); _spawn("myrm_queen",_iso(58,58))

		"dilapidated_sewers":
			_spawn("zombie",_iso(20,20)); _spawn("zombie",_iso(25,25)); _spawn("zombie",_iso(18,28))
			_spawn("zombie",_iso(30,20)); _spawn("zombie",_iso(22,30))
			_spawn("myrm_scout",_iso(35,35)); _spawn("myrm_soldier",_iso(38,38)); _spawn("myrm_soldier",_iso(42,36))
			_spawn("lich",_iso(50,40))
			_spawn("werewolf",_iso(40,50)); _spawn("werewolf_a",_iso(60,30))
			_spawn("dragon_b",_iso(70,50))

		"stormrock_ruins":
			_spawn("skeleton_a",_iso(30,35)); _spawn("skeleton_a",_iso(35,30))
			_spawn("lich",_iso(50,40)); _spawn("lich",_iso(55,50))
			_spawn("myrm_elite",_iso(46,46)); _spawn("myrm_soldier",_iso(42,48))
			_spawn("dragon",_iso(40,60)); _spawn("dragon",_iso(70,40))
			_spawn("minotaur",_iso(25,70))
			_spawn("werewolf_a",_iso(70,60))

		"st_maria_1":
			_spawn("skeleton",_iso(20,20)); _spawn("skeleton",_iso(25,18))
			_spawn("zombie",_iso(30,25)); _spawn("zombie",_iso(28,30))
			_spawn("mage",_iso(40,35))
			_spawn("lich",_iso(50,20))
			_spawn("dragon_b",_iso(25,50))

		"st_maria_2":
			_spawn("orc",_iso(20,25)); _spawn("orc",_iso(25,20))
			_spawn("werewolf",_iso(35,30)); _spawn("werewolf",_iso(30,35))
			_spawn("lich",_iso(45,40))
			_spawn("myrm_elite",_iso(42,45))
			_spawn("dragon",_iso(55,20))
			_spawn("minotaur",_iso(45,55))

		"st_maria_3":
			_spawn("skeleton",_iso(10,15)); _spawn("zombie",_iso(15,20))
			_spawn("lich",_iso(20,25))
			_spawn("minotaur",_iso(15,35))
			_spawn("dragon",_iso(30,15))

		"book_of_the_dead":
			_spawn("skeleton",_iso(10,15)); _spawn("skeleton",_iso(15,12))
			_spawn("mage",_iso(20,20)); _spawn("mage",_iso(18,25))
			_spawn("lich",_iso(25,20)); _spawn("myrm_scout",_iso(22,28)); _spawn("myrm_soldier",_iso(26,30))

		# === CITTA 3D LOCALI ===
		"new_york":
			_spawn("goblin",_iso(30,40)); _spawn("goblin",_iso(35,38)); _spawn("goblin",_iso(32,45))
			_spawn("goblin_e",_iso(40,35)); _spawn("goblin_e",_iso(42,50))
			_spawn("mage",_iso(50,40)); _spawn("mage",_iso(55,38))
			_spawn("werewolf",_iso(45,45)); _spawn("werewolf_a",_iso(38,55))
			_spawn("wyvern",_iso(60,45)); _spawn("wyvern_a",_iso(25,50))
			_spawn("lich",_iso(52,52))

		"manhattan":
			_spawn("wyvern",_iso(35,40)); _spawn("wyvern_a",_iso(40,35)); _spawn("wyvern_a",_iso(45,42))
			_spawn("dragon_b",_iso(38,48)); _spawn("dragon_b",_iso(48,38))
			_spawn("goblin_e",_iso(42,44))
			_spawn("werewolf_a",_iso(50,50))
			_spawn("dragon",_iso(55,30))

		"cyberpunk":
			_spawn("mage",_iso(30,40)); _spawn("mage",_iso(35,35)); _spawn("mage",_iso(40,42))
			_spawn("lich",_iso(45,38)); _spawn("lich",_iso(50,45))
			_spawn("myrm_elite",_iso(38,48))
			_spawn("goblin_e",_iso(48,40)); _spawn("goblin_e",_iso(42,52))
			_spawn("dragon_b",_iso(55,35))

		"lowpoly_night":
			_spawn("werewolf",_iso(35,38)); _spawn("werewolf",_iso(40,42)); _spawn("werewolf",_iso(38,48))
			_spawn("skeleton",_iso(45,40)); _spawn("skeleton",_iso(48,45))
			_spawn("goblin_e",_iso(42,38))
			_spawn("werewolf_a",_iso(50,50))
			_spawn("lich",_iso(30,50))

		"postwar_city":
			_spawn("zombie",_iso(32,40)); _spawn("zombie",_iso(38,38)); _spawn("zombie",_iso(35,45))
			_spawn("zombie",_iso(42,42)); _spawn("zombie",_iso(45,38))
			_spawn("lich",_iso(40,50)); _spawn("lich",_iso(48,42))
			_spawn("skeleton_a",_iso(30,48)); _spawn("skeleton_a",_iso(50,38))
			_spawn("dragon_b",_iso(55,45))

		"ruined_city":
			_spawn("skeleton",_iso(30,38)); _spawn("skeleton",_iso(35,42)); _spawn("skeleton",_iso(40,35))
			_spawn("lich",_iso(45,40)); _spawn("lich",_iso(35,48))
			_spawn("dragon",_iso(50,45)); _spawn("dragon_b",_iso(40,55))
			_spawn("zombie",_iso(48,38)); _spawn("zombie",_iso(30,45))
			_spawn("minotaur",_iso(55,35))

		"procedural2":
			_spawn("orc",_iso(32,38)); _spawn("orc",_iso(38,42)); _spawn("orc",_iso(42,35))
			_spawn("goblin_e",_iso(45,40)); _spawn("goblin_e",_iso(35,45))
			_spawn("orc_b",_iso(48,42))
			_spawn("dragon_b",_iso(40,48))
			_spawn("werewolf",_iso(50,38))

		"procedural3":
			_spawn("goblin",_iso(30,40)); _spawn("goblin",_iso(35,38)); _spawn("goblin",_iso(40,42))
			_spawn("orc",_iso(45,38)); _spawn("orc",_iso(38,48))
			_spawn("goblin_e",_iso(48,42)); _spawn("goblin_e",_iso(42,52))
			_spawn("werewolf_a",_iso(50,45))
			_spawn("wyvern",_iso(35,50))

		"procedural4":
			_spawn("myrm_scout",_iso(32,40)); _spawn("myrm_soldier",_iso(38,38))
			_spawn("myrm_soldier",_iso(42,42)); _spawn("myrm_elite",_iso(45,40))
			_spawn("werewolf",_iso(35,45)); _spawn("werewolf",_iso(48,38))
			_spawn("dragon_b",_iso(40,48))
			_spawn("minotaur",_iso(52,42))

		"procedural5":
			_spawn("wyvern",_iso(35,38)); _spawn("wyvern_a",_iso(42,40))
			_spawn("dragon_b",_iso(38,45)); _spawn("dragon_b",_iso(48,38))
			_spawn("lich",_iso(45,42))
			_spawn("werewolf_a",_iso(40,50))
			_spawn("myrm_elite",_iso(50,35)); _spawn("myrm_queen",_iso(30,45))

		"procedural6":
			_spawn("lich",_iso(38,40)); _spawn("lich",_iso(45,38))
			_spawn("dragon",_iso(42,45)); _spawn("dragon_b",_iso(35,48))
			_spawn("minotaur",_iso(48,42))
			_spawn("orc_b",_iso(40,35)); _spawn("orc_b",_iso(50,45))
			_spawn("myrm_elite",_iso(38,50))

		# Connect some grassland portals to dungeons
		# Already handled via MapRegistry


func _get_endless_depth_for_tier(base_tier: int) -> int:
	if not _player_node:
		return base_tier
	var player_level := int(_player_node.get("level"))
	var ascension := int(_player_node.get("ascension_level"))
	var depth_from_level := base_tier + int(floor(float(maxi(0, player_level - 1)) / 18.0))
	if player_level > 100:
		depth_from_level = base_tier + 6 + int(floor(float(ascension) / 4.0))
	var depth := maxi(base_tier, depth_from_level)
	if _player_node.has_method("set"):
		_player_node.set("highest_portal_depth", maxi(int(_player_node.get("highest_portal_depth")), depth))
	return depth


func _get_enemy_scale_for_depth(base_tier: int, depth: int) -> float:
	var extra_depth := maxi(0, depth - base_tier)
	return 1.0 + float(extra_depth) * 0.18


func _default_enemy_attack_style(enemy_type: String) -> String:
	if enemy_type in ["skeleton_a", "mage", "lich"]:
		return "ranged"
	if enemy_type in ["wyvern", "wyvern_a", "dragon", "dragon_b", "myrm_queen"]:
		return "hybrid"
	return "melee"


func _spawn(type: String, pos: Vector2) -> void:
	if not _enemy_types.has(type):
		push_warning("Unknown enemy type: %s" % type)
		return
	var c: Dictionary = _enemy_types[type]
	var base_tier: int = c.get("tier", 1)
	var endless_depth := _get_endless_depth_for_tier(base_tier)
	var enemy_scale := _get_enemy_scale_for_depth(base_tier, endless_depth)
	var scaled_hp := maxi(1, int(round(float(c["hp"]) * enemy_scale)))
	var scaled_damage := maxi(1, int(round(float(c["dmg"]) * (0.75 + enemy_scale * 0.25))))
	var scaled_xp := maxi(1, int(round(float(c["xp"]) * (0.85 + enemy_scale * 0.35))))
	var e := CharacterBody2D.new()
	e.name = c["name"]
	e.position = pos
	e.collision_layer = 4
	e.collision_mask = 1 | 2
	e.set_script(load("res://scripts/enemies/Enemy.gd"))
	e.set("enemy_id",type); e.set("enemy_name",c["name"])
	e.set("max_hp",scaled_hp); e.set("current_hp",scaled_hp)
	e.set("move_speed",c["spd"]); e.set("attack_damage",scaled_damage)
	e.set("attack_cooldown",c["cd"]); e.set("detection_radius",c["det"]); e.set("attack_range",c["atk"])
	e.set("xp_value",scaled_xp)
	var attack_style := _default_enemy_attack_style(type)
	var is_boss_like := bool(c.get("boss", base_tier >= 4 and scaled_hp >= 140))
	e.set("attack_style", c.get("style", attack_style))
	e.set("melee_range", float(c.get("melee", min(float(c["atk"]), 64.0))))
	e.set("preferred_range", float(c.get("preferred", max(float(c["atk"]) * 0.72, 120.0))))
	e.set("projectile_speed", float(c.get("projectile_speed", 390.0 + float(base_tier) * 34.0)))
	e.set("projectile_radius", float(c.get("projectile_radius", 13.0 + float(base_tier))))
	e.set("telegraph_time", float(c.get("telegraph", 0.48 if is_boss_like else 0.36)))
	e.set("boss_like", is_boss_like)
	e.set("phase_count", int(c.get("phases", 3 if is_boss_like else 1)))
	e.set("_frame_w", int(c.get("fw", 128)))
	e.set("_frame_h", int(c.get("fh", 128)))
	e.set("spawn_lines", c.get("spawn_lines", _default_enemy_lines(type, "spawn")))
	e.set("attack_lines", c.get("attack_lines", _default_enemy_lines(type, "attack")))
	e.set("hurt_lines", c.get("hurt_lines", _default_enemy_lines(type, "hurt")))
	e.set("death_lines", c.get("death_lines", _default_enemy_lines(type, "death")))
	e.set("voice_color", c.get("voice", Color(1.0, 0.45, 0.35)))

	# Generate loot table based on enemy tier
	var loot: Array = ItemDataClass.generate_random_loot(endless_depth) as Array
	e.set("loot_table", loot)

	var cs := CollisionShape2D.new(); cs.name = "CollisionShape2D"
	var cc := CircleShape2D.new(); cc.radius = c["cr"]; cs.shape = cc; e.add_child(cs)

	var sh := Sprite2D.new(); sh.name = "Shadow"
	sh.texture = _load_tex("res://assets/placeholders/shadow.png")
	var shadow_scale_x: float = float(c.get("shadow_scale_x", c["sc"]))
	var shadow_scale_y: float = float(c.get("shadow_scale_y", c["sc"]))
	sh.position = Vector2(float(c.get("shadow_x", 0.0)), float(c.get("shadow_y", 38.0)))
	sh.z_index = -2
	sh.scale = Vector2(shadow_scale_x, shadow_scale_y)
	e.add_child(sh)

	var sp := Sprite2D.new(); sp.name = "Sprite2D"
	sp.texture = _load_tex(c["tex"])
	sp.position = Vector2(float(c.get("sprite_x", 0.0)), float(c.get("sprite_y", -40.0)))
	var sprite_scale: float = float(c["sc"])
	var frame_w: int = int(c.get("fw", 128))
	var frame_h: int = int(c.get("fh", 128))
	sp.scale = Vector2(sprite_scale, sprite_scale)
	sp.region_enabled = true
	sp.region_rect = Rect2(0, 0, frame_w, frame_h)
	e.add_child(sp)

	if c.has("glow"):
		var glow := Sprite2D.new()
		glow.name = "SpriteGlow"
		glow.texture = sp.texture
		glow.position = sp.position
		var glow_scale: float = sprite_scale * float(c.get("glow_scale", 1.08))
		glow.scale = Vector2(glow_scale, glow_scale)
		glow.region_enabled = true
		glow.region_rect = sp.region_rect
		glow.z_index = -1
		glow.modulate = c["glow"]
		e.add_child(glow)

	# Themed sprite colors
	if c.has("tint"):
		sp.modulate = c["tint"]
	elif type in ["mage", "skeleton_a"]:
		sp.modulate = Color(0.6, 0.3, 1.0)
	elif type == "lich":
		sp.modulate = Color(0.2, 0.8, 0.2)
	elif type == "minotaur":
		sp.modulate = Color(0.85, 0.15, 0.05)
	elif type == "dragon":
		sp.modulate = Color(0.9, 0.15, 0.1)
	elif type == "dragon_b":
		sp.modulate = Color(0.1, 0.85, 0.9)
	elif type in ["orc", "orc_b"]:
		sp.modulate = Color(0.35, 0.65, 0.15)
	elif type in ["werewolf", "werewolf_a"]:
		sp.modulate = Color(0.55, 0.35, 0.2)
	if c.get("insect", false):
		_add_insectoid_shell(e, c)

	var da := Area2D.new(); da.name = "DetectionArea"; da.collision_mask = 2; e.add_child(da)
	var dc := CollisionShape2D.new(); dc.name = "CollisionShape2D"
	var dc2 := CircleShape2D.new(); dc2.radius = c["det"]; dc.shape = dc2; da.add_child(dc)

	if e.has_signal("enemy_killed"):
		e.enemy_killed.connect(_on_enemy_killed)
	if e.has_signal("drop_item"):
		e.drop_item.connect(_on_drop.bind(e))
	if e.has_signal("speech_requested"):
		e.speech_requested.connect(_show_combat_line)
	if e.has_signal("phase_changed"):
		e.phase_changed.connect(_on_enemy_phase_changed)

	# Health bar
	var hb := ProgressBar.new()
	hb.name = "HealthBar"
	hb.min_value = 0.0; hb.max_value = scaled_hp; hb.value = scaled_hp
	var bar_w: float = float(c.get("bar_w", 40.0))
	hb.custom_minimum_size = Vector2(bar_w, 6)
	hb.show_percentage = false
	hb.position = Vector2(-bar_w * 0.5, float(c.get("bar_y", -50.0)))
	var bg := StyleBoxFlat.new(); bg.bg_color = Color(0.1, 0.05, 0.05, 0.8)
	bg.border_width_left = 1; bg.border_width_right = 1; bg.border_width_top = 1; bg.border_width_bottom = 1
	bg.border_color = Color(0.3, 0.1, 0.1)
	hb.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	if c.has("bar"):
		fill.bg_color = c["bar"]
	elif type in ["dragon", "dragon_b", "minotaur"]:
		fill.bg_color = Color(0.95, 0.3, 0.1)
	elif type in ["mage", "lich", "skeleton_a"]:
		fill.bg_color = Color(0.7, 0.2, 1.0)
	elif type in ["orc", "orc_b"]:
		fill.bg_color = Color(0.35, 0.7, 0.15)
	elif type in ["werewolf", "werewolf_a"]:
		fill.bg_color = Color(0.7, 0.4, 0.1)
	else:
		fill.bg_color = Color(0.9, 0.15, 0.15)
	hb.add_theme_stylebox_override("fill", fill)
	e.add_child(hb)

	if e.has_signal("health_changed"):
		e.health_changed.connect(func(cur: int, mx: int):
			hb.max_value = mx; hb.value = cur
		)

	add_child(e)


func _default_enemy_lines(enemy_type: String, context: String) -> Array[String]:
	if enemy_type in ["skeleton", "skeleton_a", "lich"]:
		match context:
			"spawn":
				return ["Ossa sveglie.", "La cripta chiama."]
			"attack":
				return ["Freddo.", "Taci."]
			"hurt":
				return ["Crepa..."]
			"death":
				return ["Polvere."]
	if enemy_type in ["goblin", "goblin_e", "orc", "orc_b"]:
		match context:
			"spawn":
				return ["Carne fresca.", "Avanti!"]
			"attack":
				return ["Colpisci!", "Presa!"]
			"hurt":
				return ["Brucia!", "No!"]
			"death":
				return ["Maledetto..."]
	if enemy_type in ["dragon", "dragon_b", "wyvern", "wyvern_a"]:
		match context:
			"spawn":
				return ["Il cielo cade.", "Cenere."]
			"attack":
				return ["Ardi.", "Sparisci."]
			"hurt":
				return ["Insetto."]
			"death":
				return ["Le ali..."]
	if enemy_type in ["werewolf", "werewolf_a"]:
		match context:
			"spawn":
				return ["Sangue.", "Ti sento."]
			"attack":
				return ["Artigli!", "Corri."]
			"hurt":
				return ["Ringhio."]
			"death":
				return ["La caccia..."]
	match context:
		"spawn":
			return ["Intruso."]
		"attack":
			return ["Muori."]
		"hurt":
			return ["Ah!"]
		"death":
			return ["Fine."]
	return []


func _add_insectoid_shell(enemy: Node2D, config: Dictionary) -> void:
	var scale_value: float = float(config.get("sc", 1.0))
	var tint: Color = config.get("tint", Color(0.2, 0.9, 0.7))
	var shell_color := Color(tint.r * 0.45, tint.g * 0.55, tint.b * 0.55, 0.62)
	var glow_color := Color(min(tint.r + 0.2, 1.0), min(tint.g + 0.2, 1.0), min(tint.b + 0.2, 1.0), 0.42)

	var shell := Polygon2D.new()
	shell.name = "InsectShell"
	shell.polygon = PackedVector2Array([
		Vector2(-18, -50), Vector2(0, -62), Vector2(18, -50),
		Vector2(22, -20), Vector2(0, -8), Vector2(-22, -20),
	])
	shell.color = shell_color
	shell.scale = Vector2(scale_value, scale_value)
	shell.z_index = 2
	enemy.add_child(shell)

	var mandibles := Polygon2D.new()
	mandibles.name = "Mandibles"
	mandibles.polygon = PackedVector2Array([
		Vector2(-16, -54), Vector2(-34, -44), Vector2(-20, -38),
		Vector2(16, -54), Vector2(34, -44), Vector2(20, -38),
	])
	mandibles.color = glow_color
	mandibles.scale = Vector2(scale_value, scale_value)
	mandibles.z_index = 3
	enemy.add_child(mandibles)

	for side in [-1, 1]:
		for i in range(3):
			var leg := Line2D.new()
			leg.name = "InsectLeg"
			leg.width = max(2.0, 3.0 * scale_value)
			leg.default_color = shell_color
			var y := -30 + i * 18
			leg.add_point(Vector2(side * 13, y) * scale_value)
			leg.add_point(Vector2(side * (34 + i * 4), y + 8) * scale_value)
			leg.add_point(Vector2(side * (43 + i * 2), y + 22) * scale_value)
			leg.z_index = 1
			enemy.add_child(leg)


func _on_enemy_killed(xp_val: int, enemy_name: String) -> void:
	if _player_node and _player_node.has_method("gain_xp"):
		_player_node.gain_xp(xp_val)
	var system := _get_system_mission()
	if system and system.has_method("register_kill"):
		system.register_kill(enemy_name, xp_val, _player_node)
	_maybe_hero_kill_line(enemy_name)
	_play_audio_cue("enemy_death")
	
	# Guaranteed gold drop (scaled by XP)
	var gold_amount: int = maxi(1, xp_val / 3 + randi() % maxi(1, xp_val / 2))
	if _player_node and _player_node.has_method("add_gold"):
		_player_node.add_gold(gold_amount)
	
	# Find enemy node for position
	var enemy_node: Node2D
	for child in get_children():
		if child.has_method("is_dead") and child.is_dead() and child.name == enemy_name:
			enemy_node = child as Node2D
			break
	if not enemy_node:
		enemy_node = _player_node
	
	# Gold visual
	var gl := Label.new(); gl.name = "GoldLabel"
	gl.position = enemy_node.position + Vector2(randf_range(-20,20), randf_range(-40,-10))
	gl.text = "+%d ORO" % gold_amount
	gl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	gl.add_theme_font_size_override("font_size", 14)
	gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gl.z_index = 4090
	add_child(gl)
	var tw := create_tween()
	tw.tween_property(gl, "position:y", gl.position.y - 50, 1.5)
	tw.parallel().tween_property(gl, "modulate:a", 0.0, 1.5)
	tw.tween_callback(gl.queue_free)
	
	if has_node("GameUI") and $GameUI.has_method("show_debug_message"):
		$GameUI.show_debug_message("+%d XP +%d ORO — %s ucciso!" % [xp_val, gold_amount, enemy_name])


# ===== SPEECH / AUDIO =====

func _show_combat_line(speaker: Node2D, text: String, tone_color: Color = Color.WHITE) -> void:
	if not speaker or text.is_empty():
		return
	var line := Label.new()
	line.name = "CombatLine"
	line.text = text
	line.position = speaker.global_position + Vector2(-70, -110)
	line.custom_minimum_size = Vector2(140, 0)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_font_size_override("font_size", 13)
	line.add_theme_color_override("font_color", tone_color)
	line.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	line.add_theme_constant_override("outline_size", 4)
	line.z_index = 4090
	add_child(line)

	var tw := create_tween()
	tw.tween_property(line, "position:y", line.position.y - 34.0, 1.45).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(line, "modulate:a", 0.0, 1.45)
	tw.tween_callback(line.queue_free)


func _maybe_hero_kill_line(enemy_name: String) -> void:
	if _hero_line_cooldown > 0.0 or not _player_node:
		return
	var lines := ["Uno in meno.", "Avanti il prossimo.", "Il varco trema.", "Non rallento."]
	if enemy_name.find("Regina") >= 0:
		lines = ["Il nido tace.", "Regina caduta."]
	_show_combat_line(_player_node, lines[randi() % lines.size()], Color(0.55, 0.9, 1.0))
	_hero_line_cooldown = 5.0


func _ensure_audio_started() -> void:
	var audio := get_node_or_null("/root/ProceduralAudio")
	if audio and audio.has_method("start_after_user_gesture"):
		audio.start_after_user_gesture()


func _play_audio_cue(cue: String) -> void:
	var audio := get_node_or_null("/root/ProceduralAudio")
	if audio and audio.has_method("play_cue"):
		audio.play_cue(cue)


# ===== SYSTEM MISSIONS =====

func _get_system_mission() -> Node:
	return get_node_or_null("/root/SystemMission")


func _bind_system_to_player(player: Node) -> void:
	var system := _get_system_mission()
	if not system:
		return
	if system.has_method("bind_player"):
		system.bind_player(player)
	if player.has_signal("dash_performed") and not player.dash_performed.is_connected(_on_player_dash_performed):
		player.dash_performed.connect(_on_player_dash_performed)
	if player.has_signal("perfect_dodge") and not player.perfect_dodge.is_connected(_on_player_perfect_dodge):
		player.perfect_dodge.connect(_on_player_perfect_dodge)
	if player.has_signal("skill_used") and not player.skill_used.is_connected(_on_player_skill_used):
		player.skill_used.connect(_on_player_skill_used)


func _connect_system_ui(ui: CanvasLayer) -> void:
	var system := _get_system_mission()
	if not system:
		return
	if not _system_ui_connected:
		if system.has_signal("mission_updated"):
			system.mission_updated.connect(_refresh_system_panel)
		if system.has_signal("system_message"):
			system.system_message.connect(_show_system_popup)
		_system_ui_connected = true
	_build_system_panel(ui)
	if system.has_method("get_snapshot"):
		_refresh_system_panel(system.get_snapshot())


func _register_system_map_change(map_id: String) -> void:
	var system := _get_system_mission()
	if system and system.has_method("register_map_change"):
		system.register_map_change(map_id, _player_node)


func _on_player_dash_performed() -> void:
	var system := _get_system_mission()
	if system and system.has_method("register_dash"):
		system.register_dash(_player_node)


func _on_player_perfect_dodge() -> void:
	var system := _get_system_mission()
	if system and system.has_method("register_perfect_dodge"):
		system.register_perfect_dodge(_player_node)


func _on_player_skill_used(skill_id: String) -> void:
	var system := _get_system_mission()
	if system and system.has_method("register_skill"):
		system.register_skill(skill_id, _player_node)


func _on_enemy_phase_changed(enemy_name: String, phase_index: int) -> void:
	var system := _get_system_mission()
	if system and system.has_method("register_boss_phase"):
		system.register_boss_phase(enemy_name, phase_index, _player_node)


func _on_item_picked_up(item_data) -> void:
	_play_audio_cue("loot")
	var system := _get_system_mission()
	if system and system.has_method("register_loot"):
		system.register_loot(item_data, _player_node)


func _build_system_panel(ui: CanvasLayer) -> void:
	if ui.get_node_or_null("SystemPanel"):
		return
	var panel := Panel.new()
	panel.name = "SystemPanel"
	panel.offset_left = 10.0
	panel.offset_top = 158.0
	panel.offset_right = 360.0
	panel.offset_bottom = 304.0
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.012, 0.022, 0.044, 0.84), Color(0.24, 0.86, 1.0, 0.52), 0.50))
	ui.add_child(panel)

	var margin := MarginContainer.new()
	margin.name = "MarginContainer"
	margin.name = "SystemMargin"
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "SystemVBox"
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	header.name = "SystemHeader"
	vbox.add_child(header)

	var title := Label.new()
	title.name = "SystemTitle"
	title.text = "SYSTEM | Rank E"
	title.add_theme_color_override("font_color", Color(0.44, 0.92, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
	title.add_theme_constant_override("outline_size", 3)
	title.add_theme_font_size_override("font_size", 14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var timer := Label.new()
	timer.name = "SystemTimer"
	timer.text = "10:00"
	timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer.add_theme_color_override("font_color", Color(1.0, 0.78, 0.30))
	timer.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
	timer.add_theme_constant_override("outline_size", 3)
	timer.add_theme_font_size_override("font_size", 13)
	timer.custom_minimum_size = Vector2(58, 0)
	header.add_child(timer)

	var list := VBoxContainer.new()
	list.name = "SystemMissionList"
	list.add_theme_constant_override("separation", 2)
	vbox.add_child(list)


func _refresh_system_panel(snapshot: Dictionary) -> void:
	var ui := get_node_or_null("GameUI") as CanvasLayer
	if not ui:
		return
	var panel := ui.get_node_or_null("SystemPanel")
	if not panel:
		return
	var title := panel.get_node_or_null("SystemMargin/SystemVBox/SystemHeader/SystemTitle") as Label
	if title:
		title.text = "SYSTEM | Rank %s" % String(snapshot.get("rank", "E"))
	var timer := panel.get_node_or_null("SystemMargin/SystemVBox/SystemHeader/SystemTimer") as Label
	if timer:
		var seconds := int(ceil(float(snapshot.get("timer", 0.0))))
		timer.text = "%02d:%02d" % [int(seconds / 60), seconds % 60]
	var list := panel.get_node_or_null("SystemMargin/SystemVBox/SystemMissionList") as VBoxContainer
	if not list:
		return
	for child in list.get_children():
		child.queue_free()
	var missions: Array = snapshot.get("missions", [])
	var shown := 0
	for mission in missions:
		if bool(mission.get("completed", false)) or bool(mission.get("failed", false)):
			continue
		var row := Label.new()
		row.text = "%s  %d/%d" % [
			String(mission.get("title", "")),
			int(mission.get("progress", 0)),
			int(mission.get("target", 1)),
		]
		row.add_theme_color_override("font_color", Color(0.72, 0.90, 1.0))
		row.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.76))
		row.add_theme_constant_override("outline_size", 2)
		row.add_theme_font_size_override("font_size", 11)
		list.add_child(row)
		shown += 1
		if shown >= 4:
			break


func _show_system_popup(title: String, body: String, tone: Color) -> void:
	var ui := get_node_or_null("GameUI") as CanvasLayer
	if not ui:
		return
	var popup := Panel.new()
	popup.name = "SystemPopup"
	popup.anchor_left = 0.5
	popup.anchor_right = 0.5
	popup.offset_left = -220.0
	popup.offset_top = 92.0
	popup.offset_right = 220.0
	popup.offset_bottom = 172.0
	popup.modulate.a = 0.0
	popup.add_theme_stylebox_override("panel", _make_panel_style(Color(0.012, 0.020, 0.042, 0.94), Color(tone.r, tone.g, tone.b, 0.82), 0.66))
	ui.add_child(popup)

	var box := VBoxContainer.new()
	box.anchor_right = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = 16.0
	box.offset_top = 10.0
	box.offset_right = -16.0
	box.offset_bottom = -10.0
	box.add_theme_constant_override("separation", 4)
	popup.add_child(box)

	var ttl := Label.new()
	ttl.text = title
	ttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ttl.add_theme_color_override("font_color", tone)
	ttl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.88))
	ttl.add_theme_constant_override("outline_size", 3)
	ttl.add_theme_font_size_override("font_size", 15)
	box.add_child(ttl)

	var msg := Label.new()
	msg.text = body
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.add_theme_color_override("font_color", Color(0.86, 0.94, 1.0))
	msg.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.78))
	msg.add_theme_constant_override("outline_size", 2)
	msg.add_theme_font_size_override("font_size", 11)
	box.add_child(msg)

	var tw := create_tween()
	tw.tween_property(popup, "modulate:a", 1.0, 0.16)
	tw.tween_interval(2.2)
	tw.tween_property(popup, "modulate:a", 0.0, 0.24)
	tw.tween_callback(popup.queue_free)


# ===== PORTALS (Shadow Rifts) - Eldrath themed =====

func _get_portal_type_for_map(map_id: String) -> Dictionary:
	"""All portals use standard white type — no visual distinction between maps."""
	return PortalTypesClass.get_type_info(PortalTypesClass.Type.WHITE)

func _build_portals() -> void:
	var portal_list: Array = _current_map.get("portals", [])
	for pdata in portal_list:
		var pos := _iso(pdata.pos.x, pdata.pos.y)
		var target: String = pdata.target
		var label: String = pdata.get("label", "???")

		var portal_type_info: Dictionary = _get_portal_type_for_map(_current_map_id)
		var type_name: String = portal_type_info.get("tag", "[VARCO]")
		var type_color: Color = portal_type_info.get("color", Color(0.55, 0.92, 1.0))
		var ring_color: Color = portal_type_info.get("ring_tint", Color(0.70, 0.24, 1.0, 0.72))
		var outer_ring_color: Color = portal_type_info.get("portal_tint", Color(0.18, 0.86, 1.0, 0.86))

		var portal := Node2D.new(); portal.name = "Rift_" + target; portal.position = pos

		var outer := ColorRect.new()
		outer.size = Vector2(92, 92); outer.position = Vector2(-46, -46)
		outer.color = Color(0.05, 0.02, 0.12, 0.34); outer.pivot_offset = Vector2(46, 46)
		portal.add_child(outer)

		var inner := ColorRect.new()
		inner.size = Vector2(44, 64); inner.position = Vector2(-22, -32)
		inner.color = Color(outer_ring_color.r, outer_ring_color.g, outer_ring_color.b, 0.36); inner.pivot_offset = Vector2(22, 32)
		portal.add_child(inner)
		portal.add_child(_make_portal_ring(56.0, outer_ring_color, 4.0, 0.64))
		portal.add_child(_make_portal_ring(36.0, ring_color, 3.0, 0.72))
		_add_portal_shards(portal)

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
		area.body_entered.connect(_on_portal_proximity.bind(target))
		area.input_event.connect(_on_portal_clicked.bind(target))
		portal.add_child(area)

		_portals.append({"node": portal, "target": target, "pos": portal.position})
		add_child(portal)

		var tw := create_tween(); tw.set_loops()
		tw.tween_property(outer, "scale", Vector2(1.3, 1.3), 1.0).set_trans(Tween.TRANS_SINE)
		tw.tween_property(outer, "scale", Vector2(0.7, 0.7), 1.0).set_trans(Tween.TRANS_SINE)

		var tw2 := create_tween(); tw2.set_loops()
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


func _add_portal_shards(portal: Node2D) -> void:
	for i in range(5):
		var shard := Polygon2D.new()
		shard.name = "PortalShard"
		var a := TAU * float(i) / 5.0
		var p := Vector2(cos(a) * 64.0, sin(a) * 42.0)
		shard.position = p
		shard.rotation = a
		shard.polygon = PackedVector2Array([Vector2(-4, 0), Vector2(0, -15), Vector2(5, 2), Vector2(0, 8)])
		shard.color = Color(0.68, 0.24, 1.0, 0.42)
		shard.z_index = 3049
		portal.add_child(shard)


func _on_portal_proximity(body: Node2D, target: String) -> void:
	if body == _player_node:
		_ensure_audio_started()
		_play_audio_cue("portal")
		var portal_info: Dictionary = _get_portal_type_for_map(_current_map_id)
		var type_name: String = portal_info.get("name", "Portale")
		print("Portal proximity: " + target)
		if has_node("GameUI") and $GameUI.has_method("show_debug_message"):
			$GameUI.show_debug_message("%s → %s" % [type_name, target])
		await get_tree().create_timer(0.3).timeout
		_load_map(target)


func _on_portal_clicked(event: InputEvent, _pos: Vector2, _mouse: int, _shape: int, target: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_ensure_audio_started()
		_play_audio_cue("portal")
		print("Portal to: " + target)
		_load_map(target)


# ===== ITEM DROPS =====

func _on_drop(item_data, enemy: Node) -> void:
	if not item_data:
		return
	
	# Check if it's a Dictionary (from generate_random_loot)
	if typeof(item_data) == TYPE_DICTIONARY:
		var d: Dictionary = item_data as Dictionary
		if d.get("type", "") == "gold":
			var amount: int = d.get("amount", 0)
			if _player_node and _player_node.has_method("add_gold") and amount > 0:
				_player_node.add_gold(amount)
			# Gold visual
			var gl := Label.new(); gl.name = "GoldLabel"
			gl.position = enemy.position + Vector2(randf_range(-20,20), randf_range(-40,-10))
			gl.text = "+%d ORO" % amount
			gl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			gl.add_theme_font_size_override("font_size", 14)
			gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			add_child(gl)
			var tw := create_tween()
			tw.tween_property(gl, "position:y", gl.position.y - 40, 1.2)
			tw.parallel().tween_property(gl, "modulate:a", 0.0, 1.2)
			tw.tween_callback(gl.queue_free)
			return
		
		if d.get("type", "") == "equip":
			var equip = ItemDataClass.create_equipment_from_def(d["def"])
			_spawn_dropped_equip(equip, enemy.position)
			return

	# Standard item (ItemData Resource)
	_spawn_dropped_equip(item_data, enemy.position)


func _spawn_dropped_equip(item_data, pos: Vector2) -> void:
	var d := Area2D.new(); d.name = "DroppedItem"; d.collision_mask = 2
	d.position = pos + Vector2(randf_range(-20, 20), randf_range(-20, 20))
	var cs := CollisionShape2D.new(); var cc := CircleShape2D.new(); cc.radius = 22.0; cs.shape = cc; d.add_child(cs)

	var icon_tex := _load_tex("res://assets/placeholders/sword_icon.png")
	if item_data.slot == "armor":
		icon_tex = _load_tex("res://assets/placeholders/shadow.png")
	
	var sp := Sprite2D.new()
	sp.name = "Sprite2D"
	sp.texture = icon_tex; sp.scale = Vector2(3.0, 3.0)
	var rarity: String = item_data.get("rarity")
	if not rarity.is_empty():
		var rcols := {"common":Color.WHITE,"uncommon":Color(0.3,1.0,0.3),"rare":Color(0.3,0.5,1.0),"epic":Color(0.8,0.2,1.0),"legendary":Color(1.0,0.7,0.2),"mythic":Color(1.0,0.15,0.15),"archontic":Color(1.0,0.78,0.1),"infinite":Color(0.35,0.88,1.0)}
		sp.modulate = rcols.get(rarity, Color.WHITE)
	d.add_child(sp)

	var lb := Label.new(); lb.name = "Label"
	lb.position = Vector2(-60, -40); lb.scale = Vector2(0.7, 0.7)
	lb.add_theme_font_size_override("font_size", 11); lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.text = item_data.name if item_data.name else "???"
	d.add_child(lb)
	d.set_script(load("res://scripts/items/DroppedItem.gd"))
	d.set("item_data", item_data)
	if d.has_signal("picked_up"):
		d.picked_up.connect(_on_item_picked_up)
	
	var dropped_items := get_node_or_null("DroppedItems")
	if dropped_items:
		dropped_items.add_child(d)


# ===== UI =====

func _make_panel_style(bg: Color, border: Color, shadow_alpha: float = 0.46) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = border
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.shadow_color = Color(0.0, 0.0, 0.0, shadow_alpha)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0.0, 3.0)
	return style


func _style_progress_bar(bar: ProgressBar, bg_color: Color, fill_color: Color, border_color: Color) -> void:
	var bg := _make_panel_style(bg_color, border_color, 0.16)
	bg.corner_radius_top_left = 3
	bg.corner_radius_top_right = 3
	bg.corner_radius_bottom_left = 3
	bg.corner_radius_bottom_right = 3
	bg.shadow_size = 0
	bar.add_theme_stylebox_override("background", bg)

	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.corner_radius_top_left = 3
	fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_left = 3
	fill.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("fill", fill)


func _style_dark_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.035, 0.045, 0.072, 0.96)
	normal.border_width_left = 1; normal.border_width_right = 1
	normal.border_width_top = 1; normal.border_width_bottom = 1
	normal.border_color = Color(0.25, 0.72, 0.95, 0.66)
	normal.corner_radius_top_left = 3; normal.corner_radius_top_right = 3
	normal.corner_radius_bottom_left = 3; normal.corner_radius_bottom_right = 3
	normal.shadow_color = Color(0.0, 0.0, 0.0, 0.36)
	normal.shadow_size = 5
	normal.shadow_offset = Vector2(0.0, 2.0)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.065, 0.086, 0.126, 0.98)
	hover.border_color = Color(0.70, 0.38, 1.0, 0.90)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.03, 0.17, 0.22, 1.0)
	pressed.border_color = Color(0.24, 0.98, 1.0, 1.0)

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.025, 0.028, 0.038, 0.74)
	disabled.border_color = Color(0.24, 0.24, 0.31, 0.62)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", Color(0.72, 0.93, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.94, 0.82, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.40, 0.44, 0.50))
	button.add_theme_constant_override("outline_size", 2)
	button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.55))
	button.add_theme_font_size_override("font_size", 13)


func _build_ui() -> void:
	var ui := CanvasLayer.new(); ui.name = "GameUI"
	ui.set_script(load("res://scripts/ui/GameUI.gd"))
	ui.set("player", _player_node)
	add_child(ui)

	var hud_frame := Panel.new()
	hud_frame.name = "HudFrame"
	hud_frame.offset_left = 10.0
	hud_frame.offset_top = 10.0
	hud_frame.offset_right = 360.0
	hud_frame.offset_bottom = 148.0
	hud_frame.add_theme_stylebox_override("panel", _make_panel_style(Color(0.025, 0.030, 0.052, 0.82), Color(0.34, 0.80, 0.98, 0.42), 0.52))
	ui.add_child(hud_frame)

	var mtl := MarginContainer.new(); mtl.name = "MarginContainer"
	mtl.offset_right = 340.0; mtl.offset_bottom = 130.0
	mtl.add_theme_constant_override("margin_left", 16); mtl.add_theme_constant_override("margin_top", 16)
	ui.add_child(mtl)
	var vb := VBoxContainer.new(); vb.name = "VBoxContainer"; mtl.add_child(vb)
	vb.add_theme_constant_override("separation", 3)

	# Map title
	var tl := Label.new(); tl.name = "TitleLabel"
	tl.text = _current_map.title.to_upper()
	tl.add_theme_color_override("font_color", Color(0.94,0.82,0.50))
	tl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.78))
	tl.add_theme_constant_override("outline_size", 3)
	tl.add_theme_font_size_override("font_size", 15)
	vb.add_child(tl)

	# Level display
	var lvl := Label.new(); lvl.name = "LevelLabel"
	lvl.text = "Liv. %d" % (_player_node.get("level") if _player_node else 1)
	lvl.add_theme_color_override("font_color", Color(0.38, 0.92, 1.0))
	lvl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.70))
	lvl.add_theme_constant_override("outline_size", 2)
	lvl.add_theme_font_size_override("font_size", 13)
	vb.add_child(lvl)

	# Player health bar
	var phb := ProgressBar.new(); phb.name = "HealthBar"
	phb.min_value = 0.0; phb.max_value = _player_node.get("max_hp") if _player_node else 120.0
	phb.value = _player_node.get("current_hp") if _player_node else 120.0
	phb.custom_minimum_size = Vector2(280, 24); phb.show_percentage = false
	_style_progress_bar(phb, Color(0.12, 0.035, 0.035, 0.92), Color(0.92, 0.10, 0.12, 1.0), Color(0.56, 0.12, 0.08, 0.90))
	vb.add_child(phb)

	var hl := Label.new(); hl.name = "HealthLabel"
	hl.text = "%d / %d" % [int(phb.value), int(phb.max_value)]
	hl.add_theme_color_override("font_color", Color(1.0,0.42,0.36))
	hl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.76))
	hl.add_theme_constant_override("outline_size", 2)
	hl.add_theme_font_size_override("font_size", 12)
	vb.add_child(hl)

	# XP bar with a sharp blue shadow-rift accent.
	var xpb := ProgressBar.new(); xpb.name = "XPBar"
	xpb.min_value = 0.0
	xpb.max_value = _player_node.get("xp_to_next_level") if _player_node else 30
	xpb.value = _player_node.get("xp") if _player_node else 0
	xpb.custom_minimum_size = Vector2(280, 12); xpb.show_percentage = false
	_style_progress_bar(xpb, Color(0.015, 0.040, 0.11, 0.92), Color(0.18, 0.64, 1.0, 1.0), Color(0.10, 0.32, 0.62, 0.92))
	vb.add_child(xpb)

	var xl := Label.new(); xl.name = "XPLabel"
	xl.text = "XP %d / %d" % [int(xpb.value), int(xpb.max_value)]
	xl.add_theme_color_override("font_color", Color(0.42, 0.75, 1.0))
	xl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.70))
	xl.add_theme_constant_override("outline_size", 2)
	xl.add_theme_font_size_override("font_size", 10)
	vb.add_child(xl)

	# Connect player signals
	if _player_node:
		if _player_node.has_signal("health_changed"):
			_player_node.health_changed.connect(func(cur: int, mx: int):
				phb.max_value = mx; phb.value = cur
				hl.text = "%d / %d" % [cur, mx]
			)
		if _player_node.has_signal("xp_changed"):
			_player_node.xp_changed.connect(func(xp: int, xpn: int):
				xpb.max_value = xpn; xpb.value = xp
				xl.text = "XP %d / %d" % [xp, xpn]
			)
		if _player_node.has_signal("leveled_up"):
			_player_node.leveled_up.connect(func(lv: int):
				lvl.text = "Liv. %d" % lv
				phb.max_value = _player_node.get("max_hp"); phb.value = _player_node.get("current_hp")
				hl.text = "%d / %d" % [_player_node.get("current_hp"), _player_node.get("max_hp")]
			)

	# Buttons
	var action_frame := Panel.new()
	action_frame.name = "ActionFrame"
	action_frame.anchor_left = 1.0
	action_frame.anchor_top = 1.0
	action_frame.anchor_right = 1.0
	action_frame.anchor_bottom = 1.0
	action_frame.offset_left = -410.0
	action_frame.offset_top = -148.0
	action_frame.offset_right = -10.0
	action_frame.offset_bottom = -72.0
	action_frame.add_theme_stylebox_override("panel", _make_panel_style(Color(0.025, 0.030, 0.052, 0.74), Color(0.58, 0.36, 0.98, 0.34), 0.48))
	ui.add_child(action_frame)

	var mbr := MarginContainer.new(); mbr.name = "ButtonContainer"
	mbr.anchor_left = 1.0; mbr.anchor_top = 1.0; mbr.anchor_right = 1.0; mbr.anchor_bottom = 1.0
	mbr.offset_left = -400.0; mbr.offset_top = -140.0
	mbr.add_theme_constant_override("margin_right", 16); mbr.add_theme_constant_override("margin_bottom", 16)
	ui.add_child(mbr)
	var hbx := HBoxContainer.new(); hbx.name = "HBoxContainer"
	hbx.add_theme_constant_override("separation", 8); mbr.add_child(hbx)

	# Gold display (persistent)
	var goldbox := VBoxContainer.new(); goldbox.name = "GoldBox"
	var gl := Label.new(); gl.name = "HUDGold"
	gl.text = "Oro: %d" % (_player_node.gold if _player_node else 0)
	gl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	gl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.78))
	gl.add_theme_constant_override("outline_size", 2)
	gl.add_theme_font_size_override("font_size", 13)
	goldbox.add_child(gl)
	if _player_node and _player_node.has_signal("gold_changed"):
		_player_node.gold_changed.connect(func(g: int): gl.text = "Oro: %d" % g)
	hbx.add_child(goldbox)

	var invb := Button.new(); invb.name = "InventoryButton"; invb.text = "Zaino (I)"
	invb.custom_minimum_size = Vector2(110, 50); _style_dark_button(invb); hbx.add_child(invb)

	var atkb := Button.new(); atkb.name = "AttackButton"; atkb.text = "Attacca"
	atkb.custom_minimum_size = Vector2(100, 50); _style_dark_button(atkb); hbx.add_child(atkb)

	# Map switch button
	var mapb := Button.new(); mapb.name = "MapButton"; mapb.text = "Varchi"
	mapb.custom_minimum_size = Vector2(78, 50); _style_dark_button(mapb); hbx.add_child(mapb)
	mapb.pressed.connect(_show_map_menu.bind(ui))

	# Save/Load buttons
	var svb := Button.new(); svb.name = "SaveButton"; svb.text = "S"
	svb.custom_minimum_size = Vector2(40, 50)
	_style_dark_button(svb)
	svb.pressed.connect(_save_current_game)
	hbx.add_child(svb)
	var ldb := Button.new(); ldb.name = "LoadButton"; ldb.text = "L"
	ldb.custom_minimum_size = Vector2(40, 50)
	_style_dark_button(ldb)
	ldb.pressed.connect(_load_saved_game)
	hbx.add_child(ldb)

	# 3D Real City button
	var r3d := Button.new(); r3d.name = "TravelButton"; r3d.text = "Viaggia"
	r3d.custom_minimum_size = Vector2(40, 50)
	_style_dark_button(r3d)
	r3d.pressed.connect(_switch_to_real_world)
	hbx.add_child(r3d)
	_build_skill_quickbar(ui)

	# Minimap (top-right corner)
	var minimap := Control.new(); minimap.name = "Minimap"
	minimap.anchor_left = 1.0; minimap.anchor_top = 0.0
	minimap.anchor_right = 1.0; minimap.anchor_bottom = 0.0
	minimap.offset_left = -178.0; minimap.offset_top = 10.0
	minimap.offset_right = -10.0; minimap.offset_bottom = 178.0
	ui.add_child(minimap)

	var mm_frame := Panel.new(); mm_frame.name = "MMFrame"
	mm_frame.anchor_right = 1.0; mm_frame.anchor_bottom = 1.0
	mm_frame.add_theme_stylebox_override("panel", _make_panel_style(Color(0.018, 0.036, 0.070, 0.86), Color(0.30, 0.80, 1.0, 0.44), 0.42))
	minimap.add_child(mm_frame)

	var mmbg := ColorRect.new(); mmbg.name = "MMBg"
	mmbg.offset_left = 8.0
	mmbg.offset_top = 8.0
	mmbg.offset_right = -8.0
	mmbg.offset_bottom = -8.0
	mmbg.anchor_right = 1.0; mmbg.anchor_bottom = 1.0
	mmbg.color = Color(0.02, 0.05, 0.12, 0.68)
	minimap.add_child(mmbg)

	for i in range(1, 4):
		var vline := ColorRect.new()
		vline.name = "MMGridV"
		vline.color = Color(0.36, 0.80, 1.0, 0.12)
		vline.offset_left = 8.0 + float(i) * 38.0
		vline.offset_top = 8.0
		vline.offset_right = vline.offset_left + 1.0
		vline.offset_bottom = 150.0
		minimap.add_child(vline)

		var hline := ColorRect.new()
		hline.name = "MMGridH"
		hline.color = Color(0.36, 0.80, 1.0, 0.12)
		hline.offset_left = 8.0
		hline.offset_top = 8.0 + float(i) * 38.0
		hline.offset_right = 160.0
		hline.offset_bottom = hline.offset_top + 1.0
		minimap.add_child(hline)

	var player_dot := ColorRect.new()
	player_dot.name = "MMPlayerDot"
	player_dot.size = Vector2(6.0, 6.0)
	player_dot.position = Vector2(81.0, 81.0)
	player_dot.color = Color(0.22, 0.96, 1.0, 0.92)
	minimap.add_child(player_dot)

	var mml := Label.new(); mml.name = "MMLabel"
	mml.anchor_top = 1.0; mml.anchor_bottom = 1.0
	mml.offset_top = -20.0; mml.add_theme_font_size_override("font_size", 10)
	mml.add_theme_color_override("font_color", Color(0.58, 0.86, 1.0))
	mml.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	mml.add_theme_constant_override("outline_size", 2)
	mml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	minimap.add_child(mml)

	# Inventory panel (enhanced with equipment + gold)
	var pnl := Panel.new(); pnl.name = "InventoryPanel"
	pnl.anchor_left = 0.15; pnl.anchor_top = 0.1; pnl.anchor_right = 0.85; pnl.anchor_bottom = 0.9
	pnl.visible = false
	var ps := _make_panel_style(Color(0.035, 0.030, 0.052, 0.97), Color(0.72, 0.58, 0.30, 0.74), 0.66)
	ps.border_width_left = 2; ps.border_width_right = 2; ps.border_width_top = 2; ps.border_width_bottom = 2
	pnl.add_theme_stylebox_override("panel", ps); ui.add_child(pnl)

	var panel_hb := HBoxContainer.new(); panel_hb.name = "PanelHBox"
	panel_hb.anchor_left = 0.03; panel_hb.anchor_top = 0.03; panel_hb.anchor_right = 0.97; panel_hb.anchor_bottom = 0.97
	pnl.add_child(panel_hb)

	# LEFT: Equipment
	var eqcol := VBoxContainer.new(); eqcol.name = "EquipCol"; eqcol.custom_minimum_size = Vector2(220, 0)
	eqcol.add_theme_constant_override("separation", 5)
	panel_hb.add_child(eqcol)

	var eqtl := Label.new(); eqtl.text = "EQUIPAGGIAMENTO"; eqtl.add_theme_color_override("font_color",Color(0.92,0.80,0.50)); eqtl.add_theme_color_override("font_outline_color", Color(0,0,0,0.8)); eqtl.add_theme_constant_override("outline_size", 2); eqtl.add_theme_font_size_override("font_size",16); eqcol.add_child(eqtl)

	# Gold
	var gol := Label.new(); gol.name = "GoldLabel"; gol.text = "Oro: 0"; gol.add_theme_color_override("font_color",Color(1.0,0.85,0.2)); gol.add_theme_color_override("font_outline_color", Color(0,0,0,0.80)); gol.add_theme_constant_override("outline_size", 2); gol.add_theme_font_size_override("font_size",14); eqcol.add_child(gol)

	eqcol.add_child(HSeparator.new())

	# Equipment slots
	var slots := {"weapon":"Arma","armor":"Armatura","helmet":"Elmo","boots":"Stivali","ring":"Anello","amulet":"Amuleto","belt":"Cintura","relic":"Reliquia"}
	for sl in ["weapon","armor","helmet","boots","ring","amulet","belt","relic"]:
		var srow := HBoxContainer.new()
		var slbl := Label.new(); slbl.text = "[" + slots[sl] + "] "; slbl.add_theme_color_override("font_color", Color(0.60, 0.74, 0.84)); slbl.add_theme_font_size_override("font_size",13); slbl.custom_minimum_size = Vector2(85,0); srow.add_child(slbl)
		var sqt := Label.new(); sqt.name = "Slot_" + sl; sqt.text = "— vuoto —"; sqt.add_theme_color_override("font_color",Color(0.5,0.5,0.5)); sqt.add_theme_font_size_override("font_size",12); sqt.size_flags_horizontal = Control.SIZE_EXPAND_FILL; srow.add_child(sqt)
		var ubtn := Button.new(); ubtn.name = "UnEquip_" + sl; ubtn.text = "X"; ubtn.custom_minimum_size = Vector2(28,24); ubtn.visible = false; _style_dark_button(ubtn); srow.add_child(ubtn)
		eqcol.add_child(srow)

	eqcol.add_child(HSeparator.new())

	# Stats summary
	var stl := Label.new(); stl.name = "StatsLabel"; stl.text = "ATT:10 | DIF:0 | HP:100 | VEL:200 | AGI:0"; stl.add_theme_color_override("font_color",Color(0.58,0.95,0.70)); stl.add_theme_color_override("font_outline_color", Color(0,0,0,0.75)); stl.add_theme_constant_override("outline_size", 2); stl.add_theme_font_size_override("font_size",11); eqcol.add_child(stl)

	# VSeparator
	panel_hb.add_child(VSeparator.new())

	# RIGHT: Inventory list
	var invcol := VBoxContainer.new(); invcol.name = "InvCol"; invcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	invcol.add_theme_constant_override("separation", 6)
	panel_hb.add_child(invcol)

	var invhdr := HBoxContainer.new()
	var itl := Label.new(); itl.text = "ZAINO"; itl.add_theme_color_override("font_color",Color(0.92,0.80,0.50)); itl.add_theme_color_override("font_outline_color", Color(0,0,0,0.8)); itl.add_theme_constant_override("outline_size", 2); itl.add_theme_font_size_override("font_size",16); invhdr.add_child(itl)
	var spcr := Control.new(); spcr.size_flags_horizontal = Control.SIZE_EXPAND_FILL; invhdr.add_child(spcr)
	var cb := Button.new(); cb.name = "CloseButton"; cb.text = "Chiudi"; cb.custom_minimum_size = Vector2(78,30); _style_dark_button(cb); invhdr.add_child(cb)
	invcol.add_child(invhdr)

	var sc := ScrollContainer.new(); sc.name = "ScrollContainer"; sc.size_flags_vertical = Control.SIZE_EXPAND_FILL; invcol.add_child(sc)
	var il := VBoxContainer.new(); il.name = "InventoryList"; il.add_theme_constant_override("separation",3); sc.add_child(il)

	# Connect inventory refresh
	var inventory := get_node_or_null("/root/Inventory")
	if inventory:
		if inventory.inventory_changed.is_connected(_refresh_inventory_ui):
			inventory.inventory_changed.disconnect(_refresh_inventory_ui)
		if inventory.has_signal("inventory_changed") and not inventory.inventory_changed.is_connected(_queue_autosave):
			inventory.inventory_changed.connect(_queue_autosave)
	if _player_node:
		if _player_node.has_signal("gold_changed"):
			_player_node.gold_changed.connect(func(_g: int): ui.call("_refresh_inventory_display"))
		if _player_node.has_signal("equipment_changed"):
			_player_node.equipment_changed.connect(func(_s, _i): ui.call("_refresh_inventory_display"))
		if _player_node.has_signal("health_changed"):
			_player_node.health_changed.connect(func(_c, _m): ui.call("_refresh_inventory_display"))

	var dbg := Label.new(); dbg.name = "DebugLabel"
	dbg.anchor_left = 0.0; dbg.anchor_bottom = 1.0
	dbg.offset_left = 16.0; dbg.offset_bottom = -100.0
	dbg.modulate = Color.YELLOW; dbg.visible = false; ui.add_child(dbg)
	_connect_system_ui(ui)


func _build_skill_quickbar(ui: CanvasLayer) -> void:
	var frame := Panel.new()
	frame.name = "SkillQuickbar"
	frame.anchor_left = 1.0
	frame.anchor_top = 1.0
	frame.anchor_right = 1.0
	frame.anchor_bottom = 1.0
	frame.offset_left = -386.0
	frame.offset_top = -214.0
	frame.offset_right = -10.0
	frame.offset_bottom = -158.0
	frame.add_theme_stylebox_override("panel", _make_panel_style(Color(0.020, 0.026, 0.052, 0.76), Color(0.50, 0.82, 1.0, 0.38), 0.42))
	ui.add_child(frame)

	var margin := MarginContainer.new()
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	frame.add_child(margin)

	var row := HBoxContainer.new()
	row.name = "HBoxContainer"
	row.add_theme_constant_override("separation", 7)
	margin.add_child(row)

	var dash := Button.new()
	dash.name = "DashButton"
	dash.text = "Shift"
	dash.custom_minimum_size = Vector2(62, 40)
	_style_dark_button(dash)
	dash.pressed.connect(_emit_dash_command)
	row.add_child(dash)

	var skills := [
		{"id": "charged_shot", "label": "1"},
		{"id": "piercing_shot", "label": "2"},
		{"id": "arcane_burst", "label": "3"},
		{"id": "guardian_aegis", "label": "4"},
	]
	for def in skills:
		var skill_id := String(def["id"])
		var btn := Button.new()
		btn.name = "Skill_%s" % skill_id
		btn.text = String(def["label"])
		btn.custom_minimum_size = Vector2(48, 40)
		_style_dark_button(btn)
		btn.pressed.connect(_emit_skill_command.bind(skill_id))
		row.add_child(btn)
	if _player_node:
		if _player_node.has_signal("dash_status_changed") and not _player_node.dash_status_changed.is_connected(_on_dash_status_changed):
			_player_node.dash_status_changed.connect(_on_dash_status_changed)
		if _player_node.has_signal("skill_status_changed") and not _player_node.skill_status_changed.is_connected(_on_skill_status_changed):
			_player_node.skill_status_changed.connect(_on_skill_status_changed)


func _emit_dash_command() -> void:
	var ic := get_node_or_null("/root/InputController")
	if ic and ic.has_signal("dash_command"):
		ic.dash_command.emit()


func _emit_skill_command(skill_id: String) -> void:
	var ic := get_node_or_null("/root/InputController")
	if ic and ic.has_signal("skill_command"):
		ic.skill_command.emit(skill_id)


func _on_dash_status_changed(ready: bool, cooldown_left: float, _cooldown: float) -> void:
	var ui := get_node_or_null("GameUI") as CanvasLayer
	if not ui:
		return
	var button := ui.get_node_or_null("SkillQuickbar/MarginContainer/HBoxContainer/DashButton") as Button
	if not button:
		return
	button.disabled = not ready
	button.text = "Shift" if ready else "%.1f" % cooldown_left


func _on_skill_status_changed(skill_id: String, ready: bool, cooldown_left: float, _cooldown: float) -> void:
	var ui := get_node_or_null("GameUI") as CanvasLayer
	if not ui:
		return
	var button := ui.get_node_or_null("SkillQuickbar/MarginContainer/HBoxContainer/Skill_%s" % skill_id) as Button
	if not button:
		return
	var labels := {"charged_shot": "1", "piercing_shot": "2", "arcane_burst": "3", "guardian_aegis": "4"}
	button.disabled = not ready
	button.text = String(labels.get(skill_id, "?")) if ready else "%.1f" % cooldown_left


func _refresh_inventory_ui(ui: CanvasLayer) -> void:
	var pnl := ui.get_node_or_null("InventoryPanel")
	if not pnl or not pnl.visible:
		return

	var gol := pnl.get_node_or_null("PanelHBox/EquipCol/GoldLabel") as Label
	if gol and _player_node:
		gol.text = "Oro: %d" % _player_node.gold

	# Equipment slots
	for sl in ["weapon","armor","helmet","boots","ring","amulet","belt","relic"]:
		var sqt := pnl.get_node_or_null("PanelHBox/EquipCol/Slot_%s" % sl) as Label
		var ubtn := pnl.get_node_or_null("PanelHBox/EquipCol/UnEquip_%s" % sl) as Button
		if not sqt: continue
		var item = _player_node.equipment.get(sl) if _player_node else null
		if item:
			sqt.text = item.name
			var rcols := {"common":Color(0.7,0.7,0.7),"uncommon":Color(0.3,0.8,0.3),"rare":Color(0.3,0.4,0.9),"epic":Color(0.7,0.2,0.9),"legendary":Color(0.9,0.6,0.1),"mythic":Color(1.0,0.15,0.15),"archontic":Color(1.0,0.78,0.1),"infinite":Color(0.35,0.88,1.0)}
			sqt.add_theme_color_override("font_color", rcols.get(item.rarity, Color.WHITE))
			if ubtn:
				ubtn.visible = true
				if not ubtn.pressed.is_connected(func(): _player_node.unequip_item(sl)):
					ubtn.pressed.connect(func(): 
						var old = _player_node.unequip_item(sl)
						if old:
							var inv = get_node_or_null("/root/Inventory")
							if inv: inv.add_item(old)
					, CONNECT_ONE_SHOT)
		else:
			sqt.text = "— vuoto —"
			sqt.add_theme_color_override("font_color", Color(0.5,0.5,0.5))
			if ubtn: ubtn.visible = false

	# Stats
	var stl := pnl.get_node_or_null("PanelHBox/EquipCol/StatsLabel") as Label
	if stl and _player_node:
		stl.text = "ATT:%d | DIF:%d | HP:%d | VEL:%d | AGI:%d | Liv.%d | Asc.%d" % [
			_player_node.attack_damage,
			int(_player_node.get("defense")),
			_player_node.max_hp,
			int(_player_node.move_speed),
			int(_player_node.get("agility")),
			_player_node.level,
			int(_player_node.get("ascension_level")),
		]

	# Inventory items
	var il := pnl.get_node_or_null("PanelHBox/InvCol/ScrollContainer/InventoryList") as VBoxContainer
	if not il: return
	for child in il.get_children():
		child.queue_free()

	var inventory := get_node_or_null("/root/Inventory")
	if not inventory or inventory.items.is_empty():
		var empty := Label.new(); empty.text = "Zaino vuoto. Uccidi nemici per ottenere bottino!"; empty.add_theme_color_override("font_color",Color(0.5,0.5,0.5)); il.add_child(empty)
		return

	for item in inventory.items:
		var row := HBoxContainer.new()
		var nl := Label.new(); nl.text = item.name; nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; nl.add_theme_font_size_override("font_size",12)
		var rarity_name := String(item.get("rarity"))
		if not rarity_name.is_empty():
			var rcols := {"common":Color(0.7,0.7,0.7),"uncommon":Color(0.3,0.8,0.3),"rare":Color(0.3,0.4,0.9),"epic":Color(0.7,0.2,0.9),"legendary":Color(0.9,0.6,0.1),"mythic":Color(1.0,0.15,0.15),"archontic":Color(1.0,0.78,0.1),"infinite":Color(0.35,0.88,1.0)}
			nl.add_theme_color_override("font_color", rcols.get(rarity_name, Color.WHITE))
		row.add_child(nl)

		var vl := Label.new(); vl.text = "%d oro" % item.value; vl.add_theme_font_size_override("font_size",10); vl.custom_minimum_size = Vector2(55,0); row.add_child(vl)

		var slot_name := String(item.get("slot"))
		if not slot_name.is_empty():
			var ebtn := Button.new(); ebtn.text = "EQU"; ebtn.custom_minimum_size = Vector2(40,24)
			ebtn.pressed.connect(func():
				if _player_node:
					var old = _player_node.equipment.get(slot_name)
					if old:
						inventory.add_item(old)
					inventory.remove_item(item)
					_player_node.equip_item(slot_name, item)
			)
			row.add_child(ebtn)

		il.add_child(row)


func _show_map_menu(ui: CanvasLayer) -> void:
	var pnl := Panel.new(); pnl.name = "MapMenuPanel"
	pnl.anchor_left = 0.15; pnl.anchor_top = 0.15
	pnl.anchor_right = 0.85; pnl.anchor_bottom = 0.85
	var ps := _make_panel_style(Color(0.030, 0.032, 0.060, 0.98), Color(0.34, 0.66, 1.0, 0.76), 0.70)
	ps.border_width_left = 2; ps.border_width_right = 2
	ps.border_width_top = 2; ps.border_width_bottom = 2
	pnl.add_theme_stylebox_override("panel", ps); ui.add_child(pnl)

	var vbc := VBoxContainer.new()
	vbc.anchor_left = 0.05; vbc.anchor_top = 0.05
	vbc.anchor_right = 0.95; vbc.anchor_bottom = 0.95
	pnl.add_child(vbc)

	var tl := Label.new(); tl.text = "VARCHI - Seleziona Destinazione"
	tl.add_theme_color_override("font_color", Color(0.58,0.86,1.0))
	tl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
	tl.add_theme_constant_override("outline_size", 3)
	tl.add_theme_font_size_override("font_size", 20)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbc.add_child(tl)

	var sep := HSeparator.new(); vbc.add_child(sep)

	var sc := ScrollContainer.new(); sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbc.add_child(sc)
	var gd := GridContainer.new(); gd.columns = 3
	gd.add_theme_constant_override("h_separation", 12)
	gd.add_theme_constant_override("v_separation", 12)
	sc.add_child(gd)

	for m in MAP_REGISTRY.get_all_maps():
		var btn := Button.new()
		btn.text = "%s\n%s" % [m.title, m.desc]
		btn.custom_minimum_size = Vector2(280, 80)
		_style_dark_button(btn)
		var current := "[QUI]" if m.id == _current_map_id else ""
		if m.id == _current_map_id:
			btn.disabled = true
			btn.text += "\n[LOCAZIONE ATTUALE]"
		btn.pressed.connect(func():
			pnl.queue_free()
			if m.id != _current_map_id:
				_load_map(m.id)
		)
		gd.add_child(btn)

	var cb := Button.new(); cb.text = "Chiudi"
	cb.custom_minimum_size = Vector2(0, 44)
	_style_dark_button(cb)
	cb.pressed.connect(pnl.queue_free)
	vbc.add_child(cb)


# ===== INPUT =====

func _connect_input() -> void:
	var di := get_node_or_null("DroppedItems")
	if not di:
		di = Node2D.new(); di.name = "DroppedItems"; add_child(di)

	# Mobile controls (Android/iOS)
	var mc := _ensure_mobile_controls()

	var ic := get_node_or_null("/root/InputController")
	if ic:
		if ic.move_command.is_connected(_on_player_move):
			ic.move_command.disconnect(_on_player_move)
		ic.move_command.connect(_on_player_move)

		if ic.has_signal("move_vector_command") and not ic.move_vector_command.is_connected(_on_player_move_vector):
			ic.move_vector_command.connect(_on_player_move_vector)

		if _player_node and _player_node.has_method("_on_attack_command"):
			if ic.attack_command.is_connected(_player_node._on_attack_command):
				ic.attack_command.disconnect(_player_node._on_attack_command)
			ic.attack_command.connect(_player_node._on_attack_command)
		if _player_node and _player_node.has_method("_on_dash_command") and ic.has_signal("dash_command"):
			if ic.dash_command.is_connected(_player_node._on_dash_command):
				ic.dash_command.disconnect(_player_node._on_dash_command)
			ic.dash_command.connect(_player_node._on_dash_command)
		if _player_node and _player_node.has_method("_on_skill_command") and ic.has_signal("skill_command"):
			if ic.skill_command.is_connected(_player_node._on_skill_command):
				ic.skill_command.disconnect(_player_node._on_skill_command)
			ic.skill_command.connect(_player_node._on_skill_command)

		if has_node("GameUI") and $GameUI.has_method("_toggle_inventory"):
			if ic.toggle_inventory.is_connected($GameUI._toggle_inventory):
				ic.toggle_inventory.disconnect($GameUI._toggle_inventory)
			ic.toggle_inventory.connect($GameUI._toggle_inventory)

		if ic.has_signal("travel_command") and not ic.travel_command.is_connected(_switch_to_real_world):
			ic.travel_command.connect(_switch_to_real_world)


func _ensure_mobile_controls() -> CanvasLayer:
	var existing := get_node_or_null("MobileControls") as CanvasLayer
	if existing:
		return existing

	var MobileControlsClass := load("res://scripts/ui/MobileControls.gd")
	var mc := CanvasLayer.new()
	mc.name = "MobileControls"
	mc.set_script(MobileControlsClass)
	add_child(mc)

	var ic := get_node_or_null("/root/InputController")
	if ic and mc.has_signal("move_vector_changed"):
		if not mc.move_vector_changed.is_connected(ic._on_joystick_move):
			mc.move_vector_changed.connect(ic._on_joystick_move)
	if ic and mc.has_signal("mobile_attack"):
		if not mc.mobile_attack.is_connected(ic._on_mobile_attack):
			mc.mobile_attack.connect(ic._on_mobile_attack)
	if ic and mc.has_signal("mobile_dash"):
		if not mc.mobile_dash.is_connected(ic._on_mobile_dash):
			mc.mobile_dash.connect(ic._on_mobile_dash)
	if ic and mc.has_signal("mobile_skill"):
		if not mc.mobile_skill.is_connected(ic._on_mobile_skill):
			mc.mobile_skill.connect(ic._on_mobile_skill)
	if ic and mc.has_signal("mobile_inventory"):
		if not mc.mobile_inventory.is_connected(ic._on_mobile_inventory):
			mc.mobile_inventory.connect(ic._on_mobile_inventory)
	if ic and mc.has_signal("mobile_travel"):
		if not mc.mobile_travel.is_connected(ic._on_mobile_travel):
			mc.mobile_travel.connect(ic._on_mobile_travel)

	return mc


func _on_player_move_vector(direction: Vector2) -> void:
	"""Continuous movement from virtual joystick."""
	if _player_node and _player_node.has_method("_on_move_vector"):
		_player_node._on_move_vector(direction)
	elif _player_node and direction.length_squared() > 0.01:
		var move_amount := direction * 8.0
		_player_node._on_move_command(_player_node.global_position + move_amount)


func _on_player_move(world_pos: Vector2) -> void:
	_ensure_audio_started()
	var dot := ColorRect.new(); dot.name = "ClickDot"
	dot.size = Vector2(8, 8); dot.position = world_pos - Vector2(4, 4)
	dot.color = Color(1.0, 0.3, 0.3, 0.8)
	add_child(dot)
	var tween := create_tween()
	tween.tween_property(dot, "modulate:a", 0.0, 0.5)
	tween.tween_callback(dot.queue_free)
	if _player_node and _player_node.has_method("_on_move_command"):
		_player_node._on_move_command(world_pos)


func _update_minimap() -> void:
	var ui := get_node_or_null("GameUI")
	if not ui: return
	var mm := ui.get_node_or_null("Minimap") as Control
	if not mm: return
	var mml := mm.get_node_or_null("MMLabel") as Label
	if not mml: return
	
	var enemy_count := 0
	for child in get_children():
		if child is CharacterBody2D and child.has_method("is_dead") and not child.is_dead() and child != _player_node:
			enemy_count += 1
	
	mml.text = "Nemici: %d | Oro: %d" % [enemy_count, _player_node.gold if _player_node else 0]


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("save_game"):
		_save_current_game()
	if event.is_action_pressed("load_game"):
		_load_saved_game()
	if event.is_action_pressed("toggle_real_city"):
		_switch_to_real_world()


func _switch_to_real_world() -> void:
	"""Cycle through all available maps — no distinction between classic and city."""
	_save_current_game()
	var all_maps: Array[Dictionary] = MAP_REGISTRY.get_all_maps()
	if all_maps.is_empty():
		return

	var current_idx := -1
	for i in range(all_maps.size()):
		if all_maps[i].id == _current_map_id:
			current_idx = i
			break

	var next_idx := (current_idx + 1) % all_maps.size()
	var next_map: String = all_maps[next_idx].id
	var next_name: String = all_maps[next_idx].title

	if has_node("GameUI") and $GameUI.has_method("show_debug_message"):
		$GameUI.show_debug_message("Viaggio a %s..." % next_name)
	await get_tree().create_timer(0.3).timeout
	_load_map(next_map)


func _queue_autosave() -> void:
	if _autosave_pending:
		return
	_autosave_pending = true
	await get_tree().create_timer(0.75).timeout
	_autosave_pending = false
	_save_current_game(false)


func _save_current_game(show_message: bool = true) -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm and _player_node:
		sm.save_game(_player_node, _current_map_id)
		if show_message and has_node("GameUI") and $GameUI.has_method("show_debug_message"):
			$GameUI.show_debug_message("Partita salvata! (Liv.%d, %d oro)" % [_player_node.level, _player_node.gold])


func _load_saved_game() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm and sm.has_save():
		var data: Dictionary = sm.load_game() as Dictionary
		if not data.is_empty():
			_current_map_id = data.get("map_id", "black_oak_farm")
			_load_map(_current_map_id)
			await get_tree().process_frame
			_apply_loaded_data(data)


func _process(delta: float) -> void:
	_hero_line_cooldown = max(0.0, _hero_line_cooldown - delta)
	_update_minimap()
