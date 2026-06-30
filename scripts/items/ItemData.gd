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
@export var stat_agility: int = 0
@export var slot: String = ""  # "weapon","armor","helmet","boots","ring","amulet","belt","relic"
@export var set_id: String = ""
@export var rank: String = "E"
@export var upgrade_level: int = 0
@export var ascension_power: int = 0
@export var soulbound: bool = false

@export_group("Special Effects")
@export var effect_id: String = ""
@export var effect_value: float = 0.0
@export var corrupted: bool = false
@export var corruption_text: String = ""

@export_group("Visual")
@export var material_tag: String = ""
@export var visual_tint: Color = Color.WHITE


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
		"mythic":
			return Color(0.95, 0.15, 0.15)
		"archontic":
			return Color(0.95, 0.75, 0.1)
		"infinite":
			return Color(0.55, 0.9, 1.0)
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
	if stat_agility != 0:
		text += "\nAgilita: %+d" % stat_agility
	if rank != "E" or upgrade_level > 0 or ascension_power > 0:
		text += "\nRango: %s" % rank
	if upgrade_level > 0:
		text += "  +%d" % upgrade_level
	if ascension_power > 0:
		text += "\nPotere Ascensione: %d" % ascension_power
	if not set_id.is_empty():
		text += "\nSet: %s" % set_id.capitalize()
	if not effect_id.is_empty():
		text += "\n\n[%s]" % get_effect_display()
	if corrupted and not corruption_text.is_empty():
		text += "\n\n[Corrotto] %s" % corruption_text
	return text


