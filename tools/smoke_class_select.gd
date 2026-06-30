extends SceneTree

## P0 — verifica: su profilo senza salvataggio, le stat della classe
## selezionata su PlayerData vengono applicate al nuovo player.

const MAIN_SCENE = preload("res://scenes/main/Main.tscn")

const CLASS_CHECKS: Array[Dictionary] = [
	{"id": "shadow_blade", "hp": 75, "dmg": 8, "spd": 240.0},
	{"id": "arena_champion", "hp": 120, "dmg": 12, "spd": 190.0},
	{"id": "wood_warden", "hp": 80, "dmg": 9, "spd": 210.0},
	{"id": "battle_arcanist", "hp": 70, "dmg": 7, "spd": 200.0},
]


func _initialize() -> void:
	var failed: Array[String] = []
	var sm := root.get_node_or_null("SaveManager")
	var pd := root.get_node_or_null("PlayerData")

	print("Account: %s" % sm.get_current_account() if sm else "?")

	for check in CLASS_CHECKS:
		var cid: String = check["id"]
		if pd:
			pd.set_class(cid)

		var main := MAIN_SCENE.instantiate()
		root.add_child(main)
		for i in range(14):
			await process_frame

		var player := main.get_node_or_null("Player")
		if player == null:
			failed.append("%s (missing player)" % cid)
		else:
			var hp: int = int(player.get("max_hp"))
			var dmg: int = int(player.get("attack_damage"))
			var spd: float = float(player.get("move_speed"))
			print("  %-18s  hp=%-3d  dmg=%-2d  spd=%-6.0f" % [cid, hp, dmg, spd])
			if hp != int(check["hp"]):
				failed.append("%s (hp %d != %d)" % [cid, hp, int(check["hp"])])
			if dmg != int(check["dmg"]):
				failed.append("%s (dmg %d != %d)" % [cid, dmg, int(check["dmg"])])
			if abs(spd - float(check["spd"])) > 0.5:
				failed.append("%s (spd %f != %f)" % [cid, spd, float(check["spd"])])

		main.queue_free()
		for i in range(4):
			await process_frame

	# Class select UI: 6 cards.
	if sm:
		sm.delete_save()
	if pd:
		pd.set_class("arena_champion")
	var main2 := MAIN_SCENE.instantiate()
	root.add_child(main2)
	for i in range(10):
		await process_frame
	if main2.has_method("_show_class_select"):
		main2.call("_show_class_select")
		await process_frame
		var cs_layer := main2.get_node_or_null("ClassSelect")
		if cs_layer == null:
			failed.append("ClassSelect (layer not built)")
		else:
			var card_count := _count_cards(cs_layer)
			if card_count < 6:
				failed.append("ClassSelect (only %d cards, expected >=6)" % card_count)
	main2.queue_free()
	for i in range(4):
		await process_frame

	if failed.is_empty():
		print("Class select smoke test OK")
		quit(0)
	else:
		push_error("Class select failures: %s" % ", ".join(failed))
		quit(1)


func _count_cards(node: Node) -> int:
	var total := 0
	if node is Panel and String(node.name).begins_with("Card_"):
		total += 1
	for child in node.get_children():
		total += _count_cards(child)
	return total
