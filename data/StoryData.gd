extends Node
## StoryData - Eldrath: lore database autoload.
## Contiene world-building, protagonisti, arconti, hub, stagioni.
## Solo dati: non modifica la logica di gioco esistente.

const VERSION := "1.1.0-arconti"

## ── WORLD LORE ──
const WORLD := {
	"name": "Eldrath",
	"era": "Era dell'Eclisse",
	"premise": "I Portali si sono aperti dopo il Grande Sigillo infranto. "
		+ "Cinque campioni, toccati dall'Eclisse, sono l'ultima speranza "
		+ "contro gli Arconti che vogliono fondere i mondi.",
	"cosmology": {
		"eclipse": "L'Eclisse è una frattura dimensionale che collega infiniti mondi. "
			+ "Ogni Portale è un varco instabile generato dall'Eclisse.",
		"archons": "Gli Arconti sono entità primordiali intrappolate tra i mondi. "
			+ "Ognuno controlla un aspetto della realtà: Morte, Velocità, Pietra, Bestie, Vuoto.",
		"portal_system": "L'Ascensione è il meccanismo cosmico che permette ai mortali di "
			+ "assorbire potere dai Portali. Più Portali si chiudono, più si diventa forti — "
			+ "ma l'Eclisse genera Portali sempre più pericolosi."
	},
	"bastione": "Bastione di Velar — l'ultima città fortificata. Qui i Cacciatori di Portali "
		+ "si radunano per scegliere le loro missioni. Costruita sulle rovine di Velar, "
		+ "l'antica capitale distrutta dal primo Portale."
}


## ── PROTAGONISTI ──
## Classe mappata al campo "class_ref": una delle classi esistenti nel gioco.
## "class_ref" è opzionale; se vuoto, il protagonista è solo lore.

