extends CanvasLayer
## MobileControls — Virtual joystick + action buttons for Android/touch.
## Appears automatically on mobile platforms, hidden on desktop.

signal move_vector_changed(direction: Vector2)
signal mobile_attack
signal mobile_dash
signal mobile_skill(skill_id: String)
signal mobile_inventory
signal mobile_interact
signal mobile_travel

const JOYSTICK_RADIUS := 80.0
const JOYSTICK_DEADZONE := 15.0

var _joystick_base: Control
var _joystick_knob: Control
var _joystick_touch_index: int = -1
var _attack_button: Button
var _dash_button: Button
var _inventory_button: Button
var _travel_button: Button
var _skill_buttons: Array[Button] = []

var _base_center: Vector2
var _current_direction: Vector2 = Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100  # topmost UI layer

	if not _is_mobile():
		queue_free()
		return

	_create_joystick()
	_create_attack_button()
	_create_dash_button()
	_create_skill_buttons()
	_create_inventory_button()
	_create_travel_button()

func _is_mobile() -> bool:
	var os_name: String = OS.get_name()
	return os_name in ["Android", "iOS", "Web"] or OS.has_feature("mobile")


func _create_joystick() -> void:
	_joystick_base = Control.new()
	_joystick_base.name = "JoystickBase"
	_joystick_base.custom_minimum_size = Vector2(JOYSTICK_RADIUS * 2.8, JOYSTICK_RADIUS * 2.8)
	_joystick_base.pivot_offset = Vector2(JOYSTICK_RADIUS * 1.4, JOYSTICK_RADIUS * 1.4)
	_joystick_base.anchor_left = 0.0
	_joystick_base.anchor_bottom = 1.0
	_joystick_base.offset_left = 40
	_joystick_base.offset_bottom = -40
	_joystick_base.offset_right = JOYSTICK_RADIUS * 2.8 + 40
	_joystick_base.offset_top = -(JOYSTICK_RADIUS * 2.8) - 40
	add_child(_joystick_base)

	var base_bg := ColorRect.new()
	base_bg.name = "BaseBg"
	base_bg.size = Vector2(JOYSTICK_RADIUS * 2.8, JOYSTICK_RADIUS * 2.8)
	base_bg.color = Color(1.0, 1.0, 1.0, 0.08)
	_joystick_base.add_child(base_bg)

	var base_ring := _make_circle(JOYSTICK_RADIUS * 1.3, JOYSTICK_RADIUS * 1.4, JOYSTICK_RADIUS * 1.4,
		Color(0.3, 0.7, 1.0, 0.25), Color(0.2, 0.5, 0.9, 0.5), 3.0)
	_joystick_base.add_child(base_ring)

	_joystick_knob = Control.new()
	_joystick_knob.name = "JoystickKnob"
	_joystick_knob.custom_minimum_size = Vector2(JOYSTICK_RADIUS * 1.1, JOYSTICK_RADIUS * 1.1)
	_joystick_knob.pivot_offset = Vector2(JOYSTICK_RADIUS * 0.55, JOYSTICK_RADIUS * 0.55)
	_joystick_knob.position = Vector2(JOYSTICK_RADIUS * 0.85, JOYSTICK_RADIUS * 0.85)
	_joystick_base.add_child(_joystick_knob)
	_base_center = _joystick_knob.position + _joystick_knob.pivot_offset

	var knob_circle := _make_circle(JOYSTICK_RADIUS * 0.5, JOYSTICK_RADIUS * 0.55, JOYSTICK_RADIUS * 0.55,
		Color(0.4, 0.85, 1.0, 0.55), Color(0.55, 0.92, 1.0, 0.7), 2.5)
	_joystick_knob.add_child(knob_circle)

	_joystick_base.gui_input.connect(_on_joystick_input)


