extends CharacterBody2D

class_name Player

signal health_changed(current_hp: int, max_hp: int)
signal died
signal combo_changed(combo_level: int)
signal xp_changed(xp: int, xp_to_next: int)
signal leveled_up(level: int)
signal gold_changed(gold: int)
signal equipment_changed(slot: String, item)
signal speech_requested(speaker: Node2D, text: String, tone_color: Color)
signal dash_performed
signal perfect_dodge
signal skill_used(skill_id: String)
signal dash_status_changed(ready: bool, cooldown_left: float, cooldown: float)
signal skill_status_changed(skill_id: String, ready: bool, cooldown_left: float, cooldown: float)

@export var max_hp: int = 100
@export var current_hp: int = 100
@export var move_speed: float = 200.0
@export var stop_distance: float = 6.0
@export var attack_damage: int = 10
@export var attack_range: float = 64.0
@export var attack_cooldown: float = 0.6
@export var ranged_attack_range: float = 390.0
@export var ranged_damage_multiplier: float = 0.72
@export var projectile_speed: float = 720.0
@export var projectile_hit_radius: float = 22.0
@export var dash_cooldown: float = 2.4
@export var dash_duration: float = 0.18
@export var dash_speed_multiplier: float = 3.2
@export var dash_iframe_duration: float = 0.30
@export var guardian_shield_duration: float = 3.0
@export var guardian_shield_reduction: float = 0.55

const MOVE_SPEED_SOFT_CAP_START: float = 720.0
const MOVE_SPEED_SOFT_CAP_SCALE: float = 4.5
const MOVE_SPEED_HARD_CAP: float = 860.0

# Leveling system
var level: int = 1
var xp: int = 0
var xp_to_next_level: int = 30
var total_xp_earned: int = 0
var ascension_level: int = 0
var ascension_points: int = 0
var highest_portal_depth: int = 1
var season_level: int = 1
var base_hp: int = 100
var base_damage: int = 10
var base_speed: float = 200.0
var base_defense: int = 0
var base_agility: int = 0
var defense: int = 0
var agility: int = 0

# Economy
var gold: int = 0

# Equipment slots: {slot_name: ItemData or null}
var equipment: Dictionary = {
	"weapon": null,
	"armor": null,
	"helmet": null,
	"boots": null,
	"ring": null,
	"amulet": null,
	"belt": null,
	"relic": null,
}

# Active effect modifiers from equipped items
var _effect_mods: Dictionary = {}

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
var _evade_direction: Vector2 = Vector2.DOWN
var _evade_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _invulnerable_timer: float = 0.0
var _guardian_shield_timer: float = 0.0
var _speech_cooldown: float = 0.0
var _equipment_visuals: Node2D = null
var _outfit_base_tint: Color = Color.WHITE
var _skill_timers: Dictionary = {
	"charged_shot": 0.0,
	"piercing_shot": 0.0,
	"arcane_burst": 0.0,
	"guardian_aegis": 0.0,
}

const SKILL_COOLDOWNS: Dictionary = {
	"charged_shot": 4.2,
	"piercing_shot": 5.8,
	"arcane_burst": 7.5,
	"guardian_aegis": 10.0,
}

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
@onready var _sprite_glow: Sprite2D = get_node_or_null("SpriteGlow") as Sprite2D
@onready var _shadow: Sprite2D = get_node_or_null("Shadow") as Sprite2D


func _ready() -> void:
	add_to_group("player")
	_target_position = global_position
	current_hp = clampi(current_hp, 1, max_hp)
	_ensure_equipment_visuals()
	_rebuild_equipment_effects()
	_recalc_equip_stats()
	_update_equipment_visuals()
	_sync_sprite_glow()
	_emit_combat_status()


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	_attack_timer = max(0.0, _attack_timer - delta)
	_combo_window = max(0.0, _combo_window - delta)
	_dash_timer = max(0.0, _dash_timer - delta)
	_evade_timer = max(0.0, _evade_timer - delta)
	_dash_cooldown_timer = max(0.0, _dash_cooldown_timer - delta)
	_invulnerable_timer = max(0.0, _invulnerable_timer - delta)
	_guardian_shield_timer = max(0.0, _guardian_shield_timer - delta)
	for skill_id in _skill_timers.keys():
		_skill_timers[skill_id] = max(0.0, float(_skill_timers[skill_id]) - delta)
	_speech_cooldown = max(0.0, _speech_cooldown - delta)
	_emit_combat_status()

	# Movement
	if _evade_timer > 0.0:
		velocity = _evade_direction * move_speed * dash_speed_multiplier
	elif _anim_state == AnimState.ATTACK:
		if _dash_timer > 0.0:
			var attack_speed: float = move_speed * (1.15 + float(_combo_level) * 0.22)
			velocity = _dash_velocity * attack_speed
		else:
			velocity = Vector2.ZERO
	elif _anim_state == AnimState.HIT:
		if _dash_timer > 0.0:
			velocity = _dash_velocity * move_speed * 0.7
		else:
			velocity = Vector2.ZERO
	elif _target_position == Vector2.INF:
		# Joystick mode: velocity is set by _on_move_vector, don't override
		pass
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

	# Sprite flash on attack/hit while preserving equipped material tint.
	if _anim_state == AnimState.ATTACK:
		_sprite.modulate = _boost_color(_outfit_base_tint, 1.35)
	elif _anim_state == AnimState.HIT:
		_sprite.modulate = Color(1.45, 0.32, 0.34)
	else:
		_sprite.modulate = _outfit_base_tint
	_sync_sprite_glow()
	_update_shadow(moving, delta)


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


