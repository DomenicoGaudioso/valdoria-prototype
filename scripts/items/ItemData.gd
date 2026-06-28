extends Resource

## ItemData — Data container for items.
## Each item is a Resource that can be stored, dropped, and displayed.

class_name ItemData

@export var id: String = ""
@export var name: String = "Unknown Item"
@export var type: String = "misc"
@export var description: String = ""
@export_multiline var flavor_text: String = ""
@export var icon: Texture2D
@export var rarity: String = "common"
@export var value: int = 0
@export var stackable: bool = false
@export var max_stack: int = 99
@export var quantity: int = 1

@export_group("Stats")
@export var stat_damage: int = 0
@export var stat_armor: int = 0
@export var stat_health: int = 0
@export var stat_speed: int = 0
@export var slot: String = ""  # "weapon","armor","helmet","boots","ring"


func get_rarity_color() -> Color:
	match rarity:
		"common":
			return Color(0.7, 0.7, 0.7)
		"uncommon":
			return Color(0.3, 0.8, 0.3)
		"rare":
			return Color(0.3, 0.4, 0.9)
		"epic":
			return Color(0.7, 0.2, 0.9)
		"legendary":
			return Color(0.9, 0.6, 0.1)
		_:
			return Color.WHITE


func get_description_full() -> String:
	var text := description
	if not flavor_text.is_empty():
		text += "\n\n" + flavor_text + ""
	if stat_damage != 0:
		text += "\nDanno: %+d" % stat_damage
	if stat_armor != 0:
		text += "\nArmatura: %+d" % stat_armor
	if stat_health != 0:
		text += "\nVita: %+d" % stat_health
	if stat_speed != 0:
		text += "\nVelocità: %+d" % stat_speed
	return text


func duplicate_item():
	var copy: Resource = self.duplicate(true)
	copy.set_script(load("res://scripts/items/ItemData.gd"))
	return copy


static func create_rusty_sword():
	var item = Resource.new()
	item.set_script(load("res://scripts/items/ItemData.gd"))
	item.id = "rusty_sword"
	item.name = "Spada arrugginita"
	item.type = "weapon"
	item.description = "Una vecchia lama consumata dal tempo. Qualcuno l'ha persa lungo il sentiero."
	item.flavor_text = "Il metallo è freddo e irregolare, ma può ancora ferire."
	item.rarity = "common"
	item.value = 3
	item.stat_damage = 2
	return item


static func create_health_potion():
	var item = Resource.new()
	item.set_script(load("res://scripts/items/ItemData.gd"))
	item.id = "health_potion"
	item.name = "Pozione di guarigione"
	item.type = "consumable"
	item.description = "Rigenera 25 punti vita."
	item.rarity = "common"
	item.value = 5
	item.stackable = true
	item.max_stack = 20
	item.stat_health = 25
	return item


static func create_bone_fragment():
	var item = Resource.new()
	item.set_script(load("res://scripts/items/ItemData.gd"))
	item.id = "bone_fragment"
	item.name = "Frammento d'osso"
	item.type = "fragment"
	item.description = "Un frammento di maestria antica. Potrebbe sbloccare nuove abilit\u00e0."
	item.flavor_text = "Un tempo parte di un guerriero caduto, ora conserva un'eco del suo potere."
	item.rarity = "uncommon"
	item.value = 10
	return item


# ===== EQUIPMENT FACTORY =====

