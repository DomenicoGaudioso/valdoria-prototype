extends CharacterBody2D

class_name Enemy

signal health_changed(current_hp: int, max_hp: int)
signal enemy_died(enemy: Node2D)
signal drop_item(item_data)
signal enemy_killed(xp_value: int, enemy_name: String)
signal speech_requested(speaker: Node2D, text: String, tone_color: Color)
signal phase_changed(enemy_name: String, phase_index: int)

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
@export var attack_style: String = "melee"
@export var melee_range: float = 54.0
@export var preferred_range: float = 170.0
@export var projectile_speed: float = 430.0
@export var projectile_radius: float = 15.0
@export var telegraph_time: float = 0.42
@export var boss_like: bool = false
@export var phase_count: int = 1

@export var loot_table: Array[Dictionary] = []
@export var spawn_lines: Array[String] = []
@export var attack_lines: Array[String] = []
@export var hurt_lines: Array[String] = []
@export var death_lines: Array[String] = []
@export var voice_color: Color = Color(0.95, 0.35, 0.35)

var _state: State = State.IDLE
var _attack_timer: float = 0.0
var _player: Node2D = null
var _anim_frame: int = 0
var _anim_timer: float = 0.0
var _flash_timer: float = 0.0
var _dash_timer: float = 0.0
var _dash_velocity: Vector2 = Vector2.ZERO
var _telegraph_timer: float = 0.0
var _telegraph_kind: String = ""
var _telegraph_direction: Vector2 = Vector2.ZERO
var _telegraph_target_pos: Vector2 = Vector2.ZERO
var _phase_index: int = 0
var _base_move_speed: float = 0.0
var _base_attack_damage: int = 0
var _base_attack_cooldown: float = 1.0
var _walk_cycle: float = 0.0
var _death_timer: float = 0.0
var _last_move_dir: Vector2 = Vector2.DOWN
var _base_sprite_position: Vector2 = Vector2.ZERO
var _base_modulate: Color = Color.WHITE
var _base_glow_modulate: Color = Color.WHITE
var _speech_cooldown: float = 0.0
var _frame_w: int = 128
var _frame_h: int = 128

# Frame ranges: idle, run, attack, hit, die
var _idle_range: Array[int] = [0, 4]
var _run_range: Array[int] = [4, 12]
var _attack_range: Array[int] = [12, 16]
var _hit_range: Array[int] = [16, 18]
var _die_range: Array[int] = [18, 24]

var _frame_ranges := {}
var _frame_rates := {}

@onready var _sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
@onready var _sprite_glow: Sprite2D = get_node_or_null("SpriteGlow") as Sprite2D
@onready var _shadow: Sprite2D = get_node_or_null("Shadow") as Sprite2D
@onready var _detection_area: Area2D = get_node_or_null("DetectionArea") as Area2D


func _ready() -> void:
	add_to_group("enemies")
	current_hp = max_hp
	_base_move_speed = move_speed
	_base_attack_damage = attack_damage
	_base_attack_cooldown = attack_cooldown
	if melee_range <= 0.0:
		melee_range = min(attack_range, 58.0)
	if _sprite:
		_base_sprite_position = _sprite.position
		_base_modulate = _sprite.modulate
	if _sprite_glow:
		_base_glow_modulate = _sprite_glow.modulate
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
	call_deferred("_say_spawn")


func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		_update_death(delta)
		return

	_attack_timer = max(0.0, _attack_timer - delta)
	_flash_timer = max(0.0, _flash_timer - delta)
	_dash_timer = max(0.0, _dash_timer - delta)
	if _telegraph_timer > 0.0:
		_telegraph_timer = max(0.0, _telegraph_timer - delta)
		if _telegraph_timer <= 0.0:
			_execute_telegraphed_attack()
	_speech_cooldown = max(0.0, _speech_cooldown - delta)
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
	if _telegraph_timer > 0.0:
		velocity = Vector2.ZERO

	move_and_slide()
	_update_sprite(delta)
	_update_sorting()