func _on_move_vector(direction: Vector2) -> void:
	"""Continuous movement from virtual joystick — moves in direction each frame."""
	if _is_dead:
		return
	if direction.length_squared() > 0.01:
		_target_position = Vector2.INF  # disable click-to-move
		velocity = direction * move_speed
		_last_direction = direction
	else:
		velocity = Vector2.ZERO


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

	var melee_target := _find_closest_enemy(attack_range)
	if melee_target:
		_perform_melee_attack(melee_target)
	else:
		var ranged_target: Node2D = null
		if _is_valid_enemy(_target) and global_position.distance_to(_target.global_position) <= ranged_attack_range:
			ranged_target = _target
		else:
			ranged_target = _find_closest_enemy(ranged_attack_range, attack_range)
		_perform_ranged_attack(ranged_target)

	combo_changed.emit(_combo_level)
	_play_audio_cue("attack")
	if _combo_level >= 3:
		_try_speak(["Taglio netto.", "Ora cedi.", "Resta giu."], 0.45)


func _on_dash_command() -> void:
	if _is_dead or _dash_cooldown_timer > 0.0:
		return
	var direction := _last_direction.normalized()
	if velocity.length_squared() > 0.01:
		direction = velocity.normalized()
	if direction.length_squared() < 0.01:
		direction = Vector2.DOWN

	_evade_direction = direction
	_last_direction = direction
	_evade_timer = dash_duration
	_invulnerable_timer = dash_iframe_duration + get_effect_value("dodge_window")
	_dash_cooldown_timer = _scaled_cooldown(dash_cooldown)
	_anim_state = AnimState.RUN
	_spawn_dash_afterimage(Color(0.26, 0.86, 1.0, 0.34))
	_spawn_status_label("PASSO D'OMBRA", Color(0.38, 0.92, 1.0))
	_play_audio_cue("dash")
	dash_performed.emit()
	_emit_combat_status()


func _on_skill_command(skill_id: String) -> void:
	if _is_dead or not SKILL_COOLDOWNS.has(skill_id):
		return
	if float(_skill_timers.get(skill_id, 0.0)) > 0.0:
		return
	match skill_id:
		"charged_shot":
			_use_charged_shot()
		"piercing_shot":
			_use_piercing_shot()
		"arcane_burst":
			_use_arcane_burst()
		"guardian_aegis":
			_use_guardian_aegis()
		_:
			return
	_skill_timers[skill_id] = _scaled_cooldown(float(SKILL_COOLDOWNS[skill_id]))
	_play_audio_cue("skill")
	skill_used.emit(skill_id)
	_emit_combat_status()


func _use_charged_shot() -> void:
	var target := _find_closest_enemy(ranged_attack_range + 180.0)
	var direction := _last_direction.normalized()
	if target:
		direction = (target.global_position - global_position).normalized()
	if direction.length_squared() < 0.01:
		direction = Vector2.DOWN
	_last_direction = direction
	_spawn_ranged_cast_flash(direction, 3)
	_spawn_ranged_projectile(
		direction,
		target,
		3,
		maxi(1, int(round(float(attack_damage) * 2.15))),
		0,
		ranged_attack_range + 180.0,
		1.28,
		Color(1.0, 0.70, 0.24, 0.88)
	)
	_try_speak(["Carica piena.", "Colpo al cuore."], 0.90)


func _use_piercing_shot() -> void:
	var target := _find_closest_enemy(ranged_attack_range + 240.0)
	var direction := _last_direction.normalized()
	if target:
		direction = (target.global_position - global_position).normalized()
	if direction.length_squared() < 0.01:
		direction = Vector2.DOWN
	_last_direction = direction
	_spawn_ranged_cast_flash(direction, 2)
	_spawn_ranged_projectile(
		direction,
		target,
		2,
		maxi(1, int(round(float(attack_damage) * 1.08))),
		3,
		ranged_attack_range + 240.0,
		0.88,
		Color(0.70, 0.42, 1.0, 0.86)
	)
	_try_speak(["Attraversa.", "Linea pulita."], 0.82)


func _use_arcane_burst() -> void:
	var radius := 178.0
	var damage := maxi(1, int(round(float(attack_damage) * 1.32)))
	_deal_area_damage(global_position, radius, damage)
	_spawn_ability_burst(global_position, radius, Color(0.24, 1.0, 0.74, 0.72))
	_try_speak(["Via da me.", "Cerchio aperto."], 0.88)


