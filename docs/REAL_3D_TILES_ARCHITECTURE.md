# Sistema Mappe Reali 3D Tiles — Documentazione Architetturale
## Valdoria Prototype — Sacred-Like Action RPG

---

## 1. ARCHITETTURA GENERALE

Il sistema introduce un secondo binario di caricamento mappe affiancato a quello classico
2D isometrico (GameBootstrap + FLARE tileset). La scelta è gestita da `MapLoader.gd`.

```
                    ┌──────────────────────────┐
                    │      Main Menu / UI       │
                    │  (CitySelectionMenu.gd)   │
                    └────────────┬─────────────┘
                                 │ city_chosen
                    ┌────────────▼─────────────┐
                    │       MapLoader.gd        │
                    │   (wrapper decisionale)    │
                    └─────┬──────────────┬──────┘
                          │              │
               ┌──────────▼───┐  ┌───────▼──────────┐
               │ CLASSIC_2D   │  │  REAL_3D_TILES   │
               │ GameBootstrap│  │  RealWorldMap.gd │
               │ (FLARE tiles)│  │  (Cesium/Google) │
               └──────────────┘  └──────────────────┘
```

**Percorsi utente principali:**

1. **Avvio gioco** → GameBootstrap carica mappa classica (comportamento attuale, invariato)
2. **Menu "Varchi"** → nuova voce "Città Reali 3D" → CitySelectionMenu → RealWorldMap
3. **Tasto M** (da aggiungere) → toggle rapido tra classica e reale
4. **Offline/fallback** → automatico su mappa classica

---

## 2. STRUTTURA CARTELLE

```
res://
├── addons/
│   └── cesium_godot/              ← plugin 3D Tiles for Godot (da installare)
├── config/
│   └── map_settings.cfg           ← configurazioni centralizzate
├── maps/
│   ├── old_maps/                  ← mappe classiche di backup
│   │   └── black_oak_farm_data.gd (esempio)
│   └── real_world/
│       ├── CityDatabase.gd        ← database 8 città (Autoload)
│       ├── CitySelector.gd        ← logica selezione
│       ├── MapLoader.gd           ← wrapper classico/reale
│       ├── PlayerSpawnController.gd ← spawn player WGS84
│       ├── RealWorldMap.gd        ← scena principale 3D
│       └── TileStreamingSettings.gd ← performance/LOD
├── data/maps/                     ← mappe classiche (invariate)
├── ui/
│   ├── CitySelectionMenu.gd       ← UI menu città
│   ├── LoadingMapScreen.gd        ← schermata caricamento
│   └── MapCreditsPanel.gd         ← attribuzioni
├── scenes/main/Main.tscn          ← scena principale (da aggiornare)
└── scripts/systems/GameBootstrap.gd ← sistema classico (invariato)
```

---

## 3. DESCRIZIONE DEGLI SCRIPT

### 3.1 CityDatabase.gd (Autoload Singleton)
- **Tipo:** `Node`
- **Da registrare in project.godot** come `CityDatabase`
- Contiene `const CITIES: Dictionary` con 8 città
- Ogni città ha: id, display_name, lat, lon, height, status, description, cesium_asset_id, google_tileset_id, preferred_provider
- Metodi: `get_city()`, `get_all_cities()`, `get_verified()`, `set_favorite()`

### 3.2 CitySelector.gd
- Gestisce selezione corrente e conversione coordinate WGS84
- Signal: `city_selected(city_data)`
- Metodi: `select_city()`, `get_wgs84_position()`, `get_cesium_asset_id()`

### 3.3 MapLoader.gd
- **Wrapper universale:** decide se caricare mappa classica o 3D Tiles
- Signal: `map_loaded`, `map_load_failed`, `loading_progress`
- Metodo `load_real_city()` verifica connettività internet prima dello streaming
- Fallback automatico su `black_oak_city` se offline o errore

### 3.4 TileStreamingSettings.gd (Resource)
- Preset qualità: LOW, MEDIUM, HIGH
- Parametri: screen_space_error, max_distance, memory_cache_mb, max_concurrent_downloads
- Caricabile da `map_settings.cfg`

### 3.5 PlayerSpawnController.gd
- Posiziona il player 3D alle coordinate WGS84 della città
- Supporta CesiumGlobeAnchor (plugin) o fallback manuale
- Metodo: `spawn_player_at_wgs84(lat, lon, height)`

