extends Node

## SystemMissionManager - original System-style mission loop.
## Tracks daily directives, hunter rank and immediate rewards/penalties.

signal mission_updated(snapshot: Dictionary)
signal mission_completed(mission: Dictionary)
signal mission_failed(mission: Dictionary)
signal system_message(title: String, body: String, tone: Color)

const DAILY_DURATION := 600.0

var hunter_rank: String = "E"
var completed_total: int = 0
var daily_timer: float = DAILY_DURATION
var _missions: Array[Dictionary] = []
var _player: Node = null
var _emit_tick: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_reset_daily()


func _process(delta: float) -> void:
	daily_timer = maxf(0.0, daily_timer - delta)
	if daily_timer <= 0.0:
		_fail_unfinished_daily()
		_reset_daily()
		_emit_tick = 0.0
		_emit_update()
		return
	_emit_tick += delta
	if _emit_tick >= 0.35:
		_emit_tick = 0.0
		_emit_update()


func bind_player(player: Node) -> void:
	_player = player
	_emit_update()


func register_kill(enemy_name: String, xp_value: int, player: Node = null) -> void:
	_bind_if_needed(player)
	_advance("kill", 1)
	if xp_value >= 75 or enemy_name.find("Regina") >= 0 or enemy_name.find("Drago") >= 0 or enemy_name.find("Supremo") >= 0:
		_advance("elite_kill", 1)


func register_dash(player: Node = null) -> void:
	_bind_if_needed(player)
	_advance("dash", 1)


func register_perfect_dodge(player: Node = null) -> void:
	_bind_if_needed(player)
	_advance("perfect_dodge", 1)


func register_skill(skill_id: String, player: Node = null) -> void:
	_bind_if_needed(player)
	_advance("skill", 1)
	if skill_id == "arcane_burst":
		_advance("burst", 1)


func register_loot(item, player: Node = null) -> void:
	_bind_if_needed(player)
	if item == null:
		return
	_advance("loot", 1)
	var rarity := String(item.get("rarity"))
	if rarity in ["rare", "epic", "legendary", "mythic", "archontic", "infinite"]:
		_advance("rare_loot", 1)


func register_map_change(_map_id: String, player: Node = null) -> void:
	_bind_if_needed(player)
	_advance("gate", 1)


func register_boss_phase(_enemy_name: String, _phase_index: int, player: Node = null) -> void:
	_bind_if_needed(player)
	_advance("boss_phase", 1)


func get_snapshot() -> Dictionary:
	return {
		"rank": hunter_rank,
		"completed_total": completed_total,
		"timer": daily_timer,
		"missions": _missions.duplicate(true),
	}


func get_timer_label() -> String:
	var seconds := int(ceil(daily_timer))
	var minutes := int(seconds / 60)
	var rest := seconds % 60
	return "%02d:%02d" % [minutes, rest]


func get_hud_lines(max_lines: int = 4) -> Array[String]:
	var lines: Array[String] = []
	for mission in _missions:
		if bool(mission.get("completed", false)) or bool(mission.get("failed", false)):
			continue
		lines.append("%s %d/%d" % [
			String(mission.get("title", "")),
			int(mission.get("progress", 0)),
			int(mission.get("target", 1)),
		])
		if lines.size() >= max_lines:
			break
	return lines


func _bind_if_needed(player: Node) -> void:
	if player and player != _player:
		_player = player