func _make_circle(radius: float, w: float, h: float, fill: Color, border: Color, border_w: float) -> Control:
	var container := Control.new()
	container.custom_minimum_size = Vector2(w, h)
	var draw_node := Control.new()
	draw_node.custom_minimum_size = Vector2(w, h)
	draw_node.draw.connect(func():
		var center := Vector2(w * 0.5, h * 0.5)
		draw_node.draw_circle(center, radius, fill)
		if border_w > 0:
			draw_node.draw_arc(center, radius, 0, TAU, 64, border, border_w)
	)
	container.add_child(draw_node)
	return container


func _on_joystick_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _joystick_touch_index < 0:
			_joystick_touch_index = event.index
			_update_knob(event.position)
		elif not event.pressed and event.index == _joystick_touch_index:
			_joystick_touch_index = -1
			_reset_knob()
	elif event is InputEventScreenDrag and event.index == _joystick_touch_index:
		_update_knob(event.position)


func _update_knob(screen_pos: Vector2) -> void:
	var local_pos := _joystick_base.get_local_mouse_position()
	var offset := local_pos - _base_center

	if offset.length() < JOYSTICK_DEADZONE:
		offset = Vector2.ZERO

	var clamped := offset.limit_length(JOYSTICK_RADIUS)
	_joystick_knob.position = _base_center + clamped - _joystick_knob.pivot_offset

	_current_direction = offset.normalized() * min(offset.length() / JOYSTICK_RADIUS, 1.0)
	move_vector_changed.emit(_current_direction)


func _reset_knob() -> void:
	var tw := create_tween()
	tw.tween_property(_joystick_knob, "position", _base_center - _joystick_knob.pivot_offset, 0.1)
	_current_direction = Vector2.ZERO
	move_vector_changed.emit(Vector2.ZERO)


func _create_attack_button() -> void:
	_attack_button = Button.new()
	_attack_button.name = "MobileAttack"
	_attack_button.text = ""
	_attack_button.custom_minimum_size = Vector2(90, 90)
	_attack_button.anchor_left = 1.0
	_attack_button.anchor_bottom = 1.0
	_attack_button.offset_left = -140
	_attack_button.offset_bottom = -50
	_attack_button.offset_right = -50
	_attack_button.offset_top = -140
	_style_action_button(_attack_button, Color(0.85, 0.2, 0.15, 0.45), Color(0.95, 0.3, 0.2, 0.65))
	_attack_button.pressed.connect(func(): mobile_attack.emit())
	add_child(_attack_button)

	var atk_label := Label.new()
	atk_label.text = "⚔"
	atk_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	atk_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	atk_label.anchor_right = 1.0; atk_label.anchor_bottom = 1.0
	atk_label.add_theme_font_size_override("font_size", 32)
	atk_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.7))
	_attack_button.add_child(atk_label)


func _create_dash_button() -> void:
	_dash_button = Button.new()
	_dash_button.name = "MobileDash"
	_dash_button.text = ""
	_dash_button.custom_minimum_size = Vector2(72, 72)
	_dash_button.anchor_left = 1.0
	_dash_button.anchor_bottom = 1.0
	_dash_button.offset_left = -226
	_dash_button.offset_bottom = -60
	_dash_button.offset_right = -154
	_dash_button.offset_top = -132
	_style_action_button(_dash_button, Color(0.12, 0.55, 0.75, 0.45), Color(0.18, 0.78, 1.0, 0.65))
	_dash_button.pressed.connect(func(): mobile_dash.emit())
	add_child(_dash_button)

	var label := Label.new()
	label.text = "DASH"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.74, 0.94, 1.0))
	_dash_button.add_child(label)