const HEROES: Array[Dictionary] = [
	{
		"id": "kael_morvant",
		"name": "Kael Morvant",
		"title": "Necromante dell'Eclisse",
		"class_ref": "crimson_heir",
		"role": "evocatore_controllo",
		"resource": "Essenza d'Ombra",
		"palette": ["nero", "viola", "verde necrotico", "grigio osso"],
		"lore": "Kael era un archivista del Bastione prima che l'Eclisse lo toccasse. "
			+ "Ora sente le voci dei morti e può comandare le ombre di chi ha ceduto ai Portali. "
			+ "Il suo obiettivo è reclamare abbastanza anime da sfidare Vhar-Mor, "
			+ "l'Arconte della Morte che gli ha rubato il fratello.",
		"archon_rival": "vhar_mor",
		"archon_arena": "Necropoli Infinita",
		"advanced_class": "Imperatore dell'Ombra Eterna",
		"advanced_bonus": "Evocazioni permanenti, generali personalizzabili, Regno d'Ombra.",
		"skill_branches": {
			"legione": {
				"name": "Legione dei Caduti",
				"focus": "Quantità di evocazioni: Scheletro Vincolato, Servitori Multipli, Arcieri d'Ombra, "
					+ "Muro dei Morti, Orda Silente, Signore della Legione.",
			},
			"dominio": {
				"name": "Dominio dei Boss",
				"focus": "Resurrezione nemici potenti: Reclama Ombra, Marchio del Generale, "
					+ "Anima Incatenata, Obbedienza Forzata, Custode dell'Abisso, Trono Nero.",
			},
			"magia": {
				"name": "Magia Necrotica",
				"focus": "Danno diretto e maledizioni: Dardo d'Ombra, Maledizione della Carne Fredda, "
					+ "Esplosione Cadaverica, Catena delle Anime, Peste del Portale, Eclisse Mortale.",
			}
		},
		"build_advice": {
			"orda": "Tante evocazioni — danno costante, controllo mappa.",
			"generale": "Poche evocazioni fortissime — boss reclamati, danno élite.",
			"maledizione": "Danni nel tempo — esplosioni cadaveriche, controllo."
		},
		"signature_lines": [
			"Alzatevi, soldati dell'ombra.",
			"Ogni nemico caduto è un'arma in più.",
			"La morte non è la fine. È l'inizio.",
			"Vhar-Mor, restituiscimi mio fratello."
		],
	},
	{
		"id": "seren_veyra",
		"name": "Seren Veyra",
		"title": "Lama Astrale",
		"class_ref": "shadow_blade",
		"role": "assassina_mobilità",
		"resource": "Impulso Astrale",
		"palette": ["blu notte", "argento", "viola astrale"],
		"lore": "Seren era una ladra di reliquie nelle strade di Velar prima dell'Eclisse. "
			+ "Il Portale l'ha toccata e ora può piegare lo spazio per frazioni di secondo — "
			+ "abbastanza per apparire dietro un nemico e colpire prima che cada. "
			+ "Cerca Selyth, l'Arconte che si muove nel tempo rubato.",
		"archon_rival": "selyth",
		"archon_arena": "Il Secondo Spezzato",
		"advanced_class": "Regina del Secondo Spezzato",
		"advanced_bonus": "Rallentamento del tempo dopo schivata perfetta, "
			+ "esecuzioni concatenate, critici potenziati contro boss feriti.",
		"skill_branches": {
			"doppia_lama": {
				"name": "Doppia Lama",
				"focus": "Fendente Rapido, Taglio Gemello, Ferita Profonda, "
					+ "Combo Crescente, Danza delle Lame, Tempesta di Acciaio.",
			},
			"passo_void": {
				"name": "Passo del Vuoto",
				"focus": "Scatto Astrale, Passo dietro il Bersaglio, Schivata Perfetta, "
					+ "Doppia Ombra, Assalto Invisibile, Secondo Spezzato.",
			},
			"esecuzione": {
				"name": "Esecuzione",
				"focus": "Colpo alle Spalle, Punto Debole, Sanguinamento Critico, "
					+ "Predazione, Esecuzione Astrale, Morte Prima del Movimento.",
			}
		},
		"build_advice": {
			"critico": "Danni enormi su bersaglio singolo.",
			"ombre": "Cloni, mobilità, attacchi multipli.",
			"esecuzione": "Uccisioni rapide — reset abilità, catene di eliminazioni."
		},
		"signature_lines": [
			"Troppo lenta, la morte.",
			"Eri già caduto prima di vedermi.",
			"Il secondo è mio.",
		],
	},
	{
		"id": "brann_kord",
		"name": "Brann Kord",
		"title": "Guardiano Runico",
		"class_ref": "arena_champion",
		"role": "tank_protezione",
		"resource": "Cariche Runiche",
		"palette": ["bronzo", "ferro", "rosso runico", "oro spento"],
		"lore": "Brann era il fabbro del Bastione. Quando i Portali hanno distrutto la sua fucina, "
			+ "ha inciso rune sulla propria armatura con il metallo fuso dei varchi. "
			+ "Ora è un muro vivente che assorbe i colpi e li restituisce. "
			+ "Il suo nemico è Ghoran, l'Arconte della Pietra Viva, "
			+ "che trasforma le fortezze in trappole.",
		"archon_rival": "ghoran",
		"archon_arena": "Fortezza Senziente",
		"advanced_class": "Titano del Sigillo Finale",
		"advanced_bonus": "Riduzione danni estrema, assorbimento danni per alleati, "
			+ "barriera globale temporanea.",
		"skill_branches": {
			"scudo": {
				"name": "Scudo Vivente",
				"focus": "Parata Runica, Muro Frontale, Protezione Alleata, "
					+ "Riflesso Minore, Bastione Mobile, Scudo del Titano.",
			},
			"forgia": {
				"name": "Forgia da Battaglia",
				"focus": "Riparazione Armatura, Colpo del Fabbro, Runa Incandescente, "
					+ "Martello Sismico, Armatura Auto-Rigenerante, Forgia del Colosso.",
			},
			"controllo": {
				"name": "Provocazione e Controllo",
				"focus": "Ruggito del Guardiano, Marchio del Colosso, Catene Runiche, "
					+ "Onda d'Impatto, Dominio del Campo, Giuramento Infrangibile.",
			}
		},
		"build_advice": {
			"tank_puro": "Difesa, protezione alleati, assorbimento danni.",
			"contrattacco": "Parate, riflesso danni, colpi caricati.",
			"controllo": "Provocazione, stordimenti, catene runiche."
		},
		"signature_lines": [
			"Non un passo indietro.",
			"Queste rune non cedono.",
			"Colpite me, non loro.",
		],
	},
	{
		"id": "nyra_solen",
		"name": "Nyra Solen",
		"title": "Cacciatrice Chimera",
		"class_ref": "wood_warden",
		"role": "ranger_ibrida",
		"resource": "DNA Chimera",
		"palette": ["verde foresta", "ambra", "rosso bestiale", "scaglie iridescenti"],
		"lore": "Nyra è cresciuta nelle Giungle di Tharos, dove i Portali hanno fuso creature "
			+ "di mondi diversi in chimere. Invece di fuggire, ha imparato a cacciarle "
			+ "e ad assorbirne i tratti. Ogni bestia che uccide le offre una nuova mutazione. "
			+ "Ma Maelyra, l'Arconte delle Bestie Fuse, la considera la sua preda preferita.",
		"archon_rival": "maelyra",
		"archon_arena": "Giungla delle Mille Forme",
		"advanced_class": "Madre delle Forme Primordiali",
		"advanced_bonus": "Combinazione di più mutazioni, compagno bestiale permanente, "
			+ "trasformazioni leggendarie.",
		"skill_branches": {
			"arco": {
				"name": "Arco Predatore",
				"focus": "Tiro Rapido, Freccia Perforante, Colpo al Punto Debole, "
					+ "Pioggia di Frecce, Freccia Mutagena, Caccia Perfetta.",
			},
			"bestie": {
				"name": "Bestie Compagne",
				"focus": "Richiamo del Lupo, Morso Coordinato, Pelle Condivisa, "
					+ "Bestia Alpha, Branco Dimensionale, Compagno Leggendario.",
			},
			"mutazione": {
				"name": "Mutazione Chimera",
				"focus": "Artigli Temporanei, Pelle di Scaglia, Occhio Predatore, "
					+ "Veleno Interno, Ali del Portale, Forma Chimera.",
			}
		},
		"build_advice": {
			"arco": "Danno a distanza, critici, frecce speciali.",
			"branco": "Compagni bestiali, sinergie con evocazioni.",
			"chimera": "Trasformazioni, mutazioni, stile ibrido."
		},
		"signature_lines": [
			"Ti sento. Sei già nel mio branco.",
			"Ogni preda è un dono.",
			"La giungla non perdona.",
		],
	},
	{
		"id": "elios_var",
		"name": "Elios Var",
		"title": "Arconte Spezzato",
		"class_ref": "battle_arcanist",
		"role": "mago_instabile",
		"resource": "Corruzione Arcontica",
		"palette": ["azzurro arcano", "bianco", "nero vuoto", "oro corrotto"],
		"lore": "Elios era un Arconte — un essere di puro mana — prima di essere esiliato nel mondo "
			+ "mortale per aver sfidato Orvex. Ora è intrappolato in forma umana, "
			+ "con un potere immenso che lo consuma. Ogni incantesimo lo avvicina "
			+ "alla follia, ma anche alla vendetta contro Orvex, l'Arconte del Vuoto Arcano.",
		"archon_rival": "orvex",
		"archon_arena": "Occhio del Nulla",
		"advanced_class": "Portatore del Vuoto Lucente",
		"advanced_bonus": "Migliore controllo della Corruzione, magie ibride luce/vuoto, "
			+ "capacità di destabilizzare Portali nemici.",
		"skill_branches": {
			"arcana": {
				"name": "Magia Arcana",
				"focus": "Lancia di Mana, Sfera Arcana, Scarica Concentrata, "
					+ "Nova di Mana, Tempesta Arcana, Cataclisma Lucente.",
			},
			"controllo": {
				"name": "Controllo Dimensionale",
				"focus": "Sigillo Gravitazionale, Frattura Minore, Rallentamento Area, "
					+ "Prigione del Vuoto, Portale Instabile, Collasso Dimensionale.",
			},
			"proibito": {
				"name": "Potere Proibito",
				"focus": "Mana Nero, Occhio dell'Arconte, Rottura del Limite, "
					+ "Incantesimo Corrotto, Forma Arcontica, Vuoto Lucente.",
			}
		},
		"build_advice": {
			"arcana": "Danni magici stabili.",
			"controllo": "Rallentamenti, prigioni, manipolazione arena.",
			"corruzione": "Massimo danno — rischio elevato, magie proibite."
		},
		"signature_lines": [
			"Il vuoto risponde.",
			"Non sono mortale. Non del tutto.",
			"Orvex mi ha creato. Io lo distruggerò.",
		],
	},
]


