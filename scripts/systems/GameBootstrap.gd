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
const ENDLESS_PORTAL_PREFIX: String = "endless_portal_"
const ENDLESS_START_DEPTH: int = 7
const ENDLESS_ARENA_IDS: Array[String] = ["procedural4", "procedural5", "procedural6", "ruined_city", "cyberpunk"]
const ENDLESS_VARIANTS: Array[Dictionary] = [
	{"name": "Eclisse", "desc": "Arcanisti e non-morti saturano l'arena.", "enemies": ["lich", "mage", "skeleton_a"], "champion": "lich"},
	{"name": "Ferale", "desc": "Bestie rapide spezzano le linee sicure.", "enemies": ["werewolf", "werewolf_a", "wyvern"], "champion": "wyvern_a"},
	{"name": "Mirmidone", "desc": "Sciami corazzati chiudono ogni fuga.", "enemies": ["myrm_scout", "myrm_soldier", "myrm_elite"], "champion": "myrm_queen"},
	{"name": "Draconico", "desc": "Creature alate e draghi controllano la distanza.", "enemies": ["wyvern", "wyvern_a", "dragon_b"], "champion": "dragon"},
	{"name": "Guerra", "desc": "Bruti e comandanti spingono al combattimento frontale.", "enemies": ["orc", "orc_b", "minotaur"], "champion": "minotaur"},
]

var _current_map_id: String = EVAL_START_MAP
var _atmosphere: RefCounted = null
var _city_builder: RefCounted = null
var _portal_spawner: RefCounted = null
var _tileset_mapper: RefCounted = null
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
var _current_portal_depth: int = 1
var _current_physical_map_id: String = EVAL_START_MAP
var _last_loaded_map_id: String = ""
var _map_reload_streak: int = 0
var _new_depth_bonus_active: bool = false

func _ready() -> void:
	randomize()
	_atmosphere = load("res://scripts/world/AtmosphereBuilder.gd").new(self)
	_city_builder = load("res://scripts/world/RealCityBuilder.gd").new(self)
	_portal_spawner = load("res://scripts/world/PortalSpawner.gd").new(self)
	_tileset_mapper = load("res://scripts/world/TilesetMapper.gd").new(self)
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
	
	# New game — class selection (skipped in headless or when --class= is given)
	var requested_class: String = _get_requested_class()
	if requested_class.is_empty() and not _is_headless():
		_show_class_select()
		print("=== AWAITING CLASS SELECTION ===")
		return
	if not requested_class.is_empty():
		_set_player_class(requested_class)
	_load_map(_current_map_id)
	print("=== READY ===")


func _player_data() -> Node:
	return get_node_or_null("/root/PlayerData")


func _get_active_class_info() -> Dictionary:
	var pd := _player_data()
	if pd and pd.has_method("get_class_info"):
		return pd.get_class_info()
	return {}


func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


func _get_requested_class() -> String:
	var pd := _player_data()
	if not pd or not pd.has_method("get_all_classes"):
		return ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--class="):
			var cid: String = arg.get_slice("=", 1)
			for c in pd.get_all_classes():
				if String(c.get("id", "")) == cid:
					return cid
			push_warning("Classe richiesta non trovata: %s" % cid)
	return ""


func _set_player_class(class_id: String) -> void:
	var pd := _player_data()
	if pd and pd.has_method("set_class"):
		pd.set_class(class_id)
		print("Classe selezionata: %s (%s)" % [class_id, pd.get("player_class_name")])


