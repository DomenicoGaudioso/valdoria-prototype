extends SceneTree

## E2E: catena di portali — attraversa 8+ mappe e verifica sopravvivenza del player.

const MAIN_SCENE = preload("res://scenes/main/Main.tscn")

# Path from black_oak_city through grassland, dungeon, snowplains, real city, endless
const ROUTE: Array[String] = [
	"black_oak_farm",
	"black_oak_city",
	"roma_centro",
	"parigi_cite",
	"fort_nasu",
	"fort_amir",
	"grot_lagoon",
	"black_oak_city",
]

func _initialize() -> void:
	var failed: Array[String] = []
	var sm := root.get_node_or_null("SaveManager")
	var pd := root.get_node_or_null("PlayerData")

	sm.set_current_account("e2e_chain")
	sm.delete_save("e2e_chain")
	pd.set_class("arena_champion")

	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	for i in range(10):
		await process_frame

	for map_id in ROUTE:
		main.call("_load_map", map_id)
		for i in range(16):
			await process_frame

		var player := main.get_node_or_null("Player")
		if player == null:
			failed.append("chain: player lost at %s" % map_id)
			break

		var hp: int = int(player.get("max_hp"))
		if hp <= 0:
			failed.append("chain: player dead at %s" % map_id)
			break

		var is_dead_val: bool = bool(player.get("_is_dead") if player.has_method("is_dead") and player.is_dead() else false)
		if is_dead_val:
			failed.append("chain: player died at %s" % map_id)
			break

	main.queue_free()
	for i in range(4):
		await process_frame

	sm.delete_save("e2e_chain")
	sm.set_current_account("local_player")

	if failed.is_empty():
		print("test_e2e_portal_chain OK")
		quit(0)
	else:
		push_error("E2E portal chain failures: %s" % ", ".join(failed))
		quit(1)
