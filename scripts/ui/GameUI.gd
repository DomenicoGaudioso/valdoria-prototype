extends CanvasLayer

## GameUI - HUD, inventory, equipment and game-over overlay.

@export var player: Node2D

const EQUIP_SLOTS: Array[String] = ["weapon", "armor", "helmet", "boots", "ring", "amulet", "belt", "relic"]
const SLOT_LABELS: Dictionary = {
	"weapon": "Arma",
	"armor": "Armatura",
	"helmet": "Elmo",
	"boots": "Stivali",
	"ring": "Anello",
	"amulet": "Amuleto",
	"belt": "Cintura",
	"relic": "Reliquia",
}

var _health_bar: Range
var _health_label: Label
var _inventory_panel: Panel
var _inventory_list: VBoxContainer
var _inventory_button: Button
var _inventory_close_button: Button
var _debug_label: Label
var _attack_button: Button
var _game_over_overlay: Control
var _restart_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_initialize_ui")


func _initialize_ui() -> void:
	_find_ui_nodes()
	_ensure_game_over_overlay()
	_connect_player_signals()
	_connect_input_signals()
	_connect_inventory()
	_connect_ui_buttons()

	if _inventory_panel:
		_inventory_panel.hide()
	_update_health_display()


func _find_ui_nodes() -> void:
	_health_bar = get_node_or_null("MarginContainer/VBoxContainer/HealthBar") as Range
	_health_label = get_node_or_null("MarginContainer/VBoxContainer/HealthLabel") as Label
	_inventory_panel = get_node_or_null("InventoryPanel") as Panel
	if _inventory_panel:
		_inventory_list = _find_descendant(_inventory_panel, "InventoryList") as VBoxContainer
		_inventory_close_button = _find_descendant(_inventory_panel, "CloseButton") as Button
	_inventory_button = get_node_or_null("ButtonContainer/HBoxContainer/InventoryButton") as Button
	_attack_button = get_node_or_null("ButtonContainer/HBoxContainer/AttackButton") as Button
	_debug_label = get_node_or_null("DebugLabel") as Label
	_game_over_overlay = get_node_or_null("GameOverOverlay") as Control
	if _game_over_overlay:
		_restart_button = _find_descendant(_game_over_overlay, "RestartButton") as Button


func _find_descendant(root_node: Node, wanted_name: String) -> Node:
	if root_node == null:
		return null
	if root_node.name == wanted_name:
		return root_node
	for child in root_node.get_children():
		var found := _find_descendant(child, wanted_name)
		if found:
			return found
	return null


func _connect_player_signals() -> void:
	if not player:
		player = get_node_or_null("/root/Main/Player")

	if player:
		if player.has_signal("health_changed") and not player.health_changed.is_connected(_on_player_health_changed):
			player.health_changed.connect(_on_player_health_changed)
		if player.has_signal("died") and not player.died.is_connected(_on_player_died):
			player.died.connect(_on_player_died)
		if player.has_signal("equipment_changed") and not player.equipment_changed.is_connected(_on_equipment_changed):
			player.equipment_changed.connect(_on_equipment_changed)
		if player.has_signal("gold_changed") and not player.gold_changed.is_connected(_on_gold_changed):
			player.gold_changed.connect(_on_gold_changed)


func _connect_input_signals() -> void:
	# InputController is connected by GameBootstrap; this script only reacts to UI buttons.
	pass


func _connect_inventory() -> void:
	var inventory := get_node_or_null("/root/Inventory")
	if inventory and inventory.has_signal("inventory_changed"):
		if not inventory.inventory_changed.is_connected(_on_inventory_changed):
			inventory.inventory_changed.connect(_on_inventory_changed)


func _connect_ui_buttons() -> void:
	if _attack_button and not _attack_button.pressed.is_connected(_on_attack_pressed):
		_attack_button.pressed.connect(_on_attack_pressed)
	if _inventory_button and not _inventory_button.pressed.is_connected(_toggle_inventory):
		_inventory_button.pressed.connect(_toggle_inventory)
	if _inventory_close_button and not _inventory_close_button.pressed.is_connected(_close_inventory):
		_inventory_close_button.pressed.connect(_close_inventory)
	for slot in EQUIP_SLOTS:
		var button := _get_unequip_button(slot)
		if button and not button.pressed.is_connected(_on_unequip_pressed.bind(slot)):
			button.pressed.connect(_on_unequip_pressed.bind(slot))


func _on_player_health_changed(_current: int, _max_val: int) -> void:
	_update_health_display()
	_refresh_inventory_display()


func _on_equipment_changed(_slot: String, _item) -> void:
	_refresh_inventory_display()


func _on_gold_changed(_gold: int) -> void:
	_refresh_inventory_display()


func _on_inventory_changed() -> void:
	_refresh_inventory_display()


func _on_player_died() -> void:
	if _debug_label:
		_debug_label.text = "GAME OVER"
		_debug_label.show()
	_show_game_over()


