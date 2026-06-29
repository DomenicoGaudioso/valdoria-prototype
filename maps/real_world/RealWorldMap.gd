# RealWorldMap.gd — Scena principale per il mondo reale 3D Tiles
# ==================================================================================
# Scena: RealWorldMap.tscn
# Struttura nodi:
#   RealWorldMap (Node3D)                         ← questo script
#   ├── CesiumGeoreference                         ← plugin 3D Tiles for Godot
#   ├── Cesium3DTileset                             ← plugin: tileset principale
#   ├── CesiumGlobeAnchor (Player Anchor)           ← plugin: ancoraggio player
#   ├── SunLight (DirectionalLight3D)               ← illuminazione
#   ├── PlayerSpawnController                       ← spawn player
#   ├── GameplayCollisionLayer (StaticBody3D)       ← collisioni semplificate
#   ├── LoadingMapScreen (CanvasLayer)              ← UI caricamento
#   └── MapCreditsPanel (CanvasLayer)               ← UI crediti

extends Node3D

@export var cesium_ion_token: String = ""           # Token API Cesium ion
@export var google_api_key: String = ""             # Google Map Tiles API key
@export var default_city: String = "new_york"       # Città predefinita

var _map_loader: MapLoader
var _city_selector: Node
var _player_spawn_controller: PlayerSpawnController
var _tileset_node: Node                               # Cesium3DTileset
var _georeference_node: Node                           # CesiumGeoreference
var _loading_screen: CanvasLayer
var _credits_panel: CanvasLayer
var _current_city_data: Dictionary = {}


func _ready() -> void:
	_setup_scene()
	_load_default_city()


func _setup_scene() -> void:
	# === GEOREFERENCE (plugin 3D Tiles for Godot) ===
	# NOTA: Il nome esatto della classe dipende dal plugin installato.
	# Dopo aver installato "3D Tiles for Godot", trascinare qui il nodo
	# CesiumGeoreference e Cesium3DTileset dall'editor, oppure crearli via codice.
	_georeference_node = _create_plugin_node("CesiumGeoreference")
	if _georeference_node:
		_georeference_node.name = "CesiumGeoreference"
		_georeference_node.set("ion_access_token", cesium_ion_token)
		add_child(_georeference_node)

	# === TILESET 3D (plugin) ===
	_tileset_node = _create_plugin_node("Cesium3DTileset")
	if _tileset_node:
		_tileset_node.name = "Cesium3DTileset"
		# L'asset ID e il tileset ID vanno settati dopo la selezione città
		add_child(_tileset_node)

	# === ILLUMINAZIONE ===
	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)

	var ambient := WorldEnvironment.new()
	ambient.name = "WorldEnvironment"
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.25, 0.28, 0.35)
	env.background_mode = Environment.BG_SKY
	ambient.environment = env
	add_child(ambient)

	# === PLAYER SPAWN CONTROLLER ===
	_player_spawn_controller = PlayerSpawnController.new()
	_player_spawn_controller.name = "PlayerSpawnController"
	_player_spawn_controller.cesium_georeference = _georeference_node
	_player_spawn_controller.player_scene = load("res://scenes/player/Player.tscn")
	add_child(_player_spawn_controller)

	# === COLLISION LAYER per gameplay ===
	_add_gameplay_collision_layer()

	# === CITY SELECTOR ===
	_city_selector = CitySelector.new()
	_city_selector.name = "CitySelector"
	add_child(_city_selector)

	# === UI: Loading Screen ===
	_loading_screen = _build_loading_screen()
	add_child(_loading_screen)

	# === UI: Credits Panel ===
	_credits_panel = _build_credits_panel()
	add_child(_credits_panel)

	# === MAP LOADER ===
	_map_loader = MapLoader.new()
	_map_loader.name = "MapLoader"
	_map_loader.set_city_selector(_city_selector)
	add_child(_map_loader)
	_map_loader.loading_progress.connect(_on_loading_progress)
	_map_loader.map_loaded.connect(_on_map_loaded)
	_map_loader.map_load_failed.connect(_on_map_load_failed)