func _use_guardian_aegis() -> void:
	_guardian_shield_timer = guardian_shield_duration
	_invulnerable_timer = maxf(_invulnerable_timer, 0.12)
	heal(maxi(1, int(round(float(max_hp) * 0.12))))
	_spawn_guardian_aegis()
	_try_speak(["Scudo alto.", "Non passo."], 0.92)


func take_damage(amount: int, _source: Node2D = null) -> void:
	if _is_dead:
		return
	if _invulnerable_timer > 0.0:
		_spawn_status_label("SCHIVATA", Color(0.40, 0.95, 1.0))
		_spawn_dash_afterimage(Color(0.34, 0.90, 1.0, 0.32))
		_play_audio_cue("dodge")
		perfect_dodge.emit()
		return
	if _guardian_shield_timer > 0.0:
		amount = maxi(1, int(round(float(amount) * (1.0 - guardian_shield_reduction))))
		_spawn_status_label("SCUDO", Color(1.0, 0.78, 0.26))
	var mitigated_amount := _apply_defense(amount)
	current_hp = max(0, current_hp - mitigated_amount)
	health_changed.emit(current_hp, max_hp)
	_try_speak(["Non basta.", "Ancora in piedi.", "Stringi i denti."], 0.22)

	_anim_state = AnimState.HIT
	_anim_frame = _frame_ranges[AnimState.HIT][0]
	_anim_timer = 0.0
	_combo_level = 0
	if _source:
		_dash_velocity = (global_position - _source.global_position).normalized()
		_dash_timer = 0.08

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
	_try_speak(["Non finisce qui."], 1.0)
	died.emit()


func gain_xp(amount: int) -> void:
	if _is_dead: return
	var final_amount := amount
	if has_effect("xp_boost"):
		final_amount += int(round(float(amount) * get_effect_value("xp_boost")))
	total_xp_earned += final_amount
	xp += final_amount
	while xp >= xp_to_next_level:
		_level_up()
	xp_changed.emit(xp, xp_to_next_level)


func _level_up() -> void:
	xp -= xp_to_next_level
	level += 1
	xp_to_next_level = _calculate_next_xp_required(level, xp_to_next_level)

	var post_100 := level > 100
	if post_100:
		ascension_level += 1
		ascension_points += 1
		season_level = maxi(season_level, int(floor(float(level - 100) / 25.0)) + 1)

	base_hp += 18 if post_100 else 25
	base_damage += 2 if post_100 else 3
	base_speed += 2.0 if post_100 else 5.0
	base_defense += 1
	base_agility += 1
	
	max_hp = base_hp
	current_hp = max_hp
	attack_damage = base_damage
	move_speed = base_speed
	defense = base_defense
	agility = base_agility

	# GDD: Skill point and milestone system
	var story := get_node_or_null("/root/StoryData")
	if story:
		var band: Dictionary = story.get_level_band(level)
		if not band.is_empty():
			_try_speak(["Nuovo rango: " + band.get("band", "???"), "Un gradino più in alto."], 0.9)

	_recalc_equip_stats()
	leveled_up.emit(level)
	health_changed.emit(current_hp, max_hp)
	xp_changed.emit(xp, xp_to_next_level)
	_try_speak(["Sento l'ombra crescere.", "Un altro limite cade.", "Piu forte."], 1.0)


func _calculate_next_xp_required(new_level: int, _previous_required: int) -> int:
	var level_for_requirement := maxi(1, new_level)
	var required := 30
	if level_for_requirement <= 20:
		var n := level_for_requirement - 1
		required = 30 + n * 18 + n * n * 5
	elif level_for_requirement <= 60:
		var n := level_for_requirement - 20
		required = 2177 + n * 170 + n * n * 24
	elif level_for_requirement <= 100:
		var n := level_for_requirement - 60
		required = 47377 + n * 950 + n * n * 70
	else:
		var n := level_for_requirement - 100
		required = 197377 + n * 4500 + n * n * 180
	# Piecewise polynomial curve: fast early, slower to 100, controlled post-cap.
	return clampi(required, 30, 5000000)


func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


func equip_item(slot: String, item):
	if not equipment.has(slot):
		return null
	var previous = equipment[slot]

	if previous:
		_apply_item_effects(previous, false)

	equipment[slot] = item
	if item:
		_apply_item_effects(item, true)

	_recalc_equip_stats()
	_update_equipment_visuals()
	equipment_changed.emit(slot, item)
	_try_speak(["Questo serve.", "Me lo prendo.", "Potere utile."], 0.85)
	return previous


func unequip_item(slot: String):
	if not equipment.has(slot):
		return null
	var item = equipment[slot]
	if item:
		_apply_item_effects(item, false)
	equipment[slot] = null
	_recalc_equip_stats()
	_update_equipment_visuals()
	equipment_changed.emit(slot, null)
	return item