func _show_class_select() -> void:
	var pd := _player_data()
	if not pd or not pd.has_method("get_all_classes"):
		return
	var story := get_node_or_null("/root/StoryData")
	var layer := CanvasLayer.new()
	layer.name = "ClassSelect"
	layer.layer = 100
	add_child(layer)

	var bg := ColorRect.new()
	bg.name = "Bg"
	bg.color = Color(0.02, 0.04, 0.08, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(bg)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 36)
	layer.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var title := Label.new()
	title.name = "Title"
	title.text = "SCEGLI IL TUO EROE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.94, 0.82, 0.50))
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	title.add_theme_constant_override("outline_size", 4)
	title.add_theme_font_size_override("font_size", 26)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "Ogni classe ha statistiche e stile di gioco diversi."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.66, 0.80, 0.92))
	subtitle.add_theme_font_size_override("font_size", 13)
	vbox.add_child(subtitle)

	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(grid)

	for cinfo in pd.get_all_classes():
		grid.add_child(_make_class_card(cinfo, story))


func _make_class_card(cinfo: Dictionary, story: Node) -> Control:
	var cid: String = String(cinfo.get("id", ""))
	var cstats: Dictionary = cinfo.get("base_stats", {})
	var hero_name: String = ""
	if story and story.has_method("get_hero_by_class"):
		var hero: Dictionary = story.get_hero_by_class(cid)
		hero_name = String(hero.get("name", ""))

	var card := Panel.new()
	card.name = "Card_" + cid
	card.custom_minimum_size = Vector2(300, 200)
	card.add_theme_stylebox_override("panel", _make_panel_style(Color(0.04, 0.06, 0.10, 0.96), Color(0.28, 0.74, 0.96, 0.55), 0.50))

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("margin_left", 14)
	vb.offset_left = 14
	vb.offset_right = -14
	vb.offset_top = 12
	vb.offset_bottom = -12
	card.add_child(vb)

	var name_lbl := Label.new()
	name_lbl.text = String(cinfo.get("name", cid))
	name_lbl.add_theme_color_override("font_color", Color(0.94, 0.86, 0.60))
	name_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.80))
	name_lbl.add_theme_constant_override("outline_size", 3)
	name_lbl.add_theme_font_size_override("font_size", 18)
	vb.add_child(name_lbl)

	if not hero_name.is_empty():
		var hero_lbl := Label.new()
		hero_lbl.text = "Eroe: %s" % hero_name
		hero_lbl.add_theme_color_override("font_color", Color(0.62, 0.92, 1.0))
		hero_lbl.add_theme_font_size_override("font_size", 12)
		vb.add_child(hero_lbl)

	var style_lbl := Label.new()
	style_lbl.text = "Stile: %s" % String(cinfo.get("playstyle", "—"))
	style_lbl.add_theme_color_override("font_color", Color(0.74, 0.82, 0.92))
	style_lbl.add_theme_font_size_override("font_size", 12)
	style_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(style_lbl)

	var stats_lbl := Label.new()
	stats_lbl.text = "HP %d  ATT %d  VEL %d" % [
		int(cstats.get("max_hp", 0)),
		int(cstats.get("attack_damage", 0)),
		int(float(cstats.get("move_speed", 0))),
	]
	stats_lbl.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0))
	stats_lbl.add_theme_font_size_override("font_size", 13)
	vb.add_child(stats_lbl)

	var btn := Button.new()
	btn.name = "SelectButton"
	btn.text = "Gioca %s" % String(cinfo.get("name", cid))
	btn.size_flags_vertical = Control.SIZE_SHRINK_END
	_style_dark_button(btn)
	btn.pressed.connect(_on_class_selected.bind(cid))
	vb.add_child(btn)

	return card


func _on_class_selected(class_id: String) -> void:
	_set_player_class(class_id)
	var layer := get_node_or_null("ClassSelect")
	if layer:
		layer.queue_free()
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
	var saved_class: String = String(data.get("class_id", ""))
	if not saved_class.is_empty():
		_set_player_class(saved_class)
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
	_configure_map_progression(map_id)
	_tileset_type = _current_map.get("tileset", "grassland")
	print("Loading: %s — %s [%s]" % [map_id, _current_map.title, _tileset_type])

	# Clear existing world, enemies, portals
	_clear_world()

	# Build new world
	_build_world()
	_atmosphere.build_scene_atmosphere()
	_build_player()
	_build_enemies()
	_portal_spawner._build_portals()
	_build_ui()
	_connect_input()
	_register_system_map_change(map_id)

	if has_node("GameUI") and $GameUI.has_method("show_debug_message"):
		var story_line: String = _story_map_flavor(map_id)
		if not story_line.is_empty():
			$GameUI.show_debug_message(story_line)
		else:
			$GameUI.show_debug_message("[%s] %s" % [_current_map.title, _current_map.desc])


