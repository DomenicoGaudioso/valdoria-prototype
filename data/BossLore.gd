extends RefCounted
## BossLore - Eldrath: bestiario boss con meccaniche, dialoghi e loot.
## Mappa i boss del GDD ai tipi nemico esistenti in GameBootstrap._enemy_types.

class_name BossLore


## ── BOSS PRINCIPALI ──

const BOSSES := {
	"skeleton_odran": {
		"id": "skeleton_odran",
		"name": "Cavaliere Scheletrico di Odran",
		"title": "Guardiano del Cimitero",
		"type": "boss_iniziale",
		"category": "non_morti",
		"arena": "Cimitero delle Corone",
		"suggested_maps": ["black_oak_farm", "salted_field"],
		"base_enemy": "skeleton",
		"grade": "D",
		"tier": 1,
		"stats_mult": {"hp": 5.0, "dmg": 2.5, "spd": 0.85, "xp": 4.0},
		"phases": [
			{
				"name": "Marcia del Cavaliere",
				"hp_threshold": 1.0,
				"mechanics": [
					"Carica frontale lenta (telegrafata, 1.5s di avviso)",
					"Evocazione 2-3 scheletri ogni 20s",
					"Colpo ad area con spadone (360°, raggio ampio)",
				],
				"lines": [
					"Le corone... cadono.",
					"Odran chiama.",
				],
			},
			{
				"name": "Armatura Spezzata",
				"hp_threshold": 0.3,
				"mechanics": [
					"L'armatura si rompe: +50% velocità, -40% difesa",
					"Attacchi più rapidi ma meno potenti",
					"Carica impazzita (cambia direzione a metà)",
				],
				"lines": [
					"NON... CEDO...",
					"Ancora in sella!",
				],
			},
		],
		"loot_table": {
			"guaranteed": {"type": "weapon", "rarity": "rare", "tier_key": "tier3_weapons"},
			"special": {
				"name": "Spadone di Odran",
				"slot": "weapon",
				"rarity": "rare",
				"dmg": 9, "hp": 8, "spd": -8,
				"mat": "ferro antico",
				"tint": [0.68, 0.62, 0.55, 0.54],
			},
		},
		"defeat_text": "Il cavaliere si sbriciola in polvere d'ossa. Una corona arrugginita rotola ai tuoi piedi.",
		"for_kael": "Kael può reclamare il cavaliere come evocazione minore permanente dopo la prima sconfitta.",
	},

	"crystal_queen": {
		"id": "crystal_queen",
		"name": "Regina Ragno di Cristallo",
		"title": "Tessitrice di Vetro",
		"type": "boss_veleno",
		"category": "insettoidi",
		"arena": "Grotte di Vetro",
		"suggested_maps": ["grot_lagoon", "dilapidated_sewers"],
		"base_enemy": "myrm_queen",
		"grade": "C",
		"tier": 2,
		"stats_mult": {"hp": 4.0, "dmg": 1.8, "spd": 1.15, "xp": 3.5},
		"phases": [
			{
				"name": "Tela di Cristallo",
				"hp_threshold": 1.0,
				"mechanics": [
					"Ragnatele rallentanti sul terreno (AOE, durata 8s)",
					"Uova che generano larve velenose (3 uova, distruggibili)",
					"Veleno progressivo sul giocatore (stack fino a 5)",
				],
				"lines": [
					"Così fragile... come il vetro.",
					"Nella tela, piccolo.",
				],
			},
			{
				"name": "Arrampicata",
				"hp_threshold": 0.5,
				"mechanics": [
					"Si arrampica sulle pareti (irraggiungibile in mischia)",
					"Cristalli esplosivi cadono dal soffitto",
					"Vulnerabile solo a distanza e dopo caduta (ogni 12s scende per 3s)",
				],
				"lines": [
					"Guardami dall'alto!",
					"Il vetro taglia meglio dell'acciaio.",
				],
			},
		],
		"loot_table": {
			"guaranteed": {"type": "ring", "rarity": "rare", "tier_key": "tier3_ring"},
			"special": {
				"name": "Ambra di Cristallo",
				"slot": "ring",
				"rarity": "rare",
				"dmg": 2, "hp": 15, "spd": 10,
				"mat": "cristallo vivo",
				"tint": [0.35, 0.85, 0.75, 0.56],
			},
		},
		"defeat_text": "La regina emette un ultrasuono che frantuma i cristalli intorno. Cade in mille schegge.",
		"for_nyra": "Nyra assorbe la mutazione 'Occhi di Cristallo': +15% precisione, vede nemici attraverso muri.",
	},

	"forge_golem": {
		"id": "forge_golem",
		"name": "Golem della Forgia Morta",
		"title": "Battito di Pietra",
		"type": "boss_tank",
		"category": "costrutti",
		"arena": "Forgia dei Titani",
		"suggested_maps": ["fort_nasu", "fort_amir"],
		"base_enemy": "minotaur",
		"grade": "B",
		"tier": 3,
		"stats_mult": {"hp": 8.0, "dmg": 3.0, "spd": 0.5, "xp": 5.0},
		"phases": [
			{
				"name": "Pietra Viva",
				"hp_threshold": 1.0,
				"mechanics": [
					"Armatura estremamente alta (80% riduzione frontale)",
					"Punti deboli esposti solo dopo attacchi pesanti (2.5s finestra)",
					"Lava sul terreno (AOE crescente, zona sicura mobile)",
				],
				"lines": [
					"La forgia... non si spegne.",
					"Pietra su pietra.",
				],
			},
			{
				"name": "Nucleo Scoperto",
				"hp_threshold": 0.4,
				"mechanics": [
					"L'armatura si crepa: nucleo luminoso esposto",
					"Martellata sismica (3 onde d'urto concentriche)",
					"Auto-riparazione se non attaccato per 10s",
					"+100% danno subito al nucleo, ma +50% danno inflitto",
				],
				"lines": [
					"Il nucleo... BRUCIA!",
					"Non spegnerai la forgia!",
				],
			},
		],
		"loot_table": {
			"guaranteed": {"type": "armor", "rarity": "epic", "tier_key": "tier4_armor"},
			"special": {
				"name": "Cuore della Forgia",
				"slot": "armor",
				"rarity": "epic",
				"dmg": 0, "hp": 65, "spd": -12,
				"mat": "ferro runico antico",
				"tint": [0.55, 0.35, 0.12, 0.68],
			},
		},
		"defeat_text": "Il nucleo pulsa un'ultima volta e si spegne. Il golem si arena, statua per sempre.",
		"for_brann": "Brann assorbe la runa 'Cuore di Pietra': +10% armatura passiva, rigenerazione 2 HP/s fuori combattimento.",
	},

	"void_predator": {
		"id": "void_predator",
		"name": "Predatore del Vuoto",
		"title": "Cacciatore Silenzioso",
		"type": "boss_velocità",
		"category": "demoni",
		"arena": "Arena degli Echi",
		"suggested_maps": ["stormrock_ruins", "book_of_the_dead"],
		"base_enemy": "werewolf_a",
		"grade": "B",
		"tier": 3,
		"stats_mult": {"hp": 3.0, "dmg": 2.8, "spd": 1.8, "xp": 4.5},
		"phases": [
			{
				"name": "Caccia Invisibile",
				"hp_threshold": 1.0,
				"mechanics": [
					"Teletrasporti frequenti (ogni 4-6s, appare dietro il giocatore)",
					"Attacchi invisibili (premonizione: ombra sul terreno 0.4s prima)",
					"Copie illusorie (3 cloni, solo uno è reale)",
				],
				"lines": [
					"Ti vedo. Tu no.",
					"Sento il tuo battito.",
				],
			},
			{
				"name": "Fame del Vuoto",
				"hp_threshold": 0.35,
				"mechanics": [
					"Assorbe vita dai cloni rimasti",
					"Velocità raddoppiata, ma vulnerabile per 1.5s dopo ogni attacco",
					"Urlo del vuoto: silenzia le abilità per 3s (AOE cono)",
				],
				"lines": [
					"Il vuoto... ha fame!",
					"Non c'è fuga dall'eco.",
				],
			},
		],
		"loot_table": {
			"guaranteed": {"type": "boots", "rarity": "epic", "tier_key": "tier4_boots"},
			"special": {
				"name": "Passi del Vuoto",
				"slot": "boots",
				"rarity": "epic",
				"dmg": 3, "hp": 10, "spd": 55,
				"mat": "vuoto",
				"tint": [0.28, 0.22, 0.42, 0.64],
			},
		},
		"defeat_text": "Il predatore emette un gemito e si dissolve nell'aria. Resta solo un'eco di silenzio.",
		"for_seren": "Seren impara 'Passo del Vuoto': dopo una schivata perfetta, diventa invisibile per 1s.",
	},

	"library_keeper": {
		"id": "library_keeper",
		"name": "Custode della Biblioteca dei Portali",
		"title": "Archivista Dannato",
		"type": "boss_magico",
		"category": "non_morti",
		"arena": "Biblioteca dei Portali",
		"suggested_maps": ["book_of_the_dead"],
		"base_enemy": "lich",
		"grade": "A",
		"tier": 4,
		"stats_mult": {"hp": 4.5, "dmg": 3.2, "spd": 0.7, "xp": 5.5},
		"phases": [
			{
				"name": "Studio Infinito",
				"hp_threshold": 1.0,
				"mechanics": [
					"Incantesimi casuali da un pool di 6 (fuoco, ghiaccio, fulmine, ombra, luce, vuoto)",
					"Libri evocatori: 3 libri volanti che castano indipendentemente (distruggibili)",
					"Zone di silenzio: aree dove le abilità magiche non funzionano",
				],
				"lines": [
					"La conoscenza... è potere.",
					"Hai letto i libri sbagliati.",
				],
			},
			{
				"name": "Collasso Dimensionale",
				"hp_threshold": 0.3,
				"mechanics": [
					"Evoca 4 Portali minori che generano nemici casuali",
					"Collasso: ogni 10s un Portale esplode in AOE",
					"Libri volanti diventano proiettili homing",
					"Vulnerabile solo dopo aver chiuso tutti i Portali",
				],
				"lines": [
					"Tutti i mondi... in questa stanza!",
					"Leggi LA FINE!",
				],
			},
		],
		"loot_table": {
			"guaranteed": {"type": "helmet", "rarity": "epic", "tier_key": "tier4_helmet"},
			"special": {
				"name": "Corona dei Sepolcri",
				"slot": "helmet",
				"rarity": "epic",
				"dmg": 4, "hp": 30, "spd": 12,
				"mat": "ombra viva",
				"tint": [0.22, 0.12, 0.68, 0.62],
			},
		},
		"defeat_text": "La biblioteca collassa su sé stessa. I libri bruciano in silenzio. Solo la corona rimane.",
		"for_elios": "Elios assorbe 'Conoscenza Proibita': le magie proibite generano il 25% in meno di Corruzione.",
	},
}