func get_effect_display() -> String:
	return ItemEffects.get_display(effect_id, effect_value)


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
		{"id":"rusty_sword","name":"Ruggine","slot":"weapon","dmg":2,"hp":0,"spd":0,"value":5,"rarity":"common","mat":"ferro spento","tint":[0.54,0.52,0.48,0.38]},
		{"id":"wooden_mace","name":"Mazza Grezza","slot":"weapon","dmg":3,"hp":0,"spd":-5,"value":6,"rarity":"common","mat":"legno scuro","tint":[0.48,0.32,0.18,0.38]},
		{"id":"bone_dagger","name":"Osso Corto","slot":"weapon","dmg":1,"hp":0,"spd":15,"value":4,"rarity":"common","mat":"osso","tint":[0.74,0.70,0.58,0.38]},
	],
	"tier2_weapons": [
		{"id":"iron_sword","name":"Ferro Vivo","slot":"weapon","dmg":5,"hp":0,"spd":0,"value":20,"rarity":"uncommon","mat":"acciaio vivo","tint":[0.30,0.76,0.86,0.46]},
		{"id":"hunter_bow","name":"Arco Rovo","slot":"weapon","dmg":4,"hp":0,"spd":10,"value":18,"rarity":"uncommon","mat":"legno runico","tint":[0.26,0.68,0.42,0.42]},
		{"id":"orc_axe","name":"Ascia Rossa","slot":"weapon","dmg":7,"hp":0,"spd":-10,"value":25,"rarity":"uncommon","mat":"ferro crudo","tint":[0.80,0.18,0.12,0.48]},
	],
	"tier3_weapons": [
		{"id":"steel_blade","name":"Lama Ferma","slot":"weapon","dmg":9,"hp":0,"spd":5,"value":50,"rarity":"rare","mat":"acciaio lucido","tint":[0.42,0.70,1.0,0.50]},
		{"id":"lich_staff","name":"Asta Nera","slot":"weapon","dmg":12,"hp":0,"spd":0,"value":60,"rarity":"rare","mat":"legno d'ombra","tint":[0.46,0.22,0.88,0.54]},
		{"id":"dragon_fang","name":"Zanna","slot":"weapon","dmg":11,"hp":5,"spd":5,"value":55,"rarity":"rare","mat":"avorio caldo","tint":[0.95,0.62,0.28,0.48]},
		{"id":"void_sabre","name":"Vetro Nero","slot":"weapon","dmg":13,"hp":0,"spd":8,"value":75,"rarity":"rare","mat":"ossidiana","tint":[0.14,0.82,1.0,0.56]},
	],
	"tier4_weapons": [
		{"id":"runeblade","name":"Runalama","slot":"weapon","dmg":16,"hp":8,"spd":10,"value":120,"rarity":"epic","mat":"runa blu","tint":[0.18,0.92,1.0,0.62]},
		{"id":"demon_slayer","name":"Tagliademoni","slot":"weapon","dmg":18,"hp":0,"spd":15,"value":140,"rarity":"epic","mat":"ombra rossa","tint":[0.95,0.18,0.32,0.62]},
	],
	"tier5_weapons": [
		{"id":"excalibur","name":"Solferro","slot":"weapon","dmg":25,"hp":15,"spd":10,"value":300,"rarity":"legendary","mat":"sole nero","tint":[1.0,0.68,0.16,0.70]},
		{"id":"night_edge","name":"Filo Notte","slot":"weapon","dmg":29,"hp":10,"spd":18,"value":360,"rarity":"legendary","mat":"vuoto","tint":[0.35,0.95,1.0,0.72]},
	],
	"tier1_armor": [
		{"id":"leather_vest","name":"Giaco Ombra","slot":"armor","dmg":0,"hp":15,"spd":0,"value":8,"rarity":"common","mat":"cuoio opaco","tint":[0.16,0.13,0.16,0.48]},
		{"id":"cloth_robe","name":"Veste Fumo","slot":"armor","dmg":0,"hp":5,"spd":10,"value":6,"rarity":"common","mat":"tessuto","tint":[0.25,0.25,0.32,0.42]},
	],
	"tier2_armor": [
		{"id":"chainmail","name":"Maglia Ferro","slot":"armor","dmg":0,"hp":30,"spd":-5,"value":25,"rarity":"uncommon","mat":"anelli ferrati","tint":[0.38,0.50,0.58,0.50]},
		{"id":"bone_armor","name":"Ossa Nere","slot":"armor","dmg":2,"hp":25,"spd":0,"value":28,"rarity":"uncommon","mat":"osso inciso","tint":[0.54,0.48,0.38,0.50]},
		{"id":"chitin_vest","name":"Carapace","slot":"armor","dmg":1,"hp":34,"spd":6,"value":38,"rarity":"uncommon","mat":"chitina","tint":[0.30,0.82,0.64,0.54]},
	],
	"tier3_armor": [
		{"id":"plate_armor","name":"Piastre","slot":"armor","dmg":0,"hp":50,"spd":-10,"value":60,"rarity":"rare","mat":"acciaio pesante","tint":[0.42,0.48,0.62,0.56]},
		{"id":"dragon_scale","name":"Scaglie","slot":"armor","dmg":3,"hp":40,"spd":5,"value":70,"rarity":"rare","mat":"scaglia calda","tint":[0.86,0.30,0.12,0.58]},
		{"id":"night_mantle","name":"Manto Notte","slot":"armor","dmg":4,"hp":44,"spd":16,"value":85,"rarity":"rare","mat":"seta d'ombra","tint":[0.12,0.16,0.32,0.64]},
	],
	"tier4_armor": [
		{"id":"shadow_mail","name":"Corazza Ombra","slot":"armor","dmg":5,"hp":70,"spd":15,"value":150,"rarity":"epic","mat":"ombra viva","tint":[0.28,0.20,0.78,0.68]},
		{"id":"queen_chitin","name":"Chitina Regina","slot":"armor","dmg":7,"hp":76,"spd":12,"value":170,"rarity":"epic","mat":"chitina regale","tint":[0.55,0.12,0.78,0.70]},
	],
	"tier5_armor": [
		{"id":"aegis","name":"Egida Nera","slot":"armor","dmg":8,"hp":100,"spd":5,"value":350,"rarity":"legendary","mat":"stella spenta","tint":[0.92,0.72,0.24,0.72]},
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
		{"id":"crown_shadow","name":"Corona Nera","slot":"helmet","dmg":3,"hp":35,"spd":10,"value":100,"rarity":"epic","mat":"ombra viva","tint":[0.45,0.22,0.95,0.64]},
		{"id":"empty_crown","name":"Corona Vuota","slot":"helmet","dmg":5,"hp":28,"spd":18,"value":125,"rarity":"epic","mat":"vuoto","tint":[0.14,0.88,1.0,0.66]},
	],
	"tier1_boots": [
		{"id":"leather_boots","name":"Stivali di Cuoio","slot":"boots","dmg":0,"hp":5,"spd":15,"value":5,"rarity":"common"},
	],
	"tier2_boots": [
		{"id":"iron_boots","name":"Stivali di Ferro","slot":"boots","dmg":0,"hp":10,"spd":5,"value":15,"rarity":"uncommon"},
	],
	"tier3_boots": [
		{"id":"wind_walkers","name":"Vento","slot":"boots","dmg":0,"hp":5,"spd":35,"value":45,"rarity":"rare","mat":"cuoio leggero","tint":[0.34,0.78,1.0,0.50]},
		{"id":"phase_boots","name":"Fase","slot":"boots","dmg":1,"hp":4,"spd":42,"value":70,"rarity":"rare","mat":"ombra mobile","tint":[0.18,0.92,0.94,0.58]},
	],
	"tier4_boots": [
		{"id":"shadow_steps","name":"Passombra","slot":"boots","dmg":2,"hp":15,"spd":50,"value":110,"rarity":"epic","mat":"ombra viva","tint":[0.38,0.22,0.95,0.62]},
	],
	"tier2_ring": [
		{"id":"bone_ring","name":"Anello d'Osso","slot":"ring","dmg":1,"hp":10,"spd":0,"value":15,"rarity":"uncommon"},
	],
	"tier3_ring": [
		{"id":"ruby_ring","name":"Anello di Rubino","slot":"ring","dmg":3,"hp":20,"spd":0,"value":50,"rarity":"rare"},
	],
	"tier4_ring": [
		{"id":"dragon_ring","name":"Nodo Drago","slot":"ring","dmg":5,"hp":30,"spd":5,"value":120,"rarity":"epic","mat":"runa calda","tint":[0.95,0.28,0.12,0.62]},
		{"id":"void_seal","name":"Sigillo Buio","slot":"ring","dmg":6,"hp":24,"spd":12,"value":145,"rarity":"epic","mat":"vuoto","tint":[0.42,0.85,1.0,0.64]},
	],
	"tier5_ring": [
		{"id":"phoenix_ring","name":"Nodo Fenice","slot":"ring","dmg":8,"hp":40,"spd":10,"value":280,"rarity":"legendary","mat":"brace eterna","tint":[1.0,0.55,0.14,0.70]},
	],
	# === MITICI (Tier 6) ===
	"tier6_weapons": [
		{"id":"eclipse_blade","name":"Lama Eclisse","slot":"weapon","dmg":36,"hp":20,"spd":14,"value":600,"rarity":"mythic","mat":"eclisse nera","tint":[0.15,0.08,0.28,0.78],
			"effect":"eclipse_heart","efx_val":0.0,"flavor":"Ogni boss ucciso genera un'anomalia favorevole."},
	],
	"tier6_armor": [
		{"id":"void_plate","name":"Corazza Vuoto","slot":"armor","dmg":0,"hp":150,"spd":-5,"value":700,"rarity":"mythic","mat":"vuoto puro","tint":[0.06,0.04,0.16,0.80],
			"effect":"damage_return","efx_val":0.15,"flavor":"Restituisce il 15% dei danni subiti come danno da vuoto."},
	],
	"tier6_helmet": [
		{"id":"archon_crown","name":"Corona Arconte","slot":"helmet","dmg":6,"hp":50,"spd":14,"value":450,"rarity":"mythic","mat":"stella nera","tint":[0.88,0.78,0.15,0.72],
			"effect":"cooldown_redux","efx_val":0.25,"flavor":"Cooldown abilità ridotti del 25%."},
	],
	"tier6_boots": [
		{"id":"abyss_striders","name":"Passi Abisso","slot":"boots","dmg":4,"hp":20,"spd":70,"value":400,"rarity":"mythic","mat":"abisso","tint":[0.12,0.08,0.42,0.68],
			"effect":"dodge_window","efx_val":0.18,"flavor":"Finestra di schivata perfetta aumentata del 18%."},
	],
	"tier6_ring": [
		{"id":"vhar_mor_ring","name":"Anello Vhar-Mor","slot":"ring","dmg":10,"hp":55,"spd":8,"value":550,"rarity":"mythic","mat":"anima legata","tint":[0.55,0.15,0.75,0.74],
			"effect":"summon_power","efx_val":0.30,"flavor":"Evocazioni infliggono il 30% di danno in più."},
	],
	# === AMULETI (nuovo slot) ===
	"tier3_amulet": [
		{"id":"bone_amulet","name":"Amuleto d'Osso","slot":"amulet","dmg":1,"hp":15,"spd":0,"value":35,"rarity":"rare","mat":"osso runico","tint":[0.65,0.60,0.50,0.50]},
		{"id":"crystal_charm","name":"Ciondolo Cristallo","slot":"amulet","dmg":2,"hp":12,"spd":8,"value":42,"rarity":"rare","mat":"cristallo","tint":[0.35,0.80,0.88,0.56]},
	],
	"tier4_amulet": [
		{"id":"shadow_amulet","name":"Amuleto Ombra","slot":"amulet","dmg":3,"hp":28,"spd":6,"value":95,"rarity":"epic","mat":"ombra viva","tint":[0.32,0.18,0.72,0.62]},
	],
	"tier5_amulet": [
		{"id":"eclipse_heart_amulet","name":"Cuore Eclisse","slot":"amulet","dmg":6,"hp":45,"spd":10,"value":320,"rarity":"legendary","mat":"eclisse","tint":[0.22,0.85,1.0,0.68],
			"effect":"xp_boost","efx_val":0.35,"flavor":"Esperienza guadagnata +35%."},
	],
	# === CINTURE (nuovo slot) ===
	"tier2_belt": [
		{"id":"leather_belt","name":"Cintura Cuoio","slot":"belt","dmg":0,"hp":12,"spd":3,"value":18,"rarity":"uncommon","mat":"cuoio","tint":[0.45,0.38,0.28,0.44]},
	],
	"tier3_belt": [
		{"id":"iron_belt","name":"Cintura Ferrea","slot":"belt","dmg":1,"hp":20,"spd":0,"value":38,"rarity":"rare","mat":"ferro runico","tint":[0.42,0.48,0.62,0.50]},
	],
	"tier4_belt": [
		{"id":"rune_belt","name":"Cintura Runica","slot":"belt","dmg":2,"hp":35,"spd":5,"value":100,"rarity":"epic","mat":"runa blu","tint":[0.22,0.78,1.0,0.62]},
	],
	"tier5_belt": [
		{"id":"dragon_belt","name":"Cintura Drago","slot":"belt","dmg":4,"hp":55,"spd":8,"value":260,"rarity":"legendary","mat":"scaglia calda","tint":[0.92,0.25,0.12,0.68]},
	],
	# === RELIQUIE (nuovo slot) ===
	"tier4_relic": [
		{"id":"void_shard_relic","name":"Scheggia Vuoto","slot":"relic","dmg":4,"hp":18,"spd":12,"value":130,"rarity":"epic","mat":"vuoto","tint":[0.28,0.18,0.62,0.58],
			"effect":"void_touch","efx_val":0.10,"flavor":"10% di probabilità che un attacco infligga danno da vuoto extra."},
	],
	"tier5_relic": [
		{"id":"archon_eye_relic","name":"Occhio Arconte","slot":"relic","dmg":7,"hp":35,"spd":10,"value":340,"rarity":"legendary","mat":"arconte","tint":[0.95,0.68,0.18,0.68],
			"effect":"archon_vision","efx_val":0.0,"flavor":"Rivela nemici invisibili e punti deboli dei boss."},
	],
	# === EQUIPAGGIAMENTO CORROTTO ===
	"corrupted": [
		{"id":"cursed_blade","name":"Lama Maledetta","slot":"weapon","dmg":22,"hp":-20,"spd":5,"value":180,"rarity":"epic","mat":"ferro maledetto","tint":[0.72,0.08,0.12,0.68],
			"corrupt":true,"corr_text":"+40%% danno, -20%% vita massima.",
			"effect":"cursed_blade","efx_val":0.40},
		{"id":"hungry_mail","name":"Corazza Affamata","slot":"armor","dmg":3,"hp":60,"spd":-8,"value":160,"rarity":"epic","mat":"chitina oscura","tint":[0.18,0.12,0.15,0.62],
			"corrupt":true,"corr_text":"Cura ridotta del 30%%, armatura +25%%.",
			"effect":"hungry_armor","efx_val":0.25},
		{"id":"blood_ring","name":"Anello Sanguinario","slot":"ring","dmg":9,"hp":10,"spd":15,"value":150,"rarity":"epic","mat":"sangue","tint":[0.88,0.08,0.08,0.58],
			"corrupt":true,"corr_text":"+30%% danno inflitto, +30%% danno subito.",
			"effect":"blood_ring","efx_val":0.30},
		{"id":"void_drinker","name":"Sorso Vuoto","slot":"amulet","dmg":5,"hp":0,"spd":20,"value":140,"rarity":"epic","mat":"vuoto","tint":[0.22,0.12,0.48,0.60],
			"corrupt":true,"corr_text":"Mana rigenerato 50%% più veloce, ma -30%% HP max.",
			"effect":"void_drinker","efx_val":0.0},
	],
}