func _configure_map_progression(map_id: String) -> void:
	if map_id == _last_loaded_map_id:
		_map_reload_streak += 1
	else:
		_map_reload_streak = 0
	_last_loaded_map_id = map_id

	_current_map_id = map_id
	_current_portal_depth = _get_portal_depth_for_map(map_id)
	_current_physical_map_id = _get_physical_map_id_for(map_id)
	if _is_endless_map_id(map_id):
		_current_map = _make_endless_map_data(_current_portal_depth)
	else:
		_current_map = MAP_REGISTRY.get_map(map_id)

	var previous_highest := 1
	if _player_node:
		previous_highest = int(_player_node.get("highest_portal_depth"))
	_new_depth_bonus_active = _current_portal_depth > previous_highest
	if _player_node and _current_portal_depth > previous_highest:
		_player_node.set("highest_portal_depth", _current_portal_depth)


func _is_endless_map_id(map_id: String) -> bool:
	return map_id.begins_with(ENDLESS_PORTAL_PREFIX)


func _get_endless_map_id(depth: int) -> String:
	return "%s%d" % [ENDLESS_PORTAL_PREFIX, maxi(ENDLESS_START_DEPTH, depth)]


func _parse_endless_depth(map_id: String) -> int:
	if not _is_endless_map_id(map_id):
		return 0
	return maxi(ENDLESS_START_DEPTH, int(map_id.get_slice("_", 2)))


func _get_physical_map_id_for(map_id: String) -> String:
	if not _is_endless_map_id(map_id):
		return map_id
	var idx := posmod(_parse_endless_depth(map_id) - ENDLESS_START_DEPTH, ENDLESS_ARENA_IDS.size())
	return ENDLESS_ARENA_IDS[idx]


func _make_endless_map_data(depth: int) -> Dictionary:
	var base: Dictionary = MAP_REGISTRY.get_map(_get_physical_map_id_for(_get_endless_map_id(depth))).duplicate(true)
	var variant := _get_endless_variant(depth)
	base["id"] = _get_endless_map_id(depth)
	base["title"] = "Portale Infinito %d - %s" % [depth, String(variant.get("name", "Varco"))]
	base["desc"] = "%s Nemici, XP e bottino scalano con la profondita." % String(variant.get("desc", "Arena riciclata dal Portale."))
	base["portals"] = [
		{"target": "procedural6", "pos": Vector2(10, 75), "label": "Procedural City 6"},
		{"target": _get_endless_map_id(depth + 1), "pos": Vector2(75, 10), "label": "Portale Infinito %d" % (depth + 1)},
	]
	return base


func _get_endless_variant(depth: int) -> Dictionary:
	if ENDLESS_VARIANTS.is_empty():
		return {}
	var idx := posmod(depth - ENDLESS_START_DEPTH, ENDLESS_VARIANTS.size())
	return ENDLESS_VARIANTS[idx]


func _get_portal_depth_for_map(map_id: String) -> int:
	if _is_endless_map_id(map_id):
		return _parse_endless_depth(map_id)
	var map_depths := {
		"procedural2": 2,
		"procedural3": 3,
		"procedural4": 4,
		"procedural5": 5,
		"procedural6": 6,
		"ruined_city": 4,
		"postwar_city": 4,
		"lowpoly_night": 4,
		"cyberpunk": 5,
		"tokyo_shibuya": 5,
	}
	return int(map_depths.get(map_id, 1))