## ── ARCONTI ──

const ARCHONS: Array[Dictionary] = [
	{
		"id": "vhar_mor",
		"name": "Vhar-Mor",
		"title": "Arconte della Morte",
		"rival_of": "kael_morvant",
		"arena": "Necropoli Infinita",
		"lore": "Vhar-Mor governa il flusso delle anime tra i Portali. "
			+ "Ha reclamato il fratello di Kael come suo generale. "
			+ "Ogni evocazione di Kael è un'anima che Vhar-Mor vuole riprendersi.",
		"mechanics": [
			"ruba evocazioni del giocatore",
			"resuscita boss precedenti sconfitti",
			"prosciuga Essenza d'Ombra",
			"divide l'arena in zone di morte progressiva",
		],
		"reward": "Classe avanzata di Kael + loot Arcontico necromantico.",
		"unlock_condition": "Completare un Portale Nero di grado S, reclamare 3 boss, "
			+ "livello 60+.",
	},
	{
		"id": "selyth",
		"name": "Selyth",
		"title": "Arconte della Velocità",
		"rival_of": "seren_veyra",
		"arena": "Il Secondo Spezzato",
		"lore": "Selyth esiste nel tempo tra i secondi. I suoi attacchi sono quasi invisibili "
			+ "perché arrivano dal passato o dal futuro. Solo una schivata perfetta "
			+ "apre una finestra per colpirlo.",
		"mechanics": [
			"attacchi quasi invisibili (premonizione visiva)",
			"cloni temporali (attaccano da timeline diverse)",
			"rewind parziale della vita (cura una % ogni 30s)",
			"solo schivate perfette aprono finestre di danno",
		],
		"reward": "Classe avanzata di Seren + pugnali Arcontici + rallentamento tempo.",
		"unlock_condition": "Eseguire 50 schivate perfette, sconfiggere boss velocità, "
			+ "livello 60+.",
	},
	{
		"id": "ghoran",
		"name": "Ghoran",
		"title": "Arconte della Pietra Viva",
		"rival_of": "brann_kord",
		"arena": "Fortezza Senziente",
		"lore": "Ghoran è la pietra che pensa. La sua arena è viva: muri che si muovono, "
			+ "pavimenti che si aprono, colonne che attaccano. Brann deve usare "
			+ "le sue rune per domare la fortezza stessa.",
		"mechanics": [
			"boss enorme con punti deboli mobili",
			"arena che cambia forma (muri mobili, pavimenti che collassano)",
			"attacchi telegrafati che vanno parati (non schivati)",
			"nuclei energetici da distruggere per esporre il punto debole",
		],
		"reward": "Classe avanzata di Brann + scudo Arcontico + rune protezione globale.",
		"unlock_condition": "Bloccare 500 attacchi, sconfiggere boss tank, livello 60+.",
	},
	{
		"id": "maelyra",
		"name": "Maelyra",
		"title": "Arconte delle Bestie Fuse",
		"rival_of": "nyra_solen",
		"arena": "Giungla delle Mille Forme",
		"lore": "Maelyra è un mosaico di creature fuse in un solo corpo divino. "
			+ "Cambia forma ogni fase del combattimento e può copiare le mutazioni "
			+ "che Nyra ha assorbito. Solo la combinazione elementale giusta la ferma.",
		"mechanics": [
			"cambia forma (4 fasi: felino, rettile, alato, colosso)",
			"richiama bestie dall'arena",
			"copia le mutazioni attive di Nyra",
			"vulnerabile a combinazioni elementali specifiche per fase",
		],
		"reward": "Classe avanzata di Nyra + mutazioni leggendarie + compagno Arcontico.",
		"unlock_condition": "Assorbire 20 mutazioni, sconfiggere boss bestiali, livello 60+.",
	},
	{
		"id": "orvex",
		"name": "Orvex",
		"title": "Arconte del Vuoto Arcano",
		"rival_of": "elios_var",
		"arena": "Occhio del Nulla",
		"lore": "Orvex è il padrone del mana puro e il creatore di Elios. "
			+ "Manipola la Corruzione Arcontica per invertire i controlli del giocatore "
			+ "e spezzare le abilità. La fase finale si svolge nella mente di Elios, "
			+ "dove i ricordi diventano nemici.",
		"mechanics": [
			"manipola Corruzione Arcontica (forza incantesimi proibiti)",
			"inverte controlli temporaneamente (su/giu, sinistra/destra)",
			"spezza abilità (disattiva skill a caso)",
			"genera anomalie (portalini che evocano nemici)",
			"fase finale nella mente di Elios (arena psichica)",
		],
		"reward": "Classe avanzata di Elios + magie Vuoto/Luce + reliquia Arcontica.",
		"unlock_condition": "Usare magie proibite 30 volte, sopravvivere a Corruzione 80%, "
			+ "livello 60+.",
	},
]