const LOOT_AFFIXES: Array[Dictionary] = [
	{"name": "Affilato", "prefix": true, "dmg": 4, "spd": 0, "hp": 0, "agi": 1, "value": 1.22, "effect": "", "efx_val": 0.0},
	{"name": "Rapido", "prefix": true, "dmg": 1, "spd": 18, "hp": 0, "agi": 3, "value": 1.18, "effect": "dodge_window", "efx_val": 0.08},
	{"name": "Vampirico", "prefix": true, "dmg": 2, "spd": 0, "hp": 8, "agi": 0, "value": 1.34, "effect": "life_steal", "efx_val": 0.05},
	{"name": "Runico", "prefix": true, "dmg": 2, "spd": 4, "hp": 12, "agi": 1, "value": 1.24, "effect": "cooldown_redux", "efx_val": 0.07},
	{"name": "del Varco", "prefix": false, "dmg": 3, "spd": 8, "hp": 0, "agi": 2, "value": 1.28, "effect": "void_touch", "efx_val": 0.10},
	{"name": "dell'Ascensione", "prefix": false, "dmg": 1, "spd": 0, "hp": 26, "agi": 0, "value": 1.36, "effect": "xp_boost", "efx_val": 0.10},
	{"name": "della Guardia", "prefix": false, "dmg": 0, "spd": -2, "hp": 34, "agi": 0, "value": 1.26, "effect": "guardian_shield", "efx_val": 0.12},
]


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
	item.stat_armor = int(def.get("def", _default_defense_from_def(def)))
	item.stat_health = def.hp
	item.stat_speed = def.spd
	item.stat_agility = int(def.get("agi", _default_agility_from_def(def)))
	item.set_id = def.get("set_id", "")
	item.rank = def.get("rank", _rank_from_tier(_tier_hint_from_rarity(item.rarity)))
	item.upgrade_level = int(def.get("upgrade_level", 0))
	item.ascension_power = int(def.get("ascension_power", 0))
	item.soulbound = bool(def.get("soulbound", false))
	item.material_tag = def.get("mat", _default_material_tag(item.slot, item.rarity))
	item.visual_tint = _visual_tint_from_def(def, item.slot, item.rarity)
	item.flavor_text = def.get("flavor", "")
	item.effect_id = def.get("effect", "")
	item.effect_value = float(def.get("efx_val", 0.0))
	item.corrupted = bool(def.get("corrupt", false))
	item.corruption_text = def.get("corr_text", "")
	item.description = "ATT %+d | DIF %+d | HP %+d | VEL %+d | AGI %+d" % [
		item.stat_damage,
		item.stat_armor,
		item.stat_health,
		item.stat_speed,
		item.stat_agility,
	]
	if not item.material_tag.is_empty():
		item.description += " | " + item.material_tag
	if item.upgrade_level > 0:
		item.description += " | +%d" % item.upgrade_level
	if item.rank != "E":
		item.description += " | Rango " + item.rank
	if item.corrupted:
		item.description += " | CORROTTO"
	return item


