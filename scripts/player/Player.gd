extends CharacterBody2D

class_name Player

signal health_changed(current_hp: int, max_hp: int)
signal died
signal combo_changed(combo_level: int)
signal xp_changed(xp: int, xp_to_next: int)
signal leveled_up(level: int)
signal gold_changed(gold: int)
signal equipment_changed(slot: String, item)

@export var max_hp: int = 100
@export var current_hp: int = 100
@export var move_speed: float = 200.0
@export var stop_distance: float = 6.0
@export var attack_damage: int = 10
@export var attack_range: float = 64.0
@export var attack_cooldown: float = 0.6

# Leveling system
var level: int = 1
var xp: int = 0
var xp_to_next_level: int = 30
var base_hp: int = 100
var base_damage: int = 10
var base_speed: float = 200.0

# Economy
var gold: int = 0

# Equipment slots: {slot_name: ItemData or null}
var equipment: Dictionary = {
	"weapon": null,
	"armor": null,
	"helmet": null,
	"boots": null,
	"ring": null,
}

var _target_position: Vector2 = Vector2.INF
var _attack_timer: float = 0.0
var _is_dead: bool = false

# Combo system
var _combo_level: int = 0          # 0=idle, 1,2,3=combo stages
var _combo_window: float = 0.0     # time left to chain next attack
var _combo_max_window: float = 0.7  # window to press next attack
var _combo_damage_mult: Array[float] = [1.0, 1.0, 1.3, 1.8]  # damage multiplier per combo level

# Animation
var _anim_state: int = 0  # AnimState
var _last_direction: Vector2 = Vector2(0, 1)
var _anim_frame: int = 0
var _anim_timer: float = 0.0
var _dash_velocity: Vector2 = Vector2.ZERO
var _dash_timer: float = 0.0

enum AnimState { IDLE, RUN, ATTACK, HIT, DIE }

var _frame_rates := {
	AnimState.IDLE: 0.25,
	AnimState.RUN: 0.08,
	AnimState.ATTACK: 0.10,
	AnimState.HIT: 0.15,
	AnimState.DIE: 0.2,
}

var _frame_ranges := {
	AnimState.IDLE:  [0, 4],
	AnimState.RUN:   [4, 12],
	AnimState.ATTACK:[12, 16],
	AnimState.HIT:   [16, 18],
	AnimState.DIE:   [18, 24],
}

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("player")
	_target_position = global_position
	current_hp = max_hp


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	_attack_timer = max(0.0, _attack_timer - delta)
	_combo_window = max(0.0, _combo_window - delta)
	_dash_timer = max(0.0, _dash_timer - delta)

	# Movement
	if _anim_state == AnimState.ATTACK or _anim_state == AnimState.HIT:
		velocity = Vector2.ZERO  # Stay still during attacks
	elif _target_position != Vector2.INF and global_position.distance_to(_target_position) > stop_distance:
		velocity = (_target_position - global_position).normalized() * move_speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()
	_update_animation(delta)
	if _sprite:
		_sprite.z_index = int(global_position.y / 2.5)

	# Reset combo if window expired
	if _combo_window <= 0.0 and _combo_level > 0 and _anim_state != AnimState.ATTACK:
		_combo_level = 0
		combo_changed.emit(0)


func _update_animation(delta: float) -> void:
	if _is_dead:
		return

	var moving := velocity.length_squared() > 10.0

	if _anim_state == AnimState.ATTACK:
		pass  # Let attack finish
	elif _anim_state == AnimState.HIT:
		pass
	elif moving:
		_anim_state = AnimState.RUN
		_last_direction = velocity.normalized()
	else:
		_anim_state = AnimState.IDLE

	var fr: Array = _frame_ranges[_anim_state]
	var rate: float = _frame_rates.get(_anim_state, 0.15)

	_anim_timer += delta
	if _anim_timer >= rate:
		_anim_timer -= rate
		_anim_frame += 1
		if _anim_frame >= fr[1]:
			if _anim_state == AnimState.ATTACK:
				_anim_frame = fr[1] - 1  # Hold last frame
				_anim_state = AnimState.IDLE
				_dash_timer = 0.0
				_combo_level = 0
				combo_changed.emit(0)
			elif _anim_state == AnimState.HIT:
				_anim_state = AnimState.IDLE
			elif _anim_state == AnimState.DIE:
				_anim_frame = fr[1] - 1  # Hold last die frame
			else:
				_anim_frame = fr[0]

	var dir_idx := _get_direction_index(_last_direction)
	_apply_frame(dir_idx, _anim_frame)

	# Sprite flash on attack/hit
	if _anim_state == AnimState.ATTACK:
		_sprite.modulate = Color(1.3, 1.3, 1.3)
	elif _anim_state == AnimState.HIT:
		_sprite.modulate = Color(1.5, 0.3, 0.3)
	else:
		_sprite.modulate = Color.WHITE