## ── HUB: BASTIONE DI VELAR ──

const HUB_NPCS: Array[Dictionary] = [
	{
		"id": "lyria",
		"name": "Lyria",
		"title": "Custode dei Portali",
		"role": "Apre e classifica i Portali disponibili.",
		"location": "Sala dei Varchi",
		"lines": [
			"Questo Portale pulsa di energia antica. Grado B, pericolo moderato.",
			"Attento: un Portale Rosso si è aperto a nord. Non si esce finché il boss muore.",
			"Hai il coraggio per un Portale Nero? Tre piani di orrori ti aspettano.",
			"Gli Arconti stanno diventando più attivi. Senti l'Eclisse che cresce?",
		],
	},
	{
		"id": "drom",
		"name": "Drom",
		"title": "Fabbro Runico",
		"role": "Potenziamento armi e armature con materiali dei Portali.",
		"location": "Forgia dell'Eclisse",
		"lines": [
			"Portami ferro runico e ossa antiche. Forgerò qualcosa di degno.",
			"Questa lama ha sete di cristalli di Portale. Ne hai?",
			"Le rune brillano quando il metallo è puro. Le tue armi sono pronte?",
		],
	},
	{
		"id": "maer",
		"name": "Maer",
		"title": "Archivista",
		"role": "Spiega lore, bestiario e storia degli Arconti.",
		"location": "Biblioteca di Velar",
		"lines": [
			"Gli Arconti non sono dei. Sono errori del Grande Sigillo.",
			"Vhar-Mor ruba le anime. Selyth ruba i secondi. Ghoran ruba la terra.",
			"Ogni Portale è una cicatrice nel tessuto del mondo.",
		],
	},
	{
		"id": "solaine",
		"name": "Solaine",
		"title": "Guaritrice dell'Eclisse",
		"role": "Cure, pozioni, rimozione maledizioni da loot corrotto.",
		"location": "Santuario della Luce",
		"lines": [
			"Quella ferita puzza di magia proibita. Lascia che la purifichi.",
			"Le pozioni sono pronte. Non sprecare la vita, campione.",
		],
	},
	{
		"id": "rauk",
		"name": "Rauk",
		"title": "Mercante dei Caduti",
		"role": "Vende oggetti rischiosi, corrotti o proibiti.",
		"location": "Mercato Nero",
		"lines": [
			"Questo anello ti renderà più forte. Ma ogni colpo che dai... lo sentirai anche tu.",
			"Oggetti che nessun altro osa vendere. Interessato?",
		],
	},
]


