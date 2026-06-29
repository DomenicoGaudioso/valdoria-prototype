# RealCityController.gd — Controller scena città reale OSM (v2)
# =============================================================================
# Carica un OSMCityData .tres e crea mesh BoxMesh/CSGMesh3D direttamente.
# Nessuna dipendenza da GLB — tutto generato da codice Godot.
# Include: camera isometrica, luci, player, portali, attribuzione.

extends Node3D

const RealCityRegistry = preload("res://data/RealCityRegistry.gd")
const WORLD_SCALE: float = 0.06  # scala real-world → Godot

@export var city_id: String = ""

var _player: CharacterBody3D = null
var _camera: Camera3D = null


func _ready() -> void:
	var city_data := RealCityRegistry.get_city(city_id)
	if city_data.is_empty():
		push_error("Citta non trovata: " + city_id)
		return

	print("RealCityController: building %s..." % city_data.display_name)

	_setup_camera()
	_setup_lighting()
	_setup_environment()
	_build_city()
	_spawn_player(city_data)
	_build_return_portal(city_data)
	_setup_attribution(city_data)

	print("RealCityController: %s ready (%d buildings)." % [city_data.display_name, get_child_count()])


func _setup_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "IsoCam"
	_camera.position = Vector3(0, 45, 30)
	_camera.rotation_degrees = Vector3(-55, 0, 0)
	_camera.current = true
	add_child(_camera)


func _setup_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.position = Vector3(20, 35, 10)
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	add_child(sun)

	var ambient := DirectionalLight3D.new()
	ambient.name = "AmbientFill"
	ambient.position = Vector3(-10, 20, -15)
	ambient.rotation_degrees = Vector3(-30, -45, 0)
	ambient.light_energy = 0.25
	ambient.shadow_enabled = false
	add_child(ambient)


func _setup_environment() -> void:
	var env_node := WorldEnvironment.new()
	env_node.name = "Env"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.03, 0.08, 1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.20, 0.18, 1)
	env_node.environment = env
	add_child(env_node)


func _build_city() -> void:
	# Carica il resource .tres
	var tres_path := "res://assets/real_world/%s/%s_buildings.tres" % [city_id, city_id]
	var city_resource: Resource = null

	if ResourceLoader.exists(tres_path):
		city_resource = load(tres_path) as Resource
	else:
		push_warning("OSMCityData non trovato: %s. Uso fallback." % tres_path)
		_build_fallback()
		return

	if not city_resource:
		push_warning("OSMCityData non caricabile per %s." % city_id)
		_build_fallback()
		return

	var buildings: Array = city_resource.get("buildings") as Array
	var roads: Array = city_resource.get("roads") as Array
	if buildings.is_empty():
		push_warning("OSMCityData vuoto per %s." % city_id)
		_build_fallback()
		return

	print("  Creating %d buildings..." % buildings.size())

	# Root per la citta
	var world_root := Node3D.new()
	world_root.name = "CityRoot"
	world_root.scale = Vector3(WORLD_SCALE, WORLD_SCALE, WORLD_SCALE)
	add_child(world_root)

	# Colore dark fantasy di default
	var dark_tint := Color(0.38, 0.34, 0.28)

	# Raggruppa per tipo per ridurre i materiali
	var material_cache: Dictionary = {}

	for bld_def_variant in buildings:
		var bld_def: Dictionary = bld_def_variant as Dictionary
		var pos: Vector3 = bld_def.get("pos", Vector3.ZERO) as Vector3
		var size: Vector3 = bld_def.get("size", Vector3(2, 4, 2)) as Vector3
		var color: Color = bld_def.get("color", dark_tint) as Color

		# Crea BoxMesh
		var box := MeshInstance3D.new()
		box.name = "Building"
		var bm := BoxMesh.new()
		bm.size = size
		box.mesh = bm
		box.position = pos

		# Materiale condiviso per tipo
		var color_key := "%d_%d_%d" % [int(color.r * 10), int(color.g * 10), int(color.b * 10)]
		if not material_cache.has(color_key):
			var mat := StandardMaterial3D.new()
			mat.albedo_color = color
			mat.roughness = 0.8
			mat.metallic = 0.05
			material_cache[color_key] = mat
		box.material_override = material_cache[color_key]

		world_root.add_child(box)

	# Strade
	var roads_root := Node3D.new()
	roads_root.name = "Roads"
	world_root.add_child(roads_root)

	var road_mat := StandardMaterial3D.new()
	road_mat.albedo_color = Color(0.16, 0.15, 0.14, 1)
	road_mat.roughness = 0.95

	for road_pts_variant in roads:
		var road_pts: PackedVector2Array = road_pts_variant as PackedVector2Array
		if road_pts.size() < 2:
			continue
		for i in range(road_pts.size() - 1):
			var p1 := Vector3(road_pts[i].x, 0.01, road_pts[i].y)
			var p2 := Vector3(road_pts[i + 1].x, 0.01, road_pts[i + 1].y)
			var mid := (p1 + p2) / 2
			var length := p1.distance_to(p2)
			if length < 0.5:
				continue
			var dir := (p2 - p1).normalized()
			var angle := atan2(dir.x, dir.z)

			var road_box := MeshInstance3D.new()
			road_box.name = "Road"
			var rm := BoxMesh.new()
			rm.size = Vector3(4.0, 0.05, length)
			road_box.mesh = rm
			road_box.position = mid
			road_box.rotation.y = angle
			road_box.material_override = road_mat
			roads_root.add_child(road_box)

	# Ground plane
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var gp := PlaneMesh.new()
	gp.size = Vector2(200, 200)
	ground.mesh = gp
	ground.rotation_degrees = Vector3(90, 0, 0)
	ground.position = Vector3(0, -0.02, 0)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.16, 0.14, 0.12, 1)
	gmat.roughness = 0.9
	ground.material_override = gmat
	world_root.add_child(ground)


