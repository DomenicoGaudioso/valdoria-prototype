# Auto-generated city map data for 3D local maps - Ruined City
static func get_data() -> Dictionary:
	return {
		"width": 80,
		"height": 80,
		"background": _grid("dense_city", 83),
		"object": _obj_grid("dense_city", 83),
	}

static func _grid(style: String, seed: int) -> Array:
	var g: Array = []
	var s = seed
	for y in range(80):
		var row: Array[int] = []
		for x in range(80):
			var v := 0
			if x % 12 <= 1 or y % 12 <= 1: v = 22
			elif (x + s) % 5 == 0 and (y + s * 2) % 5 == 0: v = 20
			elif (x * y + s) % 7 < 2: v = 18
			elif (x + y) % 4 == 0: v = 26
			else: v = 19
			row.append(v)
		g.append(row)
	return g

static func _obj_grid(style: String, seed: int) -> Array:
	var g: Array = []
	var s = seed
	for y in range(80):
		var row: Array[int] = []
		for x in range(80):
			var v := 0
			if x % 12 > 1 and y % 12 > 1 and (x * y + s) % 5 == 0:
				v = 232
			row.append(v)
		g.append(row)
	return g
