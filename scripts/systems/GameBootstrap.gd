extends Node2D

## Valdoria — Multi-Map ARPG (Solo Leveling Dungeon Gates)
## 12 FLARE grassland maps, CC-BY-SA 3.0

const MAP_REGISTRY: GDScript = preload("res://data/MapRegistry.gd")
const ItemDataClass: GDScript = preload("res://scripts/items/ItemData.gd")

var _current_map_id: String = "black_oak_farm"
var _current_map: Dictionary = {}
var _portals: Array = []  # [{pos, target, label, sprite}]
var _player_node: CharacterBody2D = null
var _cam: Camera2D = null
var _world_node: Node2D = null

func _ready() -> void:
	print("=== VALDORIA — Multi-World ===")
	
	# Try to load save
	var sm := get_node_or_null("/root/SaveManager")
	if sm and sm.has_save():
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


func _apply_loaded_data(data: Dictionary) -> void:
	if not _player_node: return
	_player_node.set("level", data.get("level", 1))
	_player_node.set("xp", data.get("xp", 0))
	_player_node.set("xp_to_next_level", data.get("xp_to_next", 30))
	_player_node.set("base_hp", data.get("base_hp", 100))
	_player_node.set("base_damage", data.get("base_damage", 10))
	_player_node.set("base_speed", data.get("base_speed", 200.0))
	_player_node.set("max_hp", data.get("max_hp", 100))
	_player_node.set("current_hp", max(data.get("current_hp", 100), 1))
	_player_node.set("attack_damage", data.get("attack_damage", 10))
	_player_node.set("move_speed", data.get("move_speed", 200.0))
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
			"dmg": def.dmg, "hp": def.hp, "spd": def.spd,
		})
		_player_node.equipment[slot] = item
	_player_node._recalc_equip_stats()
	
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
				"dmg": def.get("dmg",0), "hp": def.get("hp",0), "spd": def.get("spd",0),
			})
			inv.add_item(item)


func _load_tex(path: String) -> Texture2D:
	var tex: Texture2D = load(path) as Texture2D
	if tex:
		return tex
	# Fallback: load via Image for files not yet imported
	var img := Image.load_from_file(path)
	if img:
		return ImageTexture.create_from_image(img)
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
	_build_player()
	_build_enemies()
	_build_portals()
	_build_ui()
	_connect_input()

	if has_node("GameUI") and $GameUI.has_method("show_debug_message"):
		$GameUI.show_debug_message("[%s] %s" % [_current_map.title, _current_map.desc])


func _clear_world() -> void:
	for child in get_children():
		if child.name not in ["InputController"]:
			child.queue_free()
	_clear_tweens()
	_portals.clear()
	_world_node = null
	await get_tree().process_frame


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
			var bg_gid = bg_row[x]
			if bg_gid > 0:
				var p = _tile_params(bg_gid)
				if p.tex == null: continue
				var pos = _iso(x, y)
				var z = -20 if p.type != "water" else -19
				_add_sprite(_world_node, p.tex, p.region, Vector2(pos.x + p.ox, pos.y + p.oy), z, Vector2.ONE)
			else:
				var pos = _iso(x, y)
				_add_sprite(_world_node, default_grass_tex, default_grass_rect, pos, -20, Vector2.ONE)

			var obj_gid = obj_row[x]
			if obj_gid > 0:
				var p = _tile_params(obj_gid)
				if p.tex == null: continue
				var pos = _iso(x, y)
				var z = (x + y) * 12
				_add_sprite(_world_node, p.tex, p.region, Vector2(pos.x + p.ox, pos.y + p.oy), z, Vector2.ONE)


# ===== PLAYER =====

