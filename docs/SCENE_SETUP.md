# SCENE SETUP — Guida assemblaggio Scene Godot

Questo file descrive l'esatta gerarchia di nodi per ogni scena del progetto.
Copia questa struttura nell'editor Godot, poi assegna gli script ai nodi corrispondenti.

---

## 1. Main.tscn

**Percorso**: `res://scenes/main/Main.tscn`
**Tipo root**: `Node2D`
**Script**: (nessuno, è un contenitore)

```
Main (Node2D)
├─ World (istanza di World.tscn)
├─ Player (istanza di Player.tscn)
│    └─ Camera2D (Camera2D)
│         current: on
│         position_smoothing: enabled
│         position_smoothing_speed: 5.0
├─ DroppedItems (Node2D)  [contenitore per oggetti droppati]
└─ GameUI (istanza di GameUI.tscn)
```

### Procedura:

1. Crea nuova scena: `Node2D` chiamato `Main`
2. Salva in `res://scenes/main/Main.tscn`
3. Istanzia `World.tscn` come figlio (tasto destro > Instantiate Child Scene)
4. Istanzia `Player.tscn` come figlio
5. Aggiungi `Camera2D` come figlio di `Player`
6. Aggiungi `Node2D` chiamato `DroppedItems`
7. Istanzia `GameUI.tscn` come figlio

### Camera2D Settings:
- `Current`: ON
- `Position Smoothing`: ON
- `Position Smoothing Speed`: 5.0
- `Zoom`: (1.5, 1.5) (zoom di partenza, configurabile)

---

## 2. World.tscn

**Percorso**: `res://scenes/world/World.tscn`
**Tipo root**: `Node2D`
**Script**: `res://scripts/world/World.gd`

```
World (Node2D) [script: World.gd]
├─ Terrain (Node2D)
│    ├─ Ground (Sprite2D) — rettangolo verde scuro, dimensione 1600x1200
│    ├─ Path (Sprite2D) — rettangolo marrone, più piccolo, per il sentiero
│    ├─ Rock1 (Sprite2D) — cerchio grigio, ostacolo
│    ├─ Rock2 (Sprite2D) — cerchio grigio, ostacolo
│    ├─ Ruin1 (Sprite2D) — rettangolo grigio scuro, rudere
│    └─ Ruin2 (Sprite2D) — rettangolo grigio scuro, rudere
└─ StaticBody2D (collisioni per rocce e ostacoli)
     └─ CollisionShape2D (rettangoli o cerchi)
```

### Procedura:

1. Crea `Node2D` chiamato `World`
2. Allega script `World.gd`
3. Aggiungi `Node2D` figlio chiamato `Terrain`
4. Sotto `Terrain`, crea `Sprite2D` per ogni elemento:
   - Ground: crea una texture placeholder 64x64 verde `#2d5a1e`, imposta `scale` (25, 18.75)
   - Path: crea una texture placeholder 32x32 marrone `#5c3d2e`, imposta `scale` (10, 2), posizione (800, 400)
   - Rock1: cerchio grigio `#555555`, posizione (300, 600), scala (2, 2)
   - Rock2: cerchio grigio `#555555`, posizione (900, 300), scala (1.5, 1.5)
   - Ruin1: rettangolo `#3d3d3d`, posizione (1000, 700), scala (3, 2)
   - Ruin2: rettangolo `#3d3d3d`, posizione (1200, 450), scala (2, 1.5)
5. Imposta `show_debug_grid` a `true` per vedere la griglia di debug
6. Configura nell'Inspector:
   - `Map Name`: "Sentiero delle Rovine"
   - `Map Width`: 1600, `Map Height`: 1200
   - `Player Spawn Position`: (400, 500)
   - `Enemy Spawns`: aggiungi `Vector2(800, 400)`, `Vector2(1100, 650)`
   - `Enemy Scene`: carica `res://scenes/enemies/Enemy.tscn`