## ── BOSS CLONE (PORTALE SPECCHIO) ──

const MIRROR_CLONES := {
	"arena_champion": {
		"name": "Ombra di Brann",
		"description": "Versione corrotta del Guardiano Runico. Usa rune nere invece che rosse.",
		"tint": Color(0.18, 0.18, 0.28, 1.0),
		"bar_color": Color(0.28, 0.12, 0.85, 1.0),
		"voice": Color(0.42, 0.38, 0.95),
		"lines": {
			"spawn": ["Tu cedi. Io resto.", "La fortezza è mia."],
			"attack": ["Rune nere.", "Cadi con me."],
			"hurt": ["Ancora... in piedi."],
			"death": ["La tua forza... è mia."],
		},
	},
	"shadow_blade": {
		"name": "Seren Invertita",
		"description": "Versione speculare che attacca dal futuro. Le sue mosse sono le tue, invertite.",
		"tint": Color(0.12, 0.12, 0.38, 1.0),
		"bar_color": Color(0.62, 0.18, 0.95),
		"voice": Color(0.55, 0.28, 0.95),
		"lines": {
			"spawn": ["Il secondo... è già passato."],
			"attack": ["Ti ho già uccisa."],
			"hurt": ["Questo... non era previsto."],
			"death": ["Il tempo... si chiude."],
		},
	},
	"wood_warden": {
		"name": "Nyra Ferale",
		"description": "Nyra che ha ceduto completamente alle mutazioni. Una chimera senza umanità.",
		"tint": Color(0.08, 0.32, 0.08, 1.0),
		"bar_color": Color(0.85, 0.22, 0.08),
		"voice": Color(0.72, 0.32, 0.12),
		"lines": {
			"spawn": ["La caccia... non finisce mai."],
			"attack": ["Artigli e zanne!"],
			"hurt": ["La mutazione... duole."],
			"death": ["Torno... alla giungla."],
		},
	},
	"battle_arcanist": {
		"name": "Elios Posseduto",
		"description": "Elios completamente consumato dalla Corruzione. Magia senza controllo.",
		"tint": Color(0.08, 0.08, 0.08),
		"bar_color": Color(0.95, 0.72, 0.08),
		"voice": Color(0.92, 0.78, 0.18),
		"lines": {
			"spawn": ["Il vuoto... vede tutto."],
			"attack": ["Nessun limite!", "Brucia con me!"],
			"hurt": ["La Corruzione... cresce."],
			"death": ["Orvex... hai vinto."],
		},
	},
	"crimson_heir": {
		"name": "Kael Corrotto",
		"description": "Kael che serve Vhar-Mor. Le sue evocazioni sono le anime che non ha salvato.",
		"tint": Color(0.15, 0.04, 0.15, 1.0),
		"bar_color": Color(0.35, 0.12, 0.55),
		"voice": Color(0.55, 0.12, 0.85),
		"lines": {
			"spawn": ["Alzatevi... per Vhar-Mor."],
			"attack": ["Tuo fratello... serve qui."],
			"hurt": ["L'ombra... si ribella."],
			"death": ["Perdonami... fratello."],
		},
	},
	"winged_ascendant": {
		"name": "Ascendente Caduta",
		"description": "Guerriera sacra che ha perso la luce. Le ali sono nere e tagliano come lame.",
		"tint": Color(0.18, 0.18, 0.22, 1.0),
		"bar_color": Color(0.15, 0.15, 0.22),
		"voice": Color(0.55, 0.55, 0.65),
		"lines": {
			"spawn": ["La luce... mi ha mentito."],
			"attack": ["Ali di tenebra."],
			"hurt": ["Ancora... luce dentro."],
			"death": ["Vedo... l'alba."],
		},
	},
}


