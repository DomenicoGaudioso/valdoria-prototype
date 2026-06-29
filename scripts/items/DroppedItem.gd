extends Area2D

## DroppedItem — An item lying on the ground.
## Can be picked up by the player when entering its pickup area.

signal picked_up(item_data)

var item_data
@export var pickup_cooldown: float = 0.5
@export var lifetime: float = 60.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _label: Label = $Label

var _pickup_enabled: bool = false


func _ready() -> void:
	add_to_group("items")

	if item_data:
		_setup_from_data()
	_start_idle_fx()

	body_entered.connect(_on_body_entered)

	await get_tree().create_timer(pickup_cooldown).timeout
	_pickup_enabled = true

	if lifetime > 0:
		await get_tree().create_timer(lifetime).timeout
		_fade_out()


func _setup_from_data() -> void:
	if _label:
		_label.text = item_data.name
		_label.add_theme_color_override("font_color", item_data.get_rarity_color())
		_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
		_label.add_theme_constant_override("outline_size", 3)

	if _sprite:
		if item_data.icon:
			_sprite.texture = item_data.icon
		else:
			_sprite.modulate = item_data.get_rarity_color()


func set_item_data(data) -> void:
	item_data = data
	_setup_from_data()
	_start_idle_fx()


func _start_idle_fx() -> void:
	if not _sprite:
		return
	var base_position := _sprite.position
	var base_scale := _sprite.scale
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(_sprite, "position:y", base_position.y - 5.0, 0.85).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_sprite, "scale", base_scale * 1.08, 0.85)
	tw.tween_property(_sprite, "position:y", base_position.y, 0.85).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_sprite, "scale", base_scale, 0.85)


func _on_body_entered(body: Node2D) -> void:
	if not _pickup_enabled:
		return
	if not body.is_in_group("player"):
		return

	var inventory := get_node_or_null("/root/Inventory")
	if inventory:
		inventory.add_item(item_data.duplicate_item())

	picked_up.emit(item_data)
	queue_free()


func _fade_out() -> void:
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate:a", 0.0, 1.0)
	tween.parallel().tween_property(_label, "modulate:a", 0.0, 1.0)
	await tween.finished
	queue_free()
