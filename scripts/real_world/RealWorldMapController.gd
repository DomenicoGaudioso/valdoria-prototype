# RealWorldMapController.gd — Controller principale per mappe reali OSM
# =============================================================================
# Associato a RealWorldMapBase.tscn. Gestisce:
#   - Caricamento modello .glb
#   - Applicazione scala/rotazione via RealWorldMapAdapter
#   - Posizionamento player (CharacterBody2D isometrico in spazio 3D)
#   - Spawn nemici
#   - Portali di ritorno e viaggio tra mappe reali
#   - Camera isometrica fissa (stile Valdoria)
#   - Attribuzione OSM

extends Node3D

const RealWorldMapRegistry = preload("res://data/RealWorldMapRegistry.gd")
const RealWorldMapAdapterClass = preload("res://scripts/real_world/RealWorldMapAdapter.gd")
const RealWorldAttributionClass = preload("res://scripts/real_world/RealWorldAttribution.gd")

@export var map_id: String = ""
@export var player_scene_3d: PackedScene       # Player3D.tscn con CharacterBody3D
@export var enemy_types: Dictionary = {}        # Popolato da GameBootstrap._enemy_types

var _map_data: Dictionary = {}
var _player: CharacterBody3D = null
var _camera: Camera3D = null
var _model_instance: Node3D = null
var _adapter: RealWorldMapAdapter = null
var _attribution: Control = null
var _spawned_enemies: Array[CharacterBody3D] = []

# Segnali
signal map_ready()
signal portal_activated(target_map_id: String, is_real_world: bool)
signal return_to_classic_requested()


func _ready() -> void:
	_setup_scene()
	_load_map()
	map_ready.emit()


func _setup_scene() -> void:
	# Camera isometrica fissa (stile Valdoria, ma in 3D)
	_camera = Camera3D.new()
	_camera.name = "IsometricCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 18.0
	_camera.position = Vector3(0, 16, 8)
	_camera.rotation_degrees = Vector3(-55, 0, 0)
	_camera.current = true
	add_child(_camera)


func _load_map() -> void:
	_map_data = RealWorldMapRegistry.get_map(map_id)
	if _map_data.is_empty():
		push_error("RealWorldMapController: mappa '%s' non trovata." % map_id)
		return

	print("RealWorldMapController: caricamento %s..." % _map_data.display_name)

	# Carica modello .glb
	var model_path: String = _map_data.get("model_path", "")
	if model_path.is_empty() or not FileAccess.file_exists(model_path):
		_show_placeholder_map()
	else:
		_load_glb_model(model_path)

	# Player spawn
	_spawn_player()

	# Nemici
	_spawn_enemies()

	# Portali
	_build_portals()

	# Attribuzione
	_add_attribution()

	print("RealWorldMapController: %s pronta." % _map_data.display_name)


func _load_glb_model(path: String) -> void:
	var model_scene: PackedScene = load(path) as PackedScene
	if not model_scene:
		push_warning("RealWorldMapController: impossibile caricare %s" % path)
		_show_placeholder_map()
		return

	_model_instance = model_scene.instantiate()
	_model_instance.name = "ImportedCityModel"

	var world_root := _get_or_create_node("WorldRoot")
	world_root.add_child(_model_instance)

	# Adatta il modello allo stile Valdoria
	_adapter = RealWorldMapAdapterClass.new()
	_adapter.name = "MapAdapter"
	_adapter.model_root = _model_instance
	_adapter.import_scale = _map_data.get("scale", 0.08)
	_adapter.yaw_degrees = _map_data.get("rotation_y", -35.0)
	add_child(_adapter)
	_adapter.adapt_model()