static func _default_defense_from_def(def: Dictionary) -> int:
	var slot_name: String = String(def.get("slot", ""))
	var hp_value: int = int(def.get("hp", 0))
	var rarity: String = String(def.get("rarity", "common"))
	var rarity_bonus := {"common": 0, "uncommon": 1, "rare": 2, "epic": 4, "legendary": 7, "mythic": 10, "archontic": 13, "infinite": 17}
	match slot_name:
		"armor":
			return int(round(float(hp_value) / 6.0)) + int(rarity_bonus.get(rarity, 0))
		"helmet":
			return int(round(float(hp_value) / 5.0)) + int(rarity_bonus.get(rarity, 0))
		"boots":
			return int(round(float(hp_value) / 10.0))
		"ring":
			return int(round(float(hp_value) / 12.0))
		"amulet":
			return int(round(float(hp_value) / 8.0))
		"belt":
			return int(round(float(hp_value) / 7.0))
		"relic":
			return int(round(float(hp_value) / 10.0))
		_:
			return 0


static func _default_agility_from_def(def: Dictionary) -> int:
	var slot_name: String = String(def.get("slot", ""))
	var speed_value: int = int(def.get("spd", 0))
	match slot_name:
		"boots":
			return int(round(float(speed_value) / 4.0))
		"ring":
			return int(round(float(speed_value) / 5.0))
		"weapon":
			return int(round(float(speed_value) / 8.0))
		"armor":
			return int(round(float(speed_value) / 10.0))
		"helmet":
			return int(round(float(speed_value) / 8.0))
		"amulet":
			return int(round(float(speed_value) / 5.0))
		"belt":
			return int(round(float(speed_value) / 6.0))
		"relic":
			return int(round(float(speed_value) / 7.0))
		_:
			return 0