func _chase_player(_delta: float) -> void:
	if not _player: return
	var dist := global_position.distance_to(_player.global_position)
	if dist <= attack_range:
		_set_state(State.ATTACK)
		return
	if attack_style in ["ranged", "hybrid"] and dist < preferred_range * 0.62:
		velocity = (global_position - _player.global_position).normalized() * move_speed * 0.72
		return
	if dist > stop_distance:
		velocity = (_player.global_position - global_position).normalized() * move_speed
	else:
		velocity = Vector2.ZERO


func _try_attack() -> void:
	if _attack_timer > 0.0 or _player == null or _telegraph_timer > 0.0: return
	var dist := global_position.distance_to(_player.global_position)
	if dist > attack_range:
		_set_state(State.CHASE)
		return

	_attack_timer = attack_cooldown
	_flash_timer = 0.2
	_anim_frame = _attack_range[0]
	_anim_timer = 0.0
	_say(attack_lines, 0.55)
	var dir := (_player.global_position - global_position).normalized()
	var kind := "melee"
	if attack_style == "ranged":
		kind = "ranged"
	elif attack_style == "hybrid" and dist > melee_range:
		kind = "ranged"
	_start_attack_telegraph(kind, dir)


func _start_attack_telegraph(kind: String, direction: Vector2) -> void:
	if direction.length_squared() < 0.01:
		direction = Vector2.DOWN
	_telegraph_kind = kind
	_telegraph_direction = direction
	_telegraph_target_pos = _player.global_position if _player else global_position + direction * attack_range
	_telegraph_timer = maxf(0.08, telegraph_time * (0.82 if _phase_index >= 2 else 1.0))
	_play_audio_cue("enemy_telegraph")
	if kind == "ranged":
		_spawn_ranged_telegraph(direction)
	else:
		_spawn_melee_telegraph(direction)


func _execute_telegraphed_attack() -> void:
	if _state == State.DEAD or not _player or (_player.has_method("is_dead") and _player.is_dead()):
		return
	_play_audio_cue("enemy_attack")
	if _telegraph_kind == "ranged":
		_spawn_enemy_projectile(_telegraph_direction)
		return

	var dist := global_position.distance_to(_player.global_position)
	if dist > melee_range + 18.0:
		return
	_dash_velocity = _telegraph_direction
	_dash_timer = 0.1
	if _player.has_method("take_damage"):
		_player.take_damage(attack_damage, self)


func _spawn_ranged_telegraph(direction: Vector2) -> void:
	var parent := get_parent()
	if not parent:
		return
	var line := Line2D.new()
	line.name = "EnemyRangedTelegraph"
	line.global_position = global_position
	line.rotation = direction.angle()
	line.width = 4.0 if not boss_like else 7.0
	line.default_color = Color(1.0, 0.26, 0.20, 0.62) if not boss_like else Color(1.0, 0.56, 0.16, 0.78)
	line.z_index = 4089
	line.add_point(Vector2(22.0, 0.0))
	line.add_point(Vector2(attack_range, 0.0))
	parent.add_child(line)

	var tw := create_tween()
	tw.tween_property(line, "width", line.width * 1.65, _telegraph_timer)
	tw.parallel().tween_property(line, "modulate:a", 0.0, _telegraph_timer)
	tw.tween_callback(line.queue_free)


func _spawn_melee_telegraph(direction: Vector2) -> void:
	var parent := get_parent()
	if not parent:
		return
	var ring := Line2D.new()
	ring.name = "EnemyMeleeTelegraph"
	ring.closed = true
	ring.width = 3.0 if not boss_like else 5.0
	ring.default_color = Color(1.0, 0.18, 0.12, 0.62) if not boss_like else Color(1.0, 0.62, 0.16, 0.76)
	ring.global_position = global_position + direction * (melee_range * 0.45)
	ring.z_index = 4089
	var radius := melee_range * (0.72 if not boss_like else 1.05)
	for i in range(42):
		var a := TAU * float(i) / 42.0
		ring.add_point(Vector2(cos(a) * radius, sin(a) * radius * 0.58))
	parent.add_child(ring)

	var tw := create_tween()
	ring.scale = Vector2(0.45, 0.45)
	tw.tween_property(ring, "scale", Vector2(1.0, 1.0), _telegraph_timer)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, _telegraph_timer)
	tw.tween_callback(ring.queue_free)