func _show_placeholder_map() -> void:
	# Placeholder visivo finché il .glb non viene importato
	var world_root := _get_or_create_node("WorldRoot")

	# Piano del terreno
	var ground := MeshInstance3D.new()
	ground.name = "PlaceholderGround"
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(30, 30)
	ground.mesh = ground_mesh
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.2, 0.18, 0.15)
	ground.material_override = ground_mat
	world_root.add_child(ground)

	# Griglia isometrica
	for i in range(-14, 15, 2):
		for j in range(-14, 15, 2):
			var cube := MeshInstance3D.new()
			cube.name = "PlaceholderBlock_%d_%d" % [i, j]
			var box := BoxMesh.new()
			box.size = Vector3(1.5, 1.0 + abs(i * 0.05) + abs(j * 0.05), 1.5)
			cube.mesh = box
			cube.position = Vector3(i * 1.8, box.size.y * 0.5, j * 1.8)
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.22, 0.20, 0.18).lerp(
				Color(0.35, 0.28, 0.22), float((i + j + 28) % 3) / 3.0
			)
			cube.material_override = mat
			world_root.add_child(cube)

			# Collisione semplificata
			var body := StaticBody3D.new()
			var shape := CollisionShape3D.new()
			shape.shape = BoxShape3D.new()
			shape.shape.size = box.size
			shape.position = cube.position
			body.add_child(shape)
			body.name = "Col_%d_%d" % [i, j]
			_get_or_create_node("CollisionRoot").add_child(body)

	# Etichetta placeholder
	var label_3d := Label3D.new()
	label_3d.name = "PlaceholderLabel"
	label_3d.text = "%s\n[GLB NON IMPORTATO]\nSegui pipeline OSM2World" % _map_data.display_name
	label_3d.position = Vector3(0, 8, 0)
	label_3d.font_size = 36
	label_3d.modulate = Color(0.9, 0.7, 0.3)
	world_root.add_child(label_3d)

	push_warning("RealWorldMapController: placeholder visuale per %s (modello .glb non trovato)" % _map_data.display_name)


func _spawn_player() -> void:
	if not player_scene_3d:
		push_warning("RealWorldMapController: player_scene_3d non assegnato. Creazione CharacterBody3D base.")
		_player = CharacterBody3D.new()
		_player.name = "Player"
		var col := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.height = 2.0; cap.radius = 0.4
		col.shape = cap
		_player.add_child(col)
		add_child(_player)
	else:
		_player = player_scene_3d.instantiate()
		_player.name = "Player"
		add_child(_player)

	var spawn: Vector3 = _map_data.get("player_spawn", Vector3(0, 2, 5))
	_player.position = spawn


func _spawn_enemies() -> void:
	var enemy_spawns: Array = _map_data.get("enemy_spawns", [])
	var enemy_root := _get_or_create_node("EnemySpawnRoot")

	for spawn_def in enemy_spawns:
		var type: String = spawn_def.get("type", "skeleton")
		var pos: Vector3 = spawn_def.get("pos", Vector3.ZERO)
		_spawn_single_enemy(type, pos, enemy_root)


func _spawn_single_enemy(type: String, pos: Vector3, parent: Node) -> void:
	# Crea nemico 3D semplificato. Per integrazione completa con il sistema
	# esistente (2D isometrico), questi spawn vanno collegati a Enemy.gd.
	var enemy := CharacterBody3D.new()
	enemy.name = "Enemy_%s" % type
	enemy.position = pos

	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.height = 2.0; shape.radius = 0.4
	col.shape = shape
	enemy.add_child(col)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.8, 1.8, 0.8)
	mesh.mesh = box
	mesh.position.y = 0.9
	var mat := StandardMaterial3D.new()
	match type:
		"skeleton", "skeleton_a", "lich":
			mat.albedo_color = Color(0.7, 0.65, 0.6)
		"goblin", "goblin_e":
			mat.albedo_color = Color(0.3, 0.7, 0.2)
		"orc", "orc_b":
			mat.albedo_color = Color(0.2, 0.5, 0.3)
		"zombie":
			mat.albedo_color = Color(0.3, 0.45, 0.3)
		"werewolf", "werewolf_a":
			mat.albedo_color = Color(0.4, 0.25, 0.15)
		"mage":
			mat.albedo_color = Color(0.5, 0.2, 0.8)
		"dragon", "dragon_b":
			mat.albedo_color = Color(0.8, 0.15, 0.1)
		"wyvern", "wyvern_a":
			mat.albedo_color = Color(0.7, 0.5, 0.2)
		_:
			mat.albedo_color = Color(0.6, 0.3, 0.2)
	mesh.material_override = mat
	enemy.add_child(mesh)

	# Label nome
	var label := Label3D.new()
	label.text = type.capitalize()
	label.position = Vector3(0, 2.5, 0)
	label.font_size = 24
	label.outline_size = 2
	label.modulate = Color(0.9, 0.2, 0.2)
	enemy.add_child(label)

	parent.add_child(enemy)
	_spawned_enemies.append(enemy)