static func _visual_tint_from_def(def: Dictionary, slot_name: String, rarity: String) -> Color:
	if def.has("tint"):
		var tint: Array = def["tint"]
		if tint.size() >= 3:
			var alpha := float(tint[3]) if tint.size() >= 4 else 0.62
			return Color(float(tint[0]), float(tint[1]), float(tint[2]), alpha)

	var slot_bias := {
		"weapon": Color(0.54, 0.84, 1.0, 0.48),
		"armor": Color(0.18, 0.17, 0.24, 0.58),
		"helmet": Color(0.26, 0.76, 1.0, 0.52),
		"boots": Color(0.16, 0.72, 0.95, 0.42),
		"ring": Color(0.92, 0.58, 1.0, 0.54),
		"amulet": Color(0.62, 0.88, 0.62, 0.50),
		"belt": Color(0.68, 0.55, 0.38, 0.50),
		"relic": Color(0.78, 0.68, 0.28, 0.56),
	}
	var rarity_bias := {
		"common": Color(0.58, 0.58, 0.62, 0.38),
		"uncommon": Color(0.28, 0.82, 0.42, 0.46),
		"rare": Color(0.28, 0.55, 1.0, 0.50),
		"epic": Color(0.72, 0.32, 1.0, 0.58),
		"legendary": Color(1.0, 0.66, 0.18, 0.64),
		"mythic": Color(1.0, 0.14, 0.14, 0.68),
		"archontic": Color(1.0, 0.78, 0.12, 0.72),
		"infinite": Color(0.35, 0.88, 1.0, 0.74),
	}
	var base: Color = slot_bias.get(slot_name, Color.WHITE)
	var rb: Color = rarity_bias.get(rarity, Color.WHITE)
	return Color((base.r + rb.r) * 0.5, (base.g + rb.g) * 0.5, (base.b + rb.b) * 0.5, max(base.a, rb.a))


