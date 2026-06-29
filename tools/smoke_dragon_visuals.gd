extends SceneTree

const MAIN_SCENE = preload("res://scenes/main/Main.tscn")


func _initialize() -> void:
	var world := MAIN_SCENE.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	var failed: Array[String] = []
	await _probe_dragon(world, "dragon", Vector2(320.0, 320.0), Vector2i(256, 256), failed)
	await _probe_dragon(world, "dragon_b", Vector2(460.0, 320.0), Vector2i(128, 128), failed)

	world.queue_free()
	await process_frame

	if failed.is_empty():
		print("Dragon visual smoke test OK")
		quit(0)
	else:
		push_error("Dragon visual smoke failures: %s" % ", ".join(failed))
		quit(1)


func _probe_dragon(world: Node, enemy_type: String, pos: Vector2, expected_frame: Vector2i, failed: Array[String]) -> void:
	if not world.has_method("_spawn"):
		failed.append("GameBootstrap missing _spawn")
		return
	world.call("_spawn", enemy_type, pos)
	await process_frame

	var enemy := _find_enemy(world, enemy_type)
	if enemy == null:
		failed.append("%s missing enemy node" % enemy_type)
		return

	var sprite := enemy.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		failed.append("%s missing Sprite2D" % enemy_type)
		return
	if int(sprite.region_rect.size.x) != expected_frame.x or int(sprite.region_rect.size.y) != expected_frame.y:
		failed.append("%s wrong region %s expected %s" % [enemy_type, str(sprite.region_rect.size), str(expected_frame)])
	if sprite.position.y > -70.0:
		failed.append("%s sprite pivot too low: %s" % [enemy_type, str(sprite.position)])

	var glow := enemy.get_node_or_null("SpriteGlow") as Sprite2D
	if glow == null:
		failed.append("%s missing SpriteGlow" % enemy_type)

	var health_bar := enemy.get_node_or_null("HealthBar") as ProgressBar
	if health_bar == null:
		failed.append("%s missing HealthBar" % enemy_type)
	elif health_bar.custom_minimum_size.x < 80.0:
		failed.append("%s health bar too small" % enemy_type)


func _find_enemy(world: Node, enemy_type: String) -> Node:
	var expected_name := "Drago Antico" if enemy_type == "dragon" else "Drago Supremo"
	for child in world.get_children():
		if child is CharacterBody2D and child.name.begins_with(expected_name):
			return child
	return null