func _get_direction_index(dir: Vector2) -> int:
	if dir.length_squared() < 0.001:
		return 0
	var a := fmod(dir.angle() + TAU, TAU)
	a += PI / 8.0
	var idx := int(a / (PI / 4.0)) % 8
	var flare_dir := [6, 7, 0, 1, 2, 3, 4, 5]
	return flare_dir[idx]


func _apply_frame(dir_y: int, frame_x: int) -> void:
	if not _sprite:
		return
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(frame_x * 128, dir_y * 128, 128, 128)


func _on_move_command(world_position: Vector2) -> void:
	if _is_dead:
		return
	_target_position = world_position
	# Face the click direction immediately
	var dir_to_target := (world_position - global_position).normalized()
	if dir_to_target.length_squared() > 0.01:
		_last_direction = dir_to_target


func _on_attack_command(_target: Node2D) -> void:
	if _is_dead:
		return
	if _attack_timer > 0.0:
		return

	# Combo logic
	if _combo_window > 0.0 and _combo_level < 3:
		_combo_level += 1
	else:
		_combo_level = 1

	_combo_window = _combo_max_window
	_attack_timer = attack_cooldown

	# Start attack animation
	_anim_state = AnimState.ATTACK
	_anim_frame = _frame_ranges[AnimState.ATTACK][0]
	_anim_timer = 0.0

	# Dash forward (stronger dash with higher combo)
	var dash_dir := _last_direction
	_dash_velocity = dash_dir
	_dash_timer = 0.12 + _combo_level * 0.03

	combo_changed.emit(_combo_level)

	# Find and damage nearest enemy
	var enemies := get_tree().get_nodes_in_group("enemies")
	var closest: Node2D = null
	var closest_dist: float = INF

	for enemy in enemies:
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist <= attack_range and dist < closest_dist:
			closest = enemy
			closest_dist = dist

	if closest:
		_last_direction = (closest.global_position - global_position).normalized()
		if closest.has_method("take_damage"):
			# Increasing damage with combo
			var dmg := int(attack_damage * _combo_damage_mult[_combo_level])
			closest.take_damage(dmg, self)


func take_damage(amount: int, _source: Node2D = null) -> void:
	if _is_dead:
		return
	current_hp = max(0, current_hp - amount)
	health_changed.emit(current_hp, max_hp)

	_anim_state = AnimState.HIT
	_anim_frame = _frame_ranges[AnimState.HIT][0]
	_anim_timer = 0.0
	_combo_level = 0

	if current_hp <= 0:
		_die()


func heal(amount: int) -> void:
	if _is_dead:
		return
	current_hp = min(max_hp, current_hp + amount)
	health_changed.emit(current_hp, max_hp)


func _die() -> void:
	_is_dead = true
	velocity = Vector2.ZERO
	_anim_state = AnimState.DIE
	_anim_frame = _frame_ranges[AnimState.DIE][0]
	_anim_timer = 0.0
	_combo_level = 0
	died.emit()


func gain_xp(amount: int) -> void:
	if _is_dead: return
	xp += amount
	while xp >= xp_to_next_level:
		_level_up()
	xp_changed.emit(xp, xp_to_next_level)


func _level_up() -> void:
	xp -= xp_to_next_level
	level += 1
	xp_to_next_level = int(xp_to_next_level * 1.4)
	
	base_hp += 25
	base_damage += 3
	base_speed += 5.0
	
	max_hp = base_hp
	current_hp = max_hp
	attack_damage = base_damage
	move_speed = base_speed
	
	leveled_up.emit(level)
	health_changed.emit(current_hp, max_hp)
	xp_changed.emit(xp, xp_to_next_level)


func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


func equip_item(slot: String, item) -> void:
	if not equipment.has(slot):
		return
	equipment[slot] = item
	_recalc_equip_stats()
	equipment_changed.emit(slot, item)


func unequip_item(slot: String):
	if not equipment.has(slot):
		return null
	var item = equipment[slot]
	equipment[slot] = null
	_recalc_equip_stats()
	equipment_changed.emit(slot, null)
	return item


func _recalc_equip_stats() -> void:
	var dmg_bonus := 0; var hp_bonus := 0; var spd_bonus := 0
	for s in equipment:
		if equipment[s] != null:
			dmg_bonus += equipment[s].stat_damage
			hp_bonus += equipment[s].stat_health
			spd_bonus += equipment[s].stat_speed
	attack_damage = base_damage + dmg_bonus
	max_hp = base_hp + hp_bonus
	current_hp = min(current_hp, max_hp)
	move_speed = base_speed + spd_bonus
	health_changed.emit(current_hp, max_hp)


func is_dead() -> bool:
	return _is_dead
