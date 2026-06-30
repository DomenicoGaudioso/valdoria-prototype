extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")


func _initialize() -> void:
	var failed: Array[String] = []
	var world := MAIN_SCENE.instantiate()
	root.add_child(world)
	for _i in range(12):
		await process_frame

	var controls := world.get_node_or_null("MobileControls")
	var input_controller := root.get_node_or_null("InputController")
	if controls == null:
		failed.append("MobileControls missing with ELDRATH_FORCE_MOBILE_CONTROLS=1")
	if input_controller == null:
		failed.append("missing InputController")
	if failed.is_empty():
		await _check_mobile_buttons(controls, input_controller, failed)

	world.queue_free()
	await process_frame

	if failed.is_empty():
		print("Mobile controls smoke test OK")
		quit(0)
	else:
		push_error("Mobile controls failures: %s" % ", ".join(failed))
		quit(1)


func _check_mobile_buttons(controls: Node, input_controller: Node, failed: Array[String]) -> void:
	var counts := {
		"move": 0,
		"attack": 0,
		"dash": 0,
		"skill": 0,
		"inventory": 0,
		"travel": 0,
	}
	input_controller.move_vector_command.connect(func(_dir: Vector2): counts["move"] += 1)
	input_controller.attack_command.connect(func(_target): counts["attack"] += 1)
	input_controller.dash_command.connect(func(): counts["dash"] += 1)
	input_controller.skill_command.connect(func(_skill_id: String): counts["skill"] += 1)
	input_controller.toggle_inventory.connect(func(): counts["inventory"] += 1)
	input_controller.travel_command.connect(func(): counts["travel"] += 1)

	if controls.has_signal("move_vector_changed"):
		controls.emit_signal("move_vector_changed", Vector2.RIGHT)
		controls.emit_signal("move_vector_changed", Vector2.ZERO)
	await process_frame

	_press_named(controls, "MobileAttack", failed)
	_press_named(controls, "MobileDash", failed)
	_press_named(controls, "MobileSkill_charged_shot", failed)
	_press_named(controls, "MobileInventory", failed)
	_press_named(controls, "MobileTravel", failed)
	for _i in range(3):
		await process_frame

	if int(counts["move"]) < 2:
		failed.append("joystick signal did not reach InputController")
	if int(counts["attack"]) < 1:
		failed.append("attack button did not emit attack_command")
	if int(counts["dash"]) < 1:
		failed.append("dash button did not emit dash_command")
	if int(counts["skill"]) < 1:
		failed.append("skill button did not emit skill_command")
	if int(counts["inventory"]) < 1:
		failed.append("inventory button did not emit toggle_inventory")
	if int(counts["travel"]) < 1:
		failed.append("travel button did not emit travel_command")


func _press_named(root_node: Node, node_name: String, failed: Array[String]) -> void:
	var node := _find_named(root_node, node_name)
	var button := node as Button
	if button == null:
		failed.append("missing mobile button %s" % node_name)
		return
	button.emit_signal("pressed")


func _find_named(root_node: Node, node_name: String) -> Node:
	if root_node.name == node_name:
		return root_node
	for child in root_node.get_children():
		var found := _find_named(child, node_name)
		if found:
			return found
	return null