func _update_health_display() -> void:
	if not player:
		return
	var current_hp: int = int(player.get("current_hp"))
	var max_hp: int = int(player.get("max_hp"))
	if _health_bar:
		_health_bar.max_value = max_hp
		_health_bar.value = current_hp
	if _health_label:
		_health_label.text = "%d / %d" % [current_hp, max_hp]


func _toggle_inventory() -> void:
	if not _inventory_panel:
		return
	_inventory_panel.visible = not _inventory_panel.visible
	if _inventory_panel.visible:
		_refresh_inventory_display()
		if _inventory_button:
			_inventory_button.text = "Chiudi"
	else:
		if _inventory_button:
			_inventory_button.text = "Zaino (I)"


func _close_inventory() -> void:
	if _inventory_panel:
		_inventory_panel.hide()
	if _inventory_button:
		_inventory_button.text = "Zaino (I)"


func _refresh_inventory_display() -> void:
	if not _inventory_panel:
		return
	_refresh_equipment_slots()
	_refresh_stats_summary()
	_refresh_inventory_rows()


func _refresh_equipment_slots() -> void:
	for slot in EQUIP_SLOTS:
		var label := _get_slot_value_label(slot)
		var button := _get_unequip_button(slot)
		var equipped = _get_equipped_item(slot)
		if label:
			if equipped:
				label.text = "%s  %s" % [equipped.name, _stat_line(equipped)]
				label.add_theme_color_override("font_color", equipped.get_rarity_color())
			else:
				label.text = "-- vuoto --"
				label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		if button:
			button.visible = equipped != null


func _refresh_stats_summary() -> void:
	var gold_label := _find_descendant(_inventory_panel, "GoldLabel") as Label
	if gold_label and player:
		gold_label.text = "Oro: %d" % int(player.get("gold"))

	var stats_label := _find_descendant(_inventory_panel, "StatsLabel") as Label
	if stats_label and player:
		var ascension := int(player.get("ascension_level"))
		stats_label.text = "ATT:%d | DIF:%d | HP:%d | VEL:%d | AGI:%d | Liv.%d | Asc.%d" % [
			int(player.get("attack_damage")),
			int(player.get("defense")),
			int(player.get("max_hp")),
			int(player.get("move_speed")),
			int(player.get("agility")),
			int(player.get("level")),
			ascension,
		]


func _refresh_inventory_rows() -> void:
	if not _inventory_list:
		return
	for child in _inventory_list.get_children():
		child.queue_free()

	var inventory := get_node_or_null("/root/Inventory")
	if not inventory or inventory.items.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Zaino vuoto. Sconfiggi nemici per ottenere equipaggiamenti."
		empty_label.add_theme_color_override("font_color", Color(0.54, 0.64, 0.70))
		empty_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.70))
		empty_label.add_theme_constant_override("outline_size", 2)
		empty_label.add_theme_font_size_override("font_size", 12)
		_inventory_list.add_child(empty_label)
		return

	for item in inventory.items:
		_inventory_list.add_child(_build_inventory_row(item, inventory))


func _make_inventory_row_style(item) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var rarity_color := Color(0.34, 0.48, 0.58, 0.34)
	if item != null and item.has_method("get_rarity_color"):
		var c: Color = item.get_rarity_color()
		rarity_color = Color(c.r, c.g, c.b, 0.38)
	style.bg_color = Color(0.018, 0.024, 0.040, 0.68)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = rarity_color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style


func _style_inventory_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.038, 0.055, 0.082, 0.94)
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.border_width_top = 1
	normal.border_width_bottom = 1
	normal.border_color = Color(0.34, 0.80, 1.0, 0.60)
	normal.corner_radius_top_left = 3
	normal.corner_radius_top_right = 3
	normal.corner_radius_bottom_left = 3
	normal.corner_radius_bottom_right = 3

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.060, 0.090, 0.128, 0.98)
	hover.border_color = Color(0.80, 0.58, 1.0, 0.86)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.025, 0.145, 0.185, 1.0)
	pressed.border_color = Color(0.22, 1.0, 0.94, 1.0)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color(0.78, 0.94, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.86, 0.72))
	button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.72))
	button.add_theme_constant_override("outline_size", 2)
	button.add_theme_font_size_override("font_size", 11)


func _build_inventory_row(item, inventory: Node) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_inventory_row_style(item))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	var name_label := Label.new()
	name_label.text = item.name
	if int(item.get("quantity")) > 1:
		name_label.text += " x%d" % int(item.get("quantity"))
	name_label.add_theme_color_override("font_color", item.get_rarity_color())
	name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.70))
	name_label.add_theme_constant_override("outline_size", 2)
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.custom_minimum_size = Vector2(150.0, 0.0)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var stat_label := Label.new()
	stat_label.text = _stat_line(item)
	stat_label.add_theme_color_override("font_color", Color(0.68, 0.84, 0.92))
	stat_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.62))
	stat_label.add_theme_constant_override("outline_size", 1)
	stat_label.add_theme_font_size_override("font_size", 11)
	stat_label.custom_minimum_size = Vector2(230.0, 0.0)
	row.add_child(stat_label)

	if _is_equipment(item):
		var equip_button := Button.new()
		equip_button.text = "Indossa"
		equip_button.custom_minimum_size = Vector2(78.0, 26.0)
		_style_inventory_button(equip_button)
		equip_button.pressed.connect(_on_equip_pressed.bind(item, inventory))
		row.add_child(equip_button)

	return panel


