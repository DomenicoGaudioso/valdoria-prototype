extends RefCounted
## SkillTree - Eldrath: skill progression per classe.
## 3 rami per classe, 6 skill per ramo, unlock via frammenti maestria.

class_name SkillTree

const CLASS_TREES := {
	"arena_champion": {
		"class_name": "Brann Kord — Guardiano Runico",
		"branches": {
			"scudo": {
				"name": "Scudo Vivente",
				"icon_hint": "shield",
				"skills": {
					"parata_runica": {"name":"Parata Runica","level":1,"desc":"Blocco potenziato: riduce il danno bloccato del 30%.","cost":2},
					"muro_frontale": {"name":"Muro Frontale","level":4,"desc":"Schieramento difensivo: +15% armatura per 5s dopo un blocco.","cost":3},
					"protezione_alleata": {"name":"Protezione Alleata","level":7,"desc":"Gli alleati vicini ricevono il 20% della tua armatura.","cost":4},
					"riflesso_minore": {"name":"Riflesso Minore","level":10,"desc":"10% di probabilità di riflettere un attacco.","cost":5},
					"bastione_mobile": {"name":"Bastione Mobile","level":20,"desc":"Puoi muoverti mentre blocchi (velocità -40%).","cost":8},
					"scudo_titano": {"name":"Scudo del Titano","level":40,"desc":"Blocco perfetto: annulla completamente il danno e stordisce il nemico per 1.5s.","cost":12},
				},
			},
			"forgia": {
				"name": "Forgia da Battaglia",
				"icon_hint": "hammer",
				"skills": {
					"ripara_armatura": {"name":"Riparazione Armatura","level":3,"desc":"Recuperi 2% HP max ogni 10s fuori combattimento.","cost":2},
					"colpo_fabbro": {"name":"Colpo del Fabbro","level":6,"desc":"Attacco caricato: +50% danno, ignora 30% armatura nemica.","cost":4},
					"runa_incandescente": {"name":"Runa Incandescente","level":10,"desc":"Le rune infliggono 5 danni da fuoco/s ai nemici vicini.","cost":5},
					"martello_sismico": {"name":"Martello Sismico","level":18,"desc":"Attacco ad area: 3 onde d'urto concentriche.","cost":7},
					"armatura_rigenerante": {"name":"Armatura Auto-Rigenerante","level":30,"desc":"+5 armatura ogni 5 uccisioni (max 50).","cost":10},
					"forgia_colosso": {"name":"Forgia del Colosso","level":50,"desc":"Dopo 10 uccisioni consecutive, diventi inarrestabile per 8s.","cost":15},
				},
			},
			"controllo": {
				"name": "Provocazione e Controllo",
				"icon_hint": "chains",
				"skills": {
					"ruggito_guardiano": {"name":"Ruggito del Guardiano","level":1,"desc":"Provoca tutti i nemici nel raggio di 200px per 4s.","cost":1},
					"marchio_colosso": {"name":"Marchio del Colosso","level":5,"desc":"Marchia un nemico: subisce +25% danni da tutte le fonti.","cost":3},
					"catene_runiche": {"name":"Catene Runiche","level":12,"desc":"Immobilizza i nemici in un'area per 3s.","cost":5},
					"onda_impatto": {"name":"Onda d'Impatto","level":22,"desc":"Respingi tutti i nemici intorno e rallentali del 50% per 2s.","cost":8},
					"dominio_campo": {"name":"Dominio del Campo","level":35,"desc":"Area di controllo: i nemici nella zona sono più lenti del 20%.","cost":12},
					"giuramento_infrangibile": {"name":"Giuramento Infrangibile","level":55,"desc":"Per 8s, non puoi morire. I danni subiti diventano cura per gli alleati.","cost":18},
				},
			},
		},
	},
	"shadow_blade": {
		"class_name": "Seren Veyra — Lama Astrale",
		"branches": {
			"doppia_lama": {
				"name": "Doppia Lama",
				"icon_hint": "daggers",
				"skills": {
					"fendente_rapido": {"name":"Fendente Rapido","level":1,"desc":"Due colpi rapidi in successione (+40% velocità attacco).","cost":2},
					"taglio_gemello": {"name":"Taglio Gemello","level":4,"desc":"Colpisci due nemici vicini con un solo attacco.","cost":3},
					"ferita_profonda": {"name":"Ferita Profonda","level":8,"desc":"I colpi critici applicano sanguinamento (3s, 15% danno).","cost":4},
					"combo_crescente": {"name":"Combo Crescente","level":15,"desc":"Ogni colpo in combo aumenta la velocità d'attacco del 5% (max 25%).","cost":6},
					"danza_lame": {"name":"Danza delle Lame","level":28,"desc":"Tempesta di colpi: 5 attacchi in 0.8s, danno ridotto del 30%.","cost":10},
					"tempesta_acciaio": {"name":"Tempesta di Acciaio","level":45,"desc":"Danza delle Lame potenziata: 8 colpi, danno pieno. CD 12s.","cost":15},
				},
			},
			"passo_void": {
				"name": "Passo del Vuoto",
				"icon_hint": "void",
				"skills": {
					"scatto_astrale": {"name":"Scatto Astrale","level":2,"desc":"Teletrasporto di 80px nella direzione di movimento.","cost":2},
					"passo_dietro": {"name":"Passo dietro il Bersaglio","level":6,"desc":"Appari dietro il nemico più vicino e colpisci (+30% critico).","cost":4},
					"schivata_perfetta": {"name":"Schivata Perfetta","level":10,"desc":"Finestra di schivata aumentata del 25%.","cost":5},
					"doppia_ombra": {"name":"Doppia Ombra","level":20,"desc":"Lascia un'ombra che attacca per 3s dopo il teletrasporto.","cost":8},
					"assalto_invisibile": {"name":"Assalto Invisibile","level":32,"desc":"Dopo una schivata perfetta, diventi invisibile per 2s.","cost":10},
					"secondo_spezzato": {"name":"Secondo Spezzato","level":50,"desc":"Rallenta il tempo del 70% per 0.8s dopo una schivata perfetta.","cost":16},
				},
			},
			"esecuzione": {
				"name": "Esecuzione",
				"icon_hint": "skull",
				"skills": {
					"colpo_spalle": {"name":"Colpo alle Spalle","level":3,"desc":"+40% danno quando attacchi da dietro.","cost":2},
					"punto_debole": {"name":"Punto Debole","level":7,"desc":"I nemici sotto il 40% HP subiscono +35% danni critici.","cost":4},
					"sanguinamento_critico": {"name":"Sanguinamento Critico","level":14,"desc":"I critici raddoppiano la durata del sanguinamento.","cost":6},
					"predazione": {"name":"Predazione","level":25,"desc":"Uccidere un nemico resetta il cooldown di Scatto Astrale.","cost":8},
					"esecuzione_astrale": {"name":"Esecuzione Astrale","level":38,"desc":"Nemici sotto il 15% HP: esecuzione istantanea garantita. CD 30s.","cost":12},
					"morte_prima_movimento": {"name":"Morte Prima del Movimento","level":55,"desc":"Il primo colpo dopo un teletrasporto è sempre critico e ignora l'armatura.","cost":18},
				},
			},
		},
	},
	"wood_warden": {
		"class_name": "Nyra Solen — Cacciatrice Chimera",
		"branches": {
			"arco": { "name":"Arco Predatore","icon_hint":"bow","skills":{} },
			"bestie": { "name":"Bestie Compagne","icon_hint":"wolf","skills":{} },
			"mutazione": { "name":"Mutazione Chimera","icon_hint":"dna","skills":{} },
		},
	},
	"battle_arcanist": {
		"class_name": "Elios Var — Arconte Spezzato",
		"branches": {
			"arcana": { "name":"Magia Arcana","icon_hint":"star","skills":{} },
			"controllo_dim": { "name":"Controllo Dimensionale","icon_hint":"portal","skills":{} },
			"proibito": { "name":"Potere Proibito","icon_hint":"eye","skills":{} },
		},
	},
	"crimson_heir": {
		"class_name": "Kael Morvant — Necromante dell'Eclisse",
		"branches": {
			"legione": { "name":"Legione dei Caduti","icon_hint":"army","skills":{} },
			"dominio": { "name":"Dominio dei Boss","icon_hint":"crown","skills":{} },
			"magia_necrotica": { "name":"Magia Necrotica","icon_hint":"dark_magic","skills":{} },
		},
	},
}


