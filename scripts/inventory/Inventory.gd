extends Node

## Inventory — Global inventory manager (Autoload).
## Stores collected items as a flat list (no Tetris grid for MVP).

signal inventory_changed
signal item_added(item_data)
signal item_removed(item_data)

var items: Array = []
var max_items: int = 30


func add_item(item_data) -> bool:
	if items.size() >= max_items:
		return false

	if item_data.stackable:
		for existing in items:
			if existing.id == item_data.id and existing.quantity < existing.max_stack:
				existing.quantity += item_data.quantity
				inventory_changed.emit()
				item_added.emit(item_data)
				return true

	items.append(item_data)
	inventory_changed.emit()
	item_added.emit(item_data)
	return true


func remove_item(item_data) -> void:
	var idx := items.find(item_data)
	if idx >= 0:
		items.remove_at(idx)
		inventory_changed.emit()
		item_removed.emit(item_data)


func remove_item_by_id(item_id: String, count: int = 1) -> bool:
	for item in items:
		if item.id == item_id:
			if item.stackable and item.quantity > count:
				item.quantity -= count
			else:
				remove_item(item)
			inventory_changed.emit()
			return true
	return false


func has_item(item_id: String) -> bool:
	for item in items:
		if item.id == item_id:
			return true
	return false


func get_item_count(item_id: String) -> int:
	var count := 0
	for item in items:
		if item.id == item_id:
			count += item.quantity
	return count


func get_items() -> Array:
	return items


func clear() -> void:
	items.clear()
	inventory_changed.emit()


func is_full() -> bool:
	return items.size() >= max_items