func _story_map_flavor(map_id: String) -> String:
	if _is_endless_map_id(map_id):
		var variant := _get_endless_variant(_current_portal_depth)
		return "Portale Infinito - Profondita %d, %s. Avanzare aumenta rischio, XP e bottino." % [_current_portal_depth, String(variant.get("name", "Varco"))]
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
				var p = _tileset_mapper._tile_params(bg_gid)
				if p.tex == null: continue
				var z = -20 if p.type != "water" else -19
				var ground_sprite := _add_sprite(_world_node, p.tex, p.region, Vector2(pos.x + p.ox, pos.y + p.oy), z, Vector2.ONE)
				if _is_real_city():
					ground_sprite.modulate = _city_builder._city_base_tint(bg_gid)
			else:
				var ground_sprite := _add_sprite(_world_node, default_grass_tex, default_grass_rect, pos, -20, Vector2.ONE)
				if _is_real_city():
					ground_sprite.modulate = Color(0.48, 0.54, 0.48, 1.0)

			var obj_gid = obj_row[x]
			if obj_gid > 0:
				if not _is_real_city():
					var p = _tileset_mapper._tile_params(obj_gid)
					if p.tex == null: continue
					var z = (x + y) * 12
					_add_sprite(_world_node, p.tex, p.region, Vector2(pos.x + p.ox, pos.y + p.oy), z, Vector2.ONE)

			if _is_real_city():
				_city_builder._add_city_overlay_cell(_world_node, x, y, bg_gid, obj_gid, pos)
				if _city_builder._has_city_vector_source():
					continue
				elif bg_gid >= 176 and bg_gid <= 191:
					_city_builder._add_city_collision(_world_node, pos, "water")
				elif obj_gid > 0 and _city_builder._should_draw_city_block(x, y):
					_city_builder._add_city_collision(_world_node, pos, "building")

	if _is_real_city():
		if _city_builder._has_city_vector_source():
			_city_builder._add_real_city_vector_layer()
		_city_builder._add_city_landmarks()
	else:
		_atmosphere.add_wilderness_map_details()

