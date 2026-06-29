# LocalGltfMapController.gd - livelli giocabili per mappe 3D locali da zip

extends Node3D

const LOCAL_MAPS = preload("res://data/LocalGltfMapRegistry.gd")

const WORLD_LAYER: int = 1
const PLAYER_LAYER: int = 2
const ENEMY_LAYER: int = 4
const DEFAULT_ENEMY_COUNT: int = 6
const GRAVITY: float = 24.0

const WALKABLE_NAME_TOKENS: Array[String] = [
	"road", "street", "ground", "grass", "floor", "curb", "lane",
	"sidewalk", "walk", "path", "plaza", "asphalt", "pavement", "terrain",
	"route", "crossing", "square", "park"
]
const NON_WALKABLE_NAME_TOKENS: Array[String] = [
	"water", "roof", "wall", "window", "door", "building", "house",
	"tower", "skyscraper", "fence", "pole", "tree", "car", "vehicle"
]
const BLOCKER_SKIP_TOKENS: Array[String] = [
	"road", "street", "ground", "grass", "floor", "curb", "lane",
	"water", "sidewalk", "walk", "path", "plaza", "asphalt", "pavement"
]
const ENEMY_NAMES: Array[String] = [
	"Sentinella", "Predone", "Ombra", "Assalitore", "Custode", "Cacciatore"
]

@export var default_map_id: String = "new_york_city"

var _current_map_id: String = ""
var _current_map: Dictionary = {}
var _map_root: Node3D = null
var _enemy_root: Node3D = null
var _player: CharacterBody3D = null
var _player_body: MeshInstance3D = null
var _player_material: StandardMaterial3D = null
var _camera: Camera3D = null
var _ui_layer: CanvasLayer = null
var _status_label: Label = null
var _game_over_overlay: Control = null
var _restart_button: Button = null
var _camera_size: float = 55.0
var _move_speed: float = 9.0
var _map_bounds: AABB = AABB()
var _has_map_bounds: bool = false
var _spawn_points: Array[Vector3] = []
var _blocker_bounds: Array[AABB] = []
var _enemy_nodes: Array[CharacterBody3D] = []
var _blocking_collision_count: int = 0
var _last_player_spawn: Vector3 = Vector3.ZERO
var _player_facing: Vector3 = Vector3.FORWARD
var _player_max_hp: int = 100
var _player_hp: int = 100
var _attack_timer: float = 0.0
var _attack_active_timer: float = 0.0
var _attack_hit_ids: Dictionary = {}
var _runtime_report: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_setup_world()
	_setup_player()
	_setup_ui()
	load_local_map(default_map_id)


func _physics_process(delta: float) -> void:
	_update_player(delta)
	_update_enemies(delta)
	_update_camera()


func _setup_world() -> void:
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.025, 0.028, 0.035, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.34, 0.38, 1.0)
	env_node.environment = env
	add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation_degrees = Vector3(-52.0, -36.0, 0.0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.rotation_degrees = Vector3(-28.0, 120.0, 0.0)
	fill.light_energy = 0.35
	add_child(fill)

	_camera = Camera3D.new()
	_camera.name = "IsoCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = _camera_size
	_camera.rotation_degrees = Vector3(-58.0, 0.0, 0.0)
	_camera.current = true
	add_child(_camera)

	var ground_body := StaticBody3D.new()
	ground_body.name = "GroundCollision"
	ground_body.collision_layer = WORLD_LAYER
	ground_body.collision_mask = 0
	var ground_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1000.0, 0.5, 1000.0)
	ground_shape.shape = box
	ground_shape.position = Vector3(0.0, -0.35, 0.0)
	ground_body.add_child(ground_shape)
	add_child(ground_body)