func _build_player() -> void:
	var p := CharacterBody2D.new(); p.name = "Player"
	var spawn: Vector2 = _current_map.get("hero_spawn", Vector2(50, 50)) as Vector2
	p.position = _iso(spawn.x, spawn.y); p.collision_layer = 2
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
		p.set("base_hp", _player_node.get("base_hp"))
		p.set("base_damage", _player_node.get("base_damage"))
		p.set("base_speed", _player_node.get("base_speed"))
	else:
		p.set("max_hp", 120); p.set("current_hp", 120)
		p.set("move_speed", 220.0); p.set("attack_damage", 12)

	_player_node = p

	var cs := CollisionShape2D.new(); cs.name = "CollisionShape2D"
	var c := CircleShape2D.new(); c.radius = 24.0; cs.shape = c; p.add_child(cs)

	var sh := Sprite2D.new(); sh.name = "Shadow"
	sh.texture = _load_tex("res://assets/placeholders/shadow.png")
	sh.position = Vector2(0, 38); sh.z_index = -1; sh.scale = Vector2(1.5, 1.5); p.add_child(sh)

	var sp := Sprite2D.new(); sp.name = "Sprite2D"
	sp.texture = _load_tex("res://assets/flare/characters/hero/hero_full.png")
	sp.position = Vector2(0, -42); sp.scale = Vector2(1.5, 1.5); p.add_child(sp)

	var aa := Area2D.new(); aa.name = "AttackArea"; p.add_child(aa)
	var ac := CollisionShape2D.new(); ac.name = "CollisionShape2D"
	var ac2 := CircleShape2D.new(); ac2.radius = 64.0; ac.shape = ac2; aa.add_child(ac)

	add_child(p)

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
		"xp":35,"loot":"Frammento antico","rarity":"rare","tier":3},
	"wyvern_a":{"name":"Viverna Alata","tex":"res://assets/flare/characters/wyvern_air_grid.png",
		"hp":120,"spd":120,"dmg":20,"cd":1.5,"det":400,"atk":60,"sc":2.0,"cr":32,
		"xp":50,"loot":"Frammento celestiale","rarity":"rare","tier":3},
	"dragon":  {"name":"Drago Antico","tex":"res://assets/flare/characters/wyvern_air_grid.png",
		"hp":400,"spd":70,"dmg":45,"cd":2.5,"det":500,"atk":80,"sc":2.5,"cr":48,
		"xp":200,"loot":"Scaglia di Drago","rarity":"legendary","tier":5},
	"dragon_b":{"name":"Drago Supremo","tex":"res://assets/flare/characters/wyvern_grid.png",
		"hp":250,"spd":100,"dmg":35,"cd":2.0,"det":450,"atk":70,"sc":2.2,"cr":42,
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
			_spawn("mage",_iso(50,30)); _spawn("mage",_iso(55,35))
			_spawn("dragon",_iso(60,40))
			_spawn("minotaur",_iso(40,60))

		"dilapidated_sewers":
			_spawn("zombie",_iso(20,20)); _spawn("zombie",_iso(25,25)); _spawn("zombie",_iso(18,28))
			_spawn("zombie",_iso(30,20)); _spawn("zombie",_iso(22,30))
			_spawn("lich",_iso(50,40))
			_spawn("werewolf",_iso(40,50)); _spawn("werewolf_a",_iso(60,30))
			_spawn("dragon_b",_iso(70,50))

		"stormrock_ruins":
			_spawn("skeleton_a",_iso(30,35)); _spawn("skeleton_a",_iso(35,30))
			_spawn("lich",_iso(50,40)); _spawn("lich",_iso(55,50))
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
			_spawn("liche",_iso(45,40))
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
			_spawn("lich",_iso(25,20))

		# Connect some grassland portals to dungeons
		# Already handled via MapRegistry


func _spawn(type: String, pos: Vector2) -> void:
	var c: Dictionary = _enemy_types[type]
	var e := CharacterBody2D.new(); e.name = c["name"]; e.position = pos; e.collision_layer = 3
	e.set_script(load("res://scripts/enemies/Enemy.gd"))
	e.set("enemy_id",type); e.set("enemy_name",c["name"])
	e.set("max_hp",c["hp"]); e.set("current_hp",c["hp"])
	e.set("move_speed",c["spd"]); e.set("attack_damage",c["dmg"])
	e.set("attack_cooldown",c["cd"]); e.set("detection_radius",c["det"]); e.set("attack_range",c["atk"])
	e.set("xp_value",c["xp"])

	# Generate loot table based on enemy tier
	var tier: int = c.get("tier", 1)
	var loot: Array = ItemDataClass.generate_random_loot(tier) as Array
	e.set("loot_table", loot)

	var cs := CollisionShape2D.new(); cs.name = "CollisionShape2D"
	var cc := CircleShape2D.new(); cc.radius = c["cr"]; cs.shape = cc; e.add_child(cs)

	var sh := Sprite2D.new(); sh.name = "Shadow"
	sh.texture = _load_tex("res://assets/placeholders/shadow.png")
	sh.position = Vector2(0, 38); sh.z_index = -1; sh.scale = Vector2(c["sc"],c["sc"]); e.add_child(sh)

	var sp := Sprite2D.new(); sp.name = "Sprite2D"
	sp.texture = _load_tex(c["tex"]); sp.position = Vector2(0, -40)
	sp.scale = Vector2(c["sc"],c["sc"]); sp.region_enabled = true
	sp.region_rect = Rect2(0, 0, 128, 128); e.add_child(sp)

	# Themed sprite colors
	if type in ["mage", "skeleton_a"]:
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

	var da := Area2D.new(); da.name = "DetectionArea"; da.collision_mask = 2; e.add_child(da)
	var dc := CollisionShape2D.new(); dc.name = "CollisionShape2D"
	var dc2 := CircleShape2D.new(); dc2.radius = c["det"]; dc.shape = dc2; da.add_child(dc)

	if e.has_signal("enemy_killed"):
		e.enemy_killed.connect(_on_enemy_killed)
	if e.has_signal("drop_item"):
		e.drop_item.connect(_on_drop.bind(e))

	# Health bar
	var hb := ProgressBar.new()
	hb.name = "HealthBar"
	hb.min_value = 0.0; hb.max_value = c["hp"]; hb.value = c["hp"]
	hb.custom_minimum_size = Vector2(40, 6)
	hb.show_percentage = false
	hb.position = Vector2(-20, -50)
	var bg := StyleBoxFlat.new(); bg.bg_color = Color(0.1, 0.05, 0.05, 0.8)
	bg.border_width_left = 1; bg.border_width_right = 1; bg.border_width_top = 1; bg.border_width_bottom = 1
	bg.border_color = Color(0.3, 0.1, 0.1)
	hb.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	if type in ["dragon", "dragon_b", "minotaur"]:
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


func _on_enemy_killed(xp_val: int, enemy_name: String) -> void:
	if _player_node and _player_node.has_method("gain_xp"):
		_player_node.gain_xp(xp_val)
	
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
	gl.z_index = 9999
	add_child(gl)
	var tw := create_tween()
	tw.tween_property(gl, "position:y", gl.position.y - 50, 1.5)
	tw.parallel().tween_property(gl, "modulate:a", 0.0, 1.5)
	tw.tween_callback(gl.queue_free)
	
	if has_node("GameUI") and $GameUI.has_method("show_debug_message"):
		$GameUI.show_debug_message("+%d XP +%d ORO — %s ucciso!" % [xp_val, gold_amount, enemy_name])


# ===== PORTALS (Solo Leveling Gates) =====

func _build_portals() -> void:
	var portal_list: Array = _current_map.get("portals", [])
	for pdata in portal_list:
		var pos := _iso(pdata.pos.x, pdata.pos.y)
		var target: String = pdata.target
		var label: String = pdata.get("label", "???")

		var portal := Node2D.new(); portal.name = "Gate_" + target; portal.position = pos

		# Glowing outer ring
		var outer := ColorRect.new()
		outer.size = Vector2(80, 80); outer.position = Vector2(-40, -40)
		outer.color = Color(0.3, 0.5, 1.0, 0.3); outer.pivot_offset = Vector2(40, 40)
		portal.add_child(outer)

		# Inner ring
		var inner := ColorRect.new()
		inner.size = Vector2(50, 50); inner.position = Vector2(-25, -25)
		inner.color = Color(0.3, 0.6, 1.0, 0.8); inner.pivot_offset = Vector2(25, 25)
		portal.add_child(inner)

		# Label
		var lb := Label.new(); lb.name = "Label"
		lb.text = "[PORTALE]\n" + label
		lb.position = Vector2(-50, -70)
		lb.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
		lb.add_theme_font_size_override("font_size", 11)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		portal.add_child(lb)

		# Clickable area that also auto-teleports on proximity
		var area := Area2D.new(); area.name = "PortalArea"
		area.collision_mask = 2  # detect player layer
		var ac := CollisionShape2D.new(); ac.name = "CollisionShape2D"
		var ac2 := CircleShape2D.new(); ac2.radius = 80.0; ac.shape = ac2
		area.add_child(ac)
		area.body_entered.connect(_on_portal_proximity.bind(target))
		area.input_event.connect(_on_portal_clicked.bind(target))
		portal.add_child(area)

		_portals.append({"node": portal, "target": target, "pos": portal.position})
		add_child(portal)

		# Pulses
		var tw := create_tween(); tw.set_loops()
		tw.tween_property(outer, "scale", Vector2(1.3, 1.3), 1.0).set_trans(Tween.TRANS_SINE)
		tw.tween_property(outer, "scale", Vector2(0.7, 0.7), 1.0).set_trans(Tween.TRANS_SINE)

		var tw2 := create_tween(); tw2.set_loops()
		tw2.tween_property(outer, "rotation", TAU, 5.0)
		tw2.tween_property(outer, "rotation", 0.0, 0.0)


func _on_portal_proximity(body: Node2D, target: String) -> void:
	if body == _player_node:
		print("Portal proximity: " + target)
		if has_node("GameUI") and $GameUI.has_method("show_debug_message"):
			$GameUI.show_debug_message("Teletrasporto a %s..." % target)
		await get_tree().create_timer(0.3).timeout
		_load_map(target)


func _on_portal_clicked(event: InputEvent, _pos: Vector2, _mouse: int, _shape: int, target: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
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
	sp.texture = icon_tex; sp.scale = Vector2(3.0, 3.0)
	if item_data.has("rarity"):
		var rcols := {"common":Color.WHITE,"uncommon":Color(0.3,1.0,0.3),"rare":Color(0.3,0.5,1.0),"epic":Color(0.8,0.2,1.0),"legendary":Color(1.0,0.7,0.2)}
		sp.modulate = rcols.get(item_data.rarity, Color.WHITE)
	d.add_child(sp)

	var lb := Label.new(); lb.name = "Label"
	lb.position = Vector2(-60, -40); lb.scale = Vector2(0.7, 0.7)
	lb.add_theme_font_size_override("font_size", 11); lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.text = item_data.name if item_data.name else "???"
	d.add_child(lb)
	d.set_script(load("res://scripts/items/DroppedItem.gd"))
	d.set("item_data", item_data)
	
	var dropped_items := get_node_or_null("DroppedItems")
	if dropped_items:
		dropped_items.add_child(d)


# ===== UI =====

func _build_ui() -> void:
	var ui := CanvasLayer.new(); ui.name = "GameUI"
	ui.set_script(load("res://scripts/ui/GameUI.gd"))
	ui.set("player", _player_node)
	add_child(ui)

	var mtl := MarginContainer.new(); mtl.name = "MarginContainer"
	mtl.offset_right = 340.0; mtl.offset_bottom = 130.0
	mtl.add_theme_constant_override("margin_left", 16); mtl.add_theme_constant_override("margin_top", 16)
	ui.add_child(mtl)
	var vb := VBoxContainer.new(); vb.name = "VBoxContainer"; mtl.add_child(vb)

	# Map title
	var tl := Label.new(); tl.name = "TitleLabel"
	tl.text = _current_map.title.to_upper()
	tl.add_theme_color_override("font_color", Color(0.85,0.78,0.55)); tl.add_theme_font_size_override("font_size", 14)
	vb.add_child(tl)

	# Level display
	var lvl := Label.new(); lvl.name = "LevelLabel"
	lvl.text = "Liv. %d" % (_player_node.get("level") if _player_node else 1)
	lvl.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	lvl.add_theme_font_size_override("font_size", 13)
	vb.add_child(lvl)

	# Player health bar
	var phb := ProgressBar.new(); phb.name = "HealthBar"
	phb.min_value = 0.0; phb.max_value = _player_node.get("max_hp") if _player_node else 120.0
	phb.value = _player_node.get("current_hp") if _player_node else 120.0
	phb.custom_minimum_size = Vector2(280, 24); phb.show_percentage = false
	var sbg := StyleBoxFlat.new(); sbg.bg_color = Color(0.1, 0.05, 0.05, 0.9)
	sbg.border_width_left = 1; sbg.border_width_right = 1; sbg.border_width_top = 1; sbg.border_width_bottom = 1
	sbg.border_color = Color(0.4, 0.15, 0.1)
	phb.add_theme_stylebox_override("background", sbg)
	var sfill := StyleBoxFlat.new(); sfill.bg_color = Color(0.9, 0.15, 0.15)
	phb.add_theme_stylebox_override("fill", sfill)
	vb.add_child(phb)

	var hl := Label.new(); hl.name = "HealthLabel"
	hl.text = "%d / %d" % [phb.value, phb.max_value]
	hl.add_theme_color_override("font_color", Color(1,0.3,0.3)); hl.add_theme_font_size_override("font_size", 12)
	vb.add_child(hl)

	# XP bar (Solo Leveling style)
	var xpb := ProgressBar.new(); xpb.name = "XPBar"
	xpb.min_value = 0.0
	xpb.max_value = _player_node.get("xp_to_next_level") if _player_node else 30
	xpb.value = _player_node.get("xp") if _player_node else 0
	xpb.custom_minimum_size = Vector2(280, 12); xpb.show_percentage = false
	var xbg := StyleBoxFlat.new(); xbg.bg_color = Color(0.02, 0.05, 0.15, 0.9)
	xbg.border_width_left = 1; xbg.border_width_right = 1; xbg.border_width_top = 1; xbg.border_width_bottom = 1
	xbg.border_color = Color(0.1, 0.25, 0.5)
	xpb.add_theme_stylebox_override("background", xbg)
	var xfill := StyleBoxFlat.new(); xfill.bg_color = Color(0.2, 0.6, 1.0)  # blue XP bar
	xpb.add_theme_stylebox_override("fill", xfill)
	vb.add_child(xpb)

	var xl := Label.new(); xl.name = "XPLabel"
	xl.text = "XP %d / %d" % [xpb.value, xpb.max_value]
	xl.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0)); xl.add_theme_font_size_override("font_size", 10)
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
	gl.add_theme_font_size_override("font_size", 13)
	goldbox.add_child(gl)
	if _player_node and _player_node.has_signal("gold_changed"):
		_player_node.gold_changed.connect(func(g: int): gl.text = "Oro: %d" % g)
	hbx.add_child(goldbox)

	var invb := Button.new(); invb.name = "InventoryButton"; invb.text = "Zaino (I)"
	invb.custom_minimum_size = Vector2(110, 50); hbx.add_child(invb)

	var atkb := Button.new(); atkb.name = "AttackButton"; atkb.text = "Attacca"
	atkb.custom_minimum_size = Vector2(100, 50); hbx.add_child(atkb)

	# Map switch button
	var mapb := Button.new(); mapb.name = "MapButton"; mapb.text = "Mappe"
	mapb.custom_minimum_size = Vector2(70, 50); hbx.add_child(mapb)
	mapb.pressed.connect(_show_map_menu.bind(ui))

	# Save/Load buttons
	var svb := Button.new(); svb.name = "SaveButton"; svb.text = "S"
	svb.custom_minimum_size = Vector2(40, 50)
	svb.pressed.connect(_save_current_game)
	hbx.add_child(svb)
	var ldb := Button.new(); ldb.name = "LoadButton"; ldb.text = "L"
	ldb.custom_minimum_size = Vector2(40, 50)
	ldb.pressed.connect(_load_saved_game)
	hbx.add_child(ldb)

	# Minimap (top-right corner)
	var minimap := Control.new(); minimap.name = "Minimap"
	minimap.anchor_left = 1.0; minimap.anchor_top = 0.0
	minimap.anchor_right = 1.0; minimap.anchor_bottom = 0.0
	minimap.offset_left = -170.0; minimap.offset_top = 10.0
	minimap.offset_right = -10.0; minimap.offset_bottom = 170.0
	ui.add_child(minimap)

	var mmbg := ColorRect.new(); mmbg.name = "MMBg"
	mmbg.anchor_right = 1.0; mmbg.anchor_bottom = 1.0
	mmbg.color = Color(0.02, 0.05, 0.12, 0.85)
	minimap.add_child(mmbg)

	var mml := Label.new(); mml.name = "MMLabel"
	mml.anchor_top = 1.0; mml.anchor_bottom = 1.0
	mml.offset_top = -16.0; mml.add_theme_font_size_override("font_size", 10)
	mml.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	mml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	minimap.add_child(mml)

	# Inventory panel (enhanced with equipment + gold)
	var pnl := Panel.new(); pnl.name = "InventoryPanel"
	pnl.anchor_left = 0.15; pnl.anchor_top = 0.1; pnl.anchor_right = 0.85; pnl.anchor_bottom = 0.9
	pnl.visible = false
	var ps := StyleBoxFlat.new(); ps.bg_color = Color(0.06,0.06,0.1,0.95)
	ps.border_width_left = 2; ps.border_width_right = 2; ps.border_width_top = 2; ps.border_width_bottom = 2
	ps.border_color = Color(0.45,0.38,0.25)
	pnl.add_theme_stylebox_override("panel", ps); ui.add_child(pnl)

	var panel_hb := HBoxContainer.new(); panel_hb.name = "PanelHBox"
	panel_hb.anchor_left = 0.03; panel_hb.anchor_top = 0.03; panel_hb.anchor_right = 0.97; panel_hb.anchor_bottom = 0.97
	pnl.add_child(panel_hb)

	# LEFT: Equipment
	var eqcol := VBoxContainer.new(); eqcol.name = "EquipCol"; eqcol.custom_minimum_size = Vector2(220, 0)
	panel_hb.add_child(eqcol)

	var eqtl := Label.new(); eqtl.text = "EQUIPAGGIAMENTO"; eqtl.add_theme_color_override("font_color",Color(0.85,0.78,0.55)); eqtl.add_theme_font_size_override("font_size",16); eqcol.add_child(eqtl)

	# Gold
	var gol := Label.new(); gol.name = "GoldLabel"; gol.text = "Oro: 0"; gol.add_theme_color_override("font_color",Color(1.0,0.85,0.2)); gol.add_theme_font_size_override("font_size",14); eqcol.add_child(gol)

	eqcol.add_child(HSeparator.new())

	# Equipment slots
	var slots := {"weapon":"Arma","armor":"Armatura","helmet":"Elmo","boots":"Stivali","ring":"Anello"}
	for sl in ["weapon","armor","helmet","boots","ring"]:
		var srow := HBoxContainer.new()
		var slbl := Label.new(); slbl.text = "[" + slots[sl] + "] "; slbl.add_theme_font_size_override("font_size",13); slbl.custom_minimum_size = Vector2(85,0); srow.add_child(slbl)
		var sqt := Label.new(); sqt.name = "Slot_" + sl; sqt.text = "— vuoto —"; sqt.add_theme_color_override("font_color",Color(0.5,0.5,0.5)); sqt.add_theme_font_size_override("font_size",12); sqt.size_flags_horizontal = Control.SIZE_EXPAND_FILL; srow.add_child(sqt)
		var ubtn := Button.new(); ubtn.name = "UnEquip_" + sl; ubtn.text = "X"; ubtn.custom_minimum_size = Vector2(28,24); ubtn.visible = false; srow.add_child(ubtn)
		eqcol.add_child(srow)

	eqcol.add_child(HSeparator.new())

	# Stats summary
	var stl := Label.new(); stl.name = "StatsLabel"; stl.text = "DAN: 10 | HP: 100 | VEL: 200"; stl.add_theme_color_override("font_color",Color(0.6,0.9,0.6)); stl.add_theme_font_size_override("font_size",11); eqcol.add_child(stl)

	# VSeparator
	phb.add_child(VSeparator.new())

	# RIGHT: Inventory list
	var invcol := VBoxContainer.new(); invcol.name = "InvCol"; invcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_hb.add_child(invcol)

	var invhdr := HBoxContainer.new()
	var itl := Label.new(); itl.text = "ZAINO"; itl.add_theme_color_override("font_color",Color(0.85,0.78,0.55)); itl.add_theme_font_size_override("font_size",16); invhdr.add_child(itl)
	var spcr := Control.new(); spcr.size_flags_horizontal = Control.SIZE_EXPAND_FILL; invhdr.add_child(spcr)
	var cb := Button.new(); cb.name = "CloseButton"; cb.text = "Chiudi"; cb.custom_minimum_size = Vector2(70,30); invhdr.add_child(cb)
	invcol.add_child(invhdr)

	var sc := ScrollContainer.new(); sc.name = "ScrollContainer"; sc.size_flags_vertical = Control.SIZE_EXPAND_FILL; invcol.add_child(sc)
	var il := VBoxContainer.new(); il.name = "InventoryList"; il.add_theme_constant_override("separation",3); sc.add_child(il)

	# Connect inventory refresh
	var inventory := get_node_or_null("/root/Inventory")
	if inventory:
		if inventory.inventory_changed.is_connected(_refresh_inventory_ui):
			inventory.inventory_changed.disconnect(_refresh_inventory_ui)
		inventory.inventory_changed.connect(_refresh_inventory_ui.bind(ui))
	if _player_node:
		if _player_node.has_signal("gold_changed"):
			_player_node.gold_changed.connect(func(g: int): _refresh_inventory_ui(ui))
		if _player_node.has_signal("equipment_changed"):
			_player_node.equipment_changed.connect(func(_s, _i): _refresh_inventory_ui(ui))
		if _player_node.has_signal("health_changed"):
			_player_node.health_changed.connect(func(_c,_m): _refresh_inventory_ui(ui))

	var dbg := Label.new(); dbg.name = "DebugLabel"
	dbg.anchor_left = 0.0; dbg.anchor_bottom = 1.0
	dbg.offset_left = 16.0; dbg.offset_bottom = -100.0
	dbg.modulate = Color.YELLOW; dbg.visible = false; ui.add_child(dbg)


