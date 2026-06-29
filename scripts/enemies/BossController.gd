extends RefCounted
## BossController — boss with phase transitions, special attacks, themed loot.
## Attach to an enemy node to enable boss mechanics.

class_name BossController

var _enemy: Node2D
var _boss_data: Dictionary
var _current_phase: int = 0
var _phase_timer: float = 0.0
var _special_attack_timer: float = 0.0
var _phase_thresholds: PackedFloat32Array
var _triggered_phases: Array[int] = []

signal boss_phase_changed(phase_name: String)
signal boss_special_attack(attack_name: String)


func init(enemy: Node2D, boss_id: String) -> void:
	_enemy = enemy
	_boss_data = BossLore.get_boss(boss_id)
	if _boss_data.is_empty():
		push_warning("BossController: unknown boss_id '%s'" % boss_id)
		return

	# Setup phases
	var phases: Array = _boss_data.get("phases", [])
	_phase_thresholds.clear()
	for i in range(phases.size()):
		var hp_pct: float = float(phases[i].get("hp_threshold", 1.0))
		_phase_thresholds.append(hp_pct)

	# Scale enemy stats
	if _enemy:
		var sm: Dictionary = _boss_data.get("stats_mult", {})
		var hp: int = int(_enemy.get("max_hp"))
		_enemy.set("max_hp", int(float(hp) * float(sm.get("hp", 5.0))))
		_enemy.set("current_hp", _enemy.get("max_hp"))
		_enemy.set("attack_damage", int(float(_enemy.get("attack_damage")) * float(sm.get("dmg", 2.5))))
		_enemy.set("move_speed", float(_enemy.get("move_speed")) * float(sm.get("spd", 1.0)))
		_enemy.set("xp_value", int(float(_enemy.get("xp_value")) * float(sm.get("xp", 4.0))))

		# Boss lines
		_boss_data.get("voice_color", Color(0.95, 0.3, 0.2))
		var phase0: Dictionary = phases[0] if phases.size() > 0 else {}
		_enemy.set("spawn_lines", phase0.get("lines", ["Il boss ti osserva."]))
		_enemy.set("voice_color", Color(1.0, 0.45, 0.2))

	_current_phase = 0
	_phase_timer = 0.0
	_special_attack_timer = 6.0


func process(delta: float) -> void:
	if not _enemy or _enemy.is_dead():
		return

	_phase_timer += delta
	_special_attack_timer -= delta
	_check_phase_trigger()

	if _special_attack_timer <= 0.0:
		_trigger_special()


func _check_phase_trigger() -> void:
	if not _enemy:
		return

	var max_hp: int = int(_enemy.get("max_hp"))
	var cur_hp: int = int(_enemy.get("current_hp"))
	if max_hp <= 0:
		return

	var hp_ratio: float = float(cur_hp) / float(max_hp)
	var phases: Array = _boss_data.get("phases", [])

	for i in range(phases.size()):
		if i in _triggered_phases:
			continue
		var threshold: float = float(phases[i].get("hp_threshold", 1.0))
		if hp_ratio <= threshold:
			_triggered_phases.append(i)
			_current_phase = i
			var phase_name: String = phases[i].get("name", "Fase %d" % (i + 1))
			boss_phase_changed.emit(phase_name)

			# Say phase transition line
			if _enemy.has_signal("speech_requested"):
				var lines: Array = phases[i].get("lines", [])
				if not lines.is_empty():
					_enemy.speech_requested.emit(_enemy, lines[randi() % lines.size()], Color(1.0, 0.45, 0.2))

			# Tint change for visual feedback
			var sp: Sprite2D = _enemy.get_node_or_null("Sprite2D") as Sprite2D
			if sp:
				sp.modulate = Color(1.2, 0.8, 0.6)
				var tw := _enemy.create_tween()
				tw.tween_property(sp, "modulate", sp.modulate, 0.5)
			break


func _trigger_special() -> void:
	var phases: Array = _boss_data.get("phases", [])
	if _current_phase >= phases.size():
		return

	var phase: Dictionary = phases[_current_phase]
	var mechanics: Array = phase.get("mechanics", [])
	if mechanics.is_empty():
		_special_attack_timer = 8.0
		return

	var attack_name: String = mechanics[randi() % mechanics.size()]
	boss_special_attack.emit(attack_name)
	_special_attack_timer = 5.0 + randf() * 4.0


func spawn_boss_loot() -> Array:
	"""Returns themed loot entries for this boss."""
	var loot: Array = []
	var table: Dictionary = _boss_data.get("loot_table", {})

	# Guaranteed drop
	var guaranteed: Dictionary = table.get("guaranteed", {})
	if not guaranteed.is_empty():
		loot.append({"type":"equip","def":_boss_equip_from_loot(guaranteed)})

	# Special drop (50% chance)
	if randf() < 0.5:
		var special: Dictionary = table.get("special", {})
		if not special.is_empty():
			loot.append({"type":"equip","def":_boss_equip_from_loot(special)})

	# Extra gold
	loot.append({"type":"gold","amount":100 + randi() % 200,"name":"Tesoro del Boss"})

	return loot


func _boss_equip_from_loot(def: Dictionary) -> Dictionary:
	"""Build an equipment def dict from boss loot data."""
	return {
		"id": def.get("id", def.get("name", "???").to_snake_case()),
		"name": def.get("name", "Reliquia"),
		"slot": def.get("slot", "relic"),
		"rarity": def.get("rarity", "epic"),
		"value": def.get("value", 200),
		"dmg": def.get("dmg", 0),
		"hp": def.get("hp", 0),
		"spd": def.get("spd", 0),
		"def": def.get("def", 0),
		"agi": def.get("agi", 0),
		"mat": def.get("mat", "ombra viva"),
		"tint": def.get("tint", [0.45, 0.22, 0.95, 0.68]),
		"effect": def.get("effect", ""),
		"efx_val": def.get("efx_val", 0.0),
		"corrupt": def.get("corrupt", false),
		"corr_text": def.get("corr_text", ""),
		"flavor": def.get("flavor", ""),
	}
