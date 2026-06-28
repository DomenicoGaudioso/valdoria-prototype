extends CanvasLayer

## GameUI — Main UI layer.
## Health bar, inventory button/panel, debug info.

@export var player: Node2D

var _health_bar: ColorRect
var _health_label: Label
var _inventory_panel: Panel
var _inventory_list: VBoxContainer
var _inventory_button: Button
var _debug_label: Label
var _attack_button: Button


func _ready() -> void:
	_find_ui_nodes()
	_connect_player_signals()
	_connect_input_signals()
	_connect_inventory()

	if _inventory_panel:
		_inventory_panel.hide()
	_update_health_display()

	if _attack_button:
		_attack_button.pressed.connect(_on_attack_pressed)


func _find_ui_nodes() -> void:
	_health_bar = get_node_or_null("MarginContainer/VBoxContainer/HealthBar") as ColorRect
	_health_label = get_node_or_null("MarginContainer/VBoxContainer/HealthLabel") as Label
	_inventory_panel = get_node_or_null("InventoryPanel") as Panel
	_inventory_list = get_node_or_null("InventoryPanel/VBoxContainer/ScrollContainer/InventoryList") as VBoxContainer
	_inventory_button = get_node_or_null("ButtonContainer/HBoxContainer/InventoryButton") as Button
	_attack_button = get_node_or_null("ButtonContainer/HBoxContainer/AttackButton") as Button
	_debug_label = get_node_or_null("DebugLabel") as Label


func _connect_player_signals() -> void:
	if not player:
		player = get_node_or_null("/root/Main/Player")

	if player:
		if player.has_signal("health_changed"):
			player.health_changed.connect(_on_player_health_changed)
		if player.has_signal("died"):
			player.died.connect(_on_player_died)


func _connect_input_signals() -> void:
	# Input connections handled by GameBootstrap
	pass


func _connect_inventory() -> void:
	var inventory := get_node_or_null("/root/Inventory")
	if inventory:
		inventory.inventory_changed.connect(_refresh_inventory_display)

	if _inventory_button:
		_inventory_button.pressed.connect(_toggle_inventory)


func _on_player_health_changed(current: int, max_val: int) -> void:
	_update_health_display()


func _on_player_died() -> void:
	if _debug_label:
		_debug_label.text = "SEI MORTO"
		_debug_label.show()


func _update_health_display() -> void:
	# Handled directly by GameBootstrap lambda
	pass


func _toggle_inventory() -> void:
	_inventory_panel.visible = not _inventory_panel.visible
	if _inventory_panel.visible:
		_refresh_inventory_display()
		if _inventory_button:
			_inventory_button.text = "Chiudi"
	else:
		if _inventory_button:
			_inventory_button.text = "Zaino"


func _refresh_inventory_display() -> void:
	if not _inventory_list:
		return

	for child in _inventory_list.get_children():
		child.queue_free()

	var inventory := get_node_or_null("/root/Inventory")
	if not inventory:
		return

	if inventory.items.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Inventario vuoto"
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_inventory_list.add_child(empty_label)
		return

	for item in inventory.items:
		var row := HBoxContainer.new()

		var name_label := Label.new()
		var qty_text := ""
		if item.stackable and item.quantity > 1:
			qty_text = " x%d" % item.quantity
		name_label.text = item.name + qty_text
		name_label.add_theme_color_override("font_color", item.get_rarity_color())
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		var type_label := Label.new()
		type_label.text = item.type
		type_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		row.add_child(type_label)

		_inventory_list.add_child(row)


func _on_attack_pressed() -> void:
	if _inventory_panel.visible:
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