static func get_tree_for_class(class_id: String) -> Dictionary:
	return CLASS_TREES.get(class_id, {})

static func get_available_skills(class_id: String, player_level: int) -> Array[Dictionary]:
	var tree: Dictionary = get_tree_for_class(class_id)
	if tree.is_empty():
		return []
	var result: Array[Dictionary] = []
	for branch_id in tree.get("branches", {}):
		var branch: Dictionary = tree["branches"][branch_id]
		for skill_id in branch.get("skills", {}):
			var skill: Dictionary = branch["skills"][skill_id]
			if player_level >= int(skill.get("level", 999)):
				var sd := skill.duplicate()
				sd["branch_id"] = branch_id
				sd["branch_name"] = branch.get("name", "???")
				sd["skill_id"] = skill_id
				result.append(sd)
	return result

static func get_next_unlock_hint(class_id: String, player_level: int) -> String:
	var skills: Array = get_available_skills(class_id, player_level + 1)
	var all_skills: Array = get_available_skills(class_id, 999)
	var unlocked := get_available_skills(class_id, player_level).size()
	var total := all_skills.size()

	if unlocked >= total:
		return "Tutte le skill sbloccate!"

	for s in all_skills:
		var lv: int = int(s.get("level", 999))
		if lv >= player_level:
			return "Prossima: %s (liv. %d) — Ramo %s" % [s["name"], lv, s["branch_name"]]
	return ""