func _setup_player() -> void:
	_player = CharacterBody3D.new()
	_player.name = "Player"
	_player.collision_layer = PLAYER_LAYER
	_player.collision_mask = WORLD_LAYER | ENEMY_LAYER
	_player.safe_margin = 0.04
	_player.add_to_group("player")

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 2.0
	capsule.radius = 0.42
	shape.shape = capsule
	shape.position.y = 1.0
	_player.add_child(shape)

	_player_body = MeshInstance3D.new()
	_player_body.name = "PlayerBody"
	var mesh := CapsuleMesh.new()
	mesh.height = 1.55
	mesh.radius = 0.34
	_player_body.mesh = mesh
	_player_body.position.y = 1.0
	_player_material = StandardMaterial3D.new()
	_player_material.albedo_color = Color(0.30, 0.52, 0.95, 1.0)
	_player_material.roughness = 0.55
	_player_body.material_override = _player_material
	_player.add_child(_player_body)

	add_child(_player)


func _setup_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "LocalMapUI"
	_ui_layer.layer = 100
	_ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ui_layer)

	var panel := Panel.new()
	panel.name = "Panel"
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = 12.0
	panel.offset_top = 12.0
	panel.offset_right = 390.0
	panel.offset_bottom = 700.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.025, 0.035, 0.88)
	style.border_color = Color(0.35, 0.50, 0.75, 0.9)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	panel.add_theme_stylebox_override("panel", style)
	_ui_layer.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 12.0
	vbox.offset_top = 12.0
	vbox.offset_right = -12.0
	vbox.offset_bottom = -12.0
	panel.add_child(vbox)

	_status_label = Label.new()
	_status_label.name = "Status"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", Color(0.84, 0.90, 1.0, 1.0))
	_status_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_status_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.name = "MapList"
	scroll.add_child(list)

	for map_id in LOCAL_MAPS.get_ids():
		var map_data: Dictionary = LOCAL_MAPS.get_map(map_id)
		var button := Button.new()
		button.text = "%s\n%s" % [map_data.get("display_name", map_id), map_data.get("license", "")]
		button.custom_minimum_size = Vector2(330.0, 52.0)
		button.pressed.connect(load_local_map.bind(map_id))
		list.add_child(button)

	var return_button := Button.new()
	return_button.text = "Ritorna al Bastione"
	return_button.custom_minimum_size = Vector2(0.0, 44.0)
	return_button.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/main/Main.tscn")
	)
	vbox.add_child(return_button)

	_build_game_over_overlay()


func _build_game_over_overlay() -> void:
	_game_over_overlay = Control.new()
	_game_over_overlay.name = "GameOverOverlay"
	_game_over_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_game_over_overlay.anchor_right = 1.0
	_game_over_overlay.anchor_bottom = 1.0
	_game_over_overlay.visible = false
	_ui_layer.add_child(_game_over_overlay)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	_game_over_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	_game_over_overlay.add_child(center)

	var box := VBoxContainer.new()
	box.name = "VBoxContainer"
	box.custom_minimum_size = Vector2(360.0, 150.0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	var title := Label.new()
	title.name = "Title"
	title.text = "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.24, 0.18, 1.0))
	title.add_theme_font_size_override("font_size", 46)
	box.add_child(title)

	_restart_button = Button.new()
	_restart_button.name = "RestartButton"
	_restart_button.text = "Riavvia"
	_restart_button.custom_minimum_size = Vector2(190.0, 48.0)
	_restart_button.process_mode = Node.PROCESS_MODE_ALWAYS
	_restart_button.focus_mode = Control.FOCUS_ALL
	_style_restart_button(_restart_button)
	_restart_button.pressed.connect(_restart_current_local_map)
	box.add_child(_restart_button)


func _show_game_over() -> void:
	if _game_over_overlay:
		_game_over_overlay.show()
		_game_over_overlay.move_to_front()
	if _restart_button:
		_restart_button.grab_focus()
	get_tree().paused = true


func _hide_game_over() -> void:
	if _game_over_overlay:
		_game_over_overlay.hide()


func _restart_current_local_map() -> void:
	var map_id := _current_map_id
	get_tree().paused = false
	load_local_map(map_id)


func _style_restart_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.02, 0.02, 0.96)
	normal.border_color = Color(1.0, 0.36, 0.20, 0.95)
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_width_top = 2
	normal.border_width_bottom = 2
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.20, 0.04, 0.03, 1.0)
	hover.border_color = Color(1.0, 0.72, 0.36, 1.0)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.32, 0.08, 0.04, 1.0)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color(1.0, 0.84, 0.70, 1.0))
	button.add_theme_font_size_override("font_size", 20)


