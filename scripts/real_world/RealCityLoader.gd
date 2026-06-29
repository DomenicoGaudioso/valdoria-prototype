# RealCityLoader.gd — Caricamento città reali OSM con progress screen
# =============================================================================
# Carica asset locali .glb già importati. Nessun download runtime, nessuno streaming.
# Gestisce caricamento single-file e chunked (distretti).
# Mostra loading screen durante il caricamento e gestisce errori gracefully.

class_name RealCityLoader
extends Node

signal loading_started(city_name: String)
signal loading_progress(progress: float, status: String)
signal loading_complete()
signal loading_failed(reason: String)
signal chunk_activated(chunk_name: String)
signal chunk_deactivated(chunk_name: String)

const RealCityRegistry = preload("res://data/RealCityRegistry.gd")

var _city_data: Dictionary = {}
var _loaded_chunks: Dictionary = {}     # chunk_name → Node3D
var _active_chunks: Array[String] = []
var _chunk_manager: Node = null         # RealCityChunkManager ref
var _loading_screen: Control = null
var _total_steps: int = 0
var _current_step: int = 0


func load_city(city_id: String, target_parent: Node3D) -> Node3D:
	_city_data = RealCityRegistry.get_city(city_id)
	if _city_data.is_empty():
		loading_failed.emit("Città '%s' non trovata nel registro." % city_id)
		return target_parent

	loading_started.emit(_city_data.display_name)

	match _city_data.get("model_mode", "single"):
		"chunked":
			return await _load_chunked(target_parent)
		_:
			return await _load_single(target_parent)


func _load_single(parent: Node3D) -> Node3D:
	var model_path: String = _city_data.get("model_path", "")
	_total_steps = 3; _current_step = 0

	# Step 1: verificare file
	_progress("Verifica file modello...")
	if model_path.is_empty() or not FileAccess.file_exists(model_path):
		loading_failed.emit("File GLB non trovato: %s" % model_path)
		return _create_placeholder(parent)

	# Step 2: caricamento
	_progress("Caricamento %s..." % model_path.get_file())
	var scene: PackedScene = load(model_path) as PackedScene
	if not scene:
		loading_failed.emit("Impossibile caricare il modello: %s" % model_path)
		return _create_placeholder(parent)

	# Step 3: instanziazione
	_progress("Istanziazione modello 3D...")
	var instance := scene.instantiate()
	instance.name = "CityModel_" + _city_data.id
	parent.add_child(instance)

	# Applica scala e rotazione
	instance.scale = Vector3.ONE * float(_city_data.get("scale", 0.05))
	instance.rotation_degrees.y = float(_city_data.get("rotation_y", -35.0))

	_progress("Completato.", 1.0)
	loading_complete.emit()
	print("RealCityLoader: %s caricata (single)." % _city_data.display_name)
	return instance


func _load_chunked(parent: Node3D) -> Node3D:
	var chunks: Dictionary = _city_data.get("chunks", {})
	if chunks.is_empty():
		push_warning("RealCityLoader: modalità chunked ma nessun chunk definito. Fallback single.")
		return await _load_single(parent)

	_total_steps = chunks.size() + 2; _current_step = 0

	# Step 1: verifica
	_progress("Verifica %d distretti..." % chunks.size())

	var root := Node3D.new()
	root.name = "CityChunks_" + _city_data.id
	parent.add_child(root)

	# Carica ogni chunk
	for chunk_name in chunks:
		var chunk_path: String = chunks[chunk_name]
		_progress("Caricamento distretto: %s" % chunk_name)

		if FileAccess.file_exists(chunk_path):
			var chunk_scene: PackedScene = load(chunk_path) as PackedScene
			if chunk_scene:
				var chunk := chunk_scene.instantiate()
				chunk.name = "Chunk_" + chunk_name
				chunk.scale = Vector3.ONE * float(_city_data.get("scale", 0.05))
				root.add_child(chunk)
				_loaded_chunks[chunk_name] = chunk
				_active_chunks.append(chunk_name)
				print("  + %s: OK" % chunk_name)
			else:
				push_warning("  ! %s: caricamento fallito" % chunk_name)
		else:
			push_warning("  - %s: file non trovato (%s)" % [chunk_name, chunk_path])

	# Step 2: applica rotazione globale
	_progress("Applicazione rotazione globale...")
	root.rotation_degrees.y = float(_city_data.get("rotation_y", -35.0))

	_progress("Completato (%d/%d distretti caricati)." % [_loaded_chunks.size(), chunks.size()], 1.0)
	loading_complete.emit()
	print("RealCityLoader: %s caricata (%d chunks)." % [_city_data.display_name, _loaded_chunks.size()])
	return root


func _progress(status: String, prog: float = -1.0) -> void:
	_current_step += 1
	var p := float(_current_step) / float(max(_total_steps, 1)) if prog < 0 else prog
	loading_progress.emit(clamp(p, 0.0, 1.0), status)


func _create_placeholder(parent: Node3D) -> Node3D:
	push_warning("RealCityLoader: creazione placeholder per %s (GLB assente)" % _city_data.display_name)
	var root := Node3D.new()
	root.name = "Placeholder_" + _city_data.id

	var plane := MeshInstance3D.new()
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(20, 20)
	plane.mesh = plane_mesh
	plane.material_override = StandardMaterial3D.new()
	plane.material_override.albedo_color = Color(0.18, 0.16, 0.14)
	root.add_child(plane)

	var label := Label3D.new()
	label.text = _city_data.display_name + "\n[GLB DA IMPORTARE]\nVedi pipeline BBBike→OSM2World→Godot"
	label.position = Vector3(0, 3, 0)
	label.font_size = 28
	label.modulate = Color(0.9, 0.6, 0.2)
	root.add_child(label)

	parent.add_child(root)
	loading_complete.emit()
	return root


func set_loading_screen(screen: Control) -> void:
	_loading_screen = screen


func get_loaded_chunks() -> Dictionary:
	return _loaded_chunks


func get_active_chunks() -> Array[String]:
	return _active_chunks


func get_city_data() -> Dictionary:
	return _city_data
