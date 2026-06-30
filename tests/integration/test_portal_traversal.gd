extends SceneTree

const MAIN_SCENE = preload("res://scenes/main/Main.tscn")

func _initialize() -> void:
	var failed: Array[String] = []

	# Start fresh — delete save to guarantee new game
	var sm := root.get_node_or_null("SaveManager")
	if sm:
		sm.set_current_account("int_portal_test")
		sm.delete_save("int_portal_test")

	# Set a known class
	var pd := root.get_node_or_null("PlayerData")
	if pd:
		pd.set_class("arena_champion")

	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	for i in range(12):
		await process_frame

	# Load first map
	main.call("_load_map", "black_oak_farm")
	for i in range(14):
		await process_frame

	var p1 := main.get_node_or_null("Player")
	if p1 == null:
		failed.append("player not found after first load")
	else:
		var hp1: int = int(p1.get("max_hp"))
		var xp1: int = int(p1.get("xp"))
		var gold1: int = int(p1.get("gold"))
		var lvl1: int = int(p1.get("level"))

		# Gain some XP by simulating combat
		if p1.has_method("gain_xp"):
			p1.gain_xp(60)
		p1.add_gold(100) if p1.has_method("add_gold") else null

		# Traverse portal to next map
		var target_map := "black_oak_city"
		# Call _load_map via the portal mechanism — simulate what _on_portal_proximity does
		main.call("_load_map", target_map)
		for i in range(14):
			await process_frame

		var p2 := main.get_node_or_null("Player")
		if p2 == null:
			failed.append("player lost after portal traversal")
		else:
			var hp2: int = int(p2.get("max_hp"))
			var xp2: int = int(p2.get("xp"))
			var gold2: int = int(p2.get("gold"))
			var lvl2: int = int(p2.get("level"))

			# HP should transfer (or at least be positive)
			if hp2 <= 0:
				failed.append("player hp zero after traversal")

			# XP should be preserved (or increased)
			if xp2 < xp1:
				failed.append("xp lost on traversal: %d -> %d" % [xp1, xp2])

			# Gold should be preserved
			if gold2 < gold1:
				failed.append("gold lost on traversal: %d -> %d" % [gold1, gold2])

			# Level should be preserved
			if lvl2 < lvl1:
				failed.append("level lost on traversal: %d -> %d" % [lvl1, lvl2])

			# Traverse one more time
			main.call("_load_map", "roma_centro")
			for i in range(14):
				await process_frame

			var p3 := main.get_node_or_null("Player")
			if p3 == null:
				failed.append("player lost after second traversal")

	main.queue_free()
	for i in range(4):
		await process_frame

	# Cleanup
	if sm:
		sm.delete_save("int_portal_test")
		sm.set_current_account("local_player")

	if failed.is_empty():
		print("test_portal_traversal OK")
		quit(0)
	else:
		push_error("Portal traversal failures: %s" % ", ".join(failed))
		quit(1)
