# Map Registry — all available maps with portal connections
# Solo Leveling dungeon gates system

const ALL_MAPS: Array[Dictionary] = [
	{
		"id": "black_oak_farm",
		"tileset": "grassland",
		"title": "Black Oak Farm",
		"desc": "Fattoria ai margini della foresta. Goblin e scheletri infestano i campi.",
		"data": preload("res://data/maps/black_oak_farm_data.gd"),
		"hero_spawn": Vector2(50, 50),
		"portals": [
			{"target": "black_oak_city", "pos": Vector2(15, 90), "label": "Black Oak City"},
			{"target": "nazia_highlands", "pos": Vector2(85, 15), "label": "Nazia Highlands"},
			{"target": "grot_lagoon", "pos": Vector2(65, 80), "label": "[NEVE] Grot Lagoon"},
		],
	},
	{
		"id": "black_oak_city",
		"tileset": "grassland",
		"title": "Black Oak City",
		"desc": "La citt\u00e0 fortificata. Maghi e draghi pattugliano le mura.",
		"data": preload("res://data/maps/black_oak_city_data.gd"),
		"hero_spawn": Vector2(50, 50),
		"portals": [
			{"target": "black_oak_farm", "pos": Vector2(15, 90), "label": "Black Oak Farm"},
			{"target": "merrimead_swamp", "pos": Vector2(85, 15), "label": "Merrimead Swamp"},
			{"target": "stonewood", "pos": Vector2(50, 90), "label": "Stonewood"},
		],
	},
	{
		"id": "nazia_highlands",
		"tileset": "grassland",
		"title": "Nazia Highlands",
		"desc": "Altopiani ventosi. Viverni e draghi volteggiano nel cielo.",
		"data": preload("res://data/maps/nazia_highlands_data.gd"),
		"hero_spawn": Vector2(40, 40),
		"portals": [
			{"target": "black_oak_farm", "pos": Vector2(15, 70), "label": "Black Oak Farm"},
			{"target": "oasis", "pos": Vector2(70, 15), "label": "Oasis"},
		],
	},
	{
		"id": "merrimead_swamp",
		"tileset": "grassland",
		"title": "Merrimead Swamp",
		"desc": "Palude maledetta. Zombie e non-morti emergono dalle acque.",
		"data": preload("res://data/maps/merrimead_swamp_data.gd"),
		"hero_spawn": Vector2(40, 40),
		"portals": [
			{"target": "black_oak_city", "pos": Vector2(15, 70), "label": "Black Oak City"},
			{"target": "southern_ridge", "pos": Vector2(70, 15), "label": "Southern Ridge"},
		],
	},
	{
		"id": "southern_ridge",
		"tileset": "grassland",
		"title": "Southern Ridge",
		"desc": "Crinale roccioso a sud. Lich e creature antiche.",
		"data": preload("res://data/maps/southern_ridge_data.gd"),
		"hero_spawn": Vector2(40, 40),
		"portals": [
			{"target": "merrimead_swamp", "pos": Vector2(15, 70), "label": "Merrimead Swamp"},
			{"target": "black_oak_farm", "pos": Vector2(70, 15), "label": "Black Oak Farm"},
			{"target": "salted_field", "pos": Vector2(40, 70), "label": "Salted Field"},
		],
	},
	{
		"id": "salted_field",
		"tileset": "grassland",
		"title": "Salted Field",
		"desc": "Campi di sale abbandonati. Terra desolata.",
		"data": preload("res://data/maps/salted_field_data.gd"),
		"hero_spawn": Vector2(30, 30),
		"portals": [
			{"target": "southern_ridge", "pos": Vector2(15, 50), "label": "Southern Ridge"},
			{"target": "stonewood", "pos": Vector2(50, 15), "label": "Stonewood"},
		],
	},
	{
		"id": "stonewood",
		"tileset": "grassland",
		"title": "Stonewood",
		"desc": "Foresta pietrificata. Alberi di pietra e rovine antiche.",
		"data": preload("res://data/maps/stonewood_data.gd"),
		"hero_spawn": Vector2(50, 40),
		"portals": [
			{"target": "black_oak_city", "pos": Vector2(15, 75), "label": "Black Oak City"},
			{"target": "salted_field", "pos": Vector2(85, 15), "label": "Salted Field"},
		],
	},
	{
		"id": "oasis",
		"tileset": "grassland",
		"title": "Oasis",
		"desc": "Oasi nel deserto. Rifugio di mercanti e predoni.",
		"data": preload("res://data/maps/oasis_data.gd"),
		"hero_spawn": Vector2(50, 50),
		"portals": [
			{"target": "nazia_highlands", "pos": Vector2(15, 85), "label": "Nazia Highlands"},
		],
	},
	{
		"id": "river_trail",
		"tileset": "grassland",
		"title": "River Trail",
		"desc": "Sentiero lungo il fiume. Goblin e creature acquatiche.",
		"data": preload("res://data/maps/river_trail_data.gd"),
		"hero_spawn": Vector2(40, 20),
		"portals": [
			{"target": "lochport", "pos": Vector2(15, 30), "label": "Lochport"},
			{"target": "perdition_harbor", "pos": Vector2(70, 15), "label": "Perdition Harbor"},
		],
	},
	{
		"id": "lochport",
		"tileset": "grassland",
		"title": "Lochport",
		"desc": "Porto lacustre avvolto nella nebbia.",
		"data": preload("res://data/maps/lochport_data.gd"),
		"hero_spawn": Vector2(25, 30),
		"portals": [
			{"target": "river_trail", "pos": Vector2(15, 50), "label": "River Trail"},
			{"target": "perdition_harbor", "pos": Vector2(40, 15), "label": "Perdition Harbor"},
		],
	},
	{
		"id": "perdition_harbor",
		"tileset": "grassland",
		"title": "Perdition Harbor",
		"desc": "Porto maledetto. Navi fantasma e pirati non-morti.",
		"data": preload("res://data/maps/perdition_harbor_data.gd"),
		"hero_spawn": Vector2(20, 20),
		"portals": [
			{"target": "lochport", "pos": Vector2(15, 30), "label": "Lochport"},
			{"target": "river_trail", "pos": Vector2(30, 15), "label": "River Trail"},
		],
	},
	# === SNOWPLAINS (NEVE) ===
	{
		"id": "grot_lagoon",
		"tileset": "snowplains",
		"title": "Grot Lagoon",
		"desc": "Laguna ghiacciata tra le montagne innevate. Viverni del ghiaccio.",
		"data": preload("res://data/maps/grot_lagoon_data.gd"),
		"hero_spawn": Vector2(56, 56),
		"portals": [
			{"target": "black_oak_farm", "pos": Vector2(15, 100), "label": "Black Oak Farm"},
			{"target": "lake_kuuma", "pos": Vector2(100, 15), "label": "[NEVE] Lake Kuuma"},
		],
	},
	{
		"id": "lake_kuuma",
		"tileset": "snowplains",
		"title": "Lake Kuuma",
		"desc": "Lago ghiacciato immenso. Draghi di ghiaccio e spiriti antichi.",
		"data": preload("res://data/maps/lake_kuuma_data.gd"),
		"hero_spawn": Vector2(66, 66),
		"portals": [
			{"target": "grot_lagoon", "pos": Vector2(15, 120), "label": "[NEVE] Grot Lagoon"},
		],
	},
]


static func get_map(map_id: String) -> Dictionary:
	for m in ALL_MAPS:
		if m.id == map_id:
			return m
	return ALL_MAPS[0]


static func get_all_maps() -> Array[Dictionary]:
	return ALL_MAPS