## ── LIVELLI E FASCE ──

const LEVEL_BANDS: Array[Dictionary] = [
	{
		"band": "Risveglio", "levels": [1, 10],
		"portals": ["F", "E", "D"],
		"unlocks": [
			"3 abilità base",
			"equipaggiamento comune",
			"primo miniboss",
			"primo compagno o evocazione",
		],
		"objective": "Imparare i controlli, affrontare i primi Portali.",
	},
	{
		"band": "Cacciatore di Portali", "levels": [11, 30],
		"portals": ["C", "B"],
		"unlocks": [
			"ramo secondario dello skill tree",
			"rune base",
			"boss regionali",
			"crafting iniziale",
		],
		"objective": "Costruire la prima build, ottenere oggetti rari.",
	},
	{
		"band": "Ascendente", "levels": [31, 60],
		"portals": ["A", "S"],
		"unlocks": [
			"abilità ultimate",
			"set di classe",
			"Portali Rossi",
			"Portali Neri",
			"boss evocabili per Kael",
		],
		"objective": "Affrontare Portali A e S, sbloccare sinergie, loot epico.",
	},
	{
		"band": "Campione dell'Eclisse", "levels": [61, 100],
		"portals": ["S", "SS"],
		"unlocks": [
			"trasformazioni",
			"oggetti leggendari",
			"set completi",
			"modalità Portali Infiniti",
			"classi avanzate",
		],
		"objective": "Sconfiggere Arconti, completare la Torre Inversa.",
	},
	{
		"band": "Grado Infinito", "levels": [101, -1],
		"portals": ["SSS", "Abisso"],
		"unlocks": [
			"punti Ascensione",
			"livelli Paragon",
			"potenziamenti globali",
			"Portali Abisso",
			"reliquie mitiche",
			"boss mondiali",
		],
		"objective": "Progressione endgame illimitata.",
	},
]