func _refresh_inventory_ui(ui: CanvasLayer) -> void:
	var pnl := ui.get_node_or_null("InventoryPanel")
	if not pnl or not pnl.visible:
		return

	var gol := pnl.get_node_or_null("PanelHBox/EquipCol/GoldLabel") as Label
	if gol and _player_node:
		gol.text = "Oro: %d" % _player_node.gold

	# Equipment slots
	for sl in ["weapon","armor","helmet","boots","ring"]:
		var sqt := pnl.get_node_or_null("PanelHBox/EquipCol/Slot_%s" % sl) as Label
		var ubtn := pnl.get_node_or_null("PanelHBox/EquipCol/UnEquip_%s" % sl) as Button
		if not sqt: continue
		var item = _player_node.equipment.get(sl) if _player_node else null
		if item:
			sqt.text = item.name
			var rcols := {"common":Color(0.7,0.7,0.7),"uncommon":Color(0.3,0.8,0.3),"rare":Color(0.3,0.4,0.9),"epic":Color(0.7,0.2,0.9),"legendary":Color(0.9,0.6,0.1)}
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
		stl.text = "DAN:%d | HP:%d | VEL:%d | Liv.%d" % [_player_node.attack_damage,_player_node.max_hp,int(_player_node.move_speed),_player_node.level]

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
		if item.has("rarity"):
			var rcols := {"common":Color(0.7,0.7,0.7),"uncommon":Color(0.3,0.8,0.3),"rare":Color(0.3,0.4,0.9),"epic":Color(0.7,0.2,0.9),"legendary":Color(0.9,0.6,0.1)}
			nl.add_theme_color_override("font_color", rcols.get(item.rarity, Color.WHITE))
		row.add_child(nl)

		var vl := Label.new(); vl.text = "%d oro" % item.value; vl.add_theme_font_size_override("font_size",10); vl.custom_minimum_size = Vector2(55,0); row.add_child(vl)

		if item.has("slot") and not item.slot.is_empty():
			var ebtn := Button.new(); ebtn.text = "EQU"; ebtn.custom_minimum_size = Vector2(40,24)
			ebtn.pressed.connect(func():
				if _player_node:
					var old = _player_node.equipment.get(item.slot)
					if old:
						inventory.add_item(old)
					inventory.remove_item(item)
					_player_node.equip_item(item.slot, item)
			)
			row.add_child(ebtn)

		il.add_child(row)