func _get_map_visual_profile() -> Dictionary:
	var style: String = _current_map.get("city_style", "")
	var profile := {
		"family": "grassland",
		"identity": Color(0.38, 0.62, 0.32, 1.0),
		"accent": Color(0.86, 0.78, 0.48, 1.0),
		"secondary": Color(0.28, 0.44, 0.24, 1.0),
		"canvas_tint": Color(0.84, 0.90, 0.86, 1.0),
		"horizon_color": Color(0.04, 0.10, 0.06, 0.20),
		"mote_color": Color(0.64, 0.90, 0.62, 0.22),
		"ground_detail_count": 86,
		"ground_alpha": 0.24,
		"crack_density": 0.16,
		"rune_density": 0.08,
		"park_mark_density": 0.55,
		"water_edge": 0.32,
		"road_detail": 0.44,
		"roof_variation": 0.10,
		"window_density": 0.55,
		"rift_density": 0.42,
		"rift_intensity": 0.35,
		"portal_sparks": 5,
	}
	if _current_map_id in ["ruined_city", "postwar_city"] or _current_map_id.contains("stormrock"):
		profile.merge({
			"family": "ruined",
			"identity": Color(0.58, 0.48, 0.38, 1.0),
			"accent": Color(0.86, 0.58, 0.32, 1.0),
			"secondary": Color(0.30, 0.27, 0.25, 1.0),
			"canvas_tint": Color(0.82, 0.80, 0.74, 1.0),
			"horizon_color": Color(0.12, 0.10, 0.09, 0.28),
			"mote_color": Color(0.76, 0.62, 0.42, 0.24),
			"ground_detail_count": 118,
			"ground_alpha": 0.32,
			"crack_density": 0.72,
			"rune_density": 0.05,
		}, true)
	if _current_map_id in ["cyberpunk", "lowpoly_night"]:
		profile.merge({
			"family": "cyber",
			"identity": Color(0.20, 0.92, 1.0, 1.0),
			"accent": Color(0.92, 0.32, 1.0, 1.0),
			"secondary": Color(0.18, 0.28, 0.42, 1.0),
			"canvas_tint": Color(0.78, 0.88, 1.0, 1.0),
			"horizon_color": Color(0.02, 0.18, 0.28, 0.34),
			"mote_color": Color(0.22, 0.92, 1.0, 0.30),
			"ground_detail_count": 92,
			"ground_alpha": 0.28,
			"crack_density": 0.30,
			"road_detail": 0.92,
			"window_density": 0.88,
		}, true)
	if _is_real_city():
		match _current_map_id:
			"roma_centro":
				profile.merge({"family": "roman", "identity": Color(0.90, 0.60, 0.34, 1.0), "accent": Color(1.0, 0.78, 0.48, 1.0), "secondary": Color(0.48, 0.36, 0.25, 1.0), "horizon_color": Color(0.24, 0.14, 0.08, 0.24), "road_detail": 0.50, "roof_variation": 0.16}, true)
			"venezia_rialto":
				profile.merge({"family": "venice", "identity": Color(0.18, 0.82, 1.0, 1.0), "accent": Color(0.96, 0.72, 0.40, 1.0), "secondary": Color(0.22, 0.48, 0.50, 1.0), "horizon_color": Color(0.05, 0.22, 0.28, 0.27), "water_edge": 0.78, "park_mark_density": 0.38}, true)
			"parigi_cite":
				profile.merge({"family": "paris", "identity": Color(0.74, 0.68, 0.92, 1.0), "accent": Color(0.92, 0.82, 0.56, 1.0), "secondary": Color(0.34, 0.34, 0.42, 1.0), "horizon_color": Color(0.14, 0.12, 0.20, 0.26), "roof_variation": 0.13}, true)
			"berlin_mitte_3d":
				profile.merge({"family": "berlin", "identity": Color(0.76, 0.84, 0.92, 1.0), "accent": Color(0.96, 0.76, 0.38, 1.0), "secondary": Color(0.30, 0.34, 0.38, 1.0), "horizon_color": Color(0.10, 0.12, 0.15, 0.28), "road_detail": 0.62}, true)
			"tokyo_shibuya":
				profile.merge({"family": "tokyo", "identity": Color(0.28, 0.95, 1.0, 1.0), "accent": Color(1.0, 0.34, 0.95, 1.0), "secondary": Color(0.20, 0.28, 0.48, 1.0), "horizon_color": Color(0.02, 0.16, 0.27, 0.36), "road_detail": 0.95, "window_density": 0.94, "roof_variation": 0.18}, true)
		if style == "ancient":
			profile["canvas_tint"] = Color(0.88, 0.86, 0.78, 1.0)
		elif style == "water_city":
			profile["canvas_tint"] = Color(0.80, 0.90, 0.88, 1.0)
		elif style in ["urban_3d", "dense_3d"]:
			profile["canvas_tint"] = Color(0.80, 0.88, 1.0, 1.0)
	if _is_endless_map_id(_current_map_id):
		var variant: Dictionary = _get_endless_variant(_current_portal_depth)
		var name: String = String(variant.get("name", "")).to_lower()
		var depth_factor: float = clamp(float(_current_portal_depth - ENDLESS_START_DEPTH) / 10.0, 0.0, 1.0)
		profile["family"] = "endless_" + name
		profile["ground_detail_count"] = clampi(96 + int(depth_factor * 32.0), 96, 132)
		profile["rift_density"] = 0.52 + depth_factor * 0.36
		profile["rift_intensity"] = 0.42 + depth_factor * 0.42
		profile["portal_sparks"] = 6 + int(depth_factor * 5.0)
		if name.contains("eclisse"):
			profile.merge({"identity": Color(0.72, 0.36, 1.0, 1.0), "accent": Color(0.40, 0.24, 0.92, 1.0), "secondary": Color(0.12, 0.08, 0.20, 1.0), "mote_color": Color(0.72, 0.36, 1.0, 0.34)}, true)
		elif name.contains("ferale"):
			profile.merge({"identity": Color(0.46, 0.88, 0.34, 1.0), "accent": Color(0.86, 0.58, 0.22, 1.0), "secondary": Color(0.16, 0.32, 0.16, 1.0), "mote_color": Color(0.54, 0.94, 0.38, 0.28)}, true)
		elif name.contains("mirmidone"):
			profile.merge({"identity": Color(0.78, 0.64, 0.30, 1.0), "accent": Color(0.24, 0.82, 0.82, 1.0), "secondary": Color(0.24, 0.22, 0.18, 1.0), "mote_color": Color(0.78, 0.70, 0.42, 0.30)}, true)
		elif name.contains("draconico"):
			profile.merge({"identity": Color(1.0, 0.44, 0.20, 1.0), "accent": Color(1.0, 0.80, 0.26, 1.0), "secondary": Color(0.34, 0.10, 0.06, 1.0), "mote_color": Color(1.0, 0.45, 0.22, 0.30)}, true)
		elif name.contains("guerra"):
			profile.merge({"identity": Color(0.76, 0.18, 0.16, 1.0), "accent": Color(0.72, 0.70, 0.64, 1.0), "secondary": Color(0.18, 0.18, 0.18, 1.0), "mote_color": Color(0.68, 0.54, 0.46, 0.24)}, true)
		var endless_secondary: Color = profile.get("secondary", Color(0.12, 0.08, 0.20, 1.0))
		profile["horizon_color"] = Color(endless_secondary.r, endless_secondary.g, endless_secondary.b, 0.34 + depth_factor * 0.12)
	return profile


