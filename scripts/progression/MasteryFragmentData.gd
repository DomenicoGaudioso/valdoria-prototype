extends Resource

## MasteryFragmentData — Data container for "Frammenti di Maestria".
## Sacred-like rune system: fragments drop from enemies and unlock/upgrade skills.

class_name MasteryFragmentData

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var class_id: String = ""
@export var skill_id: String = ""
@export var rarity: String = "uncommon"
@export var drop_chance_mult: float = 1.0

var _owned_count: int = 0


func add(count: int = 1) -> void:
	_owned_count += count


func remove(count: int) -> bool:
	if _owned_count >= count:
		_owned_count -= count
		return true
	return false


func get_count() -> int:
	return _owned_count


func has_enough(required: int) -> bool:
	return _owned_count >= required


static func create_warrior_fragment() -> MasteryFragmentData:
	var frag := MasteryFragmentData.new()
	frag.id = "warrior_fragment"
	frag.name = "Frammento del Guerriero"
	frag.description = "Contiene l'essenza di un antico guerriero dell'arena. Potenzia le abilità fisiche."
	frag.class_id = "arena_champion"
	frag.skill_id = "arena_slam"
	frag.rarity = "uncommon"
	return frag


static func create_assassin_fragment() -> MasteryFragmentData:
	var frag := MasteryFragmentData.new()
	frag.id = "assassin_fragment"
	frag.name = "Frammento dell'Ombra"
	frag.description = "Un'eco di un assassino dimenticato. Accelera i riflessi e affila le lame."
	frag.class_id = "shadow_blade"
	frag.skill_id = "whirlwind"
	frag.rarity = "uncommon"
	return frag


static func create_ranger_fragment() -> MasteryFragmentData:
	var frag := MasteryFragmentData.new()
	frag.id = "ranger_fragment"
	frag.name = "Frammento del Bosco"
	frag.description = "Un frammento permeato dall'energia della foresta. Affina la mira e la connessione con la natura."
	frag.class_id = "wood_warden"
	frag.skill_id = "multi_shot"
	frag.rarity = "uncommon"
	return frag


static func create_arcanist_fragment() -> MasteryFragmentData:
	var frag := MasteryFragmentData.new()
	frag.id = "arcanist_fragment"
	frag.name = "Frammento Arcano"
	frag.description = "Un cristallo che pulsa di magia elementale grezza."
	frag.class_id = "battle_arcanist"
	frag.rarity = "uncommon"
	return frag


static func create_crimson_fragment() -> MasteryFragmentData:
	var frag := MasteryFragmentData.new()
	frag.id = "crimson_fragment"
	frag.name = "Frammento Cremisi"
	frag.description = "Un frammento che vibra di energia vitale rubata."
	frag.class_id = "crimson_heir"
	frag.rarity = "rare"
	return frag


static func create_winged_fragment() -> MasteryFragmentData:
	var frag := MasteryFragmentData.new()
	frag.id = "winged_fragment"
	frag.name = "Frammento Alato"
	frag.description = "Un frammento che risplende di luce sacra. Leggero come una piuma celestiale."
	frag.class_id = "winged_ascendant"
	frag.rarity = "rare"
	return frag