func _spawn_enemy_projectile(direction: Vector2) -> void:
	var parent := get_parent()
	if not parent:
		return
	if direction.length_squared() < 0.01:
		direction = Vector2.DOWN
	var projectile := Area2D.new()
	projectile.name = "EnemyProjectile"
	projectile.collision_layer = 0
	projectile.collision_mask = 2
	projectile.monitorable = false
	projectile.monitoring = true
	projectile.global_position = global_position + direction * 34.0
	projectile.rotation = direction.angle()
	projectile.z_index = 4090
	parent.add_child(projectile)

	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = projectile_radius * (1.25 if boss_like else 1.0)
	col.shape = circle
	projectile.add_child(col)

	var trail := Line2D.new()
	trail.name = "EnemyProjectileTrail"
	trail.width = 6.0 if not boss_like else 9.0
	trail.default_color = Color(1.0, 0.24, 0.18, 0.70) if not boss_like else Color(1.0, 0.58, 0.14, 0.78)
	trail.add_point(Vector2(-24.0, 0.0))
	trail.add_point(Vector2(10.0, 0.0))
	projectile.add_child(trail)

	var core := Polygon2D.new()
	core.name = "EnemyProjectileCore"
	core.polygon = PackedVector2Array([
		Vector2(16.0, 0.0), Vector2(1.0, -7.0), Vector2(-12.0, 0.0), Vector2(1.0, 7.0),
	])
	core.color = Color(1.0, 0.74, 0.36, 0.96) if boss_like else Color(1.0, 0.42, 0.32, 0.94)
	projectile.add_child(core)

	var hit_done := {"value": false}
	projectile.body_entered.connect(func(body: Node) -> void:
		if bool(hit_done["value"]) or not body.is_in_group("player"):
			return
		hit_done["value"] = true
		if body.has_method("take_damage"):
			body.take_damage(attack_damage, self)
		_spawn_projectile_impact(projectile.global_position)
		projectile.queue_free()
	)

	var travel := attack_range + 44.0
	var end_pos := projectile.global_position + direction * travel
	var duration := maxf(0.12, travel / maxf(projectile_speed, 1.0))
	var tw := projectile.create_tween()
	tw.tween_property(projectile, "global_position", end_pos, duration)
	tw.tween_callback(func() -> void:
		if not is_instance_valid(projectile):
			return
		_spawn_projectile_impact(projectile.global_position)
		projectile.queue_free()
	)


func _spawn_projectile_impact(position: Vector2) -> void:
	var parent := get_parent()
	if not parent:
		return
	for i in range(5):
		var spark := Line2D.new()
		spark.name = "EnemyProjectileSpark"
		spark.global_position = position
		spark.rotation = TAU * float(i) / 5.0 + randf_range(-0.20, 0.20)
		spark.width = 3.0
		spark.default_color = Color(1.0, 0.32, 0.20, 0.70)
		spark.z_index = 4092
		spark.add_point(Vector2.ZERO)
		spark.add_point(Vector2(randf_range(14.0, 28.0), 0.0))
		parent.add_child(spark)
		var tw := create_tween()
		tw.tween_property(spark, "scale", Vector2(1.25, 1.25), 0.18)
		tw.parallel().tween_property(spark, "modulate:a", 0.0, 0.18)
		tw.tween_callback(spark.queue_free)


func take_damage(amount: int, _source: Node2D = null) -> void:
	if _state == State.DEAD: return
	current_hp = max(0, current_hp - amount)
	health_changed.emit(current_hp, max_hp)
	_spawn_damage_number(amount)
	_check_phase_transition()
	if current_hp > 0:
		_say(hurt_lines, 0.35)
		_play_audio_cue("enemy_hurt")
	if _state == State.IDLE and _source:
		_player = _source; _set_state(State.CHASE)
		if _source is Node2D:
			global_position += (global_position - (_source as Node2D).global_position).normalized() * 8.0
	if current_hp <= 0: _die()