func _recalc_equip_stats() -> void:
	var dmg_bonus := 0
	var hp_bonus := 0
	var spd_bonus := 0
	var def_bonus := 0
	var agi_bonus := 0
	var corrupted_hp_penalty := 0.0
	for s in equipment:
		if equipment[s] != null:
			var item = equipment[s]
			dmg_bonus += item.stat_damage
			hp_bonus += item.stat_health
			spd_bonus += item.stat_speed
			def_bonus += int(item.get("stat_armor"))
			agi_bonus += int(item.get("stat_agility"))
			# Corrupted items: apply percentage-based malus
			if _item_get(item, "corrupted", false):
				var eid: String = str(_item_get(item, "effect_id", ""))
				if eid == "blood_ring":
					dmg_bonus += int(base_damage * 0.30)
					corrupted_hp_penalty += 0.0  # applied as +30% dmg taken elsewhere
				elif eid == "cursed_blade":
					dmg_bonus += int(base_damage * float(_item_get(item, "effect_value", 0.0)))
					corrupted_hp_penalty += 0.20
				elif eid == "void_drinker":
					corrupted_hp_penalty += 0.30
	attack_damage = base_damage + dmg_bonus
	max_hp = base_hp + hp_bonus
	# Apply corrupted HP penalty
	if corrupted_hp_penalty > 0.0:
		max_hp = int(float(max_hp) * (1.0 - corrupted_hp_penalty))
	current_hp = min(current_hp, max_hp)
	defense = base_defense + def_bonus
	agility = base_agility + agi_bonus
	var raw_speed := base_speed + spd_bonus + float(agility) * 2.0
	move_speed = _soft_cap_move_speed(raw_speed)
	health_changed.emit(current_hp, max_hp)


func _apply_item_effects(item, activate: bool) -> void:
	if item == null:
		return
	var eid: String = str(_item_get(item, "effect_id", ""))
	if eid.is_empty():
		return
	var val: float = float(_item_get(item, "effect_value", 0.0))
	_apply_effect_mod(eid, val, activate)


func _item_get(item, property_name: String, default_value = null):
	var value = item.get(property_name)
	return default_value if value == null else value


func _soft_cap_move_speed(raw_speed: float) -> float:
	if raw_speed <= MOVE_SPEED_SOFT_CAP_START:
		return raw_speed
	var softened := MOVE_SPEED_SOFT_CAP_START + sqrt(raw_speed - MOVE_SPEED_SOFT_CAP_START) * MOVE_SPEED_SOFT_CAP_SCALE
	return minf(softened, MOVE_SPEED_HARD_CAP)


func _rebuild_equipment_effects() -> void:
	_effect_mods.clear()
	for slot in equipment:
		var item = equipment[slot]
		if item != null:
			_apply_item_effects(item, true)


func _apply_effect_mod(eid: String, val: float, activate: bool) -> void:
	if activate:
		_effect_mods[eid] = val
	else:
		_effect_mods.erase(eid)


func has_effect(effect_id: String) -> bool:
	return _effect_mods.has(effect_id)


func get_effect_value(effect_id: String) -> float:
	return float(_effect_mods.get(effect_id, 0.0))


func _scaled_cooldown(base_cooldown: float) -> float:
	var reduction := clampf(get_effect_value("cooldown_redux"), 0.0, 0.65)
	return maxf(0.25, base_cooldown * (1.0 - reduction))


func _emit_combat_status() -> void:
	dash_status_changed.emit(_dash_cooldown_timer <= 0.0, _dash_cooldown_timer, _scaled_cooldown(dash_cooldown))
	for skill_id in SKILL_COOLDOWNS.keys():
		var cooldown := _scaled_cooldown(float(SKILL_COOLDOWNS[skill_id]))
		var left := float(_skill_timers.get(skill_id, 0.0))
		skill_status_changed.emit(skill_id, left <= 0.0, left, cooldown)


func _resolve_attack_damage(base_amount: int) -> int:
	var final_amount := maxi(1, base_amount)
	if has_effect("berserker") and current_hp <= int(float(max_hp) * 0.50):
		final_amount += int(round(float(base_amount) * get_effect_value("berserker")))
	if has_effect("void_touch") and randf() < get_effect_value("void_touch"):
		final_amount += maxi(1, int(round(float(base_amount) * 0.36)))
		_spawn_status_label("VUOTO", Color(0.40, 0.95, 1.0))
	return final_amount


func _apply_on_hit_effects(damage_done: int) -> void:
	if has_effect("life_steal"):
		var amount := int(round(float(damage_done) * get_effect_value("life_steal")))
		if amount > 0:
			heal(amount)


func _apply_defense(amount: int) -> int:
	var reduction := int(round(float(amount) * float(defense) / float(defense + 80)))
	return max(1, amount - reduction)


func is_dead() -> bool:
	return _is_dead


func _try_speak(lines: Array[String], chance: float) -> void:
	if _speech_cooldown > 0.0 or lines.is_empty() or randf() > chance:
		return
	speech_requested.emit(self, lines[randi() % lines.size()], Color(0.55, 0.9, 1.0))
	_speech_cooldown = 3.4


func _boost_color(color: Color, amount: float) -> Color:
	return Color(min(color.r * amount, 1.8), min(color.g * amount, 1.8), min(color.b * amount, 1.8), color.a)


func _is_valid_enemy(node: Node) -> bool:
	if not node or not (node is Node2D):
		return false
	if not node.is_in_group("enemies"):
		return false
	return not (node.has_method("is_dead") and node.is_dead())


