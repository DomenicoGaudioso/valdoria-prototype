extends CharacterBody2D

class_name Enemy

signal health_changed(current_hp: int, max_hp: int)
signal enemy_died(enemy: Node2D)
signal drop_item(item_data)
signal enemy_killed(xp_value: int, enemy_name: String)

enum State { IDLE, CHASE, ATTACK, DEAD }

@export var enemy_id: String = "skeleton"
@export var enemy_name: String = "Nemico"

@export var max_hp: int = 30
@export var current_hp: int = 30
@export var move_speed: float = 80.0
@export var detection_radius: float = 280.0
@export var attack_range: float = 50.0
@export var attack_damage: int = 5
@export var attack_cooldown: float = 1.2
@export var stop_distance: float = 5.0
@export var xp_value: int = 10

@export var loot_table: Array[Dictionary] = []

var _state: State = State.IDLE
var _attack_timer: float = 0.0
var _player: Node2D = null
var _anim_frame: int = 0
var _anim_timer: float = 0.0
var _flash_timer: float = 0.0
var _dash_timer: float = 0.0
var _dash_velocity: Vector2 = Vector2.ZERO
var _walk_cycle: float = 0.0
var _death_timer: float = 0.0
var _last_move_dir: Vector2 = Vector2.DOWN
var _base_sprite_position: Vector2 = Vector2.ZERO
var _frame_w: int = 128
var _frame_h: int = 128

# Frame ranges (columns in 128px grid): idle, run, attack, hit, die
var _idle_range: Array[int] = [0, 4]
var _run_range: Array[int] = [4, 12]
var _attack_range: Array[int] = [12, 16]
var _hit_range: Array[int] = [16, 18]
var _die_range: Array[int] = [18, 24]

var _frame_ranges := {}
var _frame_rates := {}

@onready var _sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
@onready var _shadow: Sprite2D = get_node_or_null("Shadow") as Sprite2D
@onready var _detection_area: Area2D = get_node_or_null("DetectionArea") as Area2D


func _ready() -> void:
	add_to_group("enemies")
	current_hp = max_hp
	if _sprite: _base_sprite_position = _sprite.position
	if _detection_area:
		_detection_area.body_entered.connect(_on_body_entered_detection)
		_detection_area.body_exited.connect(_on_body_exited_detection)
		var col := _detection_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if col and col.shape is CircleShape2D:
			col.shape.radius = detection_radius
	
	_frame_ranges = {
		State.IDLE: _idle_range, State.CHASE: _run_range,
		State.ATTACK: _attack_range, State.DEAD: _die_range,
	}
	_frame_rates = {
		State.IDLE: 0.22, State.CHASE: 0.09,
		State.ATTACK: 0.08, State.DEAD: 0.18,
	}


func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		_update_death(delta)
		return

	_attack_timer = max(0.0, _attack_timer - delta)
	_flash_timer = max(0.0, _flash_timer - delta)
	_dash_timer = max(0.0, _dash_timer - delta)
	if velocity.length_squared() > 4.0:
		_walk_cycle += delta * 9.0
		_last_move_dir = velocity.normalized()

	# Auto-find player if not already targeted
	if _player == null or (_player.has_method("is_dead") and _player.is_dead()):
		_find_player()

	match _state:
		State.IDLE:
			velocity = Vector2.ZERO
			# Check if player is nearby even in idle
			if _player and global_position.distance_to(_player.global_position) <= detection_radius:
				_set_state(State.CHASE)
		State.CHASE:
			if _player and not _player.is_dead():
				_chase_player(delta)
			else:
				_set_state(State.IDLE)
		State.ATTACK:
			if _player and not _player.is_dead():
				_try_attack()
			else:
				_set_state(State.IDLE)
	
	if _dash_timer > 0.0:
		velocity = _dash_velocity * move_speed * 2.5

	move_and_slide()
	_update_sprite(delta)
	_update_sorting()


func _chase_player(_delta: float) -> void:
	if not _player: return
	var dist := global_position.distance_to(_player.global_position)
	if dist <= attack_range:
		_set_state(State.ATTACK)
		return
	if dist > stop_distance:
		velocity = (_player.global_position - global_position).normalized() * move_speed
	else:
		velocity = Vector2.ZERO


func _try_attack() -> void:
	if _attack_timer > 0.0 or _player == null: return
	var dist := global_position.distance_to(_player.global_position)
	if dist > attack_range:
		_set_state(State.CHASE)
		return

	_attack_timer = attack_cooldown
	_flash_timer = 0.2
	_anim_frame = _attack_range[0]
	_anim_timer = 0.0

	var dir := (_player.global_position - global_position).normalized()
	_dash_velocity = dir
	_dash_timer = 0.1

	if _player.has_method("take_damage"):
		_player.take_damage(attack_damage, self)