func _check_phase_transition() -> void:
	if not boss_like or phase_count <= 1 or max_hp <= 0 or _state == State.DEAD:
		return
	var hp_ratio := float(current_hp) / float(max_hp)
	var next_phase := 0
	if phase_count >= 2 and hp_ratio <= 0.66:
		next_phase = 1
	if phase_count >= 3 and hp_ratio <= 0.36:
		next_phase = 2
	if phase_count >= 4 and hp_ratio <= 0.16:
		next_phase = 3
	if next_phase <= _phase_index:
		return
	_phase_index = next_phase
	var phase_mult := 1.0 + float(_phase_index) * 0.16
	move_speed = _base_move_speed * phase_mult
	attack_damage = maxi(1, int(round(float(_base_attack_damage) * (1.0 + float(_phase_index) * 0.20))))
	attack_cooldown = maxf(0.42, _base_attack_cooldown * (1.0 - float(_phase_index) * 0.12))
	telegraph_time = maxf(0.18, telegraph_time * 0.90)
	_say(["Fase %d." % (_phase_index + 1), "Il varco risponde.", "Basta trattenersi."], 1.0, true)
	_spawn_phase_burst()
	_play_audio_cue("boss_phase")
	phase_changed.emit(enemy_name, _phase_index)


func _spawn_phase_burst() -> void:
	var parent := get_parent()
	if not parent:
		return
	var ring := Line2D.new()
	ring.name = "BossPhaseBurst"
	ring.closed = true
	ring.width = 8.0
	ring.default_color = Color(1.0, 0.58, 0.12, 0.82)
	ring.global_position = global_position
	ring.z_index = 4092
	var radius := 72.0 + float(_phase_index) * 28.0
	for i in range(64):
		var a := TAU * float(i) / 64.0
		ring.add_point(Vector2(cos(a) * radius, sin(a) * radius * 0.55))
	parent.add_child(ring)
	var tw := create_tween()
	ring.scale = Vector2(0.35, 0.35)
	tw.tween_property(ring, "scale", Vector2(1.3, 1.3), 0.34).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.42)
	tw.tween_callback(ring.queue_free)


func _die() -> void:
	_set_state(State.DEAD)
	velocity = Vector2.ZERO
	_death_timer = 0.8
	_anim_frame = _die_range[0]
	_anim_timer = 0.0
	_say(death_lines, 1.0, true)
	_play_audio_cue("enemy_death")
	_spawn_death_burst()
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
		State.ATTACK: _sprite.modulate = _boost_color(_base_modulate, 1.35)
		State.DEAD: _sprite.modulate = Color(_base_modulate.r * 0.55, _base_modulate.g * 0.55, _base_modulate.b * 0.65, _base_modulate.a)
		_: _sprite.modulate = _base_modulate if _flash_timer <= 0.0 else _boost_color(_base_modulate, 1.5)
	
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
	_sync_sprite_glow()
	
	# Bob and rotation for walk
	if _state == State.IDLE or _state == State.CHASE:
		var moving := velocity.length_squared() > 4.0
		var bob := sin(_walk_cycle) * 3.0 if moving else sin(Time.get_ticks_msec() / 520.0) * 0.9
		_sprite.position = _base_sprite_position + Vector2(0, bob)
		_sprite.rotation = lerpf(_sprite.rotation, clamp(velocity.x / max(move_speed, 1.0), -1.0, 1.0) * 0.06, min(delta * 8.0, 1.0))
		_sync_sprite_glow()


func _get_dir(d: Vector2) -> int:
	if d.length_squared() < 0.001: return 0
	var a := fmod(d.angle() + TAU, TAU) + PI / 8.0
	var idx := int(a / (PI / 4.0)) % 8
	return [6, 7, 0, 1, 2, 3, 4, 5][idx]


func _update_sorting() -> void:
	var z := int(global_position.y / 2.5)
	if _sprite: _sprite.z_index = z
	if _sprite_glow: _sprite_glow.z_index = z - 1
	if _shadow: _shadow.z_index = z - 1