func load_local_map(map_id: String) -> void:
	get_tree().paused = false
	_current_map_id = map_id
	_current_map = LOCAL_MAPS.get_map(map_id)
	_camera_size = float(_current_map.get("camera_size", 55.0))
	if _camera:
		_camera.size = _camera_size

	_clear_enemies()
	if _map_root and is_instance_valid(_map_root):
		remove_child(_map_root)
		_map_root.queue_free()
	_map_root = Node3D.new()
	_map_root.name = "ImportedLocalMap"
	add_child(_map_root)

	_enemy_root = Node3D.new()
	_enemy_root.name = "EnemySpawnRoot"
	_map_root.add_child(_enemy_root)

	_has_map_bounds = false
	_map_bounds = AABB()
	_spawn_points.clear()
	_blocker_bounds.clear()
	_blocking_collision_count = 0
	_player_hp = _player_max_hp
	_attack_timer = 0.0
	_attack_active_timer = 0.0
	_attack_hit_ids.clear()

	var model_path: String = _current_map.get("model_path", "")
	var model: Node3D = _instantiate_gltf_model(model_path)
	if model:
		model.name = "Model_" + map_id
		model.scale = Vector3.ONE * float(_current_map.get("scale", 0.05))
		model.rotation_degrees.y = float(_current_map.get("rotation_y", -35.0))
		_map_root.add_child(model)
		_adapt_materials(model)
		_add_simplified_collisions(model)
		_collect_spawn_points(model)
	else:
		push_warning("LocalGltfMapController: impossibile caricare %s" % model_path)
		_build_placeholder()
		_collect_spawn_points(_map_root)

	var spawn := _choose_player_spawn()
	_last_player_spawn = spawn
	_player.global_position = spawn
	_player.velocity = Vector3.ZERO
	_spawn_enemies_for_map(spawn)
	_update_runtime_report()
	_update_status()
	_hide_game_over()
	print("LocalGltfMapController: %s giocabile, spawn=%s, nemici=%d, collisioni=%d, punti=%d" % [
		_current_map_id,
		str(spawn),
		_enemy_nodes.size(),
		_blocking_collision_count,
		_spawn_points.size(),
	])


func _instantiate_gltf_model(model_path: String) -> Node3D:
	if not model_path.ends_with(".gltf") and not model_path.ends_with(".glb"):
		var packed: PackedScene = ResourceLoader.load(model_path) as PackedScene
		if packed:
			var imported := packed.instantiate()
			if imported is Node3D:
				return imported as Node3D
			imported.queue_free()

	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error: Error = document.append_from_file(model_path, state)
	if error != OK:
		push_warning("GLTFDocument append_from_file failed for %s: %s" % [model_path, error_string(error)])
		return null
	var generated := document.generate_scene(state)
	if generated is Node3D:
		return generated as Node3D
	if generated:
		generated.queue_free()
	return null


func _adapt_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		for i in range(mesh_instance.get_surface_override_material_count()):
			var mat := mesh_instance.get_surface_override_material(i)
			_tint_material(mat)
		if mesh_instance.mesh:
			for i in range(mesh_instance.mesh.get_surface_count()):
				var mat := mesh_instance.mesh.surface_get_material(i)
				_tint_material(mat)
	for child in node.get_children():
		_adapt_materials(child)


func _tint_material(mat: Material) -> void:
	if mat == null:
		return
	if mat is BaseMaterial3D:
		var base := mat as BaseMaterial3D
		base.albedo_color = base.albedo_color.lerp(Color(0.34, 0.34, 0.38, 1.0), 0.14)
		base.roughness = clamp(base.roughness * 1.12, 0.35, 1.0)