func _on_equip_pressed(item, inventory: Node) -> void:
	if not player or not _is_equipment(item):
		return
	if inventory and inventory.has_method("remove_item"):
		inventory.remove_item(item)
	var previous = player.equip_item(item.slot, item)
	if previous and inventory and inventory.has_method("add_item"):
		inventory.add_item(previous)
	_refresh_inventory_display()


func _on_unequip_pressed(slot: String) -> void:
	if not player or not player.has_method("unequip_item"):
		return
	var removed = player.unequip_item(slot)
	if removed:
		var inventory := get_node_or_null("/root/Inventory")
		if inventory and inventory.has_method("add_item"):
			inventory.add_item(removed)
	_refresh_inventory_display()


func _get_equipped_item(slot: String):
	if not player:
		return null
	var equipment: Dictionary = player.get("equipment")
	return equipment.get(slot)


func _get_slot_value_label(slot: String) -> Label:
	return _find_descendant(_inventory_panel, "Slot_%s" % slot) as Label


func _get_unequip_button(slot: String) -> Button:
	return _find_descendant(_inventory_panel, "UnEquip_%s" % slot) as Button


func _is_equipment(item) -> bool:
	return item != null and item.get("slot") is String and not String(item.get("slot")).is_empty()


func _stat_line(item) -> String:
	if item == null:
		return ""
	var line := "ATT %+d  DIF %+d  HP %+d  VEL %+d  AGI %+d" % [
		int(item.get("stat_damage")),
		int(item.get("stat_armor")),
		int(item.get("stat_health")),
		int(item.get("stat_speed")),
		int(item.get("stat_agility")),
	]
	var rank := String(item.get("rank"))
	var upgrade := int(item.get("upgrade_level"))
	if not rank.is_empty() and rank != "E":
		line += "  R:%s" % rank
	if upgrade > 0:
		line += " +%d" % upgrade
	return line


func _ensure_game_over_overlay() -> void:
	if _game_over_overlay:
		_setup_restart_button()
		return

	_game_over_overlay = Control.new()
	_game_over_overlay.name = "GameOverOverlay"
	_game_over_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_game_over_overlay.anchor_right = 1.0
	_game_over_overlay.anchor_bottom = 1.0
	_game_over_overlay.visible = false
	add_child(_game_over_overlay)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	_game_over_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	_game_over_overlay.add_child(center)

	var box := VBoxContainer.new()
	box.name = "VBoxContainer"
	box.custom_minimum_size = Vector2(360.0, 150.0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	var title := Label.new()
	title.name = "Title"
	title.text = "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.24, 0.18, 1.0))
	title.add_theme_font_size_override("font_size", 46)
	box.add_child(title)

	_restart_button = Button.new()
	_restart_button.name = "RestartButton"
	_restart_button.text = "Riavvia"
	_restart_button.custom_minimum_size = Vector2(190.0, 48.0)
	_restart_button.focus_mode = Control.FOCUS_ALL
	_style_restart_button(_restart_button)
	box.add_child(_restart_button)
	_setup_restart_button()


func _setup_restart_button() -> void:
	if not _restart_button:
		return
	_restart_button.process_mode = Node.PROCESS_MODE_ALWAYS
	if not _restart_button.pressed.is_connected(_restart_current_game):
		_restart_button.pressed.connect(_restart_current_game)


func _show_game_over() -> void:
	_ensure_game_over_overlay()
	if _game_over_overlay:
		_game_over_overlay.show()
		_game_over_overlay.move_to_front()
	if _restart_button:
		_restart_button.grab_focus()
	get_tree().paused = true


func _restart_current_game() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _style_restart_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.02, 0.02, 0.96)
	normal.border_color = Color(1.0, 0.36, 0.20, 0.95)
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_width_top = 2
	normal.border_width_bottom = 2
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.20, 0.04, 0.03, 1.0)
	hover.border_color = Color(1.0, 0.72, 0.36, 1.0)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.32, 0.08, 0.04, 1.0)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color(1.0, 0.84, 0.70, 1.0))
	button.add_theme_font_size_override("font_size", 20)


func _on_attack_pressed() -> void:
	if _inventory_panel and _inventory_panel.visible:
		return

	var input_ctrl := get_node_or_null("/root/InputController")
	if input_ctrl:
		input_ctrl.attack_command.emit(null)


func show_debug_message(msg: String) -> void:
	if _debug_label:
		_debug_label.text = msg
		_debug_label.show()
		await get_tree().create_timer(3.0).timeout
		_debug_label.hide()