func _show_map_menu(ui: CanvasLayer) -> void:
	var pnl := Panel.new(); pnl.name = "MapMenuPanel"
	pnl.anchor_left = 0.15; pnl.anchor_top = 0.15
	pnl.anchor_right = 0.85; pnl.anchor_bottom = 0.85
	var ps := StyleBoxFlat.new(); ps.bg_color = Color(0.04,0.04,0.08,0.97)
	ps.border_width_left = 2; ps.border_width_right = 2
	ps.border_width_top = 2; ps.border_width_bottom = 2
	ps.border_color = Color(0.3,0.5,1.0)
	pnl.add_theme_stylebox_override("panel", ps); ui.add_child(pnl)

	var vbc := VBoxContainer.new()
	vbc.anchor_left = 0.05; vbc.anchor_top = 0.05
	vbc.anchor_right = 0.95; vbc.anchor_bottom = 0.95
	pnl.add_child(vbc)

	var tl := Label.new(); tl.text = "GATES — Seleziona Destinazione"
	tl.add_theme_color_override("font_color", Color(0.5,0.8,1.0))
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
	cb.pressed.connect(pnl.queue_free)
	vbc.add_child(cb)


# ===== INPUT =====

func _connect_input() -> void:
	var di := get_node_or_null("DroppedItems")
	if not di:
		di = Node2D.new(); di.name = "DroppedItems"; add_child(di)
	var ic := get_node_or_null("/root/InputController")
	if ic:
		if ic.move_command.is_connected(_on_player_move):
			ic.move_command.disconnect(_on_player_move)
		ic.move_command.connect(_on_player_move)
		if _player_node and _player_node.has_method("_on_attack_command"):
			if ic.attack_command.is_connected(_player_node._on_attack_command):
				ic.attack_command.disconnect(_player_node._on_attack_command)
			ic.attack_command.connect(_player_node._on_attack_command)
		if has_node("GameUI") and $GameUI.has_method("_toggle_inventory"):
			if ic.toggle_inventory.is_connected($GameUI._toggle_inventory):
				ic.toggle_inventory.disconnect($GameUI._toggle_inventory)
			ic.toggle_inventory.connect($GameUI._toggle_inventory)


func _on_player_move(world_pos: Vector2) -> void:
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


func _save_current_game() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm and _player_node:
		sm.save_game(_player_node, _current_map_id)
		if has_node("GameUI") and $GameUI.has_method("show_debug_message"):
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


func _process(_delta: float) -> void:
	_update_minimap()
