extends Resource

## SkillData — Data container for character abilities.
## Used for future ability system with cooldowns, levels, and mastery fragments.

class_name SkillData

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var class_id: String = ""
@export var skill_slot: int = 0
@export var max_level: int = 5
@export var current_level: int = 0
@export var cooldown: float = 2.0
@export var mana_cost: int = 0
@export var damage_multiplier: float = 1.0
@export var range_multiplier: float = 1.0
@export var required_fragment_id: String = ""
@export var required_fragment_count: int = 1

var _cooldown_remaining: float = 0.0


func is_unlocked() -> bool:
	return current_level > 0


func is_ready() -> bool:
	return is_unlocked() and _cooldown_remaining <= 0.0


func can_upgrade(fragment_count: int) -> bool:
	return current_level < max_level and fragment_count >= required_fragment_count


func upgrade() -> void:
	current_level = min(current_level + 1, max_level)


func get_damage(base_damage: float) -> float:
	return base_damage * damage_multiplier * (1.0 + (current_level - 1) * 0.2)


func tick_cooldown(delta: float) -> void:
	if _cooldown_remaining > 0:
		_cooldown_remaining = max(0.0, _cooldown_remaining - delta)


func trigger() -> void:
	_cooldown_remaining = cooldown


func reset_cooldown() -> void:
	_cooldown_remaining = 0.0


static func create_arena_slam() -> SkillData:
	var skill := SkillData.new()
	skill.id = "arena_slam"
	skill.name = "Schianto dell'Arena"
	skill.description = "Colpisce il terreno con forza bruta, danneggiando tutti i nemici vicini."
	skill.class_id = "arena_champion"
	skill.skill_slot = 1
	skill.max_level = 5
	skill.cooldown = 4.0
	skill.mana_cost = 15
	skill.damage_multiplier = 2.0
	skill.required_fragment_id = "warrior_fragment"
	skill.required_fragment_count = 3
	return skill


static func create_whirlwind() -> SkillData:
	var skill := SkillData.new()
	skill.id = "whirlwind"
	skill.name = "Vortice di Lame"
	skill.description = "Ruota su sé stesso colpendo tutti i nemici intorno con le armi."
	skill.class_id = "shadow_blade"
	skill.skill_slot = 1
	skill.max_level = 5
	skill.cooldown = 3.0
	skill.mana_cost = 20
	skill.damage_multiplier = 1.5
	skill.required_fragment_id = "assassin_fragment"
	skill.required_fragment_count = 2
	return skill


static func create_multi_shot() -> SkillData:
	var skill := SkillData.new()
	skill.id = "multi_shot"
	skill.name = "Raffica Multipla"
	skill.description = "Scocca tre frecce contemporaneamente verso i nemici."
	skill.class_id = "wood_warden"
	skill.skill_slot = 1
	skill.max_level = 3
	skill.cooldown = 5.0
	skill.mana_cost = 12
	skill.damage_multiplier = 0.8
	skill.required_fragment_id = "ranger_fragment"
	skill.required_fragment_count = 2
	return skill