func _update_death(delta: float) -> void:
	if not _sprite: return
	_death_timer = max(0.0, _death_timer - delta)
	var phase := 1.0 - _death_timer / 0.8
	_sprite.rotation = lerpf(_sprite.rotation, 0.9, min(delta * 7.0, 1.0))
	_sprite.modulate.a = 1.0 - phase
	_sprite.position = _base_sprite_position + Vector2(0, phase * 16.0)
	_sync_sprite_glow()
	if _sprite_glow: _sprite_glow.modulate.a = _base_glow_modulate.a * (1.0 - phase)
	if _shadow: _shadow.modulate.a = 1.0 - phase


func _sync_sprite_glow() -> void:
	if not _sprite_glow or not _sprite:
		return
	_sprite_glow.texture = _sprite.texture
	_sprite_glow.region_enabled = _sprite.region_enabled
	_sprite_glow.region_rect = _sprite.region_rect
	_sprite_glow.position = _sprite.position
	_sprite_glow.rotation = _sprite.rotation
	var alpha_mult: float = 1.35 if _state == State.ATTACK else 1.0
	_sprite_glow.modulate = Color(
		_base_glow_modulate.r,
		_base_glow_modulate.g,
		_base_glow_modulate.b,
		min(_base_glow_modulate.a * alpha_mult, 0.55)
	)


func _spawn_damage_number(amount: int) -> void:
	var parent := get_parent()
	if not parent:
		return
	var label := Label.new()
	label.name = "DamageNumber"
	label.text = "-%d" % amount
	label.position = global_position + Vector2(randf_range(-22.0, 22.0), randf_range(-96.0, -74.0))
	label.custom_minimum_size = Vector2(84.0, 0.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(1.0, 0.76, 0.34, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.88))
	label.add_theme_constant_override("outline_size", 4)
	label.z_index = 4094
	parent.add_child(label)

	var tw := create_tween()
	tw.tween_property(label, "position:y", label.position.y - 34.0, 0.78).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(label, "scale", Vector2(1.18, 1.18), 0.18)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.78)
	tw.tween_callback(label.queue_free)


func _spawn_death_burst() -> void:
	var parent := get_parent()
	if not parent:
		return
	for i in range(8):
		var shard := Polygon2D.new()
		shard.name = "DeathShard"
		var r := randf_range(3.0, 6.0)
		shard.polygon = PackedVector2Array([
			Vector2(0.0, -r), Vector2(r * 0.55, 0.0), Vector2(0.0, r), Vector2(-r * 0.55, 0.0),
		])
		shard.color = Color(voice_color.r, voice_color.g, voice_color.b, 0.68)
		shard.position = global_position + Vector2(randf_range(-18.0, 18.0), randf_range(-58.0, -28.0))
		shard.rotation = randf_range(0.0, TAU)
		shard.z_index = 4093
		parent.add_child(shard)

		var drift := Vector2(randf_range(-54.0, 54.0), randf_range(-72.0, -22.0))
		var tw := create_tween()
		tw.tween_property(shard, "position", shard.position + drift, 0.58).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(shard, "rotation", shard.rotation + randf_range(-2.8, 2.8), 0.58)
		tw.parallel().tween_property(shard, "modulate:a", 0.0, 0.58)
		tw.tween_callback(shard.queue_free)


func is_dead() -> bool: return _state == State.DEAD


func _say_spawn() -> void:
	_say(spawn_lines, 0.85, true)


func _say(lines: Array[String], chance: float, force: bool = false) -> void:
	if lines.is_empty():
		return
	if not force and (_speech_cooldown > 0.0 or randf() > chance):
		return
	speech_requested.emit(self, lines[randi() % lines.size()], voice_color)
	_speech_cooldown = 3.0


func _boost_color(color: Color, amount: float) -> Color:
	return Color(min(color.r * amount, 1.8), min(color.g * amount, 1.8), min(color.b * amount, 1.8), color.a)


func _play_audio_cue(cue: String) -> void:
	var audio := get_node_or_null("/root/ProceduralAudio")
	if audio and audio.has_method("play_cue"):
		audio.play_cue(cue)
