extends SceneTree

const PlayerClass = preload("res://scripts/player/Player.gd")

func _initialize() -> void:
	var failed: Array[String] = []

	var p := PlayerClass.new()

	# XP curve: check that _calculate_next_xp_required is monotonic
	var prev := 30
	for lv in range(2, 105, 3):
		var req: int = int(p._calculate_next_xp_required(lv, prev))
		if req < prev:
			failed.append("xp curve not monotonic at lv %d: %d < %d" % [lv, req, prev])
		prev = req

	# Speed cap: _soft_cap_move_speed
	var uncapped: float = float(p._soft_cap_move_speed(360.0))
	if abs(uncapped - 360.0) > 0.01:
		failed.append("speed 360 should be uncapped: %.2f" % uncapped)

	var capped: float = float(p._soft_cap_move_speed(1300.0))
	if capped > 860.0:
		failed.append("speed 1300 exceeds hard cap: %.2f" % capped)
	if capped <= 720.0:
		failed.append("speed 1300 cap too severe: %.2f" % capped)

	var extreme: float = float(p._soft_cap_move_speed(5000.0))
	if extreme > 860.0:
		failed.append("speed 5000 exceeds hard cap: %.2f" % extreme)

	# Damage computation: take_damage should reduce HP
	p.max_hp = 100; p.current_hp = 100
	if p.has_method("take_damage"):
		p.take_damage(30, null)
		if p.current_hp != 70:
			failed.append("take_damage 30 -> hp=%d (expected 70)" % p.current_hp)

	# Overkill: damage > remaining HP should cap at 0
	p.current_hp = 10
	p.take_damage(50, null)
	if p.current_hp != 0:
		failed.append("overkill should set hp=0, got %d" % p.current_hp)
	if not p.is_dead():
		failed.append("player should be dead after overkill")

	# Gold
	p.gold = 0
	p.add_gold(100)
	if p.gold != 100:
		failed.append("add_gold 100 -> %d" % p.gold)
	p.add_gold(-30)
	if p.gold != 70:
		failed.append("add_gold -30 -> %d" % p.gold)

	# Equipment slots
	var slots: Dictionary = p.equipment
	if slots.size() < 8:
		failed.append("equipment slots: %d < 8" % slots.size())
	for expected_slot in ["weapon","armor","helmet","boots","ring","amulet","belt","relic"]:
		if not slots.has(expected_slot):
			failed.append("missing equipment slot: %s" % expected_slot)

	if failed.is_empty():
		print("test_player OK")
		quit(0)
	else:
		push_error("Player failures: %s" % ", ".join(failed))
		quit(1)
