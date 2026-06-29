# generate_real_world.gd — Build automatico delle scene 3D Tiles
# ==================================================================================
# Esegui con: godot --headless --script generate_real_world.gd
# Genera RealWorldMap.tscn, CitySelectionMenu.tscn, LoadingMapScreen.tscn.
#
# IMPORTANTE: il plugin 3D Tiles for Godot deve essere installato in addons/
# prima di eseguire questo script.

extends SceneTree

var _root: Node


func _init() -> void:
	print("=== VALDORIA — Generazione Scene 3D Tiles ===")
	var plugin_ready := _check_plugin()
	if not plugin_ready:
		print("AVVISO: Plugin '3D Tiles for Godot' non trovato.")
		print("  Le scene useranno nodi placeholder Node3D.")
		print("  Installa il plugin e riesegui questo script.")
	print("")

	_create_city_selection_menu()
	_create_loading_screen()
	_create_real_world_map()

	print("=== COMPLETATO. Apri l'Editor e verifica le scene in maps/real_world/ e ui/ ===")
	quit()


func _check_plugin() -> bool:
	return ClassDB.class_exists("CesiumGeoreference") or ClassDB.class_exists("Cesium3DTileset")


func _ensure_dir(path: String) -> void:
	var d := DirAccess.open("res://")
	if d and not d.dir_exists(path):
		d.make_dir_recursive(path)


func _instantiate_or_placeholder(class_name: String, fallback_type: String = "Node3D") -> Node:
	if ClassDB.class_exists(class_name):
		return ClassDB.instantiate(class_name)
	push_warning("generate_real_world: classe '%s' non trovata, uso %s placeholder." % [class_name, fallback_type])
	match fallback_type:
		"Node3D": return Node3D.new()
		"Control": return Control.new()
		"Node": return Node.new()
	return Node.new()


func _set_owners(node: Node) -> void:
	for c in node.get_children():
		c.owner = _root
		_set_owners(c)


func _finish(path: String) -> void:
	_set_owners(_root)
	var packed := PackedScene.new()
	var err := packed.pack(_root)
	if err == OK:
		_ensure_dir(path.get_base_dir())
		ResourceSaver.save(packed, path)
		print("  OK  %s" % path)
	else:
		print("  ERR pack %s  code=%d" % [path, err])


# ===== CitySelectionMenu.tscn =====

func _create_city_selection_menu() -> void:
	_root = Control.new()
	_root.name = "CitySelectionMenu"
	_root.set_script(load("res://ui/CitySelectionMenu.gd"))
	# La UI viene costruita a runtime da _build_ui() in _ready()
	_finish("res://ui/CitySelectionMenu.tscn")


# ===== LoadingMapScreen.tscn =====

func _create_loading_screen() -> void:
	_root = CanvasLayer.new()
	_root.name = "LoadingMapScreen"
	_root.layer = 100

	var loading_control := Control.new()
	loading_control.name = "LoadingScreen"
	loading_control.set_script(load("res://ui/LoadingMapScreen.gd"))
	_root.add_child(loading_control)

	_finish("res://ui/LoadingMapScreen.tscn")


# ===== RealWorldMap.tscn =====

func _create_real_world_map() -> void:
	_root = Node3D.new()
	_root.name = "RealWorldMap"
	_root.set_script(load("res://maps/real_world/RealWorldMap.gd"))

	# === CesiumGeoreference (plugin) ===
	var georef := _instantiate_or_placeholder("CesiumGeoreference", "Node3D")
	georef.name = "CesiumGeoreference"
	_root.add_child(georef)

	# === Cesium3DTileset (plugin) ===
	var tileset := _instantiate_or_placeholder("Cesium3DTileset", "Node3D")
	tileset.name = "Cesium3DTileset"
	_root.add_child(tileset)

	# === Illuminazione ===
	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	_root.add_child(sun)

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.25, 0.28, 0.35)
	env.background_mode = Environment.BG_SKY
	world_env.environment = env
	_root.add_child(world_env)

	# === Collisioni gameplay ===
	var collision_root := StaticBody3D.new()
	collision_root.name = "GameplayCollisionLayer"
	collision_root.collision_layer = 1
	_root.add_child(collision_root)

	var ground_shape_node := CollisionShape3D.new()
	ground_shape_node.name = "GroundPlane"
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(10000, 0.5, 10000)
	ground_shape_node.shape = ground_shape
	ground_shape_node.position = Vector3(0, -1, 0)
	collision_root.add_child(ground_shape_node)

	# === PlayerSpawnController ===
	var spawn_ctrl := Node3D.new()
	spawn_ctrl.name = "PlayerSpawnController"
	spawn_ctrl.set_script(load("res://maps/real_world/PlayerSpawnController.gd"))
	spawn_ctrl.set("cesium_georeference", georef)
	_root.add_child(spawn_ctrl)

	# === CitySelector ===
	var city_sel := Node.new()
	city_sel.name = "CitySelector"
	city_sel.set_script(load("res://maps/real_world/CitySelector.gd"))
	_root.add_child(city_sel)

	# === MapLoader ===
	var map_ldr := Node.new()
	map_ldr.name = "MapLoader"
	map_ldr.set_script(load("res://maps/real_world/MapLoader.gd"))
	map_ldr.set("_city_selector", city_sel)
	_root.add_child(map_ldr)

	# === UI: LoadingMapScreen ===
	var loading_cl := CanvasLayer.new()
	loading_cl.name = "LoadingMapLayer"
	loading_cl.layer = 100
	var loading_screen := Control.new()
	loading_screen.name = "LoadingScreen"
	loading_screen.set_script(load("res://ui/LoadingMapScreen.gd"))
	loading_screen.set("map_loader", map_ldr)
	loading_cl.add_child(loading_screen)
	_root.add_child(loading_cl)

	# === UI: MapCreditsPanel ===
	var credits_cl := CanvasLayer.new()
	credits_cl.name = "CreditsLayer"
	credits_cl.layer = 90
	var credits_panel := Control.new()
	credits_panel.name = "CreditsPanel"
	credits_panel.set_script(load("res://ui/MapCreditsPanel.gd"))
	credits_cl.add_child(credits_panel)
	_root.add_child(credits_cl)

	_finish("res://maps/real_world/RealWorldMap.tscn")
