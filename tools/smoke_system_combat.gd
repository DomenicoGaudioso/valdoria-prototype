extends SceneTree

const PlayerScript := preload("res://scripts/player/Player.gd")
const EnemyScript := preload("res://scripts/enemies/Enemy.gd")


func _init() -> void:
	await process_frame
	var arena := Node2D.new()
	root.add_child(arena)

	var player := CharacterBody2D.new()
	player.name = "Player"
	player.set_script(PlayerScript)
	player.global_position = Vector2.ZERO
	var player_sprite := Sprite2D.new()
	player_sprite.name = "Sprite2D"
	player.add_child(player_sprite)
	var player_shadow := Sprite2D.new()
	player_shadow.name = "Shadow"
	player.add_child(player_shadow)
	arena.add_child(player)

	var enemy := CharacterBody2D.new()
	enemy.name = "SmokeTarget"
	enemy.set_script(EnemyScript)
	enemy.global_position = Vector2(86.0, 0.0)
	enemy.set("max_hp", 120)
	enemy.set("current_hp", 120)
	enemy.set("boss_like", true)
	enemy.set("phase_count", 3)
	var enemy_sprite := Sprite2D.new()
	enemy_sprite.name = "Sprite2D"
	enemy.add_child(enemy_sprite)
	arena.add_child(enemy)

	await process_frame

	var system := root.get_node_or_null("SystemMission")
	if system and system.has_method("bind_player"):
		system.bind_player(player)
		player.dash_performed.connect(func(): system.register_dash(player))
		player.skill_used.connect(func(skill_id: String): system.register_skill(skill_id, player))

	player._on_dash_command()
	player._on_skill_command("arcane_burst")
	await create_timer(0.2).timeout

	if int(enemy.get("current_hp")) >= 120:
		push_error("Smoke failed: arcane_burst did not damage the target.")
		quit(1)
		return

	if system and system.has_method("get_snapshot"):
		var snapshot: Dictionary = system.get_snapshot()
		var missions: Array = snapshot.get("missions", [])
		var saw_dash_progress := false
		var saw_skill_progress := false
		for mission in missions:
			if String(mission.get("type", "")) == "dash" and int(mission.get("progress", 0)) > 0:
				saw_dash_progress = true
			if String(mission.get("type", "")) == "skill" and int(mission.get("progress", 0)) > 0:
				saw_skill_progress = true
		if not saw_dash_progress or not saw_skill_progress:
			push_error("Smoke failed: System missions did not receive dash/skill events.")
			quit(1)
			return

	print("System combat smoke OK: target HP %d" % int(enemy.get("current_hp")))
	quit(0)
