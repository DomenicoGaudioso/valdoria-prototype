# RealWorldMapAdapter.gd — Adattamento modello OSM2World allo stile Valdoria
# =============================================================================
# Prende un modello .glb importato e lo trasforma per adattarlo a:
#   - Vista isometrica (camera angolata, non FPS)
#   - Stile dark fantasy (materiali desaturati, palette scura)
#   - Performance mobile-friendly (merge mesh, simplify, LOD)
#
# Uso: chiamare adapt_model() dopo aver istanziato il .glb nella scena.

class_name RealWorldMapAdapter
extends Node

## Nodo root del modello importato (scena istanziata dal .glb)
@export var model_root: Node3D

## Scala applicata al modello (dipende dall'export OSM2World)
@export var import_scale: float = 0.08

## Rotazione sull'asse Y per allineare alla visuale isometrica
@export var yaw_degrees: float = -35.0

## Colore dominante per i materiali dark fantasy
@export var dark_palette_tint: Color = Color(0.35, 0.30, 0.28, 1.0)

## Mantenere texture originali (false = applica solo tint)
@export var keep_textures: bool = true

## Disabilita mesh troppo piccole (sotto questa dimensione in metri)
@export var cull_small_mesh_threshold: float = 0.3

## Aggiunge un piano ombra sotto ogni mesh
@export var add_shadow_planes: bool = true


func adapt_model() -> void:
	if not model_root:
		push_error("RealWorldMapAdapter: model_root non assegnato.")
		return

	model_root.scale = Vector3(import_scale, import_scale, import_scale)
	model_root.rotation_degrees.y = yaw_degrees

	_adapt_materials(model_root)
	_cull_small_meshes(model_root)
	_generate_collision_simplified(model_root)
	if add_shadow_planes:
		_add_ground_shadow(model_root)

	print("RealWorldMapAdapter: modello adattato. Scala=%.3f, Rotazione=%.1f°" % [import_scale, yaw_degrees])


func _adapt_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mat_count := mi.get_surface_override_material_count()
		for i in range(mat_count):
			var mat := mi.get_surface_override_material(i)
			if mat and mat is StandardMaterial3D:
				var sm := mat as StandardMaterial3D
				if not keep_textures:
					sm.albedo_color = sm.albedo_color.lerp(dark_palette_tint, 0.6)
					sm.albedo_texture = null
				else:
					sm.albedo_color = sm.albedo_color.lerp(dark_palette_tint, 0.35)
				sm.metallic = clamp(sm.metallic * 0.4, 0.0, 0.5)
				sm.roughness = clamp(sm.roughness * 1.3, 0.5, 1.0)
				sm.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			elif mat and mat is ORMMaterial3D:
				var om := mat as ORMMaterial3D
				om.albedo_color = om.albedo_color.lerp(dark_palette_tint, 0.4)
				om.roughness = clamp(om.roughness * 1.2, 0.5, 1.0)

	for child in node.get_children():
		_adapt_materials(child)


func _cull_small_meshes(node: Node) -> void:
	var to_remove: Array[Node] = []
	for child in node.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			var aabb := mi.get_aabb()
			var diag := aabb.size.length()
			if diag < cull_small_mesh_threshold:
				to_remove.append(child)
		_cull_small_meshes(child)
	for n in to_remove:
		n.queue_free()


func _generate_collision_simplified(node: Node) -> void:
	var collision_parent := _find_or_create_collision_root()
	for child in node.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			var body := StaticBody3D.new()
			body.name = "Col_" + mi.name
			var shape := CollisionShape3D.new()
			shape.name = "Shape_" + mi.name

			var aabb := mi.get_aabb()
			var box := BoxShape3D.new()
			box.size = aabb.size * 0.85
			shape.shape = box
			shape.position = aabb.get_center()

			body.add_child(shape)
			collision_parent.add_child(body)
		_generate_collision_simplified(child)


func _find_or_create_collision_root() -> Node3D:
	var root := get_parent()
	if root:
		var cr := root.get_node_or_null("CollisionRoot")
		if cr:
			return cr as Node3D
	return self


func _add_ground_shadow(node: Node) -> void:
	var shadow_parent := _find_or_create_shadow_root()
	for child in node.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			var aabb := mi.get_aabb()
			var center := mi.global_position + aabb.get_center()

			var shadow := MeshInstance3D.new()
			shadow.name = "Shadow_" + mi.name
			var plane := PlaneMesh.new()
			plane.size = Vector2(aabb.size.x * 1.2, aabb.size.z * 1.2)
			shadow.mesh = plane
			shadow.position = Vector3(center.x, 0.02, center.z)
			shadow.rotation_degrees = Vector3(90, 0, 0)

			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.0, 0.0, 0.0, 0.35)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			shadow.material_override = mat
			shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

			shadow_parent.add_child(shadow)
		_add_ground_shadow(child)


func _find_or_create_shadow_root() -> Node3D:
	var root := get_parent()
	if root:
		var sr := root.get_node_or_null("ShadowRoot")
		if sr:
			return sr as Node3D
	return self
