extends SceneTree

const MAIN_SCENE = preload("res://scenes/main/Main.tscn")
const ItemDataClass = preload("res://scripts/items/ItemData.gd")


func _initialize() -> void:
	var world := MAIN_SCENE.instantiate()
	root.add_child(world)
	for i in range(12):
		await process_frame

	var failed: Array[String] = []
	var player := world.get_node_or_null("Player")
	var ui := world.get_node_or_null("GameUI")
	var inventory := root.get_node_or_null("Inventory")
	if player == null:
		failed.append("missing Player")
	if ui == null:
		failed.append("missing GameUI")
	if inventory == null:
		failed.append("missing Inventory autoload")

	if failed.is_empty():
		await _check_inventory_equip(player, ui, inventory, failed)
		await _check_enemy_equipment_drop(world, player, failed)

	world.queue_free()
	await process_frame

	if failed.is_empty():
		print("Inventory equipment smoke test OK")
		quit(0)
	else:
		push_error("Inventory equipment failures: %s" % ", ".join(failed))
		quit(1)


func _check_inventory_equip(player: Node, ui: Node, inventory: Node, failed: Array[String]) -> void:
	inventory.call("clear")
	var item = ItemDataClass.create_equipment_from_def({
		"id": "smoke_blade",
		"name": "Lama Smoke",
		"slot": "weapon",
		"rarity": "rare",
		"value": 1,
		"dmg": 9,
		"def": 2,
		"hp": 4,
		"spd": 6,
		"agi": 3,
	})
	inventory.call("add_item", item)
	ui.call("_toggle_inventory")
	await process_frame

	var panel := ui.get_node_or_null("InventoryPanel") as Panel
	if panel == null or not panel.visible:
		failed.append("inventory panel did not open")
	var equip_button := _find_button_with_text(ui, "Indossa")
	if equip_button == null:
		failed.append("missing Indossa button")
	else:
		equip_button.emit_signal("pressed")
		await process_frame

	var equipment: Dictionary = player.get("equipment")
	if equipment.get("weapon") == null:
		failed.append("weapon was not equipped")
	if int(player.get("attack_damage")) < int(player.get("base_damage")) + 9:
		failed.append("attack stat was not applied")
	if int(player.get("defense")) < 2:
		failed.append("defense stat was not applied")
	if int(player.get("agility")) < 3:
		failed.append("agility stat was not applied")

	var unequip_button := _find_named(ui, "UnEquip_weapon") as Button
	if unequip_button == null:
		failed.append("missing weapon unequip button")
	else:
		unequip_button.emit_signal("pressed")
		await process_frame
		equipment = player.get("equipment")
		if equipment.get("weapon") != null:
			failed.append("weapon was not unequipped")


func _check_enemy_equipment_drop(world: Node, player: Node, failed: Array[String]) -> void:
	if not world.has_method("_spawn"):
		failed.append("world missing _spawn")
		return
	var before_count := _enemy_count(world)
	world.call("_spawn", "skeleton", player.get("global_position") + Vector2(90.0, 0.0))
	await process_frame

	var enemy := _find_newest_enemy(world, before_count)
	if enemy == null:
		failed.append("could not spawn enemy")
		return
	var forced_loot: Array[Dictionary] = [{
		"type": "equip",
		"def": {
			"id": "smoke_armor",
			"name": "Corazza Smoke",
			"slot": "armor",
			"rarity": "uncommon",
			"value": 1,
			"dmg": 1,
			"def": 5,
			"hp": 12,
			"spd": 0,
			"agi": 1,
		}
	}]
	enemy.set("loot_table", forced_loot)
	enemy.call("take_damage", 9999, player)
	await process_frame
	await process_frame

	var dropped_items := world.get_node_or_null("DroppedItems")
	if dropped_items == null or dropped_items.get_child_count() <= 0:
		failed.append("enemy defeat did not create equipment drop")


func _enemy_count(world: Node) -> int:
	var count := 0
	for child in world.get_children():
		if child.is_in_group("enemies") and child.has_method("take_damage"):
			count += 1
	return count


func _find_newest_enemy(world: Node, before_count: int) -> Node:
	var seen := 0
	for child in world.get_children():
		if child.is_in_group("enemies") and child.has_method("take_damage"):
			if seen >= before_count:
				return child
			seen += 1
	return null


func _find_button_with_text(root_node: Node, text: String) -> Button:
	if root_node is Button and (root_node as Button).text == text:
		return root_node as Button
	for child in root_node.get_children():
		var found := _find_button_with_text(child, text)
		if found:
			return found
	return null


func _find_named(root_node: Node, node_name: String) -> Node:
	if root_node.name == node_name:
		return root_node
	for child in root_node.get_children():
		var found := _find_named(child, node_name)
		if found:
			return found
	return null
