# RealCityChunkManager.gd — Gestione distretti per città grandi
# =============================================================================
# Attiva/disattiva i chunk della città in base alla posizione del player,
# riducendo il carico di rendering e memoria per città estese.
#
# Ogni chunk ha:
#   - un AABB di attivazione (bounding box)
#   - una distanza di attivazione (activation_radius)
#   - uno stato (active, inactive, loading)
#
# Uso tipico: collegato a RealCityController, chiamato ogni frame.

class_name RealCityChunkManager
extends Node

@export var activation_radius: float = 60.0       # metri nel mondo Godot
@export var deactivation_radius: float = 90.0      # margine per evitare flickering
@export var player_node: Node3D                    # per calcolare distanza
@export var chunk_check_interval: float = 0.3      # secondi tra controlli

var _chunks: Dictionary = {}      # chunk_name → {"node": Node3D, "aabb": AABB, "active": bool}
var _timer: float = 0.0


func register_chunks(chunks: Dictionary) -> void:
	for name in chunks:
		var node: Node3D = chunks[name]
		_chunks[name] = {
			"node": node,
			"aabb": _compute_aabb(node),
			"active": true,
		}
	print("RealCityChunkManager: registrati %d chunk." % _chunks.size())


func _compute_aabb(node: Node3D) -> AABB:
	var aabb := AABB()
	for child in node.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			var child_aabb := mi.get_aabb()
			aabb = aabb.merge(child_aabb)
	if aabb.size.length() < 1.0:
		aabb = AABB(Vector3(-20, -5, -20), Vector3(40, 10, 40))
	return aabb


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 or not player_node or _chunks.is_empty():
		return
	_timer = chunk_check_interval
	_update_chunks()


func _update_chunks() -> void:
	var player_pos := player_node.global_position
	for name in _chunks:
		var chunk := _chunks[name]
		var node: Node3D = chunk["node"]
		var aabb: AABB = chunk["aabb"]

		# Centro del chunk in coordinate mondo
		var world_aabb := AABB(
			node.global_position + aabb.position,
			aabb.size
		)
		var dist := _distance_to_aabb(player_pos, world_aabb)

		if dist <= activation_radius and not chunk["active"]:
			_activate_chunk(name)
		elif dist > deactivation_radius and chunk["active"]:
			_deactivate_chunk(name)


func _activate_chunk(name: String) -> void:
	var chunk := _chunks[name]
	chunk["node"].visible = true
	chunk["node"].process_mode = Node.PROCESS_MODE_INHERIT
	chunk["active"] = true


func _deactivate_chunk(name: String) -> void:
	var chunk := _chunks[name]
	chunk["node"].visible = false
	chunk["node"].process_mode = Node.PROCESS_MODE_DISABLED
	chunk["active"] = false


func _distance_to_aabb(point: Vector3, aabb: AABB) -> float:
	var closest := Vector3(
		clamp(point.x, aabb.position.x, aabb.position.x + aabb.size.x),
		clamp(point.y, aabb.position.y, aabb.position.y + aabb.size.y),
		clamp(point.z, aabb.position.z, aabb.position.z + aabb.size.z)
	)
	return point.distance_to(closest)


func force_activate_all() -> void:
	for name in _chunks:
		_activate_chunk(name)


func force_deactivate_all() -> void:
	for name in _chunks:
		_deactivate_chunk(name)


func get_active_count() -> int:
	var count := 0
	for name in _chunks:
		if _chunks[name]["active"]:
			count += 1
	return count