static func _default_material_tag(slot_name: String, rarity: String) -> String:
	if rarity in ["epic", "legendary"]:
		return "ombra viva"
	match slot_name:
		"weapon":
			return "acciaio"
		"armor":
			return "cuoio/ferro"
		"helmet":
			return "metallo"
		"boots":
			return "tessuto rinforzato"
		"ring":
			return "runa"
		_:
			return ""


static func _tier_hint_from_rarity(rarity_name: String) -> int:
	match rarity_name:
		"common":
			return 1
		"uncommon":
			return 2
		"rare":
			return 3
		"epic":
			return 4
		"legendary":
			return 5
		"mythic":
			return 6
		"archontic":
			return 8
		"infinite":
			return 10
		_:
			return 1


static func _rank_from_tier(tier: int) -> String:
	if tier <= 1:
		return "E"
	if tier == 2:
		return "D"
	if tier == 3:
		return "C"
	if tier == 4:
		return "B"
	if tier == 5:
		return "A"
	if tier == 6:
		return "S"
	if tier <= 8:
		return "SS"
	if tier <= 11:
		return "SSS"
	if tier <= 15:
		return "National"
	return "Monarch"


static func _rarity_from_depth(depth: int) -> String:
	if depth <= 1:
		return "common"
	if depth == 2:
		return "uncommon"
	if depth == 3:
		return "rare"
	if depth == 4:
		return "epic"
	if depth == 5:
		return "legendary"
	if depth == 6:
		return "mythic"
	if depth <= 10:
		return "archontic"
	return "infinite"


