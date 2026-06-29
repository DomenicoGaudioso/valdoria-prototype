extends RefCounted
## ItemEffects — Special effects system for equipment.
## Each effect_id modifies gameplay behavior when an item is equipped.

class_name ItemEffects

const EFFECTS := {
	"eclipse_heart": {
		"name": "Cuore dell'Eclisse",
		"display": "Ogni boss ucciso genera un'anomalia favorevole.",
	},
	"damage_return": {
		"name": "Riflesso del Vuoto",
		"display": "Restituisce il {val:.0%} dei danni subiti come danno da vuoto.",
	},
	"cooldown_redux": {
		"name": "Mente Lucida",
		"display": "Cooldown abilità ridotti del {val:.0%}.",
	},
	"dodge_window": {
		"name": "Riflessi Amplificati",
		"display": "Finestra di schivata perfetta aumentata del {val:.0%}.",
	},
	"summon_power": {
		"name": "Dominio dell'Ombra",
		"display": "Evocazioni infliggono il {val:.0%} di danno in più.",
	},
	"xp_boost": {
		"name": "Sete di Sapere",
		"display": "Esperienza guadagnata +{val:.0%}.",
	},
	"void_touch": {
		"name": "Tocco del Vuoto",
		"display": "{val:.0%} di probabilità che un attacco infligga danno da vuoto extra.",
	},
	"archon_vision": {
		"name": "Visione Arcontica",
		"display": "Rivela nemici invisibili e punti deboli dei boss.",
	},
	"cursed_blade": {
		"name": "Lama Maledetta",
		"display": "+{val:.0%} danno inflitto. -20% vita massima.",
	},
	"hungry_armor": {
		"name": "Fame d'Acciaio",
		"display": "Armatura +{val:.0%}. Cura ricevuta -30%.",
	},
	"blood_ring": {
		"name": "Patto di Sangue",
		"display": "+{val:.0%} danno inflitto e subito.",
	},
	"void_drinker": {
		"name": "Sorso del Vuoto",
		"display": "Rigenerazione mana +50%. -30% vita massima.",
	},
	"life_steal": {
		"name": "Sanguisugio",
		"display": "Cura per il {val:.0%} del danno inflitto.",
	},
	"fire_aura": {
		"name": "Aura di Fuoco",
		"display": "I nemici vicini subiscono {val:.0f} danni da fuoco al secondo.",
	},
	"freeze_strike": {
		"name": "Colpo Glaciale",
		"display": "{val:.0%} di probabilità di rallentare il nemico del 40% per 3s.",
	},
	"chain_lightning": {
		"name": "Catena di Fulmini",
		"display": "Gli attacchi rimbalzano su {val:.0f} nemici aggiuntivi.",
	},
	"poison_cloud": {
		"name": "Nube Tossica",
		"display": "I nemici uccisi rilasciano una nube di veleno per {val:.0f}s.",
	},
	"berserker": {
		"name": "Furia del Berserker",
		"display": "Sotto il 50% HP: +{val:.0%} danno e velocità d'attacco.",
	},
	"guardian_shield": {
		"name": "Scudo del Guardiano",
		"display": "Dopo aver subito danno, guadagni uno scudo del {val:.0%} dei HP max per 5s (CD 20s).",
	},
	"shadow_step": {
		"name": "Passo d'Ombra",
		"display": "Dopo un'uccisione, diventi invisibile per {val:.1f}s.",
	},
	"summon_heal": {
		"name": "Nutrimento d'Ombra",
		"display": "Le evocazioni rigenerano {val:.0%} HP ogni 5s.",
	},
}


static func get_display(effect_id: String, value: float) -> String:
	if effect_id.is_empty() or not EFFECTS.has(effect_id):
		return ""
	var template: String = EFFECTS[effect_id].get("display", "")
	if value > 0.0 or "{val" in template:
		return template.replace("{val:.0%}", "%d%%" % int(value * 100)) \
			.replace("{val:.1f}", "%.1f" % value) \
			.replace("{val:.0f}", "%.0f" % value)
	return template


static func get_name(effect_id: String) -> String:
	if not EFFECTS.has(effect_id):
		return ""
	return EFFECTS[effect_id].get("name", "")


static func apply_effect(player, item, activate: bool) -> void:
	"""Apply or remove a special effect from an equipped item."""
	if not player or item == null:
		return

	var eid: String = item.get("effect_id") if item is Resource else str(item.get("effect_id", ""))
	if eid.is_empty():
		return

	var val: float = float(item.get("effect_value") if item is Resource else item.get("effect_value", 0.0))

	if not player.has_method("_apply_effect_mod"):
		return

	player._apply_effect_mod(eid, val, activate)
