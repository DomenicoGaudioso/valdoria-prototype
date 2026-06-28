# Valdoria Prototype

**Action RPG Isometrico open-source** — prototipo funzionante ispirato a Sacred, Diablo e Solo Leveling.

Engine: **Godot 4.7** (GDScript, `gl_compatibility`)  
Stato: **Prototipo giocabile** — 14 mappe, 16 nemici, XP/livelli, loot, portali

---

## Caratteristiche

### Mondo
- **14 mappe FLARE** (CC-BY-SA 3.0) da `flareteam/flare-game` Empyrean Campaign
- 11 grassland + 2 snowplains + 1 arrivo — fino a 132×132 tile
- Biome: prateria, palude, altopiani, deserto (oasis), foreste pietrificate, neve
- Mappe interconnesse tramite **portali teletrasporto** (click o prossimità)
- Tile isometrici renderizzati con z-index e offsets corretti

### Giocatore
- Eroe isometrico 8 direzioni (Clint Bellanger, CC-BY 3.0)
- **Sistema XP/Livelli**: 10+ livelli scalabili, ogni level-up aumenta HP, danno, velocità
- **Barra XP blu** stile Solo Leveling
- Sistema combo 3 livelli con moltiplicatore danno
- **Equipaggiamento**: 5 slot (arma, armatura, elmo, stivali, anello)
- **30+ oggetti** con 5 tier rarità (comune → leggendario)
- Stats in tempo reale: DAN, HP, VEL

### Nemici (16 tipi)
| Nemico | HP | Tier | Tipo |
|---|---|---|---|
| Scheletro | 30 | 1 | Base |
| Goblin | 18 | 1 | Veloce |
| Zombie | 55 | 1 | Lento |
| Arciere Scheletrico | 25 | 2 | Ranged |
| Goblin Sciamano | 45 | 2 | Magico |
| Mago Oscuro | 60 | 3 | Ranged |
| Viverna | 80 | 3 | Volante |
| Viverna Alata | 120 | 3 | Boss |
| Orco Guerriero | 90 | 3 | Tank |
| Lich Supremo | 180 | 4 | Boss magico |
| Licantropo | 110 | 3 | Veloce |
| Licantropo Alfa | 200 | 4 | Boss |
| Drago Supremo | 250 | 4 | Boss |
| Orco Campione | 150 | 4 | Elite |
| Minotauro | 300 | 5 | Boss |
| Drago Antico | 400 | 5 | Boss finale |

### Loot & Economia
- **Oro**: ogni nemico droppa oro proporzionale al tier
- **Equipaggiamento**: armi, armature, elmi, stivali, anelli con bonus stats
- Drop chance crescente col tier (30% → 80%)
- Oggetti colorati per rarità (bianco, verde, blu, viola, arancione)
- Zaino (tasto I) con sezione equip + inventario

### Mappe
| Mappa | Dim. | Bioma |
|---|---|---|
| Black Oak Farm | 100×100 | Prateria |
| Black Oak City | 100×100 | Città |
| Nazia Highlands | 80×80 | Altopiani |
| Merrimead Swamp | 80×80 | Palude |
| Southern Ridge | 80×80 | Roccioso |
| Salted Field | 60×60 | Desolato |
| Stonewood | 100×80 | Foresta pietrificata |
| Oasis | 100×100 | Deserto |
| River Trail | 80×40 | Fiume |
| Lochport | 50×60 | Porto |
| Perdition Harbor | 40×40 | Porto maledetto |
| Grot Lagoon | 112×112 | Neve |
| Lake Kuuma | 132×132 | Neve |

---

## Requisiti
- **Godot 4.7** (standard, no moduli extra)
- Windows / Linux / macOS
- Scheda video con OpenGL 3.3+

## Avvio rapido
```bash
# Clona il repository
git clone https://github.com/DomenicoGaudioso/valdoria-prototype.git
cd valdoria-prototype

# Apri con Godot 4.7
godot --path . res://scenes/main/Main.tscn
# oppure apri project.godot nell'editor
```

## Controlli
| Tasto | Azione |
|---|---|
| **Click sinistro** | Muovi eroe |
| **Click su portale** | Teletrasporto |
| **Spazio / Click destro** | Attacca |
| **I** | Zaino (equipaggia/loot) |
| **E** | Interagisci |
| **Mappe** (bottone UI) | Menu viaggio rapido |

## Crediti
- **Tileset e mappe**: [FLARE Team](https://github.com/flareteam/flare-game) — CC-BY-SA 3.0
- **Sprite eroe**: Clint Bellanger — CC-BY 3.0
- **Sprite nemici**: FLARE art_src (goblin, skeleton, zombie, wyvern) — CC-BY-SA 3.0
- **Engine**: [Godot Engine](https://godotengine.org) — MIT

## Licenza
Il codice sorgente di questo progetto è rilasciato sotto **MIT License**.  
Gli asset (tileset, sprite, mappe) mantengono le loro licenze originali (CC-BY / CC-BY-SA 3.0).  
Vedi `assets/flare/LICENSE.txt` e `assets/flare/CREDITS.txt` per i dettagli.

## Struttura
```
Sacred/
├── assets/flare/          # Asset FLARE (tileset, characters, animations)
│   ├── tilesets/          # grassland, snowplains, dungeon...
│   └── characters/        # grid sprite sheets
├── data/
│   ├── maps/              # Dati mappe convertiti da .tmx
│   └── MapRegistry.gd     # Registro mappe e portali
├── scripts/
│   ├── systems/           # GameBootstrap (core loop)
│   ├── player/            # Player (movimento, XP, equip)
│   ├── enemies/           # Enemy AI
│   ├── items/             # ItemData, DroppedItem
│   ├── inventory/         # Inventory manager
│   ├── ui/                # GameUI
│   └── ...
├── scenes/main/           # Main.tscn
└── tools/                 # convert_tmx_to_gd.py
```

---

*"Il più forte non è colui che vince sempre, ma colui che si rialza ogni volta."* — Solo Leveling