func _find_closest_enemy(max_range: float, min_range: float = 0.0) -> Node2D:
	var closest: Node2D = null
	var closest_dist := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not _is_valid_enemy(enemy):
			continue
		var enemy_node := enemy as Node2D
		var dist := global_position.distance_to(enemy_node.global_position)
		if dist <= min_range or dist > max_range:
			continue
		if dist < closest_dist:
			closest = enemy_node
			closest_dist = dist
	return closest


func _find_enemy_near_point(point: Vector2, radius: float) -> Node2D:
	var closest: Node2D = null
	var closest_dist := radius
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not _is_valid_enemy(enemy):
			continue
		var enemy_node := enemy as Node2D
		var dist := enemy_node.global_position.distance_to(point)
		if dist < closest_dist:
			closest = enemy_node
			closest_dist = dist
	return closest


func _perform_melee_attack(target: Node2D) -> void:
	_last_direction = (target.global_position - global_position).normalized()
	if target.has_method("take_damage"):
		var dmg := _resolve_attack_damage(int(attack_damage * _combo_damage_mult[_combo_level]))
		target.take_damage(dmg, self)
		_apply_on_hit_effects(dmg)

	var dash_dir: Vector2 = _last_direction
	match _combo_level:
		1:
			_dash_velocity = dash_dir
			_dash_timer = 0.13
		2:
			var side: float = -1.0 if randi() % 2 == 0 else 1.0
			_dash_velocity = (dash_dir.rotated(0.52 * side) * 0.65 + dash_dir * 0.85).normalized()
			_dash_timer = 0.17
		3:
			_dash_velocity = dash_dir
			_dash_timer = 0.23
		_:
			_dash_velocity = dash_dir
			_dash_timer = 0.12

	_spawn_attack_arc(_combo_level)


func _perform_ranged_attack(target: Node2D) -> void:
	var direction := _last_direction.normalized()
	if target:
		direction = (target.global_position - global_position).normalized()
	if direction.length_squared() < 0.01:
		direction = Vector2.DOWN
	_last_direction = direction

	_dash_velocity = -direction * 0.22
	_dash_timer = 0.07
	_spawn_ranged_cast_flash(direction, _combo_level)
	_spawn_ranged_projectile(direction, target, _combo_level)


func _sync_sprite_glow() -> void:
	if not _sprite_glow or not _sprite:
		return
	_sprite_glow.texture = _sprite.texture
	_sprite_glow.region_enabled = _sprite.region_enabled
	_sprite_glow.region_rect = _sprite.region_rect
	_sprite_glow.position = _sprite.position
	_sprite_glow.rotation = _sprite.rotation
	_sprite_glow.z_index = _sprite.z_index - 1
	var alpha := 0.22
	if _anim_state == AnimState.ATTACK:
		alpha = 0.46 + float(_combo_level) * 0.04
	elif _anim_state == AnimState.HIT:
		alpha = 0.18
	_sprite_glow.modulate = Color(
		lerpf(0.22, _outfit_base_tint.r, 0.22),
		lerpf(0.70, _outfit_base_tint.g, 0.18),
		1.0,
		min(alpha, 0.58)
	)


func _update_shadow(moving: bool, delta: float) -> void:
	if not _shadow:
		return
	var target_scale := Vector2(1.58, 1.36) if moving else Vector2(1.46, 1.30)
	_shadow.scale = _shadow.scale.lerp(target_scale, min(delta * 8.0, 1.0))
	_shadow.modulate = Color(1.0, 1.0, 1.0, 0.70 if moving else 0.58)


func _spawn_attack_arc(combo_level: int) -> void:
	var parent := get_parent()
	if not parent:
		return
	var dir := _last_direction.normalized()
	if dir.length_squared() < 0.01:
		dir = Vector2.DOWN
	var side := Vector2(-dir.y, dir.x)
	var reach := attack_range * (0.72 + float(combo_level) * 0.10)

	var arc := Line2D.new()
	arc.name = "AttackArc"
	arc.position = global_position
	arc.width = 5.0 + float(combo_level) * 1.6
	arc.default_color = Color(0.42, 0.88, 1.0, 0.84) if combo_level < 3 else Color(1.0, 0.66, 0.22, 0.92)
	arc.z_index = 4092
	arc.add_point(dir * 18.0 - side * 32.0)
	arc.add_point(dir * reach)
	arc.add_point(dir * 18.0 + side * 32.0)
	parent.add_child(arc)

	var tw := create_tween()
	tw.tween_property(arc, "scale", Vector2(1.18, 1.18), 0.18).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(arc, "modulate:a", 0.0, 0.18)
	tw.tween_callback(arc.queue_free)