### 3.6 RealWorldMap.gd (Node3D)
- Scena root del mondo 3D reale
- Crea e configura: CesiumGeoreference, Cesium3DTileset, illuminazione, collisioni
- Integra CitySelector, MapLoader, PlayerSpawnController
- Gestisce il flusso: selezione → streaming → spawn player

### 3.7 CitySelectionMenu.gd (Control)
- UI per selezionare la città con card colorate per stato
- Filtro "solo verificate", toggle preferiti
- Signal: `city_chosen(city_id)`, `back_pressed()`

### 3.8 LoadingMapScreen.gd (Control)
- Progress bar + status durante lo streaming
- Tips randomizzati
- Collegata a `MapLoader.loading_progress`

### 3.9 MapCreditsPanel.gd (Control)
- Sezioni: Cesium, Google, OpenStreetMap, Plugin, Avviso Legale
- Richiesto dai ToS dei provider

---

## 4. STRUTTURA SCENA RealWorldMap.tscn

```
RealWorldMap (Node3D) ── script: RealWorldMap.gd
├── CesiumGeoreference          ← plugin (posizionamento geodetico)
│   └── ion_access_token: ""
├── Cesium3DTileset             ← plugin (streaming tiles)
│   └── ion_asset_id: 0         ← da impostare dopo selezione città
├── SunLight (DirectionalLight3D)
├── WorldEnvironment (WorldEnvironment)
├── GameplayCollisionLayer (StaticBody3D)
│   └── GroundPlane (CollisionShape3D + BoxShape3D)
├── PlayerSpawnController (Node3D) ── script: PlayerSpawnController.gd
├── CitySelector (Node) ── script: CitySelector.gd
├── MapLoader (Node) ── script: MapLoader.gd
├── LoadingMapLayer (CanvasLayer)
│   └── LoadingScreen (Control) ── script: LoadingMapScreen.gd
└── CreditsLayer (CanvasLayer)
    └── CreditsPanel (Control) ── script: MapCreditsPanel.gd
```

---

## 5. PROCEDURA DI INTEGRAZIONE (PASSO-PASSO)

### Step 1: Installare il plugin 3D Tiles for Godot
1. Scaricare da https://github.com/battle-road/3d-tiles-for-godot
2. Copiare la cartella `addons/cesium_godot/` dentro `res://addons/`
3. Abilitare il plugin in Project → Project Settings → Plugins

### Step 2: Registrare gli Autoload in project.godot
Aggiungere in `[autoload]`:
```
CityDatabase="*res://maps/real_world/CityDatabase.gd"
```