static func _find_pool_key(depth: int, category: String) -> String:
	var capped := clampi(depth, 1, 6)
	for t in range(capped, 0, -1):
		var key := "tier%d_%s" % [t, category]
		if EQUIPMENT_TABLE.has(key):
			return key
	return ""


static func _scale_def_for_depth(base_def: Dictionary, depth: int) -> Dictionary:
	var def := base_def.duplicate(true)
	if depth <= 6:
		return def

	var extra := depth - 6
	var stat_mult := 1.0 + float(extra) * 0.22
	def["id"] = "endless_%s_%d" % [String(def.get("id", "item")), depth]
	def["name"] = "%s +%d" % [String(def.get("name", "Oggetto")), extra]
	def["rarity"] = _rarity_from_depth(depth)
	def["rank"] = _rank_from_tier(depth)
	def["upgrade_level"] = extra
	def["ascension_power"] = maxi(1, extra * 2)
	def["soulbound"] = depth >= 12
	def["value"] = int(float(def.get("value", 10)) * stat_mult * 1.35)
	def["dmg"] = int(round(float(def.get("dmg", 0)) * stat_mult)) + int(extra * 1.5)
	def["def"] = int(round(float(def.get("def", _default_defense_from_def(def))) * stat_mult)) + extra
	def["hp"] = int(round(float(def.get("hp", 0)) * stat_mult)) + extra * 12
	def["spd"] = int(round(float(def.get("spd", 0)) * (1.0 + float(extra) * 0.08)))
	def["agi"] = int(round(float(def.get("agi", _default_agility_from_def(def))) * stat_mult)) + int(extra / 2)

	if not def.has("effect") or String(def.get("effect", "")).is_empty():
		var effects := ["life_steal", "shadow_step", "chain_lightning", "guardian_shield", "summon_power"]
		def["effect"] = effects[extra % effects.size()]
		def["efx_val"] = clampf(0.08 + float(extra) * 0.015, 0.08, 0.45)

	if not def.has("set_id") or String(def.get("set_id", "")).is_empty():
		var slot_name := String(def.get("slot", ""))
		def["set_id"] = "ombra_monarca" if slot_name in ["weapon", "ring", "relic"] else "sigillo_arcontico"
	def["flavor"] = "Forgiato in un Portale Infinito. Cresce con chi sopravvive all'Ascensione."
	return def


