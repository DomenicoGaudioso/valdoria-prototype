extends RefCounted
## PortalTypes - Eldrath: tipi di Portale, gerarchia, modificatori.
## Mappa i concetti del GDD sulle 27 mappe esistenti in MapRegistry.

class_name PortalTypes


## ── GRADI DI PORTALE ──
## I gradi determinano difficoltà, loot tier e nemici.
## Mappati sui level band di StoryData.

enum Grade { F, E, D, C, B, A, S, SS, SSS, ABYSS, INFINITE }

const GRADE_INFO := {
	Grade.F:  {"label": "F",  "difficulty": "Principiante", "tier": 0, "min_level": 1,  "mod_slots": 0},
	Grade.E:  {"label": "E",  "difficulty": "Facile",       "tier": 1, "min_level": 3,  "mod_slots": 0},
	Grade.D:  {"label": "D",  "difficulty": "Normale",      "tier": 1, "min_level": 6,  "mod_slots": 1},
	Grade.C:  {"label": "C",  "difficulty": "Intermedio",   "tier": 2, "min_level": 11, "mod_slots": 1},
	Grade.B:  {"label": "B",  "difficulty": "Avanzato",     "tier": 2, "min_level": 20, "mod_slots": 2},
	Grade.A:  {"label": "A",  "difficulty": "Esperto",      "tier": 3, "min_level": 31, "mod_slots": 2},
	Grade.S:  {"label": "S",  "difficulty": "Maestro",      "tier": 3, "min_level": 45, "mod_slots": 3},
	Grade.SS: {"label": "SS", "difficulty": "Campione",     "tier": 4, "min_level": 61, "mod_slots": 3},
	Grade.SSS: {"label": "SSS", "difficulty": "Leggendario", "tier": 4, "min_level": 80, "mod_slots": 4},
	Grade.ABYSS: {"label": "Abisso", "difficulty": "Estremo", "tier": 5, "min_level": 101, "mod_slots": 5},
	Grade.INFINITE: {"label": "Infinito", "difficulty": "Senza limite", "tier": 5, "min_level": 101, "mod_slots": 5},
}


## ── TIPI DI PORTALE ──

enum Type { WHITE, RED, BLACK, MIRROR, SIEGE, ARCHONTIC, ABYSS }