### Step 3: Configurare i token API
1. Ottenere un token da https://ion.cesium.com (gratuito per uso non-commerciale)
2. Inserire il token in `config/map_settings.cfg` sotto `[cesium] ion_access_token`
3. **NON COMMITTARE MAI** i token su Git (aggiungere `map_settings.cfg` a `.gitignore` o usare variabili d'ambiente)

### Step 4: Registrare gli Asset ID su Cesium ion
1. Caricare su Cesium ion i dataset 3D Tiles per ogni città
2. Annotare gli asset ID e inserirli in `CityDatabase.gd` (`cesium_asset_id`)

### Step 5: Creare RealWorldMap.tscn nell'Editor
1. Apri Godot Editor
2. Crea nuova scena 3D, salva come `res://maps/real_world/RealWorldMap.tscn`
3. Aggiungi nodo radice Node3D, assegna script `RealWorldMap.gd`
4. Trascina `CesiumGeoreference` e `Cesium3DTileset` dal pannello nodi del plugin
5. Collega i riferimenti negli @export di RealWorldMap.gd

### Step 6: Aggiornare GameBootstrap per supportare il passaggio a 3D
Aggiungere nel menu "Varchi" di GameBootstrap un pulsante:
```gdscript
var btn_3d := Button.new()
btn_3d.text = "Città Reali 3D"
btn_3d.pressed.connect(_switch_to_real_world)
```

E la funzione:
```gdscript
func _switch_to_real_world() -> void:
    get_tree().change_scene_to_file("res://maps/real_world/RealWorldMap.tscn")
```

### Step 7: Aggiungere tasto per tornare alle mappe classiche
In RealWorldMap.gd, già presente il menu `CitySelectionMenu` con pulsante "Indietro".

---

## 6. PROCEDURA DI TEST

### Test 1: New York
```gdscript
# Avviare RealWorldMap con default_city = "new_york"
# Verificare:
# - La camera parte alle coordinate corrette (40.71, -74.00)
# - I tiles iniziano lo streaming (manhattan visibile)
# - Il player è posizionato sopra il suolo
# - Il caricamento progressivo funziona
```

### Test 2: Venezia
```gdscript
# Selezionare Venezia dal menu (45.44, 12.31)
# Verificare:
# - Presenza di acqua/canali visibili nei tiles
# - Performance accettabile (città compatta)
# - Eventuale necessità di collisioni custom per acqua
```

### Test 3: Roma
```gdscript
# Selezionare Roma (41.90, 12.49)
# Verificare:
# - Disponibilità tiles su Cesium ion per Roma
# - Se non disponibile, testare con dataset OSM alternativo
```

### Test 4: Bologna
```gdscript
# Selezionare Bologna (44.49, 11.34)
# Verificare:
# - Disponibilità tiles
# - Qualità sufficiente per gameplay
```

---

## 7. CHECKLIST PERFORMANCE

- [ ] LOW preset: max_distance 1500m, cache 128MB, 4 download → testare su hardware minimo
- [ ] MEDIUM preset: max_distance 3000m, cache 512MB, 8 download → target principale
- [ ] HIGH preset: max_distance 5000m, cache 1024MB, 12 download → hardware potente
- [ ] Frustum culling abilitato (riduce draw calls)
- [ ] Skip LOD su LOW (meno geometria, più performance)
- [ ] Test FPS con player fermo e in movimento veloce
- [ ] Test memory usage con profiler Godot
- [ ] Test latenza streaming su connessione lenta
- [ ] Test fallback offline (scollegare rete, deve caricare mappa classica)

---

## 8. CHECKLIST LICENZE / ATTRIBUTION

- [ ] Cesium ion: attribution "Includes data from Cesium ion" visibile nei crediti
- [ ] Google: i Photorealistic 3D Tiles sono SOLO in streaming, nessun caching permanente
- [ ] Google: attribution "Google" e logo richiesti dai ToS se usati
- [ ] OpenStreetMap: © OpenStreetMap contributors, ODbL
- [ ] Plugin 3D Tiles for Godot: credito a Battle Road
- [ ] Godot Engine: licenza MIT
- [ ] Pannello "Credits / Map Data" accessibile dal menu (MapCreditsPanel.gd)
- [ ] `force_attribution=true` in `map_settings.cfg` garantisce attribuzione sempre visibile

---

## 9. PROBLEMI PROBABILI E SOLUZIONI

| Problema | Causa Probabile | Soluzione |
|----------|----------------|-----------|
| "Classe CesiumGeoreference non trovata" | Plugin non installato o non abilitato | Verificare Project Settings → Plugins, reimportare assets |
| Tiles non visibili / schermo nero | Token Cesium ion non valido o assente | Controllare `ion_access_token` in map_settings.cfg |
| Player cade nel vuoto | Collisioni assenti nel tileset fotogrammetrico | Aggiungere mesh proxy collider in GameplayCollisionLayer |
| Crash su città grande (NY) | Memoria insufficiente | Usare preset LOW, ridurre max_distance |
| Streaming lentissimo | Connessione lenta o server congestionato | Ridurre qualità, aumentare cache, usare mappa classica come fallback |
| Venezia/Roma tiles assenti | Dataset non disponibili su Cesium ion | Caricare manualmente dataset OSM o usare Google 3D Tiles (se disponibile) |
| Google tiles non funzionano | API key mancante o invalida | Registrare Google Map Tiles API key, verificare quota |
| Conflitto Autoload | CityDatabase già registrato con altro nome | Controllare project.godot [autoload] |

---

## 10. PIPELINE ALTERNATIVA OFFLINE (OpenStreetMap)

Se serve una mappa offline senza dipendere da Cesium/Google:

```
OpenStreetMap (.osm.pbf)
    → OSM2World / Blender-OSM
        → esporta GLB/GLTF con edifici
            → importa in Godot come MeshInstance3D
                → aggiungi collider manualmente
```

Questa pipeline è completamente offline, modificabile, e non ha vincoli di licenza
oltre a OpenStreetMap (ODbL, richiede attribuzione).

---

## 11. COMANDI RAPIDI PER IL DEBUG

```gdscript
# Nella console Godot:
CityDatabase.get_city("roma")          # Mostra dati città
CityDatabase.get_verified()             # Città funzionanti
TileStreamingSettings.from_config_file()  # Carica impostazioni

# Cambio città a runtime:
var rwm = get_node("/root/RealWorldMap")
rwm.change_city("venezia")

# Mostra/nascondi crediti:
rwm.toggle_credits()
```

---

*Ultimo aggiornamento: Giugno 2026*
*File generato per il progetto Valdoria Prototype / Sacred*