## ── STAGIONI ENDGAME ──

const SEASONS: Array[Dictionary] = [
	{
		"id": "season_1", "title": "I Portali dell'Eclisse",
		"theme": "non morti, primi Arconti, Torre Inversa",
		"featured_heroes": ["kael_morvant", "brann_kord"],
		"featured_bosses": ["vhar_mor", "skeleton_odran"],
		"maps": ["st_maria_1", "st_maria_2", "st_maria_3", "stormrock_ruins"],
	},
	{
		"id": "season_2", "title": "Bestie Fuse",
		"theme": "mutazioni, Portali naturali, boss chimera",
		"featured_heroes": ["nyra_solen"],
		"featured_bosses": ["maelyra", "crystal_queen"],
		"maps": ["grot_lagoon", "lake_kuuma", "river_trail"],
	},
	{
		"id": "season_3", "title": "Guerra delle Rune",
		"theme": "costrutti, fortezze viventi, equipaggiamento difensivo",
		"featured_heroes": ["brann_kord"],
		"featured_bosses": ["ghoran", "forge_golem"],
		"maps": ["fort_nasu", "fort_amir", "dilapidated_sewers"],
	},
	{
		"id": "season_4", "title": "Specchi del Sistema",
		"theme": "copie alternative, boss clone, versioni corrotte dei protagonisti",
		"featured_heroes": ["seren_veyra", "elios_var"],
		"featured_bosses": ["selyth", "orvex"],
		"maps": ["book_of_the_dead", "stormrock_ruins"],
	},
	{
		"id": "season_5", "title": "Oltre il Livello Massimo",
		"theme": "Portali Infiniti, loot Prisma, Ascensione senza limite",
		"featured_heroes": [],
		"featured_bosses": [],
		"maps": [],
	},
]


## ── MATERIALI DI CRAFTING ──

