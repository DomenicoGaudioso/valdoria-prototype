# PlayerSpawnController.gd — Posizionamento player nel mondo 3D reale
# ==================================================================================
# Converte coordinate WGS84 (lat, lon, height) in posizione Godot 3D.
# Il plugin 3D Tiles for Godot include un CesiumGeoreference che gestisce
# la conversione automatica tra WGS84 e coordinate ECEF/engine.
#
# Collegamenti richiesti nel plugin:
#   - CesiumGeoreference: definisce l'origine geodetica della scena
#   - CesiumGlobeAnchor: nodo child per posizionare oggetti su lat/lon/alt

extends Node3D

@export var player_scene: PackedScene            # Player.tscn 3D
@export var cesium_georeference: Node             # CesiumGeoreference del plugin
@export var spawn_height_offset: float = 2.0      # offset verticale dal suolo in metri

var _player: Node3D = null
var _spawned: bool = false


func spawn_player_at_wgs84(lat: float, lon: float, height: float) -> Node3D:
	if not player_scene:
		push_error("PlayerSpawnController: player_scene non assegnato.")
		return null

	if _spawned and is_instance_valid(_player):
		_player.queue_free()

	_player = player_scene.instantiate()
	_player.name = "Player"

	# Posizionamento tramite CesiumGlobeAnchor (plugin 3D Tiles for Godot)
	# Se il plugin fornisce CesiumGlobeAnchor, lo aggiungiamo come child
	# al player e settiamo lat/lon/height. Altrimenti usiamo il georeference
	# direttamente per la conversione.
	var anchor := _find_or_create_globe_anchor(_player)
	if anchor:
		anchor.set("latitude", lat)
		anchor.set("longitude", lon)
		anchor.set("height", height + spawn_height_offset)
	else:
		# Fallback: conversione manuale tramite CesiumGeoreference
		# (dipende dall'API specifica del plugin)
		if cesium_georeference and cesium_georeference.has_method("transform_wgs84_to_ecef"):
			var ecef := cesium_georeference.transform_wgs84_to_ecef(lat, lon, height + spawn_height_offset)
			_player.global_position = ecef
		else:
			# Posizionamento grezzo: assumiamo che il georeference abbia già
			# impostato l'origine sulle coordinate della città selezionata.
			_player.global_position = Vector3(0, height + spawn_height_offset, 0)

	add_child(_player)
	_spawned = true

	print("PlayerSpawnController: player spawnato a lat=%.4f lon=%.4f alt=%.1f" % [lat, lon, height])
	return _player


func _find_or_create_globe_anchor(parent: Node3D) -> Node:
	# Cerca un CesiumGlobeAnchor esistente o ne crea uno
	# Nota: il nome esatto della classe dipende dal plugin.
	# Possibili nomi: "CesiumGlobeAnchor", "GlobeAnchor", "CesiumAnchor"
	for child in parent.get_children():
		var cname := child.get_class()
		if cname.find("GlobeAnchor") >= 0 or cname.find("CesiumAnchor") >= 0:
			return child

	# Se non esiste, creiamo un nodo generico e commentiamo il settaggio
	var anchor := Node3D.new()
	anchor.name = "CesiumGlobeAnchor"
	parent.add_child(anchor)
	return anchor


func move_player_to_city(city_data: Dictionary) -> Node3D:
	var lat: float = city_data.get("lat", 0.0)
	var lon: float = city_data.get("lon", 0.0)
	var height: float = city_data.get("height", 500.0)
	return spawn_player_at_wgs84(lat, lon, height)


func get_player() -> Node3D:
	return _player


func remove_player() -> void:
	if _player:
		_player.queue_free()
		_player = null
	_spawned = false