const TYPE_INFO := {
	Type.WHITE: {
		"name": "Portale Bianco",
		"tag": "[BIANCO]",
		"color": Color(0.55, 0.92, 1.0, 1.0),
		"portal_tint": Color(0.18, 0.86, 1.0, 0.86),
		"ring_tint": Color(0.70, 0.24, 1.0, 0.72),
		"description": "Portale standard. Buono per farming. Boss singolo, loot bilanciato.",
		"mechanics": "Ingresso libero, uscita libera. Nessuna penalità alla morte.",
		"mood": "Esplorazione tranquilla. Il Portale attende paziente.",
		"best_for": "Farming materiali, livellamento base, test build.",
	},
	Type.RED: {
		"name": "Portale Rosso",
		"tag": "[ROSSO]",
		"color": Color(1.0, 0.25, 0.2, 1.0),
		"portal_tint": Color(1.0, 0.22, 0.12, 0.86),
		"ring_tint": Color(0.95, 0.38, 0.15, 0.72),
		"description": "Portale di sopravvivenza. Non si può uscire finché il boss non muore.",
		"mechanics": "Uscita bloccata fino alla morte del boss. Nemici aggressivi, "
			+ "ondate tra un'élite e l'altra. Ricompense migliorate del 50%.",
		"mood": "Sudore freddo. Il Portale si richiude alle tue spalle.",
		"best_for": "Loot potenziato, sfida, build test avanzato.",
	},
	Type.BLACK: {
		"name": "Portale Nero",
		"tag": "[NERO]",
		"color": Color(0.65, 0.2, 1.0, 1.0),
		"portal_tint": Color(0.45, 0.15, 1.0, 0.86),
		"ring_tint": Color(0.88, 0.28, 1.0, 0.72),
		"description": "Dungeon profondo a più piani con modificatori cumulativi.",
		"mechanics": "2-5 piani collegati. Ogni piano aggiunge un modificatore cumulativo. "
			+ "Miniboss intermedi. Boss finale potenziato. Loot epico+ garantito.",
		"mood": "Oscurità che si infittisce. Ogni piano è un patto col buio.",
		"best_for": "Loot epico/leggendario, sblocco classi avanzate.",
	},
	Type.MIRROR: {
		"name": "Portale Specchio",
		"tag": "[SPECCHIO]",
		"color": Color(0.85, 0.85, 0.95, 1.0),
		"portal_tint": Color(0.75, 0.75, 1.0, 0.86),
		"ring_tint": Color(0.55, 0.55, 0.9, 0.72),
		"description": "Il giocatore affronta copie alternative dei protagonisti.",
		"mechanics": "Nemici cloni con build simili al giocatore. "
			+ "Ogni clone usa una variante dello skill tree. "
			+ "Ottimo per sbloccare abilità avanzate e frammenti rari.",
		"mood": "Riflessi inquietanti. Stai combattendo te stesso attraverso infinite possibilità.",
		"best_for": "Frammenti maestria, sblocco skill avanzate.",
	},
	Type.SIEGE: {
		"name": "Portale d'Assedio",
		"tag": "[ASSEDIO]",
		"color": Color(1.0, 0.55, 0.1, 1.0),
		"portal_tint": Color(1.0, 0.55, 0.08, 0.86),
		"ring_tint": Color(0.95, 0.62, 0.15, 0.72),
		"description": "Il Portale si è aperto in una città. Bisogna difenderla.",
		"mechanics": "Difesa di obiettivi, civili da salvare, ondate di mostri. "
			+ "Boss comandante finale. Ricompense legate alla reputazione con le fazioni. "
			+ "Fallire = la mappa reale viene corrotta per un ciclo.",
		"mood": "Caos urbano. La gente urla, i mostri avanzano, tu sei l'ultima linea.",
		"best_for": "Reputazione fazioni, loot raro, eventi stagionali.",
	},
	Type.ARCHONTIC: {
		"name": "Portale Arcontico",
		"tag": "[ARCONTICO]",
		"color": Color(1.0, 0.72, 0.2, 1.0),
		"portal_tint": Color(1.0, 0.68, 0.16, 0.86),
		"ring_tint": Color(0.92, 0.72, 0.24, 0.72),
		"description": "Portale legato a un Arconte. Boss narrativo con loot Arcontico.",
		"mechanics": "Ambientazione unica, meccaniche speciali legate all'Arconte. "
			+ "Boss narrativo con cutscene. Loot Arcontico garantito. "
			+ "Possibile sblocco classe avanzata.",
		"mood": "Epico e opprimente. Stai sfidando un dio dimenticato.",
		"best_for": "Classe avanzata, loot Arcontico, progressione storia.",
	},
	Type.ABYSS: {
		"name": "Portale Abisso",
		"tag": "[ABISSO]",
		"color": Color(0.08, 0.02, 0.12, 1.0),
		"portal_tint": Color(0.05, 0.02, 0.12, 0.90),
		"ring_tint": Color(0.35, 0.08, 0.55, 0.78),
		"description": "Endgame avanzato. Difficoltà estrema, ricompense mitiche.",
		"mechanics": "Morte delle evocazioni permanenti temporaneamente. "
			+ "Modificatori solo negativi (3-5). Boss multipli. "
			+ "Loot Mitico e Infinito. Nessuna cura passiva.",
		"mood": "Terrore puro. L'Abisso ti guarda e ti giudica.",
		"best_for": "Loot Mitico/Infinito, endgame, classifiche.",
	},
}


## ── MODIFICATORI ──