func _spawn_ranged_cast_flash(direction: Vector2, combo_level: int) -> void:
	var parent := get_parent()
	if not parent:
		return
	var flash := Line2D.new()
	flash.name = "RangedCastFlash"
	flash.global_position = global_position
	flash.width = 4.0 + float(combo_level)
	flash.default_color = Color(0.30, 0.92, 1.0, 0.84) if combo_level < 3 else Color(1.0, 0.72, 0.26, 0.92)
	flash.z_index = 4092
	flash.add_point(direction * 18.0 - Vector2(-direction.y, direction.x) * 18.0)
	flash.add_point(direction * 58.0)
	flash.add_point(direction * 18.0 + Vector2(-direction.y, direction.x) * 18.0)
	parent.add_child(flash)

	var tw := create_tween()
	tw.tween_property(flash, "scale", Vector2(1.26, 1.26), 0.16).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(flash, "modulate:a", 0.0, 0.16)
	tw.tween_callback(flash.queue_free)


func _spawn_ranged_projectile(
	direction: Vector2,
	target: Node2D,
	combo_level: int,
	damage_override: int = -1,
	pierce_count: int = 0,
	range_override: float = -1.0,
	radius_scale: float = 1.0,
	projectile_color: Color = Color(0.0, 0.0, 0.0, 0.0)
) -> void:
	var parent := get_parent()
	if not parent:
		return
	var projectile := Area2D.new()
	projectile.name = "PlayerProjectile"
	projectile.collision_layer = 0
	projectile.collision_mask = 4
	projectile.monitoring = true
	projectile.monitorable = false
	projectile.global_position = global_position + direction * 34.0
	projectile.rotation = direction.angle()
	projectile.z_index = 4091
	parent.add_child(projectile)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = projectile_hit_radius * radius_scale
	shape.shape = circle
	projectile.add_child(shape)

	var base_trail_color := Color(0.20, 0.84, 1.0, 0.68) if combo_level < 3 else Color(1.0, 0.64, 0.18, 0.74)
	var base_core_color := Color(0.72, 0.96, 1.0, 0.96) if combo_level < 3 else Color(1.0, 0.88, 0.46, 0.98)
	if projectile_color.a > 0.0:
		base_trail_color = projectile_color
		base_core_color = Color(min(projectile_color.r + 0.22, 1.0), min(projectile_color.g + 0.22, 1.0), min(projectile_color.b + 0.22, 1.0), 0.98)

	var trail := Line2D.new()
	trail.name = "Trail"
	trail.width = 7.0 * radius_scale
	trail.default_color = base_trail_color
	trail.add_point(Vector2(-28.0 - float(pierce_count) * 8.0, 0.0))
	trail.add_point(Vector2(10.0, 0.0))
	projectile.add_child(trail)

	var core := Polygon2D.new()
	core.name = "Core"
	core.polygon = PackedVector2Array([
		Vector2(18.0, 0.0), Vector2(3.0, -8.0), Vector2(-13.0, 0.0), Vector2(3.0, 8.0),
	])
	core.color = base_core_color
	projectile.add_child(core)

	var combo_idx := clampi(combo_level, 0, _combo_damage_mult.size() - 1)
	var damage: int = damage_override if damage_override > 0 else maxi(1, int(round(float(attack_damage) * ranged_damage_multiplier * _combo_damage_mult[combo_idx])))
	var pierce_state := {"remaining": pierce_count}
	var hit_bodies: Dictionary = {}
	projectile.body_entered.connect(func(body: Node) -> void:
		if not is_instance_valid(projectile) or not _is_valid_enemy(body):
			return
		if hit_bodies.has(body.get_instance_id()):
			return
		hit_bodies[body.get_instance_id()] = true
		var final_damage := _resolve_attack_damage(damage)
		if body.has_method("take_damage"):
			body.take_damage(final_damage, self)
			_apply_on_hit_effects(final_damage)
		_spawn_projectile_impact(projectile.global_position, combo_level)
		if int(pierce_state["remaining"]) <= 0:
			projectile.queue_free()
		else:
			pierce_state["remaining"] = int(pierce_state["remaining"]) - 1
	)

	var travel_distance: float = range_override if range_override > 0.0 else ranged_attack_range
	if target:
		travel_distance = min(travel_distance, projectile.global_position.distance_to(target.global_position) + 36.0)
	var end_pos: Vector2 = projectile.global_position + direction * travel_distance
	var duration: float = maxf(0.12, projectile.global_position.distance_to(end_pos) / maxf(projectile_speed, 1.0))
	var tw := projectile.create_tween()
	tw.tween_property(projectile, "global_position", end_pos, duration)
	tw.parallel().tween_property(projectile, "scale", Vector2(1.10, 1.10), duration * 0.5)
	tw.tween_callback(func() -> void:
		if not is_instance_valid(projectile):
			return
		if hit_bodies.is_empty():
			var fallback := _find_enemy_near_point(projectile.global_position, projectile_hit_radius * radius_scale * 1.7)
			if fallback and fallback.has_method("take_damage"):
				var final_damage := _resolve_attack_damage(damage)
				fallback.take_damage(final_damage, self)
				_apply_on_hit_effects(final_damage)
			_spawn_projectile_impact(projectile.global_position, combo_level)
		projectile.queue_free()
	)


