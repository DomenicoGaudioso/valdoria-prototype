extends Node

## InputController — Centralized input handler.
## Converts mouse, touch, and keyboard events into abstract game commands.
## The rest of the game never checks for specific input types directly.

signal move_command(world_position: Vector2)
signal attack_command(target: Node2D)
signal toggle_inventory
signal interact_command(target: Node2D)

@export var touch_deadzone: float = 10.0
@export var touch_min_duration: float = 0.05
@export var touch_max_duration: float = 0.3
@export var ui_layer: CanvasLayer

var _touch_start_position: Vector2 = Vector2.ZERO
var _touch_start_time: float = 0.0
var _is_touching: bool = false
var _touch_over_ui: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
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