const MODIFIERS := {
	"negative": {
		"darkness": {
			"name": "Oscurità Totale",
			"effect": "Visibilità ridotta al 60%. I nemici appaiono più vicini di quanto siano.",
			"icon_hint": "occhio barrato",
		},
		"mana_unstable": {
			"name": "Mana Instabile",
			"effect": "Le abilità magiche hanno il 25% di probabilità di costare il doppio.",
			"icon_hint": "cristallo incrinato",
		},
		"hungry_death": {
			"name": "Morte Affamata",
			"effect": "I nemici si curano del 15% quando uccidono evocazioni o compagni.",
			"icon_hint": "teschio con fauci",
		},
		"broken_time": {
			"name": "Tempo Spezzato",
			"effect": "Il layout del Portale cambia ogni 3 minuti. Nuovi muri, nuove strade.",
			"icon_hint": "clessidra rotta",
		},
		"corrupted_blood": {
			"name": "Sangue Corrotto",
			"effect": "Cure ridotte del 40%. Le pozioni curano la metà.",
			"icon_hint": "goccia nera",
		},
		"twin_boss": {
			"name": "Boss Gemelli",
			"effect": "Il boss finale appare in doppia forma. Entrambi devono morire.",
			"icon_hint": "due teschi",
		},
		"sealed_portal": {
			"name": "Portale Sigillato",
			"effect": "Uscita bloccata fino al completamento. Morte = perdita di tutto il loot del Portale.",
			"icon_hint": "lucchetto",
		},
	},
	"positive": {
		"eclipse_blessing": {
			"name": "Benedizione dell'Eclisse",
			"effect": "Esperienza guadagnata aumentata del 100%.",
			"icon_hint": "sole nero",
		},
		"unstable_treasure": {
			"name": "Tesoro Instabile",
			"effect": "Probabilità di loot raro raddoppiata. Ma il 10% degli oggetti è corrotto.",
			"icon_hint": "scrigno luminoso",
		},
		"hero_echo": {
			"name": "Eco degli Eroi",
			"effect": "Tutti i cooldown ridotti del 30%.",
			"icon_hint": "fantasma blu",
		},
		"essence_vein": {
			"name": "Vena d'Essenza",
			"effect": "Risorse speciali generate il 50% più velocemente.",
			"icon_hint": "vena viola",
		},
		"archontic_shards": {
			"name": "Frammenti Arcontici",
			"effect": "5% di probabilità di drop Arcontico da qualsiasi nemico.",
			"icon_hint": "scheggia dorata",
		},
	},
	"mixed": {
		"risen_enemies": {
			"name": "Nemici Risorti",
			"effect": "I nemici possono tornare in vita una volta (30% probabilità), "
				+ "ma rilasciano doppio loot ed esperienza.",
			"icon_hint": "freccia circolare",
		},
		"overcharge": {
			"name": "Sovraccarico",
			"effect": "+50% danno inflitto. +50% danno subito.",
			"icon_hint": "fulmine",
		},
		"portal_hunt": {
			"name": "Caccia del Portale",
			"effect": "Un miniboss insegue il giocatore in tutta la mappa. "
				+ "Se sconfitto, ricompensa tripla garantita.",
			"icon_hint": "impronta rossa",
		},
	},
}


## ── MAPPATURA PORTALI → MAPPE ESISTENTI ──