---

## 3. Player.tscn

**Percorso**: `res://scenes/player/Player.tscn`
**Tipo root**: `CharacterBody2D`
**Script**: `res://scripts/player/Player.gd`

```
Player (CharacterBody2D) [script: Player.gd]
├─ CollisionShape2D (CircleShape2D, radius ~16)
├─ Shadow (Sprite2D) — cerchio nero semitrasparente sotto il personaggio
├─ Sprite2D — placeholder rettangolare 32x48
├─ AttackArea (Area2D)
│    └─ CollisionShape2D (CircleShape2D, radius = attack_range)
├─ HealthBar (ProgressBar) — facoltativo, sopra la testa
└─ AnimationPlayer
```

### Procedura:

1. Crea `CharacterBody2D` chiamato `Player`
2. Allega script `Player.gd`
3. Aggiungi `CollisionShape2D` con `CircleShape2D` radius 16
4. Aggiungi `Sprite2D` chiamato `Shadow`:
   - Crea una texture placeholder: cerchio nero 32x32, semi-trasparente
   - `Modulate`: `(0, 0, 0, 0.5)`
   - `Offset`: `(0, 16)` (ombra ai piedi)
   - `Z Index`: -1
5. Aggiungi `Sprite2D` per il personaggio:
   - Crea una texture placeholder: rettangolo 32x48 blu scuro `#1a3a5c`
   - `Offset`: `(0, -24)` (centrato sui piedi)
6. Aggiungi `Area2D` chiamato `AttackArea`:
   - `CollisionShape2D` con `CircleShape2D`, radius 50 (uguale a `attack_range`)
7. Aggiungi `AnimationPlayer` (vuoto per ora)
8. Configura nell'Inspector Player:
   - `Class Id`: "arena_champion"
   - `Class Name`: "Campione delle Arene"
   - `Max Hp`: 100, `Current Hp`: 100
   - `Move Speed`: 200, `Stop Distance`: 8
   - `Attack Damage`: 10, `Attack Range`: 50, `Attack Cooldown`: 0.8

---

## 4. Enemy.tscn

**Percorso**: `res://scenes/enemies/Enemy.tscn`
**Tipo root**: `CharacterBody2D`
**Script**: `res://scripts/enemies/Enemy.gd`

```
Enemy (CharacterBody2D) [script: Enemy.gd]
├─ CollisionShape2D (CircleShape2D, radius ~14)
├─ Shadow (Sprite2D) — cerchio nero semitrasparente
├─ Sprite2D — placeholder rettangolare 32x48
├─ DetectionArea (Area2D)
│    └─ CollisionShape2D (CircleShape2D, radius = detection_radius)
└─ AnimationPlayer
```

### Procedura:

1. Crea `CharacterBody2D` chiamato `Enemy`
2. Allega script `Enemy.gd`
3. Aggiungi `CollisionShape2D` con `CircleShape2D` radius 14
4. Aggiungi `Sprite2D` chiamato `Shadow`:
   - Stesso metodo del Player, cerchio nero semi-trasparente
5. Aggiungi `Sprite2D` per lo scheletro:
   - Placeholder: rettangolo 32x48 bianco/grigio `#cccccc`
6. Aggiungi `Area2D` chiamato `DetectionArea`:
   - `CollisionShape2D` con `CircleShape2D`, radius 200
   - Il raggio viene sovrascritto dallo script con `detection_radius`
7. Aggiungi `AnimationPlayer` (vuoto)
8. Configura nell'Inspector:
   - `Enemy Id`: "wandering_skeleton"
   - `Enemy Name`: "Scheletro errante"
   - `Max Hp`: 30, `Current Hp`: 30
   - `Move Speed`: 80, `Detection Radius`: 200
   - `Attack Range`: 40, `Attack Damage`: 5, `Attack Cooldown`: 1.2
   - `Loot Table`: aggiungi una entry:
     - `chance`: 0.8
     - `item_id`: "rusty_sword"
     - `item_name`: "Spada arrugginita"
     - `item_type`: "weapon"
     - `item_rarity`: "common"