static func _apply_random_affixes(base_def: Dictionary, depth: int) -> Dictionary:
	var def := base_def.duplicate(true)
	var rarity := String(def.get("rarity", "common"))
	var roll_count := 0
	if rarity in ["rare", "epic"]:
		roll_count = 1
	elif rarity in ["legendary", "mythic", "archontic", "infinite"]:
		roll_count = 2
	if depth >= 8:
		roll_count += 1
	roll_count = mini(roll_count, 3)
	if roll_count <= 0:
		return def

	var chosen: Array[Dictionary] = []
	for _i in range(roll_count):
		var affix: Dictionary = LOOT_AFFIXES[randi() % LOOT_AFFIXES.size()]
		chosen.append(affix)

	for affix in chosen:
		def["dmg"] = int(def.get("dmg", 0)) + int(affix.get("dmg", 0)) + int(depth / 3)
		def["hp"] = int(def.get("hp", 0)) + int(affix.get("hp", 0)) + int(depth * 2)
		def["spd"] = int(def.get("spd", 0)) + int(affix.get("spd", 0))
		def["agi"] = int(def.get("agi", _default_agility_from_def(def))) + int(affix.get("agi", 0))
		def["value"] = int(round(float(def.get("value", 10)) * float(affix.get("value", 1.0))))
		var effect_id := String(affix.get("effect", ""))
		if not effect_id.is_empty() and (not def.has("effect") or String(def.get("effect", "")).is_empty() or randf() < 0.45):
			def["effect"] = effect_id
			def["efx_val"] = float(affix.get("efx_val", 0.0)) + min(0.18, float(depth) * 0.006)
		if bool(affix.get("prefix", false)):
			def["name"] = "%s %s" % [String(affix.get("name", "")), String(def.get("name", "Oggetto"))]
		else:
			def["name"] = "%s %s" % [String(def.get("name", "Oggetto")), String(affix.get("name", ""))]

	var old_flavor := String(def.get("flavor", ""))
	var names: Array[String] = []
	for affix in chosen:
		names.append(String(affix.get("name", "")))
	def["flavor"] = ("%s\nAffissi: %s" % [old_flavor, ", ".join(names)]).strip_edges()
	return def


static func generate_random_loot(tier: int) -> Array:
	var result := []
	var depth := maxi(1, tier)
	var loot_tier := clampi(depth, 1, 6)
	var gold_amount := depth * 8 + int(pow(float(depth), 1.35)) + randi() % (depth * 14 + 1)
	result.append({"type":"gold","amount":gold_amount,"name":"%d Oro" % gold_amount})

	var equip_chance: float = min(0.92, 0.22 + float(depth) * 0.08)
	if randf() < equip_chance:
		var categories: Array[String] = ["weapons","armor","helmet","boots","ring","amulet","belt","relic"]
		var cat: String = categories[randi() % categories.size()]
		var tier_key: String = _find_pool_key(loot_tier, cat)
		if not tier_key.is_empty():
			var pool: Array = EQUIPMENT_TABLE[tier_key]
			var def: Dictionary = _scale_def_for_depth(pool[randi() % pool.size()], depth)
			def = _apply_random_affixes(def, depth)
			result.append({"type":"equip","def":def})

	# Corrupted item chance (tier 3+)
	if depth >= 3 and randf() < min(0.22, 0.08 + float(depth) * 0.01):
		var cpool: Array = EQUIPMENT_TABLE.get("corrupted", [])
		if not cpool.is_empty():
			var cdef: Dictionary = _scale_def_for_depth(cpool[randi() % cpool.size()], depth)
			result.append({"type":"equip","def":cdef})

	return result