func _build_fallback() -> void:
	# Griglia di edifici placeholder
	var root := Node3D.new()
	root.name = "CityRoot"
	add_child(root)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.38, 0.35, 0.28)

	for i in range(-8, 9):
		for j in range(-8, 9):
			if abs(i) < 2 and abs(j) < 2: continue
			if (i + j) % 3 == 0: continue

			var height_seed: int = abs(hash(str(i * 100 + j))) % 10
			var h: float = 3.0 + float(height_seed)
			var box := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(2.0, h, 2.0)
			box.mesh = bm
			box.position = Vector3(i * 3.5, h / 2, j * 3.5)
			box.material_override = mat
			root.add_child(box)

	print("  Built fallback city grid.")


func _spawn_player(city_data: Dictionary) -> void:
	var spawn: Vector3 = city_data.get("player_spawn", Vector3(0, 1.5, 5))

	_player = CharacterBody3D.new()
	_player.name = "Player"
	_player.position = spawn

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.height = 2.0; cap.radius = 0.4
	col.shape = cap
	_player.add_child(col)

	# Mesh visibile
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.6, 1.8, 0.6)
	body.mesh = bm
	body.position.y = 0.9
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.2, 0.5, 0.9)
	body.material_override = pm
	_player.add_child(body)

	add_child(_player)


func _build_return_portal(city_data: Dictionary) -> void:
	var return_map: String = city_data.get("return_map_id", "black_oak_city")

	var portal := Node3D.new()
	portal.name = "ReturnPortal"
	portal.position = Vector3(0, 1.5, -25)

	# Beam
	for i in range(5):
		var ring := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.height = 0.1; cyl.top_radius = 1.0 - i * 0.15; cyl.bottom_radius = 1.0 - i * 0.15
		ring.mesh = cyl
		ring.position.y = i * 0.8
		ring.rotation_degrees.x = 90
		var rm := StandardMaterial3D.new()
		rm.albedo_color = Color(0.5, 0.2, 1.0, 0.6)
		rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring.material_override = rm
		portal.add_child(ring)

	var label := Label3D.new()
	label.text = "[RITORNO AL BASTIONE]"
	label.position = Vector3(0, 4.5, 0)
	label.font_size = 20
	label.outline_size = 2
	label.modulate = Color(0.8, 0.4, 1.0)
	portal.add_child(label)

	# Area trigger
	var area := Area3D.new()
	area.name = "Trigger"
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 3.0
	col.shape = sph
	area.add_child(col)
	area.body_entered.connect(func(b: Node3D):
		if b == _player:
			var main_scene := "res://scenes/main/Main.tscn"
			if ResourceLoader.exists(main_scene):
				get_tree().change_scene_to_file(main_scene)
	)
	portal.add_child(area)

	add_child(portal)


func _setup_attribution(city_data: Dictionary) -> void:
	var attr_layer := CanvasLayer.new()
	attr_layer.name = "Attribution"
	attr_layer.layer = 100

	var panel := Panel.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0, 0, 0, 0.55)
	panel.add_theme_stylebox_override("panel", ps)

	var label := Label.new()
	label.text = "%s (c) OpenStreetMap contributors | ODbL" % city_data.display_name
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55, 0.85))
	panel.add_child(label)

	panel.position = Vector2(6, -6)
	panel.anchor_bottom = 1.0
	attr_layer.add_child(panel)
	add_child(attr_layer)