func _profile_color(key: String, fallback: Color) -> Color:
	var value: Variant = _get_map_visual_profile().get(key, fallback)
	return value if typeof(value) == TYPE_COLOR else fallback


func _profile_float(key: String, fallback: float) -> float:
	var value: Variant = _get_map_visual_profile().get(key, fallback)
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	return fallback


func _stable_map_noise(key: String, salt: String = "") -> float:
	var h: int = abs(("%s:%s:%s:%d" % [_current_map_id, key, salt, _current_portal_depth]).hash())
	return float(h % 10000) / 10000.0


func _tinted_color(base: Color, tint: Color, amount: float, alpha_override: float = -1.0) -> Color:
	var c := base.lerp(tint, clamp(amount, 0.0, 1.0))
	if alpha_override >= 0.0:
		c.a = alpha_override
	return c

func _is_real_city() -> bool:
	return _current_map.get("real_city", false)

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
		var cinfo: Dictionary = _get_active_class_info()
		var cstats: Dictionary = cinfo.get("base_stats", {})
		var c_hp: int = int(cstats.get("max_hp", 120))
		var c_dmg: int = int(cstats.get("attack_damage", 12))
		var c_spd: float = float(cstats.get("move_speed", 220.0))
		p.set("max_hp", c_hp); p.set("current_hp", c_hp)
		p.set("move_speed", c_spd); p.set("attack_damage", c_dmg)
		p.set("base_hp", c_hp); p.set("base_damage", c_dmg); p.set("base_speed", c_spd)
		p.set("base_defense", 0); p.set("base_agility", 0)
		p.set("defense", 0); p.set("agility", 0)
		if cstats.has("attack_range"):
			p.set("attack_range", float(cstats["attack_range"]))
		if cstats.has("attack_cooldown"):
			p.set("attack_cooldown", float(cstats["attack_cooldown"]))
		p.set("total_xp_earned", 0)
		p.set("ascension_level", 0)
		p.set("ascension_points", 0)
		p.set("highest_portal_depth", 1)
		p.set("season_level", 1)
		p.set("gold", 0)

	_player_node = p
	if _current_portal_depth > int(p.get("highest_portal_depth")):
		p.set("highest_portal_depth", _current_portal_depth)

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
	match _current_physical_map_id:
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
	if _is_endless_map_id(_current_map_id):
		_build_endless_bonus_wave()