const CRAFTING_MATERIALS: Dictionary = {
	"iron_runico": {
		"name": "Ferro Runico", "rarity": "common",
		"source": "Portali Bianchi, nemici non-morti",
		"use": "Potenziamento armi e armature base.",
	},
	"ossa_antiche": {
		"name": "Ossa Antiche", "rarity": "common",
		"source": "Scheletri, lich, cripte",
		"use": "Riforgiatura equipaggiamento necrotico.",
	},
	"cristallo_portale": {
		"name": "Cristallo di Portale", "rarity": "uncommon",
		"source": "Boss dei Portali, Portali Rossi",
		"use": "Incantamento elementale, crafting rune.",
	},
	"sangue_chimera": {
		"name": "Sangue Chimera", "rarity": "uncommon",
		"source": "Bestie dimensionali, boss mutanti",
		"use": "Mutazioni per Nyra, frecce speciali.",
	},
	"frammento_arcontico": {
		"name": "Frammento Arcontico", "rarity": "rare",
		"source": "Portali Arcontici, evento raro",
		"use": "Evoluzione Leggendaria, crafting reliquie.",
	},
	"cenere_eclisse": {
		"name": "Cenere d'Eclisse", "rarity": "epic",
		"source": "Arconti sconfitti, Portali Abisso",
		"use": "Corruzione oggetti, potenziamenti estremi.",
	},
	"essenza_boss": {
		"name": "Essenza Boss", "rarity": "legendary",
		"source": "Qualsiasi boss dei Portali",
		"use": "Riforgiatura suprema, Fusione Rune.",
	},
}


## ── DIREZIONE ARTISTICA ──

const ART_DIRECTION := {
	"style": "Dark fantasy leggibile con contrasti forti. Portali luminosi e instabili, "
		+ "dungeon cupi, armature stilizzate, mostri riconoscibili, "
		+ "effetti magici molto visivi, silhouette chiare per ogni classe.",
	"ui_colors": {
		"darkest": Color(0.02, 0.05, 0.15, 1.0),
		"panel": Color(0.045, 0.055, 0.085, 0.96),
		"border_primary": Color(0.22, 0.72, 0.95, 0.72),
		"border_legendary": Color(1.0, 0.7, 0.2, 0.9),
		"text_primary": Color(0.72, 0.93, 1.0),
		"text_gold": Color(1.0, 0.85, 0.2),
		"portal_glow": Color(0.18, 0.86, 1.0, 0.86),
		"portal_dark": Color(0.70, 0.24, 1.0, 0.72),
	},
}


## ── FUNZIONI DI UTILITÀ ──

func get_hero(hero_id: String) -> Dictionary:
	for h in HEROES:
		if h.id == hero_id:
			return h
	return {}

func get_archon(archon_id: String) -> Dictionary:
	for a in ARCHONS:
		if a.id == archon_id:
			return a
	return {}

func get_hero_by_class(class_id: String) -> Dictionary:
	for h in HEROES:
		if h.class_ref == class_id:
			return h
	return {}

func get_archon_for_hero(hero_id: String) -> Dictionary:
	var hero := get_hero(hero_id)
	if hero.is_empty():
		return {}
	return get_archon(hero.archon_rival)

func get_level_band(level: int) -> Dictionary:
	for band in LEVEL_BANDS:
		var lo: int = band.levels[0]
		var hi: int = band.levels[1]
		if level >= lo and (hi < 0 or level <= hi):
			return band
	return {}

func get_season_for_level(level: int) -> Dictionary:
	if level <= 30:
		return SEASONS[0]
	elif level <= 60:
		return SEASONS[1]
	elif level <= 80:
		return SEASONS[2]
	elif level <= 100:
		return SEASONS[3]
	else:
		return SEASONS[4]

func get_hero_lines(hero_id: String) -> Array:
	var hero := get_hero(hero_id)
	if hero.is_empty():
		return []
	return hero.get("signature_lines", [])


## ── VERTICAL SLICE CONSIGLIATA ──

const VERTICAL_SLICE := {
	"description": "Demo 20-30 minuti con Kael (Necromante).",
	"content": {
		"playable_hero": "kael_morvant",
		"hub_size": "piccolo",
		"portals": 2,
		"enemies": 5,
		"miniboss": 1,
		"boss": 1,
		"skills": 10,
		"loot_items": 20,
		"rarity_tiers": 3,
		"summon_system": "base",
		"level_cap": 10,
	},
	"portal_1": {
		"name": "Cripta Spezzata",
		"enemies": ["skeleton", "skeleton_a", "zombie"],
		"boss": "skeleton_odran",
	},
	"portal_2": {
		"name": "Grotte di Vetro",
		"enemies": ["myrm_scout", "myrm_soldier", "myrm_elite"],
		"boss": "crystal_queen",
	},
}
