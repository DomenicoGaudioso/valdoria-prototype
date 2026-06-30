extends Node

## ClassData — Central player data manager (Autoload).
## Holds current class, stats, and progression info.
## Prepared for future multi-class system.

signal class_changed(class_info: Dictionary)
signal stats_updated

@export var player_class_id: String = "arena_champion"
@export var player_class_name: String = "Campione delle Arene"

var base_stats: Dictionary = {
	"max_hp": 100,
	"move_speed": 200.0,
	"attack_damage": 10,
	"attack_range": 50.0,
	"attack_cooldown": 0.8,
}

var bonus_stats: Dictionary = {
	"max_hp": 0,
	"move_speed": 0.0,
	"attack_damage": 0,
	"attack_range": 0.0,
}

var _class_definitions: Dictionary = {}


func _init() -> void:
	_define_classes()


func _ready() -> void:
	pass


func _define_classes() -> void:
	_class_definitions = {
		"arena_champion": {
			"id": "arena_champion",
			"name": "Campione delle Arene",
			"description": "Combattente corpo a corpo temprato da mille duelli nell'arena. Brandisce armi pesanti con forza brutale.",
			"base_stats": {
				"max_hp": 120,
				"move_speed": 190.0,
				"attack_damage": 12,
				"attack_range": 50.0,
				"attack_cooldown": 0.9,
			},
			"weapon_types": ["sword", "axe", "mace", "shield"],
			"armor_type": "heavy",
			"playstyle": "melee_heavy",
		},
		"shadow_blade": {
			"id": "shadow_blade",
			"name": "Lama d'Ombra",
			"description": "Assassino silenzioso che colpisce dall'oscurità con veleno e lame gemelle.",
			"base_stats": {
				"max_hp": 75,
				"move_speed": 240.0,
				"attack_damage": 8,
				"attack_range": 40.0,
				"attack_cooldown": 0.5,
			},
			"weapon_types": ["dagger", "dual_blades", "poison"],
			"armor_type": "light",
			"playstyle": "melee_fast",
		},
		"wood_warden": {
			"id": "wood_warden",
			"name": "Custode dei Boschi",
			"description": "Arciere della foresta che usa l'arco, la natura e le trappole per abbattere i nemici.",
			"base_stats": {
				"max_hp": 80,
				"move_speed": 210.0,
				"attack_damage": 9,
				"attack_range": 300.0,
				"attack_cooldown": 0.7,
			},
			"weapon_types": ["bow", "crossbow", "trap"],
			"armor_type": "medium",
			"playstyle": "ranged",
		},
		"battle_arcanist": {
			"id": "battle_arcanist",
			"name": "Arcanista da Battaglia",
			"description": "Mago guerriero che fonde incantesimi elementali con combattimento ravvicinato.",
			"base_stats": {
				"max_hp": 70,
				"move_speed": 200.0,
				"attack_damage": 7,
				"attack_range": 60.0,
				"attack_cooldown": 0.6,
			},
			"weapon_types": ["staff", "wand", "spell"],
			"armor_type": "cloth",
			"playstyle": "hybrid_caster",
		},
		"crimson_heir": {
			"id": "crimson_heir",
			"name": "Erede Cremisi",
			"description": "Nobile oscuro che ruba la vita ai nemici. Stile gotico e abilità di metamorfosi.",
			"base_stats": {
				"max_hp": 85,
				"move_speed": 220.0,
				"attack_damage": 8,
				"attack_range": 45.0,
				"attack_cooldown": 0.7,
			},
			"weapon_types": ["sword", "orb", "blood_magic"],
			"armor_type": "medium",
			"playstyle": "lifesteal",
		},
		"winged_ascendant": {
			"id": "winged_ascendant",
			"name": "Ascendente Alata",
			"description": "Guerriera sacra che incanala energia luminosa. Le ali sono segno del suo potere celestiale.",
			"base_stats": {
				"max_hp": 90,
				"move_speed": 210.0,
				"attack_damage": 9,
				"attack_range": 50.0,
				"attack_cooldown": 0.8,
			},
			"weapon_types": ["sword", "spear", "holy_magic"],
			"armor_type": "medium",
			"playstyle": "holy_warrior",
		},
	}


func set_class(class_id: String) -> void:
	if not _class_definitions.has(class_id):
		push_error("ClassData: unknown class_id '%s'" % class_id)
		return

	player_class_id = class_id
	var info: Dictionary = _class_definitions[class_id]
	player_class_name = info.get("name", "Unknown")
	base_stats = info.get("base_stats", {}).duplicate()
	bonus_stats.clear()

	class_changed.emit(info)
	stats_updated.emit()


func get_class_info() -> Dictionary:
	return _class_definitions.get(player_class_id, {})


func get_all_classes() -> Array:
	var result: Array = []
	for key in _class_definitions:
		result.append(_class_definitions[key])
	return result


func get_stat(stat_name: String) -> float:
	var base: float = base_stats.get(stat_name, 0.0)
	var bonus: float = bonus_stats.get(stat_name, 0.0)
	return base + bonus


func apply_equipment_bonus(item) -> void:
	if item.stat_damage != 0:
		bonus_stats["attack_damage"] = bonus_stats.get("attack_damage", 0) + item.stat_damage
	if item.stat_health != 0:
		bonus_stats["max_hp"] = bonus_stats.get("max_hp", 0) + item.stat_health
	if item.stat_speed != 0:
		bonus_stats["move_speed"] = bonus_stats.get("move_speed", 0.0) + item.stat_speed
	if item.stat_armor != 0:
		bonus_stats["armor"] = bonus_stats.get("armor", 0) + item.stat_armor
	stats_updated.emit()