## ── BOSS RICORRENTI / WORLD BOSS ──

const WORLD_BOSSES := {
	"ancient_dragon": {
		"id": "ancient_dragon",
		"name": "Drago Primordiale",
		"title": "Ala dell'Eclisse",
		"type": "world_boss",
		"spawn_condition": "Dopo 1000 nemici uccisi in una stagione, appare in una mappa casuale per 30 minuti.",
		"grade": "SS",
		"tier": 5,
		"loot_special": "Scaglia del Primordiale (materiale leggendario per evoluzione armi).",
	},
	"portal_lord": {
		"id": "portal_lord",
		"name": "Signore dei Portali",
		"title": "Guardiano della Soglia",
		"type": "world_boss",
		"spawn_condition": "Ogni 50 Portali completati, si manifesta nel Portale successivo come boss extra.",
		"grade": "SSS",
		"tier": 5,
		"loot_special": "Frammento di Soglia (consumabile: ripristina tutte le evocazioni perse in un Portale Abisso).",
	},
}


## ── UTILITÀ ──

static func get_boss(boss_id: String) -> Dictionary:
	return BOSSES.get(boss_id, {})

static func get_mirror_clone(class_id: String) -> Dictionary:
	return MIRROR_CLONES.get(class_id, {})

static func get_world_boss(boss_id: String) -> Dictionary:
	return WORLD_BOSSES.get(boss_id, {})

static func get_boss_by_map(map_id: String) -> Array:
	var result: Array = []
	for boss_id in BOSSES:
		var boss: Dictionary = BOSSES[boss_id]
		var maps: Array = boss.get("suggested_maps", [])
		if map_id in maps:
			result.append(boss)
	return result

static func get_bosses_by_category(category: String) -> Array:
	var result: Array = []
	for boss_id in BOSSES:
		var boss: Dictionary = BOSSES[boss_id]
		if boss.get("category", "") == category:
			result.append(boss)
	return result

static func generate_boss_from_enemy(enemy_type: String, grade_mult: float = 1.0) -> Dictionary:
	if not BOSSES.has(enemy_type):
		return {}

	var boss: Dictionary = BOSSES[enemy_type].duplicate(true)
	boss["current_phase"] = 0
	boss["hp_mult"] = grade_mult * float(boss.get("stats_mult", {}).get("hp", 5.0))
	boss["dmg_mult"] = grade_mult * float(boss.get("stats_mult", {}).get("dmg", 2.5))
	boss["spd_mult"] = float(boss.get("stats_mult", {}).get("spd", 1.0))
	boss["xp_mult"] = grade_mult * float(boss.get("stats_mult", {}).get("xp", 4.0))
	return boss