func _create_plugin_node(class_name: String) -> Node:
	# Prova a creare il nodo del plugin tramite ClassDB.
	# Se il plugin non e installato, stampa un warning.
	if ClassDB.class_exists(class_name):
		return ClassDB.instantiate(class_name)
	else:
		push_warning("RealWorldMap: classe '%s' non trovata. Plugin '3D Tiles for Godot' installato?" % class_name)
		# Nodo placeholder per non bloccare la scena
		return Node3D.new()


func _add_gameplay_collision_layer() -> void:
	var collision_root := StaticBody3D.new()
	collision_root.name = "GameplayCollisionLayer"
	collision_root.collision_layer = 1
	add_child(collision_root)

	# Piano orizzontale di base (evita che il player cada nel vuoto)
	var ground := CollisionShape3D.new()
	ground.name = "GroundPlane"
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(10000, 0.5, 10000)
	ground.shape = ground_shape
	ground.position = Vector3(0, -1, 0)
	collision_root.add_child(ground)

	# Area giocabile: mesh proxy invisibile per zone pedonali/strade
	# In futuro, queste possono essere generate da OSM o definite manualmente.
	# Per ora, un grande piano su cui il player puo camminare.


func _load_default_city() -> void:
	_load_city(default_city)


func _load_city(city_id: String) -> void:
	_current_city_data = CityDatabase.get_city(city_id)
	if _current_city_data.is_empty():
		push_error("RealWorldMap: città '%s' non trovata nel database." % city_id)
		return

	_map_loader.load_real_city(city_id)
	_loading_screen.visible = true
	if _loading_screen.has_method("show_screen"):
		_loading_screen.show_screen()


func _on_loading_progress(progress: float, status: String) -> void:
	# Propagato alla LoadingMapScreen
	pass


func _on_map_loaded(city_id: String) -> void:
	# Configura il tileset con l'asset ID
	var city := CityDatabase.get_city(city_id)
	if city.is_empty():
		return

	var asset_id: int = city.get("cesium_asset_id", 0)
	var tileset_id: String = city.get("google_tileset_id", "")

	if _tileset_node:
		# Settaggio proprieta del plugin (nomi esatti dipendono dal plugin)
		if _tileset_node.has_method("set_ion_asset_id"):
			_tileset_node.set_ion_asset_id(asset_id)
		elif "ion_asset_id" in _tileset_node:
			_tileset_node.set("ion_asset_id", asset_id)

		# Se disponibile Google Tileset
		if not tileset_id.is_empty() and _tileset_node.has_method("set_google_tileset_id"):
			_tileset_node.set_google_tileset_id(tileset_id)

	# Posiziona il player nella citta
	if _player_spawn_controller:
		_player_spawn_controller.move_player_to_city(city)

	# Nascondi schermata caricamento
	_loading_screen.visible = false
	if _loading_screen.has_method("hide_screen"):
		_loading_screen.hide_screen()

	print("RealWorldMap: città '%s' caricata. Player posizionato." % city.display_name)


func _on_map_load_failed(reason: String) -> void:
	push_error("RealWorldMap: caricamento fallito — %s" % reason)
	_loading_screen.visible = false

	# Fallback: carica mappa classica
	var bootstrap := get_node_or_null("/root/Main/GameBootstrap")
	if bootstrap and bootstrap.has_method("_load_map"):
		bootstrap._load_map("black_oak_city")


func _build_loading_screen() -> CanvasLayer:
	var cl := CanvasLayer.new()
	cl.name = "LoadingMapScreen"
	cl.layer = 100
	var ls := Control.new()
	ls.name = "LoadingScreen"
	ls.set_script(load("res://ui/LoadingMapScreen.gd"))
	ls.set("map_loader", _map_loader)
	cl.add_child(ls)
	return cl


func _build_credits_panel() -> CanvasLayer:
	var cl := CanvasLayer.new()
	cl.name = "MapCreditsLayer"
	cl.layer = 90
	var cp := Control.new()
	cp.name = "CreditsPanel"
	cp.set_script(load("res://ui/MapCreditsPanel.gd"))
	cl.add_child(cp)
	return cl


func change_city(city_id: String) -> void:
	if _player_spawn_controller:
		_player_spawn_controller.remove_player()
	_load_city(city_id)


func get_current_city_data() -> Dictionary:
	return _current_city_data


func toggle_credits() -> void:
	if _credits_panel and _credits_panel.has_method("toggle"):
		_credits_panel.toggle()
