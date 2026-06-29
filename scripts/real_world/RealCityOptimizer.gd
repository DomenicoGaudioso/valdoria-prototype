# RealCityOptimizer.gd — Ottimizzazione modelli città per Godot
# =============================================================================
# Trasforma un modello .glb importato per adattarlo a:
#   - Vista isometrica (camera ortografica angolata)
#   - Stile dark fantasy Valdoria (desaturazione, palette scura)
#   - Performance (merge mesh statiche, collisioni semplificate, LOD)
#
# Uso: chiamare optimize() dopo _load_city(), passando il Node3D root del modello.

class_name RealCityOptimizer
extends Node

## Nodo root del modello città importato
@export var city_root: Node3D

## Applicare stile dark fantasy (desaturazione, palette scura)
@export var apply_dark_style: bool = true

## Colore dominante per la palette scura
@export var dark_tint: Color = Color(0.35, 0.30, 0.26, 1.0)

## Intensità della desaturazione (0=nessuna, 1=completa)
@export var desaturate_strength: float = 0.4

## Generare collisioni semplificate
@export var generate_collisions: bool = true

## Dimensione minima mesh (sotto questa, viene nascosta)
@export var cull_below_size: float = 0.2

## Disabilitare ombre su mesh piccole
@export var disable_shadows_on_small: bool = true

## Soglia per "mesh piccola" (in metri)
@export var small_mesh_threshold: float = 1.0

## Eseguire merge mesh statiche (riduce draw calls)
@export var merge_static_meshes: bool = false

## Mantenere texture originali
@export var keep_textures: bool = true

## Rimuovere nodi non-mesh (luci, camere importate)
@export var remove_non_mesh: bool = true

var _stats := {"meshes_total": 0, "meshes_culled": 0, "materials_adapted": 0, "collision_bodies": 0}


func optimize() -> Dictionary:
	if not city_root:
		push_error("RealCityOptimizer: city_root non assegnato.")
		return _stats

	_stats = {"meshes_total": 0, "meshes_culled": 0, "materials_adapted": 0, "collision_bodies": 0}

	if remove_non_mesh:
		_remove_non_mesh_nodes(city_root)
	_count_meshes(city_root)
	if apply_dark_style:
		_adapt_materials(city_root)
	_cull_tiny_meshes(city_root)
	if generate_collisions:
		_generate_collisions(city_root)
	if disable_shadows_on_small:
		_disable_shadows_small(city_root)

	print("RealCityOptimizer: ottimizzato. Stats: ", _stats)
	return _stats


func _count_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		_stats["meshes_total"] += 1
	for child in node.get_children():
		_count_meshes(child)


func _adapt_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in range(mi.get_surface_override_material_count()):
			var mat := mi.get_surface_override_material(i)
			if mat:
				_apply_dark_palette(mat)
				_stats["materials_adapted"] += 1
		var surf_count := mi.mesh.get_surface_count() if mi.mesh else 0
		for i in range(surf_count):
			var mat := mi.get_active_material(i)
			if mat:
				_apply_dark_palette(mat)
	for child in node.get_children():
		_adapt_materials(child)


func _apply_dark_palette(mat: Material) -> void:
	if mat is StandardMaterial3D:
		var sm := mat as StandardMaterial3D
		if not keep_textures:
			sm.albedo_color = sm.albedo_color.lerp(dark_tint, 0.6 + desaturate_strength * 0.3)
			sm.albedo_texture = null
		else:
			sm.albedo_color = sm.albedo_color.lerp(dark_tint, desaturate_strength)
		sm.metallic = clamp(sm.metallic * 0.3, 0.0, 0.4)
		sm.roughness = clamp(sm.roughness * 1.2, 0.5, 1.0)
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	elif mat is ORMMaterial3D:
		var om := mat as ORMMaterial3D
		om.albedo_color = om.albedo_color.lerp(dark_tint, desaturate_strength)
		om.roughness = clamp(om.roughness * 1.1, 0.5, 1.0)


func _cull_tiny_meshes(node: Node) -> void:
	var to_remove: Array[Node] = []
	for child in node.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			var aabb := mi.get_aabb()
			if aabb.size.length() < cull_below_size:
				to_remove.append(child)
				_stats["meshes_culled"] += 1
		_cull_tiny_meshes(child)
	for n in to_remove:
		n.queue_free()


func _generate_collisions(node: Node) -> void:
	var col_parent := _find_or_create("CollisionRoot")
	for child in node.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			var aabb := mi.get_aabb()
			var world_aabb := AABB(
				mi.global_position + aabb.position,
				aabb.size
			)

			var body := StaticBody3D.new()
			body.name = "Col_" + mi.name
			body.collision_layer = 1
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = aabb.size * 0.85
			shape.shape = box
			shape.position = world_aabb.get_center()
			body.add_child(shape)
			col_parent.add_child(body)
			_stats["collision_bodies"] += 1
		_generate_collisions(child)


func _disable_shadows_small(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var aabb := mi.get_aabb()
		if aabb.size.length() < small_mesh_threshold:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_disable_shadows_small(child)


func _remove_non_mesh_nodes(node: Node) -> void:
	var to_remove: Array[Node] = []
	for child in node.get_children():
		if child is Light3D or child is Camera3D:
			to_remove.append(child)
		else:
			_remove_non_mesh_nodes(child)
	for n in to_remove:
		n.queue_free()


func _find_or_create(name: String) -> Node3D:
	var p := get_parent()
	if p:
		var existing := p.get_node_or_null(name)
		if existing:
			return existing as Node3D
		var n := Node3D.new()
		n.name = name
		p.add_child(n)
		return n
	return city_root


func get_stats() -> Dictionary:
	return _stats