---

## 5. DroppedItem.tscn

**Percorso**: `res://scenes/items/DroppedItem.tscn`
**Tipo root**: `Area2D`
**Script**: `res://scripts/items/DroppedItem.gd`

```
DroppedItem (Area2D) [script: DroppedItem.gd]
├─ CollisionShape2D (CircleShape2D, radius ~20)
├─ Sprite2D — icona item placeholder
└─ Label — nome item
```

### Procedura:

1. Crea `Area2D` chiamato `DroppedItem`
2. Allega script `DroppedItem.gd`
3. Aggiungi `CollisionShape2D` con `CircleShape2D` radius 20
4. Aggiungi `Sprite2D` per l'icona (placeholder 16x16 colorato in base alla rarità)
5. Aggiungi `Label`:
   - Posiziona sopra lo sprite
   - `Scale`: (0.8, 0.8)
6. Imposta `Pickup Cooldown`: 0.5, `Lifetime`: 60

---

## 6. GameUI.tscn

**Percorso**: `res://scenes/ui/GameUI.tscn`
**Tipo root**: `CanvasLayer`
**Script**: `res://scripts/ui/GameUI.gd`

```
GameUI (CanvasLayer) [script: GameUI.gd]
├─ MarginContainer (top-left)
│    └─ VBoxContainer
│         ├─ Label "Vita"
│         ├─ HealthBar (ProgressBar) [unique: %HealthBar]
│         └─ HealthLabel (Label) [unique: %HealthLabel]
├─ MarginContainer (bottom-right)
│    └─ HBoxContainer
│         ├─ InventoryButton (Button) [unique: %InventoryButton]
│         │    text: "Zaino"
│         └─ AttackButton (Button) [unique: %AttackButton]
│              text: "⚔ Attacca"
├─ InventoryPanel (Panel) [unique: %InventoryPanel]
│    └─ VBoxContainer
│         ├─ Label "Inventario"
│         ├─ ScrollContainer
│         │    └─ InventoryList (VBoxContainer) [unique: %InventoryList]
│         └─ Button "Chiudi" (chiude pannello)
└─ DebugLabel (Label) [unique: %DebugLabel]
     modulate: yellow
     visible: false
```

### Procedura:

1. Crea `CanvasLayer` chiamato `GameUI`
2. Allega script `GameUI.gd`
3. Crea i nodi come sopra con i nomi `%` (Scene Unique Name):
   - Tasto destro sul nodo > "Access as Unique Name"
4. **MarginContainer (top-left)**:
   - `Layout > Anchors Preset`: Top Left
   - `Theme Overrides > Constants > Margin Left/Right/Top/Bottom`: 12
5. **HealthBar**:
   - `Min Value`: 0, `Max Value`: 100, `Value`: 100
   - `Custom Minimum Size`: (200, 20)
   - `Show Percentage`: OFF
6. **MarginContainer (bottom-right)**:
   - `Layout > Anchors Preset`: Bottom Right
   - `Theme Overrides > Constants`: margin 12
7. **InventoryButton**: `Text`: "Zaino", `Custom Min Size`: (100, 48)
8. **AttackButton**: `Text`: "Attacca", `Custom Min Size`: (100, 48)
9. **InventoryPanel**:
   - `Layout > Anchors Preset`: Center
   - `Custom Min Size`: (400, 500)
   - `Visible`: OFF (toggle via script)
   - Aggiungi stile pannello scuro semi-trasparente:
     - `Theme Overrides > Styles > Panel`: `StyleBoxFlat`
     - `Bg Color`: `(0.08, 0.08, 0.12, 0.95)`
     - `Border Width`: 2
     - `Border Color`: `(0.4, 0.35, 0.25, 1.0)` (bordo oro/rame)