func _add_simplified_collisions(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if _mesh_should_block(mesh_instance):
			var aabb: AABB = mesh_instance.get_aabb()
			var body := StaticBody3D.new()
			body.name = "Collision_" + mesh_instance.name
			body.collision_layer = WORLD_LAYER
			body.collision_mask = 0
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(max(aabb.size.x, 0.2), max(aabb.size.y, 0.2), max(aabb.size.z, 0.2))
			shape.shape = box
			shape.position = aabb.get_center()
			body.add_child(shape)
			mesh_instance.add_child(body)
			_blocker_bounds.append(_transform_aabb(mesh_instance.global_transform, aabb))
			_blocking_collision_count += 1
	for child in node.get_children():
		_add_simplified_collisions(child)


func _mesh_should_block(mesh_instance: MeshInstance3D) -> bool:
	var name_lc: String = mesh_instance.name.to_lower()
	for token in BLOCKER_SKIP_TOKENS:
		if name_lc.contains(token):
			return false
	var aabb: AABB = mesh_instance.get_aabb()
	if aabb.size.y < 0.65:
		return false
	if aabb.size.x * aabb.size.z < 0.12:
		return false
	return true


func _collect_spawn_points(model: Node3D) -> void:
	var mesh_records: Array[Dictionary] = []
	_collect_mesh_records(model, mesh_records)
	if not _has_map_bounds:
		_map_bounds = AABB(Vector3(-22.0, -0.2, -22.0), Vector3(44.0, 8.0, 44.0))
		_has_map_bounds = true

	for record in mesh_records:
		var mesh_name: String = record.get("name", "")
		var bounds: AABB = record.get("bounds", AABB())
		if _is_walkable_surface(mesh_name, bounds):
			_add_spawn_samples_from_bounds(bounds)

	if _spawn_points.size() < 6:
		_add_fallback_spawn_grid()


func _collect_mesh_records(node: Node, records: Array[Dictionary]) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh:
			var bounds := _transform_aabb(mesh_instance.global_transform, mesh_instance.get_aabb())
			if bounds.size.length_squared() > 0.0001:
				records.append({"name": mesh_instance.name, "bounds": bounds})
				_include_map_bounds(bounds)
	for child in node.get_children():
		_collect_mesh_records(child, records)


func _transform_aabb(xform: Transform3D, aabb: AABB) -> AABB:
	var p0 := xform * aabb.position
	var out := AABB(p0, Vector3.ZERO)
	var p1 := aabb.position + Vector3(aabb.size.x, 0.0, 0.0)
	var p2 := aabb.position + Vector3(0.0, aabb.size.y, 0.0)
	var p3 := aabb.position + Vector3(0.0, 0.0, aabb.size.z)
	var p4 := aabb.position + Vector3(aabb.size.x, aabb.size.y, 0.0)
	var p5 := aabb.position + Vector3(aabb.size.x, 0.0, aabb.size.z)
	var p6 := aabb.position + Vector3(0.0, aabb.size.y, aabb.size.z)
	var p7 := aabb.position + aabb.size
	for point in [p1, p2, p3, p4, p5, p6, p7]:
		out = out.expand(xform * point)
	return out


func _include_map_bounds(bounds: AABB) -> void:
	if not _has_map_bounds:
		_map_bounds = bounds
		_has_map_bounds = true
	else:
		_map_bounds = _map_bounds.merge(bounds)


func _is_walkable_surface(mesh_name: String, bounds: AABB) -> bool:
	var name_lc: String = mesh_name.to_lower()
	for token in NON_WALKABLE_NAME_TOKENS:
		if name_lc.contains(token):
			return false
	for token in WALKABLE_NAME_TOKENS:
		if name_lc.contains(token):
			return true

	var footprint: float = bounds.size.x * bounds.size.z
	if footprint < 3.0:
		return false
	var low_surface_limit: float = _map_bounds.position.y + max(2.0, _map_bounds.size.y * 0.16)
	var top_y: float = bounds.position.y + bounds.size.y
	if bounds.size.y <= 0.45 and top_y <= low_surface_limit:
		return true
	return false


func _add_spawn_samples_from_bounds(bounds: AABB) -> void:
	if _spawn_points.size() >= 220:
		return

	var top_y: float = bounds.position.y + bounds.size.y
	var min_x: float = bounds.position.x + min(bounds.size.x * 0.20, 2.0)
	var max_x: float = bounds.position.x + bounds.size.x - min(bounds.size.x * 0.20, 2.0)
	var min_z: float = bounds.position.z + min(bounds.size.z * 0.20, 2.0)
	var max_z: float = bounds.position.z + bounds.size.z - min(bounds.size.z * 0.20, 2.0)

	var count_x: int = clampi(int(bounds.size.x / 7.0) + 1, 1, 4)
	var count_z: int = clampi(int(bounds.size.z / 7.0) + 1, 1, 4)
	for ix in range(count_x):
		for iz in range(count_z):
			var tx: float = 0.5
			var tz: float = 0.5
			if count_x > 1:
				tx = float(ix) / float(count_x - 1)
			if count_z > 1:
				tz = float(iz) / float(count_z - 1)
			var point: Vector3 = Vector3(
				lerp(min_x, max_x, tx),
				max(top_y + 0.16, 0.16),
				lerp(min_z, max_z, tz)
			)
			_add_spawn_point(point)


func _add_spawn_point(point: Vector3, force: bool = false) -> void:
	if not force and not _is_spawn_clear(point):
		return
	for existing in _spawn_points:
		if _flat_distance(existing, point) < 2.4:
			return
	_spawn_points.append(point)


func _is_spawn_clear(point: Vector3) -> bool:
	for bounds in _blocker_bounds:
		var top_y: float = bounds.position.y + bounds.size.y
		var bottom_y: float = bounds.position.y
		if point.y < bottom_y - 0.35 or point.y > top_y + 0.85:
			continue
		var margin: float = 0.85
		var in_x: bool = point.x >= bounds.position.x - margin and point.x <= bounds.position.x + bounds.size.x + margin
		var in_z: bool = point.z >= bounds.position.z - margin and point.z <= bounds.position.z + bounds.size.z + margin
		if in_x and in_z:
			return false
	return true


func _add_fallback_spawn_grid() -> void:
	var center: Vector3 = _map_bounds.get_center()
	var extent_x: float = max(_map_bounds.size.x * 0.24, 8.0)
	var extent_z: float = max(_map_bounds.size.z * 0.24, 8.0)
	var y: float = max(_map_bounds.position.y + 0.22, 0.22)
	for x in [-1, 0, 1]:
		for z in [-1, 0, 1]:
			_add_spawn_point(Vector3(center.x + float(x) * extent_x, y, center.z + float(z) * extent_z))
	if _spawn_points.is_empty():
		_add_spawn_point(Vector3(center.x, y, center.z), true)


func _choose_player_spawn() -> Vector3:
	if _spawn_points.is_empty():
		return _current_map.get("player_spawn", Vector3(0.0, 0.25, 0.0)) as Vector3

	var center: Vector3 = _map_bounds.get_center()
	var ground_y: float = _map_bounds.position.y
	var best: Vector3 = _spawn_points[0]
	var best_score: float = INF
	for point in _spawn_points:
		if not _is_spawn_clear(point):
			continue
		var center_dist: float = _flat_distance(point, center)
		var height_penalty: float = abs(point.y - ground_y) * 1.8
		var score: float = center_dist + height_penalty
		if score < best_score:
			best_score = score
			best = point
	return best + Vector3(0.0, 0.08, 0.0)


func _spawn_enemies_for_map(player_spawn: Vector3) -> void:
	if not _enemy_root:
		return
	var enemy_count: int = int(_current_map.get("enemy_count", DEFAULT_ENEMY_COUNT))
	var enemy_spawns: Array[Vector3] = _choose_enemy_spawns(player_spawn, enemy_count)
	for i in range(enemy_spawns.size()):
		_spawn_single_enemy(enemy_spawns[i], i)


func _choose_enemy_spawns(player_spawn: Vector3, enemy_count: int) -> Array[Vector3]:
	var chosen: Array[Vector3] = []
	var candidates: Array[Vector3] = _spawn_points.duplicate()
	var min_dist: float = max(5.0, _camera_size * 0.10)
	var ideal_dist: float = max(10.0, _camera_size * 0.28)
	while chosen.size() < enemy_count and not candidates.is_empty():
		var best_idx: int = -1
		var best_score: float = -INF
		for i in range(candidates.size()):
			var point: Vector3 = candidates[i]
			var dist_to_player: float = _flat_distance(point, player_spawn)
			if dist_to_player < min_dist:
				continue
			var spacing: float = 999.0
			for used in chosen:
				spacing = min(spacing, _flat_distance(point, used))
			if chosen.is_empty():
				spacing = ideal_dist
			var score: float = spacing * 1.4 - abs(dist_to_player - ideal_dist) * 0.55 + dist_to_player * 0.08
			if score > best_score:
				best_score = score
				best_idx = i
		if best_idx < 0:
			break
		chosen.append(candidates[best_idx])
		candidates.remove_at(best_idx)

	var ring_radius: float = max(7.0, min(_camera_size * 0.25, 18.0))
	while chosen.size() < enemy_count:
		var idx: int = chosen.size()
		var angle: float = TAU * float(idx) / float(max(enemy_count, 1)) + 0.45
		var pos: Vector3 = Vector3(
			player_spawn.x + cos(angle) * ring_radius,
			player_spawn.y,
			player_spawn.z + sin(angle) * ring_radius
		)
		chosen.append(pos)
	return chosen


func _spawn_single_enemy(pos: Vector3, index: int) -> void:
	var enemy := CharacterBody3D.new()
	enemy.name = "Enemy_%02d" % index
	enemy.position = pos
	enemy.collision_layer = ENEMY_LAYER
	enemy.collision_mask = WORLD_LAYER | PLAYER_LAYER | ENEMY_LAYER
	enemy.safe_margin = 0.04
	enemy.add_to_group("enemies")
	enemy.set_meta("hp", 28 + index * 3)
	enemy.set_meta("cooldown", 0.2 + float(index % 3) * 0.25)
	enemy.set_meta("speed", 4.0 + float(index % 3) * 0.45)

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.75
	capsule.radius = 0.36
	shape.shape = capsule
	shape.position.y = 0.9
	enemy.add_child(shape)

	var body := MeshInstance3D.new()
	body.name = "EnemyBody"
	var mesh := CapsuleMesh.new()
	mesh.height = 1.35
	mesh.radius = 0.30
	body.mesh = mesh
	body.position.y = 0.9
	var mat := StandardMaterial3D.new()
	var tint: Color = Color(0.78, 0.24, 0.18, 1.0).lerp(Color(0.95, 0.66, 0.20, 1.0), float(index % 4) / 5.0)
	mat.albedo_color = tint
	mat.roughness = 0.62
	body.material_override = mat
	enemy.add_child(body)

	var marker := MeshInstance3D.new()
	marker.name = "EnemyMarker"
	var marker_mesh := SphereMesh.new()
	marker_mesh.radius = 0.18
	marker_mesh.height = 0.36
	marker.mesh = marker_mesh
	marker.position.y = 1.9
	var marker_mat := StandardMaterial3D.new()
	marker_mat.albedo_color = Color(1.0, 0.18, 0.14, 1.0)
	marker_mat.emission_enabled = true
	marker_mat.emission = Color(1.0, 0.08, 0.04, 1.0)
	marker.material_override = marker_mat
	enemy.add_child(marker)

	var label := Label3D.new()
	label.name = "EnemyLabel"
	label.text = ENEMY_NAMES[index % ENEMY_NAMES.size()]
	label.position = Vector3(0.0, 2.35, 0.0)
	label.font_size = 22
	label.outline_size = 3
	label.modulate = Color(1.0, 0.40, 0.32, 1.0)
	enemy.add_child(label)

	_enemy_root.add_child(enemy)
	_enemy_nodes.append(enemy)


func _clear_enemies() -> void:
	for enemy in _enemy_nodes:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_enemy_nodes.clear()


func _build_placeholder() -> void:
	for x in range(-8, 9):
		for z in range(-8, 9):
			if abs(x) < 2 or abs(z) < 2:
				continue
			var cube := MeshInstance3D.new()
			var box := BoxMesh.new()
			var h: float = 2.0 + float(abs((x * 13 + z * 7) % 8))
			box.size = Vector3(1.6, h, 1.6)
			cube.mesh = box
			cube.position = Vector3(float(x) * 2.2, h * 0.5, float(z) * 2.2)
			_map_root.add_child(cube)

			var body := StaticBody3D.new()
			body.name = "Collision_Placeholder_%d_%d" % [x, z]
			body.collision_layer = WORLD_LAYER
			var shape := CollisionShape3D.new()
			var col := BoxShape3D.new()
			col.size = box.size
			shape.shape = col
			body.add_child(shape)
			cube.add_child(body)
			_blocking_collision_count += 1


func _update_player(delta: float) -> void:
	if not _player:
		return
	_attack_timer = max(0.0, _attack_timer - delta)
	_attack_active_timer = max(0.0, _attack_active_timer - delta)

	var dir: Vector3 = Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.z += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if dir.length_squared() > 0.0:
		dir = dir.normalized()
		_player_facing = dir

	if (Input.is_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) and _attack_timer <= 0.0:
		_start_player_attack()

	if _attack_active_timer > 0.0:
		_player.velocity.x = _player_facing.x * _move_speed * 1.85
		_player.velocity.z = _player_facing.z * _move_speed * 1.85
		_process_player_attack_hits()
	elif dir.length_squared() > 0.0:
		_player.velocity.x = dir.x * _move_speed
		_player.velocity.z = dir.z * _move_speed
	else:
		_player.velocity.x = move_toward(_player.velocity.x, 0.0, _move_speed * 4.0 * delta)
		_player.velocity.z = move_toward(_player.velocity.z, 0.0, _move_speed * 4.0 * delta)

	_player.velocity.y -= GRAVITY * delta
	_player.move_and_slide()

	if _player_material:
		if _attack_active_timer > 0.0:
			_player_material.albedo_color = Color(1.0, 0.82, 0.26, 1.0)
		elif dir.length_squared() > 0.0:
			_player_material.albedo_color = Color(0.34, 0.68, 1.0, 1.0)
		else:
			_player_material.albedo_color = Color(0.30, 0.52, 0.95, 1.0)


func _start_player_attack() -> void:
	_attack_timer = 0.54
	_attack_active_timer = 0.20
	_attack_hit_ids.clear()
	if _player_facing.length_squared() < 0.01:
		_player_facing = Vector3.FORWARD


func _process_player_attack_hits() -> void:
	for enemy in _enemy_nodes.duplicate():
		if not is_instance_valid(enemy):
			continue
		var instance_id: int = enemy.get_instance_id()
		if _attack_hit_ids.has(instance_id):
			continue
		var to_enemy: Vector3 = enemy.global_position - _player.global_position
		to_enemy.y = 0.0
		if to_enemy.length() > 2.35:
			continue
		var dir: Vector3 = to_enemy.normalized()
		if dir.dot(_player_facing.normalized()) < 0.18:
			continue
		_attack_hit_ids[instance_id] = true
		_damage_enemy(enemy, 18)


func _damage_enemy(enemy: CharacterBody3D, amount: int) -> void:
	var hp: int = int(enemy.get_meta("hp", 1)) - amount
	enemy.set_meta("hp", hp)
	if hp <= 0:
		_enemy_nodes.erase(enemy)
		enemy.queue_free()
		_update_runtime_report()
		_update_status()
		return

	var body := enemy.get_node_or_null("EnemyBody") as MeshInstance3D
	if body and body.material_override is StandardMaterial3D:
		var mat := body.material_override as StandardMaterial3D
		mat.albedo_color = Color(1.0, 0.12, 0.08, 1.0)


func _update_enemies(delta: float) -> void:
	if not _player:
		return
	for enemy in _enemy_nodes.duplicate():
		if not is_instance_valid(enemy):
			_enemy_nodes.erase(enemy)
			continue
		var to_player: Vector3 = _player.global_position - enemy.global_position
		to_player.y = 0.0
		var dist: float = to_player.length()
		var cooldown: float = max(0.0, float(enemy.get_meta("cooldown", 0.0)) - delta)
		enemy.set_meta("cooldown", cooldown)

		if dist > 1.2 and dist < max(_camera_size * 1.25, 32.0):
			var dir: Vector3 = to_player.normalized()
			var speed: float = float(enemy.get_meta("speed", 4.0))
			if dist > 2.2:
				enemy.velocity.x = dir.x * speed
				enemy.velocity.z = dir.z * speed
			else:
				enemy.velocity.x = 0.0
				enemy.velocity.z = 0.0
				if cooldown <= 0.0:
					_damage_player(6)
					enemy.set_meta("cooldown", 1.25)
			var look_target: Vector3 = Vector3(_player.global_position.x, enemy.global_position.y, _player.global_position.z)
			if enemy.global_position.distance_to(look_target) > 0.2:
				enemy.look_at(look_target, Vector3.UP)
		else:
			enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, 5.0 * delta)
			enemy.velocity.z = move_toward(enemy.velocity.z, 0.0, 5.0 * delta)

		enemy.velocity.y -= GRAVITY * delta
		enemy.move_and_slide()