func _spawn_projectile_impact(position: Vector2, combo_level: int) -> void:
	var parent := get_parent()
	if not parent:
		return
	var impact_color := Color(0.28, 0.92, 1.0, 0.70) if combo_level < 3 else Color(1.0, 0.68, 0.20, 0.78)
	for i in range(6):
		var spark := Line2D.new()
		spark.name = "ProjectileSpark"
		spark.global_position = position
		spark.rotation = TAU * float(i) / 6.0 + randf_range(-0.18, 0.18)
		spark.width = 3.0
		spark.default_color = impact_color
		spark.z_index = 4093
		spark.add_point(Vector2.ZERO)
		spark.add_point(Vector2(randf_range(18.0, 34.0), 0.0))
		parent.add_child(spark)

		var tw := create_tween()
		tw.tween_property(spark, "scale", Vector2(1.35, 1.35), 0.20).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(spark, "modulate:a", 0.0, 0.20)
		tw.tween_callback(spark.queue_free)


func _deal_area_damage(center: Vector2, radius: float, damage: int) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not _is_valid_enemy(enemy):
			continue
		var enemy_node := enemy as Node2D
		if enemy_node.global_position.distance_to(center) > radius:
			continue
		if enemy_node.has_method("take_damage"):
			var final_damage := _resolve_attack_damage(damage)
			enemy_node.take_damage(final_damage, self)
			_apply_on_hit_effects(final_damage)


func _spawn_ability_burst(center: Vector2, radius: float, color: Color) -> void:
	var parent := get_parent()
	if not parent:
		return
	var ring := Line2D.new()
	ring.name = "ArcaneBurst"
	ring.closed = true
	ring.width = 7.0
	ring.default_color = color
	ring.global_position = center
	ring.z_index = 4092
	for i in range(64):
		var a := TAU * float(i) / 64.0
		ring.add_point(Vector2(cos(a) * radius, sin(a) * radius * 0.58))
	parent.add_child(ring)

	var tw := create_tween()
	ring.scale = Vector2(0.18, 0.18)
	tw.tween_property(ring, "scale", Vector2(1.0, 1.0), 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.38)
	tw.tween_callback(ring.queue_free)


func _spawn_guardian_aegis() -> void:
	var parent := get_parent()
	if not parent:
		return
	var shield := Line2D.new()
	shield.name = "GuardianAegis"
	shield.closed = true
	shield.width = 4.5
	shield.default_color = Color(1.0, 0.76, 0.22, 0.72)
	shield.global_position = global_position + Vector2(0.0, -28.0)
	shield.z_index = 4091
	for i in range(52):
		var a := TAU * float(i) / 52.0
		shield.add_point(Vector2(cos(a) * 48.0, sin(a) * 66.0))
	parent.add_child(shield)

	var tw := create_tween()
	tw.set_loops(6)
	tw.tween_property(shield, "scale", Vector2(1.12, 1.12), 0.25).set_trans(Tween.TRANS_SINE)
	tw.tween_property(shield, "scale", Vector2(0.96, 0.96), 0.25).set_trans(Tween.TRANS_SINE)
	var fade := create_tween()
	fade.tween_interval(guardian_shield_duration)
	fade.tween_property(shield, "modulate:a", 0.0, 0.30)
	fade.tween_callback(shield.queue_free)


func _spawn_dash_afterimage(color: Color) -> void:
	var parent := get_parent()
	if not parent or not _sprite:
		return
	var ghost := Sprite2D.new()
	ghost.name = "DashAfterimage"
	ghost.texture = _sprite.texture
	ghost.region_enabled = _sprite.region_enabled
	ghost.region_rect = _sprite.region_rect
	ghost.global_position = global_position + Vector2(0.0, -42.0)
	ghost.scale = _sprite.scale
	ghost.rotation = _sprite.rotation
	ghost.modulate = color
	ghost.z_index = _sprite.z_index - 1
	parent.add_child(ghost)

	var tw := create_tween()
	tw.tween_property(ghost, "global_position", ghost.global_position - _evade_direction * 34.0, 0.22)
	tw.parallel().tween_property(ghost, "modulate:a", 0.0, 0.22)
	tw.tween_callback(ghost.queue_free)


func _spawn_status_label(text: String, color: Color) -> void:
	var parent := get_parent()
	if not parent:
		return
	var label := Label.new()
	label.name = "PlayerStatus"
	label.text = text
	label.position = global_position + Vector2(-62.0, -118.0)
	label.custom_minimum_size = Vector2(124.0, 0.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.84))
	label.add_theme_constant_override("outline_size", 4)
	label.z_index = 4095
	parent.add_child(label)

	var tw := create_tween()
	tw.tween_property(label, "position:y", label.position.y - 30.0, 0.72)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.72)
	tw.tween_callback(label.queue_free)