func _build_portals() -> void:
	var portal_list: Array = _map_data.get("portals", [])
	var portal_root := _get_or_create_node("PortalRoot")

	for pdata in portal_list:
		var target: String = pdata.get("target", "")
		var pos_3d: Vector3 = pdata.get("pos_3d", Vector3.ZERO)
		var label: String = pdata.get("label", "???")

		_portal_to_real_map(portal_root, pos_3d, target, label)

	# Portale di ritorno al mondo classico
	var return_map: String = _map_data.get("return_map_id", "black_oak_city")
	_portal_return_classic(portal_root, return_map)


func _portal_to_real_map(parent: Node, pos: Vector3, target: String, label_text: String) -> void:
	var portal := Node3D.new()
	portal.name = "Portal_%s" % target
	portal.position = pos

	# Raggio luminoso
	var glow := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.height = 3.0; cylinder.top_radius = 0.8; cylinder.bottom_radius = 0.8
	glow.mesh = cylinder
	glow.position.y = 1.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.7, 1.0, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.material_override = mat
	portal.add_child(glow)

	var label_3d := Label3D.new()
	label_3d.text = "[VARCO]\n" + label_text
	label_3d.position = Vector3(0, 3.5, 0)
	label_3d.font_size = 20
	label_3d.outline_size = 2
	label_3d.modulate = Color(0.5, 0.9, 1.0)
	portal.add_child(label_3d)

	# Area di attivazione
	var area := Area3D.new()
	area.name = "PortalArea"
	var col_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.0
	col_shape.shape = sphere
	area.add_child(col_shape)
	area.body_entered.connect(func(body: Node3D):
		if body == _player:
			portal_activated.emit(target, true)
	)
	portal.add_child(area)

	parent.add_child(portal)


func _portal_return_classic(parent: Node, return_map_id: String) -> void:
	var portal := Node3D.new()
	portal.name = "Portal_Return_Classic"
	portal.position = Vector3(0, 0, -14)

	var glow := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.height = 3.0; cylinder.top_radius = 1.0; cylinder.bottom_radius = 1.0
	glow.mesh = cylinder
	glow.position.y = 1.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.3, 1.0, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.material_override = mat
	portal.add_child(glow)

	var label_3d := Label3D.new()
	label_3d.text = "[RITORNO]\nBastione"
	label_3d.position = Vector3(0, 3.5, 0)
	label_3d.font_size = 22
	label_3d.outline_size = 2
	label_3d.modulate = Color(0.8, 0.4, 1.0)
	portal.add_child(label_3d)

	var area := Area3D.new()
	area.name = "ReturnArea"
	var col_shape := CollisionShape3D.new()
	col_shape.shape = SphereShape3D.new()
	col_shape.shape.radius = 2.5
	area.add_child(col_shape)
	area.body_entered.connect(func(body: Node3D):
		if body == _player:
			return_to_classic_requested.emit()
	)
	portal.add_child(area)

	parent.add_child(portal)


func _add_attribution() -> void:
	var attr := RealWorldAttributionClass.new()
	attr.name = "Attribution"
	attr.set_city_attribution(_map_data.display_name)
	add_child(attr)
	_attribution = attr


func _get_or_create_node(node_name: String) -> Node3D:
	var existing := get_node_or_null(node_name)
	if existing:
		return existing
	var n := Node3D.new()
	n.name = node_name
	add_child(n)
	return n


func get_player() -> Node3D:
	return _player


func get_map_data() -> Dictionary:
	return _map_data