const PORTAL_MAP_ASSIGNMENTS := {
	Type.WHITE: {
		"grade_F": ["black_oak_farm"],
		"grade_E": ["black_oak_farm", "river_trail"],
		"grade_D": ["black_oak_city", "salted_field", "lochport"],
		"grade_C": ["nazia_highlands", "merrimead_swamp", "perdition_harbor"],
		"grade_B": ["southern_ridge", "stonewood", "oasis"],
		"grade_A": ["grot_lagoon", "lake_kuuma"],
	},
	Type.RED: {
		"grade_C": ["fort_nasu"],
		"grade_B": ["fort_amir", "dilapidated_sewers"],
		"grade_A": ["stormrock_ruins"],
		"grade_S": ["st_maria_1", "st_maria_2", "st_maria_3"],
		"grade_SS": ["book_of_the_dead"],
	},
	Type.BLACK: {
		"chains": [
			{
				"name": "Cripta di St. Maria",
				"maps": ["st_maria_1", "st_maria_2", "st_maria_3"],
				"cumulative_mods": ["darkness", "corrupted_blood", "twin_boss"],
				"min_grade": Grade.A,
			},
			{
				"name": "Abisso Runico",
				"maps": ["fort_nasu", "fort_amir", "stormrock_ruins", "book_of_the_dead"],
				"cumulative_mods": ["sealed_portal", "mana_unstable", "hungry_death", "broken_time"],
				"min_grade": Grade.S,
			},
		],
	},
	Type.MIRROR: {
		"maps": ["book_of_the_dead"],
		"clone_types": {
			"arena_champion": "Ombra di Brann",
			"shadow_blade": "Seren Invertita",
			"wood_warden": "Nyra Ferale",
			"battle_arcanist": "Elios Posseduto",
			"crimson_heir": "Kael Corrotto",
			"winged_ascendant": "Ascendente Caduta",
		},
	},
	Type.SIEGE: {
		"maps": ["roma_centro", "venezia_rialto", "parigi_cite", "berlin_mitte_3d", "tokyo_shibuya"],
	},
	Type.ARCHONTIC: {
		"vhar_mor": {"map": "book_of_the_dead", "min_grade": Grade.S},
		"selyth": {"map": "stormrock_ruins", "min_grade": Grade.S},
		"ghoran": {"map": "fort_nasu", "min_grade": Grade.S},
		"maelyra": {"map": "grot_lagoon", "min_grade": Grade.S},
		"orvex": {"map": "dilapidated_sewers", "min_grade": Grade.S},
	},
	Type.ABYSS: {
		"maps": ["book_of_the_dead", "stormrock_ruins"],
	},
}


## ── TAGLIE E OBIETTIVI ──

const BOUNTY_OBJECTIVES := {
	"kill_count": {
		"name": "Sterminio",
		"description": "Uccidi {count} nemici di tipo {family}.",
		"families": ["non_morti", "bestie", "costrutti", "demoni", "insettoidi"],
	},
	"boss_hunt": {
		"name": "Caccia al Boss",
		"description": "Sconfiggi {boss_name} in qualsiasi Portale.",
	},
	"portal_clear": {
		"name": "Pulizia Portale",
		"description": "Completa un Portale di tipo {type} grado {grade} o superiore.",
	},
	"speedrun": {
		"name": "Contro il Tempo",
		"description": "Completa un Portale in meno di {minutes} minuti.",
	},
	"no_damage": {
		"name": "Intoccabile",
		"description": "Completa un Portale senza subire danni.",
	},
	"loot_collector": {
		"name": "Collezionista",
		"description": "Raccogli {count} oggetti di rarità {rarity}+.",
	},
}


## ── UTILITÀ ──

static func get_grade_info(grade: int) -> Dictionary:
	return GRADE_INFO.get(grade, GRADE_INFO[Grade.F])

static func get_type_info(type: int) -> Dictionary:
	return TYPE_INFO.get(type, TYPE_INFO[Type.WHITE])

static func roll_modifiers(grade: int) -> Array:
	var info: Dictionary = get_grade_info(grade)
	var slots: int = info.get("mod_slots", 0)
	if slots <= 0:
		return []

	var result: Array = []
	var negative_pool: Array = MODIFIERS["negative"].keys()
	var positive_pool: Array = MODIFIERS["positive"].keys()
	var mixed_pool: Array = MODIFIERS["mixed"].keys()

	negative_pool.shuffle()
	positive_pool.shuffle()
	mixed_pool.shuffle()

	for i in range(slots):
		var roll := randf()
		var pool: Array
		if roll < 0.5:
			pool = negative_pool
		elif roll < 0.8:
			pool = positive_pool
		else:
			pool = mixed_pool
		if not pool.is_empty():
			result.append(pool.pop_front())

	return result

static func get_random_modifier_of_kind(kind: String) -> String:
	if not MODIFIERS.has(kind):
		return ""
	var keys: Array = MODIFIERS[kind].keys()
	if keys.is_empty():
		return ""
	return keys[randi() % keys.size()]