10. **InventoryList**: contenitore per gli item generati dinamicamente
11. **DebugLabel**: `Visible`: OFF, `Modulate`: Yellow, posizionato in basso a sinistra

---

## Autoload (Project Settings > Autoload)

Configura questi Autoload (sono già nel `project.godot`):

| Nome | Percorso |
|------|----------|
| `InputController` | `res://scripts/input/InputController.gd` |
| `Inventory` | `res://scripts/inventory/Inventory.gd` |
| `PlayerData` | `res://scripts/progression/ClassData.gd` |

---

## Project Settings > Input Map

Aggiungi queste azioni (se non già configurate da `project.godot`):

| Azione | Tasti/Eventi |
|--------|-------------|
| `move_click` | Left Mouse Button |
| `toggle_inventory` | Key I |
| `attack` | Key Space, Right Mouse Button |
| `interact` | Key E |

---

## Physics Layers

Configura i layer in Project Settings > Layer Names > 2d Physics:

| Layer | Nome |
|-------|------|
| 1 | world |
| 2 | player |
| 3 | enemies |
| 4 | items |
| 5 | ui |

### Maschere di Collisione:

- **Player (layer 2)**: collide con world (1)
- **Enemy (layer 3)**: collide con world (1)
- **DroppedItem (layer 4)**: rileva solo player (2) — imposta `mask` a `2`
- **DetectionArea (in Enemy, layer 3)**: rileva solo player (2) — su `Area2D`, imposta `mask` a `2`

---

## Spawning Loot (da Enemy a Ground)

Quando un nemico muore, emette `drop_item(item_data)`. Il segnale arriva a World, che deve spawnare un `DroppedItem`. Aggiungi nel World.gd:

```gdscript
func _on_enemy_drop_item(item_data: ItemData) -> void:
    var dropped_item_scene := preload("res://scenes/items/DroppedItem.tscn")
    var dropped := dropped_item_scene.instantiate()
    dropped.set_item_data(item_data)
    dropped.global_position = (my_enemy_node_reference).global_position
    get_node("/root/Main/DroppedItems").add_child(dropped)
```

Oppure, più semplicemente, collega il segnale `drop_item` di ogni Enemy direttamente a una funzione in Main o in World.

### Metodo consigliato:

In `Enemy.gd`, alla riga dove emettiamo `drop_item.emit(item_data)`, possiamo anche spawnare direttamente il DroppedItem. Modifica la funzione `_spawn_loot()` per spawnare il nodo direttamente se la scena è disponibile.

---

## Placeholder Texture (creazione rapida)

Nell'editor Godot, puoi creare texture placeholder al volo:

1. Clicca su `Sprite2D` > `Texture` > `New ImageTexture`
2. Imposta larghezza/altezza
3. Clicca sul quadrato del colore e scegli il colore

Oppure usa il seguente GDScript in una Tool scene per generare placeholder:

```gdscript
# Crea un'immagine 32x48 e la salva
var img := Image.create(32, 48, false, Image.FORMAT_RGBA8)
img.fill(Color(0.1, 0.2, 0.35))
ResourceSaver.save(img, "res://assets/placeholders/placeholder_player.png")
```

---

## Verifica Rapida

Dopo l'assemblaggio, controlla:

- [ ] `Main.tscn` ha tutti i figli
- [ ] `Main` è impostata come scena principale (Project Settings > Run > Main Scene)
- [ ] I 3 Autoload sono registrati
- [ ] Input Map ha `move_click`, `toggle_inventory`, `attack`
- [ ] Player ha `CollisionShape2D`
- [ ] Enemy ha `DetectionArea` con `CollisionShape2D`
- [ ] GameUI ha i nomi univoci `%` corretti
- [ ] Camera2D è figlia di Player con `current = true`
- [ ] Physics layers configurati