const EQUIPMENT_TABLE: Dictionary = {
	"tier1_weapons": [
		{"id":"rusty_sword","name":"Spada Arrugginita","slot":"weapon","dmg":2,"hp":0,"spd":0,"value":5,"rarity":"common"},
		{"id":"wooden_mace","name":"Mazza di Legno","slot":"weapon","dmg":3,"hp":0,"spd":-5,"value":6,"rarity":"common"},
		{"id":"bone_dagger","name":"Pugnale d'Osso","slot":"weapon","dmg":1,"hp":0,"spd":15,"value":4,"rarity":"common"},
	],
	"tier2_weapons": [
		{"id":"iron_sword","name":"Spada di Ferro","slot":"weapon","dmg":5,"hp":0,"spd":0,"value":20,"rarity":"uncommon"},
		{"id":"hunter_bow","name":"Arco del Cacciatore","slot":"weapon","dmg":4,"hp":0,"spd":10,"value":18,"rarity":"uncommon"},
		{"id":"orc_axe","name":"Ascia da Guerra","slot":"weapon","dmg":7,"hp":0,"spd":-10,"value":25,"rarity":"uncommon"},
	],
	"tier3_weapons": [
		{"id":"steel_blade","name":"Lama d'Acciaio","slot":"weapon","dmg":9,"hp":0,"spd":5,"value":50,"rarity":"rare"},
		{"id":"lich_staff","name":"Bastone del Lich","slot":"weapon","dmg":12,"hp":0,"spd":0,"value":60,"rarity":"rare"},
		{"id":"dragon_fang","name":"Zanna di Drago","slot":"weapon","dmg":11,"hp":5,"spd":5,"value":55,"rarity":"rare"},
	],
	"tier4_weapons": [
		{"id":"runeblade","name":"Lama Runica","slot":"weapon","dmg":16,"hp":8,"spd":10,"value":120,"rarity":"epic"},
		{"id":"demon_slayer","name":"Ammazza Demoni","slot":"weapon","dmg":18,"hp":0,"spd":15,"value":140,"rarity":"epic"},
	],
	"tier5_weapons": [
		{"id":"excalibur","name":"Excalibur","slot":"weapon","dmg":25,"hp":15,"spd":10,"value":300,"rarity":"legendary"},
	],
	"tier1_armor": [
		{"id":"leather_vest","name":"Giaco di Cuoio","slot":"armor","dmg":0,"hp":15,"spd":0,"value":8,"rarity":"common"},
		{"id":"cloth_robe","name":"Tunica di Stoffa","slot":"armor","dmg":0,"hp":5,"spd":10,"value":6,"rarity":"common"},
	],
	"tier2_armor": [
		{"id":"chainmail","name":"Cotta di Maglia","slot":"armor","dmg":0,"hp":30,"spd":-5,"value":25,"rarity":"uncommon"},
		{"id":"bone_armor","name":"Armatura d'Ossa","slot":"armor","dmg":2,"hp":25,"spd":0,"value":28,"rarity":"uncommon"},
	],
	"tier3_armor": [
		{"id":"plate_armor","name":"Armatura a Piastre","slot":"armor","dmg":0,"hp":50,"spd":-10,"value":60,"rarity":"rare"},
		{"id":"dragon_scale","name":"Scaglie di Drago","slot":"armor","dmg":3,"hp":40,"spd":5,"value":70,"rarity":"rare"},
	],
	"tier4_armor": [
		{"id":"shadow_mail","name":"Corazza d'Ombra","slot":"armor","dmg":5,"hp":70,"spd":15,"value":150,"rarity":"epic"},
	],
	"tier5_armor": [
		{"id":"aegis","name":"Egida Divina","slot":"armor","dmg":8,"hp":100,"spd":5,"value":350,"rarity":"legendary"},
	],
	"tier1_helmet": [
		{"id":"leather_cap","name":"Berretto di Cuoio","slot":"helmet","dmg":0,"hp":8,"spd":0,"value":5,"rarity":"common"},
	],
	"tier2_helmet": [
		{"id":"iron_helm","name":"Elmo di Ferro","slot":"helmet","dmg":0,"hp":15,"spd":0,"value":15,"rarity":"uncommon"},
	],
	"tier3_helmet": [
		{"id":"crested_helm","name":"Elmo Piumato","slot":"helmet","dmg":1,"hp":25,"spd":5,"value":40,"rarity":"rare"},
	],
	"tier4_helmet": [
		{"id":"crown_shadow","name":"Corona d'Ombra","slot":"helmet","dmg":3,"hp":35,"spd":10,"value":100,"rarity":"epic"},
	],
	"tier1_boots": [
		{"id":"leather_boots","name":"Stivali di Cuoio","slot":"boots","dmg":0,"hp":5,"spd":15,"value":5,"rarity":"common"},
	],
	"tier2_boots": [
		{"id":"iron_boots","name":"Stivali di Ferro","slot":"boots","dmg":0,"hp":10,"spd":5,"value":15,"rarity":"uncommon"},
	],
	"tier3_boots": [
		{"id":"wind_walkers","name":"Camminavento","slot":"boots","dmg":0,"hp":5,"spd":35,"value":45,"rarity":"rare"},
	],
	"tier4_boots": [
		{"id":"shadow_steps","name":"Passi d'Ombra","slot":"boots","dmg":2,"hp":15,"spd":50,"value":110,"rarity":"epic"},
	],
	"tier2_ring": [
		{"id":"bone_ring","name":"Anello d'Osso","slot":"ring","dmg":1,"hp":10,"spd":0,"value":15,"rarity":"uncommon"},
	],
	"tier3_ring": [
		{"id":"ruby_ring","name":"Anello di Rubino","slot":"ring","dmg":3,"hp":20,"spd":0,"value":50,"rarity":"rare"},
	],
	"tier4_ring": [
		{"id":"dragon_ring","name":"Anello del Drago","slot":"ring","dmg":5,"hp":30,"spd":5,"value":120,"rarity":"epic"},
	],
	"tier5_ring": [
		{"id":"phoenix_ring","name":"Anello Fenice","slot":"ring","dmg":8,"hp":40,"spd":10,"value":280,"rarity":"legendary"},
	],
}


static func create_equipment_from_def(def: Dictionary):
	var item = Resource.new()
	item.set_script(load("res://scripts/items/ItemData.gd"))
	item.id = def.id
	item.name = def["name"]
	item.type = def.slot
	item.slot = def.slot
	item.rarity = def.get("rarity", "common")
	item.value = def.value
	item.stat_damage = def.dmg
	item.stat_health = def.hp
	item.stat_speed = def.spd
	item.description = "+%d DAN +%d HP +%d VEL" % [def.dmg, def.hp, def.spd]
	return item


static func generate_random_loot(tier: int) -> Array:
	var result := []
	# Gold always drops
	var gold_amount := tier * 5 + randi() % (tier * 10 + 1)
	result.append({"type":"gold","amount":gold_amount,"name":"%d Oro" % gold_amount})
	
	# Equipment drop chance
	var equip_chance: float = [0.0, 0.30, 0.45, 0.55, 0.65, 0.80][tier] as float
	if randf() < equip_chance:
		var categories: Array[String] = ["weapons","armor","helmet","boots","ring"]
		var cat: String = categories[randi() % categories.size()]
		var tier_key: String = "tier%d_%s" % [tier, cat]
		if EQUIPMENT_TABLE.has(tier_key):
			var pool: Array = EQUIPMENT_TABLE[tier_key]
			var def: Dictionary = pool[randi() % pool.size()]
			result.append({"type":"equip","def":def})
	
	return result