func _ensure_equipment_visuals() -> void:
	if _equipment_visuals:
		return
	_equipment_visuals = Node2D.new()
	_equipment_visuals.name = "EquipmentVisuals"
	add_child(_equipment_visuals)

	_add_visual_poly("Cloak", [Vector2(-26, -38), Vector2(26, -38), Vector2(34, 36), Vector2(0, 52), Vector2(-34, 36)], 1, Color(0.07, 0.05, 0.12, 0.42))
	_add_visual_poly("Shoulders", [Vector2(-38, -48), Vector2(-14, -58), Vector2(-3, -42), Vector2(-30, -32), Vector2(3, -42), Vector2(14, -58), Vector2(38, -48), Vector2(30, -32)], 4, Color(0.18, 0.18, 0.24, 0.62))
	_add_visual_poly("HelmGlow", [Vector2(-13, -78), Vector2(0, -90), Vector2(13, -78), Vector2(8, -66), Vector2(-8, -66)], 5, Color(0.2, 0.75, 1.0, 0.55))
	_add_visual_poly("BladeAura", [Vector2(30, -68), Vector2(40, -74), Vector2(55, 3), Vector2(47, 10)], 6, Color(0.55, 0.88, 1.0, 0.45))
	_add_visual_poly("BootGlow", [Vector2(-22, 25), Vector2(-5, 25), Vector2(-9, 45), Vector2(-28, 42), Vector2(5, 25), Vector2(22, 25), Vector2(28, 42), Vector2(9, 45)], 6, Color(0.18, 0.78, 1.0, 0.45))
	_add_visual_poly("RingGlow", [Vector2(18, -29), Vector2(25, -32), Vector2(29, -25), Vector2(22, -21)], 7, Color(0.9, 0.55, 1.0, 0.55))
	_add_visual_poly("AmuletGlow", [Vector2(-8, -52), Vector2(0, -60), Vector2(8, -52), Vector2(4, -44), Vector2(-4, -44)], 7, Color(0.35, 0.88, 0.55, 0.52))
	_add_visual_poly("BeltGlow", [Vector2(-24, -10), Vector2(-10, -18), Vector2(10, -18), Vector2(24, -10), Vector2(18, 2), Vector2(-18, 2)], 3, Color(0.72, 0.58, 0.32, 0.48))
	_add_visual_poly("RelicGlow", [Vector2(32, -42), Vector2(40, -34), Vector2(36, -24), Vector2(28, -24), Vector2(24, -34)], 8, Color(0.85, 0.72, 0.22, 0.58))


func _add_visual_poly(node_name: String, points: Array[Vector2], z: int, color: Color) -> void:
	var poly := Polygon2D.new()
	poly.name = node_name
	poly.polygon = PackedVector2Array(points)
	poly.color = color
	poly.z_index = z
	poly.visible = false
	_equipment_visuals.add_child(poly)


func _update_equipment_visuals() -> void:
	_ensure_equipment_visuals()
	_outfit_base_tint = Color.WHITE

	var armor = equipment.get("armor")
	var helmet = equipment.get("helmet")
	var boots = equipment.get("boots")
	var weapon = equipment.get("weapon")
	var ring = equipment.get("ring")
	var amulet = equipment.get("amulet")
	var belt = equipment.get("belt")
	var relic = equipment.get("relic")

	_set_visual("Cloak", armor != null, _item_visual_color(armor, Color(0.09, 0.07, 0.14, 0.50)))
	_set_visual("Shoulders", armor != null, _item_visual_color(armor, Color(0.22, 0.22, 0.28, 0.65)))
	_set_visual("HelmGlow", helmet != null, _item_visual_color(helmet, Color(0.22, 0.8, 1.0, 0.58)))
	_set_visual("BladeAura", weapon != null, _item_visual_color(weapon, Color(0.55, 0.88, 1.0, 0.50)))
	_set_visual("BootGlow", boots != null, _item_visual_color(boots, Color(0.16, 0.76, 1.0, 0.44)))
	_set_visual("RingGlow", ring != null, _item_visual_color(ring, Color(0.95, 0.62, 1.0, 0.55)))
	_set_visual("AmuletGlow", amulet != null, _item_visual_color(amulet, Color(0.35, 0.88, 0.55, 0.52)))
	_set_visual("BeltGlow", belt != null, _item_visual_color(belt, Color(0.72, 0.58, 0.32, 0.48)))
	_set_visual("RelicGlow", relic != null, _item_visual_color(relic, Color(0.85, 0.72, 0.22, 0.58)))

	if armor != null:
		var armor_color := _item_visual_color(armor, Color(0.8, 0.85, 1.0, 1.0))
		_outfit_base_tint = Color(
			lerpf(1.0, armor_color.r, 0.18),
			lerpf(1.0, armor_color.g, 0.18),
			lerpf(1.0, armor_color.b, 0.18),
			1.0
		)


func _set_visual(node_name: String, visible: bool, color: Color) -> void:
	var node := _equipment_visuals.get_node_or_null(node_name) as Polygon2D
	if not node:
		return
	node.visible = visible
	node.color = color


func _item_visual_color(item, fallback: Color) -> Color:
	if item == null:
		return fallback
	var value = item.get("visual_tint")
	if value is Color:
		var c: Color = value
		return Color(c.r, c.g, c.b, max(c.a, fallback.a))
	return fallback


func _play_audio_cue(cue: String) -> void:
	var audio := get_node_or_null("/root/ProceduralAudio")
	if audio and audio.has_method("play_cue"):
		audio.play_cue(cue)