func _create_skill_buttons() -> void:
	var skills := [
		{"id": "charged_shot", "label": "1", "x": -302, "y": -58, "color": Color(0.18, 0.50, 0.95, 0.44)},
		{"id": "piercing_shot", "label": "2", "x": -350, "y": -112, "color": Color(0.48, 0.24, 0.92, 0.44)},
		{"id": "arcane_burst", "label": "3", "x": -294, "y": -166, "color": Color(0.12, 0.75, 0.62, 0.44)},
		{"id": "guardian_aegis", "label": "4", "x": -238, "y": -184, "color": Color(0.95, 0.58, 0.16, 0.44)},
	]
	for def in skills:
		var btn := Button.new()
		btn.name = "MobileSkill_%s" % String(def["id"])
		btn.text = ""
		btn.custom_minimum_size = Vector2(48, 48)
		btn.anchor_left = 1.0
		btn.anchor_bottom = 1.0
		btn.offset_left = float(def["x"])
		btn.offset_bottom = float(def["y"])
		btn.offset_right = float(def["x"]) + 48.0
		btn.offset_top = float(def["y"]) - 48.0
		var base_color: Color = def["color"]
		_style_action_button(btn, base_color, Color(min(base_color.r + 0.16, 1.0), min(base_color.g + 0.16, 1.0), min(base_color.b + 0.16, 1.0), 0.66))
		var skill_id := String(def["id"])
		btn.pressed.connect(func(): mobile_skill.emit(skill_id))
		add_child(btn)
		_skill_buttons.append(btn)

		var label := Label.new()
		label.text = String(def["label"])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.anchor_right = 1.0
		label.anchor_bottom = 1.0
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
		btn.add_child(label)


func _create_inventory_button() -> void:
	_inventory_button = Button.new()
	_inventory_button.name = "MobileInventory"
	_inventory_button.text = ""
	_inventory_button.custom_minimum_size = Vector2(60, 60)
	_inventory_button.anchor_left = 1.0
	_inventory_button.anchor_top = 0.0
	_inventory_button.offset_left = -70
	_inventory_button.offset_top = 10
	_inventory_button.offset_right = -10
	_inventory_button.offset_bottom = 70
	_style_action_button(_inventory_button, Color(0.15, 0.45, 0.85, 0.45), Color(0.2, 0.6, 0.95, 0.65))
	_inventory_button.pressed.connect(func(): mobile_inventory.emit())
	add_child(_inventory_button)

	var inv_label := Label.new()
	inv_label.text = "📦"
	inv_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inv_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inv_label.anchor_right = 1.0; inv_label.anchor_bottom = 1.0
	inv_label.add_theme_font_size_override("font_size", 22)
	inv_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_inventory_button.add_child(inv_label)


func _create_travel_button() -> void:
	_travel_button = Button.new()
	_travel_button.name = "MobileTravel"
	_travel_button.text = ""
	_travel_button.custom_minimum_size = Vector2(60, 60)

	_travel_button.anchor_left = 1.0
	_travel_button.anchor_right = 1.0
	_travel_button.anchor_top = 0.0
	_travel_button.offset_left = -140
	_travel_button.offset_top = 10
	_travel_button.offset_right = -80
	_travel_button.offset_bottom = 70
	_style_action_button(_travel_button, Color(0.55, 0.35, 0.15, 0.45), Color(0.75, 0.5, 0.2, 0.65))
	_travel_button.pressed.connect(func(): mobile_travel.emit())
	add_child(_travel_button)

	var trv_label := Label.new()
	trv_label.text = "🗺"
	trv_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trv_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	trv_label.anchor_right = 1.0; trv_label.anchor_bottom = 1.0
	trv_label.add_theme_font_size_override("font_size", 22)
	trv_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4))
	_travel_button.add_child(trv_label)


func _style_action_button(btn: Button, normal_color: Color, hover_color: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = normal_color
	normal.border_width_left = 2; normal.border_width_right = 2
	normal.border_width_top = 2; normal.border_width_bottom = 2
	normal.border_color = Color(1.0, 1.0, 1.0, 0.3)
	normal.corner_radius_top_left = 45; normal.corner_radius_top_right = 45
	normal.corner_radius_bottom_left = 45; normal.corner_radius_bottom_right = 45

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = hover_color
	hover.border_color = Color(1.0, 1.0, 1.0, 0.6)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