func _damage_player(amount: int) -> void:
	_player_hp = max(0, _player_hp - amount)
	if _player_hp <= 0:
		_player_hp = 0
		_player.velocity = Vector3.ZERO
		_show_game_over()
	_update_runtime_report()
	_update_status()


func _update_camera() -> void:
	if not _camera or not _player:
		return
	var target := _player.global_position
	_camera.global_position = target + Vector3(0.0, _camera_size * 0.72, _camera_size * 0.52)
	_camera.look_at(target, Vector3.UP)


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _update_runtime_report() -> void:
	_runtime_report = {
		"map_id": _current_map_id,
		"player_position": _player.global_position if _player else Vector3.ZERO,
		"player_hp": _player_hp,
		"enemy_count": _enemy_nodes.size(),
		"spawn_count": _spawn_points.size(),
		"collision_count": _blocking_collision_count,
		"map_loaded": _map_root != null and _map_root.get_child_count() > 0,
	}


func _update_status() -> void:
	if not _status_label:
		return
	var title: String = _current_map.get("display_name", _current_map_id)
	var desc: String = _current_map.get("desc", "")
	var author: String = _current_map.get("author", "")
	var license: String = _current_map.get("license", "")
	_status_label.text = "%s\n%s\nHP %d/%d | Nemici %d | Spawn %d | Collisioni %d\n%s - %s" % [
		title,
		desc,
		_player_hp,
		_player_max_hp,
		_enemy_nodes.size(),
		_spawn_points.size(),
		_blocking_collision_count,
		author,
		license,
	]


func get_enemy_count() -> int:
	return _enemy_nodes.size()


func get_spawn_count() -> int:
	return _spawn_points.size()


func get_collision_count() -> int:
	return _blocking_collision_count


func get_runtime_report() -> Dictionary:
	_update_runtime_report()
	return _runtime_report.duplicate()


func debug_gameplay_probe() -> Dictionary:
	if not _player:
		return {"ok": false, "reason": "missing player"}
	var before := _player.global_position
	_start_player_attack()
	_update_player(0.08)
	_update_enemies(0.08)
	_update_runtime_report()
	return {
		"ok": true,
		"player_moved": _flat_distance(before, _player.global_position) > 0.02,
		"attack_started": _attack_timer > 0.0,
		"enemy_count": _enemy_nodes.size(),
		"player_hp": _player_hp,
		"spawn_count": _spawn_points.size(),
		"collision_count": _blocking_collision_count,
	}
