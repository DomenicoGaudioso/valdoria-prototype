extends Node2D

## World — Manages the game world, spawning enemies and items.

@export var map_name: String = "Sentiero delle Rovine"
@export var map_width: float = 1600.0
@export var map_height: float = 1200.0

@export var player_spawn_position: Vector2 = Vector2(400, 500)

@export var enemy_scene: PackedScene
@export var enemy_spawns: Array[Vector2] = []

@export var dropped_item_scene: PackedScene

@export var show_debug_grid: bool = false


func _ready() -> void:
	_spawn_player()
	_spawn_enemies()


func _spawn_player() -> void:
	var player_node := get_node_or_null("/root/Main/Player")
	if player_node:
		player_node.global_position = player_spawn_position


func _spawn_enemies() -> void:
	if not enemy_scene:
		push_warning("World: enemy_scene not set")
		return

	for spawn_pos in enemy_spawns:
		var enemy := enemy_scene.instantiate()
		enemy.global_position = spawn_pos
		enemy.drop_item.connect(_on_enemy_drop_item.bind(enemy))
		add_child(enemy)


func _on_enemy_drop_item(item_data, enemy: Node2D) -> void:
	if not dropped_item_scene:
		push_warning("World: dropped_item_scene not set, cannot spawn loot")
		return

	var dropped := dropped_item_scene.instantiate()
	dropped.set_item_data(item_data)
	dropped.global_position = enemy.global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))

	var dropped_container := get_node_or_null("/root/Main/DroppedItems")
	if dropped_container:
		dropped_container.add_child(dropped)
	else:
		add_child(dropped)


func _draw() -> void:
	if not show_debug_grid:
		return

	var grid_size := 64.0
	var color := Color(0.3, 0.3, 0.3, 0.3)

	var cols: int = ceil(map_width / grid_size)
	var rows: int = ceil(map_height / grid_size)

	for x in range(cols + 1):
		draw_line(Vector2(x * grid_size, 0), Vector2(x * grid_size, rows * grid_size), color, 0.5)
	for y in range(rows + 1):
		draw_line(Vector2(0, y * grid_size), Vector2(cols * grid_size, y * grid_size), color, 0.5)


func get_map_bounds() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(map_width, map_height))


func get_random_position() -> Vector2:
	return Vector2(randf_range(100, map_width - 100), randf_range(100, map_height - 100))