func _reset_daily() -> void:
	daily_timer = DAILY_DURATION
	_missions = [
		{
			"id": "daily_kills",
			"title": "Elimina ostili",
			"desc": "Ordine giornaliero del Sistema.",
			"type": "kill",
			"target": 12,
			"progress": 0,
			"rank": "E",
			"reward_xp": 60,
			"reward_gold": 35,
			"completed": false,
			"failed": false,
		},
		{
			"id": "daily_dash",
			"title": "Schivate operative",
			"desc": "Usa il passo d'ombra per sopravvivere.",
			"type": "dash",
			"target": 5,
			"progress": 0,
			"rank": "E",
			"reward_xp": 35,
			"reward_gold": 20,
			"completed": false,
			"failed": false,
		},
		{
			"id": "daily_skill",
			"title": "Arti attive",
			"desc": "Esegui abilita da combattimento.",
			"type": "skill",
			"target": 4,
			"progress": 0,
			"rank": "D",
			"reward_xp": 55,
			"reward_gold": 28,
			"completed": false,
			"failed": false,
		},
		{
			"id": "daily_elite",
			"title": "Prede superiori",
			"desc": "Abbatti un nemico d'elite o boss.",
			"type": "elite_kill",
			"target": 1,
			"progress": 0,
			"rank": "C",
			"reward_xp": 120,
			"reward_gold": 75,
			"completed": false,
			"failed": false,
		},
		{
			"id": "daily_rare_loot",
			"title": "Requisizione rara",
			"desc": "Raccogli equipaggiamento raro o migliore.",
			"type": "rare_loot",
			"target": 1,
			"progress": 0,
			"rank": "D",
			"reward_xp": 45,
			"reward_gold": 50,
			"completed": false,
			"failed": false,
		},
	]
	system_message.emit("SISTEMA", "Direttive giornaliere assegnate. Mancato completamento: penalita vitale.", Color(0.42, 0.86, 1.0))
	_emit_update()


func _advance(kind: String, amount: int) -> void:
	for i in range(_missions.size()):
		var mission := _missions[i]
		if String(mission.get("type", "")) != kind:
			continue
		if bool(mission.get("completed", false)) or bool(mission.get("failed", false)):
			continue
		mission["progress"] = mini(int(mission.get("target", 1)), int(mission.get("progress", 0)) + amount)
		_missions[i] = mission
		if int(mission["progress"]) >= int(mission.get("target", 1)):
			_complete_mission(i)
	_emit_update()


func _complete_mission(index: int) -> void:
	var mission := _missions[index]
	mission["completed"] = true
	_missions[index] = mission
	completed_total += 1
	_update_rank()
	_apply_reward(mission)
	mission_completed.emit(mission.duplicate(true))
	system_message.emit(
		"MISSIONE COMPLETATA",
		"%s | Ricompensa: %d XP, %d oro" % [
			String(mission.get("title", "")),
			int(mission.get("reward_xp", 0)),
			int(mission.get("reward_gold", 0)),
		],
		Color(0.42, 1.0, 0.72)
	)


func _apply_reward(mission: Dictionary) -> void:
	if not _player:
		return
	var reward_xp := int(mission.get("reward_xp", 0))
	var reward_gold := int(mission.get("reward_gold", 0))
	if reward_xp > 0 and _player.has_method("gain_xp"):
		_player.gain_xp(reward_xp)
	if reward_gold > 0 and _player.has_method("add_gold"):
		_player.add_gold(reward_gold)
	if _player.has_method("heal"):
		_player.heal(maxi(1, int(float(_player.get("max_hp")) * 0.08)))


func _fail_unfinished_daily() -> void:
	var failed_any := false
	for i in range(_missions.size()):
		var mission := _missions[i]
		if bool(mission.get("completed", false)):
			continue
		mission["failed"] = true
		_missions[i] = mission
		failed_any = true
		mission_failed.emit(mission.duplicate(true))
	if failed_any:
		_apply_penalty()
		system_message.emit("PENALITA DEL SISTEMA", "Direttive ignorate. Vitalita ridotta e nuova lista assegnata.", Color(1.0, 0.36, 0.24))


func _apply_penalty() -> void:
	if not _player or not _player.has_method("take_damage"):
		return
	var damage := maxi(5, int(float(_player.get("max_hp")) * 0.18))
	_player.take_damage(damage, null)


func _update_rank() -> void:
	if completed_total >= 40:
		hunter_rank = "S"
	elif completed_total >= 25:
		hunter_rank = "A"
	elif completed_total >= 15:
		hunter_rank = "B"
	elif completed_total >= 8:
		hunter_rank = "C"
	elif completed_total >= 3:
		hunter_rank = "D"
	else:
		hunter_rank = "E"


func _emit_update() -> void:
	mission_updated.emit(get_snapshot())