func _build_endless_bonus_wave() -> void:
	var variant := _get_endless_variant(_current_portal_depth)
	var enemies: Array = variant.get("enemies", [])
	if enemies.is_empty():
		return
	var wave_count := clampi(3 + int(floor(float(_current_portal_depth - ENDLESS_START_DEPTH) / 4.0)), 3, 8)
	for i in range(wave_count):
		var enemy_type := String(enemies[(i + _current_portal_depth) % enemies.size()])
		var angle := TAU * float(i) / float(wave_count)
		var radius := 11.0 + float((i + _current_portal_depth) % 4) * 6.0
		var tx := clampf(50.0 + cos(angle) * radius, 22.0, 78.0)
		var ty := clampf(50.0 + sin(angle) * radius, 24.0, 80.0)
		_spawn(enemy_type, _iso(tx, ty))
	if _current_portal_depth % 5 == 0:
		_spawn(String(variant.get("champion", enemies[0])), _iso(50, 50))


func _get_endless_depth_for_tier(base_tier: int) -> int:
	var depth_from_map := maxi(base_tier, _current_portal_depth)
	if _is_endless_map_id(_current_map_id):
		return depth_from_map
	if not _player_node:
		return depth_from_map
	var player_level := int(_player_node.get("level"))
	var level_depth := base_tier + int(floor(float(maxi(0, player_level - 1)) / 30.0))
	return maxi(depth_from_map, mini(level_depth, base_tier + 5))


func _get_enemy_scale_for_depth(base_tier: int, depth: int) -> float:
	var extra_depth := maxi(0, depth - base_tier)
	return 1.0 + float(extra_depth) * 0.18


func _get_reward_multiplier_for_depth(base_tier: int, depth: int) -> float:
	var extra_depth := maxi(0, depth - base_tier)
	var multiplier := 1.0 + float(extra_depth) * 0.42
	if _is_endless_map_id(_current_map_id):
		multiplier += float(maxi(0, depth - ENDLESS_START_DEPTH)) * 0.12
		if _player_node:
			var player_level := int(_player_node.get("level"))
			var expected_depth := ENDLESS_START_DEPTH + int(floor(float(maxi(0, player_level - 100)) / 2.0))
			var stale_depth_gap := maxi(0, expected_depth - depth)
			multiplier *= 1.0 + minf(float(stale_depth_gap) * 0.32, 10.0)
	if _new_depth_bonus_active:
		multiplier *= 1.35
	if _map_reload_streak > 0:
		multiplier *= maxf(0.35, 1.0 - float(_map_reload_streak) * 0.25)
	return multiplier


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
	var reward_multiplier := _get_reward_multiplier_for_depth(base_tier, endless_depth)
	var scaled_hp := maxi(1, int(round(float(c["hp"]) * enemy_scale)))
	var scaled_damage := maxi(1, int(round(float(c["dmg"]) * (0.75 + enemy_scale * 0.25))))
	var scaled_xp := maxi(1, int(round(float(c["xp"]) * (0.90 + enemy_scale * 0.35) * reward_multiplier)))
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

	var depth_label := Label.new(); depth_label.name = "PortalDepthLabel"
	depth_label.text = "Profondita Portale %d" % _current_portal_depth
	depth_label.add_theme_color_override("font_color", Color(0.78, 0.66, 1.0))
	depth_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.70))
	depth_label.add_theme_constant_override("outline_size", 2)
	depth_label.add_theme_font_size_override("font_size", 11)
	vb.add_child(depth_label)

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
	
	mml.text = "Nemici: %d | Oro: %d | Prof. %d" % [enemy_count, _player_node.gold if _player_node else 0, _current_portal_depth]


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
