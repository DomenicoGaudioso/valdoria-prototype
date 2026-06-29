extends Node

## InputController — Centralized input handler.
## Converts mouse, touch, keyboard, and mobile joystick into abstract game commands.

signal move_command(world_position: Vector2)
signal move_vector_command(direction: Vector2)  # continuous movement from joystick
signal attack_command(target: Node2D)
signal dash_command
signal skill_command(skill_id: String)
signal toggle_inventory
signal interact_command(target: Node2D)
signal travel_command  # mobile travel/map button

@export var touch_deadzone: float = 10.0
@export var touch_min_duration: float = 0.05
@export var touch_max_duration: float = 0.3
@export var ui_layer: CanvasLayer
@export var mobile_controls_path: NodePath

var _touch_start_position: Vector2 = Vector2.ZERO
var _touch_start_time: float = 0.0
var _is_touching: bool = false
var _touch_over_ui: bool = false
var _mobile_controls: CanvasLayer
var _joystick_active: bool = false
var _joystick_direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_connect_mobile")


func _connect_mobile() -> void:
	if mobile_controls_path and not mobile_controls_path.is_empty():
		_mobile_controls = get_node_or_null(mobile_controls_path) as CanvasLayer
	elif has_node("/root/Main/MobileControls"):
		_mobile_controls = get_node_or_null("/root/Main/MobileControls") as CanvasLayer

	if _mobile_controls and _mobile_controls.has_signal("move_vector_changed"):
		if not _mobile_controls.move_vector_changed.is_connected(_on_joystick_move):
			_mobile_controls.move_vector_changed.connect(_on_joystick_move)
	if _mobile_controls and _mobile_controls.has_signal("mobile_attack"):
		if not _mobile_controls.mobile_attack.is_connected(_on_mobile_attack):
			_mobile_controls.mobile_attack.connect(_on_mobile_attack)
	if _mobile_controls and _mobile_controls.has_signal("mobile_dash"):
		if not _mobile_controls.mobile_dash.is_connected(_on_mobile_dash):
			_mobile_controls.mobile_dash.connect(_on_mobile_dash)
	if _mobile_controls and _mobile_controls.has_signal("mobile_skill"):
		if not _mobile_controls.mobile_skill.is_connected(_on_mobile_skill):
			_mobile_controls.mobile_skill.connect(_on_mobile_skill)
	if _mobile_controls and _mobile_controls.has_signal("mobile_inventory"):
		if not _mobile_controls.mobile_inventory.is_connected(_on_mobile_inventory):
			_mobile_controls.mobile_inventory.connect(_on_mobile_inventory)
	if _mobile_controls and _mobile_controls.has_signal("mobile_travel"):
		if not _mobile_controls.mobile_travel.is_connected(_on_mobile_travel):
			_mobile_controls.mobile_travel.connect(_on_mobile_travel)


func _on_joystick_move(dir: Vector2) -> void:
	_joystick_active = dir.length_squared() > 0.001
	_joystick_direction = dir
	move_vector_command.emit(dir)


func _on_mobile_attack() -> void:
	attack_command.emit(null)


func _on_mobile_dash() -> void:
	dash_command.emit()


func _on_mobile_skill(skill_id: String) -> void:
	skill_command.emit(skill_id)


func _on_mobile_inventory() -> void:
	toggle_inventory.emit()


func _on_mobile_travel() -> void:
	travel_command.emit()


func _process(_delta: float) -> void:
	if _joystick_active:
		move_vector_command.emit(_joystick_direction)

func _input(event: InputEvent) -> void:
	if _is_activation_event(event):
		var audio := get_node_or_null("/root/ProceduralAudio")
		if audio and audio.has_method("start_after_user_gesture"):
			audio.start_after_user_gesture()
	if event is InputEventMouseButton:
		_handle_mouse(event)
	elif event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventKey:
		if event.pressed:
			_handle_key(event)

func _handle_mouse(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return

	if _is_point_over_ui(event.position):
		return

	var viewport := get_viewport()
	var vsize := viewport.get_visible_rect().size
	var camera := viewport.get_camera_2d()
	
	var world_pos: Vector2
	if camera:
		var cam_pos := camera.global_position
		var zoom := camera.zoom
		# Manual screen-to-world: center of screen = camera position
		world_pos = cam_pos + (event.position - vsize * 0.5) / zoom
	else:
		world_pos = event.position
	
	move_command.emit(world_pos)

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _is_point_over_ui(event.position):
			_touch_over_ui = true
			return

		_touch_start_position = event.position
		_touch_start_time = Time.get_ticks_msec() / 1000.0
		_is_touching = true
		_touch_over_ui = false
	else:
		if _touch_over_ui:
			return

		var duration := (Time.get_ticks_msec() / 1000.0) - _touch_start_time
		var distance := event.position.distance_to(_touch_start_position)

		if duration >= touch_min_duration and duration <= touch_max_duration and distance <= touch_deadzone:
			var viewport := get_viewport()
			var camera := viewport.get_camera_2d()
			var world_position: Vector2

			if camera:
				world_position = camera.get_screen_transform().affine_inverse() * _touch_start_position
			else:
				world_position = _touch_start_position

			move_command.emit(world_position)

		_is_touching = false
		_touch_over_ui = false

func _handle_key(event: InputEventKey) -> void:
	print("KEY: ", event.keycode, " pressed=", event.pressed)
	match event.keycode:
		KEY_I:
			toggle_inventory.emit()
		KEY_SPACE:
			attack_command.emit(null)
		KEY_SHIFT:
			dash_command.emit()
		KEY_1:
			skill_command.emit("charged_shot")
		KEY_2:
			skill_command.emit("piercing_shot")
		KEY_3:
			skill_command.emit("arcane_burst")
		KEY_4:
			skill_command.emit("guardian_aegis")
		KEY_ESCAPE:
			toggle_inventory.emit()

func _is_point_over_ui(screen_position: Vector2) -> bool:
	if not ui_layer:
		return false

	var controls := ui_layer.get_children()
	for control: Control in controls:
		if control.visible and control.get_global_rect().has_point(screen_position):
			return true
	return false

func get_world_position_from_screen(screen_position: Vector2) -> Vector2:
	var viewport := get_viewport()
	var camera := viewport.get_camera_2d()
	if camera:
		return camera.get_screen_transform().affine_inverse() * screen_position
	return screen_position


func _is_activation_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.pressed
	if event is InputEventScreenTouch:
		return event.pressed
	if event is InputEventKey:
		return event.pressed
	return false