func take_damage(amount: int, _source: Node2D = null) -> void:
	if _state == State.DEAD: return
	current_hp = max(0, current_hp - amount)
	health_changed.emit(current_hp, max_hp)
	if _state == State.IDLE and _source:
		_player = _source; _set_state(State.CHASE)
		if _source is Node2D:
			global_position += (global_position - (_source as Node2D).global_position).normalized() * 8.0
	if current_hp <= 0: _die()


func _die() -> void:
	_set_state(State.DEAD)
	velocity = Vector2.ZERO
	_death_timer = 0.8
	_anim_frame = _die_range[0]
	_anim_timer = 0.0
	_spawn_loot()
	enemy_killed.emit(xp_value, enemy_name)
	enemy_died.emit(self)
	await get_tree().create_timer(0.8).timeout
	queue_free()


func _spawn_loot() -> void:
	if loot_table.is_empty(): return
	for entry in loot_table:
		drop_item.emit(entry)  # gold dict or equip dict or ItemData


func _on_body_entered_detection(body: Node2D) -> void:
	if body.is_in_group("player"): _player = body; _set_state(State.CHASE)


func _on_body_exited_detection(body: Node2D) -> void:
	if body == _player: _player = null; _set_state(State.IDLE)


func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0] as Node2D


func _set_state(new_state: State) -> void:
	if _state != new_state:
		_anim_frame = _frame_ranges[new_state][0]
		_anim_timer = 0.0
	_state = new_state


func _update_sprite(delta: float) -> void:
	if not _sprite: return
	
	# Color per state
	match _state:
		State.ATTACK: _sprite.modulate = Color(1.5, 1.0, 0.8)
		State.DEAD: _sprite.modulate = Color(0.55, 0.55, 0.65)
		_: _sprite.modulate = Color.WHITE if _flash_timer <= 0.0 else Color(1.5, 1.3, 1.2)
	
	# Frame animation
	var fr: Array = _frame_ranges.get(_state, [0, 4])
	var rate: float = _frame_rates.get(_state, 0.12)
	_anim_timer += delta
	if _anim_timer >= rate:
		_anim_timer -= rate
		_anim_frame += 1
		if _anim_frame >= fr[1]:
			if _state == State.ATTACK:
				_anim_frame = fr[1] - 1; _set_state(State.IDLE)
			elif _state == State.DEAD:
				_anim_frame = fr[1] - 1
			else:
				_anim_frame = fr[0]
	
	# Direction index (0-7)
	var dir_idx := 0
	if _state != State.DEAD and _player:
		var to_player := (_player.global_position - global_position).normalized()
		dir_idx = _get_dir(to_player)
	else:
		dir_idx = _get_dir(_last_move_dir)
	
	# Apply sprite frame
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(_anim_frame * _frame_w, dir_idx * _frame_h, _frame_w, _frame_h)
	
	# Bob and rotation for walk
	if _state == State.IDLE or _state == State.CHASE:
		var moving := velocity.length_squared() > 4.0
		var bob := sin(_walk_cycle) * 3.0 if moving else sin(Time.get_ticks_msec() / 520.0) * 0.9
		_sprite.position = _base_sprite_position + Vector2(0, bob)
		_sprite.rotation = lerpf(_sprite.rotation, clamp(velocity.x / max(move_speed, 1.0), -1.0, 1.0) * 0.06, min(delta * 8.0, 1.0))


func _get_dir(d: Vector2) -> int:
	if d.length_squared() < 0.001: return 0
	var a := fmod(d.angle() + TAU, TAU) + PI / 8.0
	var idx := int(a / (PI / 4.0)) % 8
	return [6, 7, 0, 1, 2, 3, 4, 5][idx]


func _update_sorting() -> void:
	var z := int(global_position.y / 2.5)
	if _sprite: _sprite.z_index = z
	if _shadow: _shadow.z_index = z - 1


func _update_death(delta: float) -> void:
	if not _sprite: return
	_death_timer = max(0.0, _death_timer - delta)
	var phase := 1.0 - _death_timer / 0.8
	_sprite.rotation = lerpf(_sprite.rotation, 0.9, min(delta * 7.0, 1.0))
	_sprite.modulate.a = 1.0 - phase
	_sprite.position = _base_sprite_position + Vector2(0, phase * 16.0)
	if _shadow: _shadow.modulate.a = 1.0 - phase


func is_dead() -> bool: return _state == State.DEAD
