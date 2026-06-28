# FLARE ASSETS — Documentazione Import

## Fonte

**Repository**: https://github.com/flareteam/flare-game  
**Release**: v1.15  
**Download**: https://github.com/flareteam/flare-game/releases/tag/v1.15

## Licenza

**CC-BY-SA 3.0 Unported** (Creative Commons Attribution-ShareAlike 3.0)

Diritti:
- Uso commerciale: SÌ
- Modifiche: SÌ
- Distribuzione: SÌ
- Obbligo di attribuzione: SÌ
- Obbligo ShareAlike (stessa licenza): SÌ

File di licenza: `assets/flare/LICENSE.txt`

## Autori (da CREDITS.txt)

**Art Lead / Programming**: Clint Bellanger  
**Art / Tilesets / Sprites**: Clint Bellanger, Justin Jacobs, Stefan Beller, Henrik Andersson,  
                                Bart Kelsey, Igor Paliychuk, Makrohn, Blarumyrran, Pennomi,  
                                Matthew Krohn, Peter Laux, and many contributors.

Vedi `assets/flare/CREDITS.txt` per l'elenco completo.

## Asset Importati nel Progetto

### Cartelle

```
res://assets/flare/
├── tilesets/                  # Tilesheets per Godot TileMap
│   ├── grassland.png          # 3072x3072, 16x8 tile, terreno prato/sentiero
│   ├── grassland_2x2.png      # Tile combinati (x2 velocità editing)
│   ├── grassland_structures.png # Edifici, rovine, muri
│   ├── grassland_trees.png    # Alberi, cespugli
│   └── grassland_water.png    # Acqua, fiumi, laghi
├── characters/
│   ├── knight.png             # NPC cavaliere (1013x492, 8 dir × 4 frame)
│   └── skeleton.png           # Nemico scheletro (3886x2154, 8 dir × animazioni)
├── animations/                # File di definizione animazioni (.txt)
├── LICENSE.txt                # CC-BY-SA 3.0
└── CREDITS.txt                # Attribuzioni complete
```

### Dettaglio Tilesheets

| File | Dim. (KB) | Dimensione | Griglia | Uso |
|------|-----------|------------|---------|-----|
| `grassland.png` | 2741 | 3072×3072 | 16×8 tile | Terreno base (erba, sentiero, terra) |
| `grassland_water.png` | 1481 | 3072×768 | 16×4 tile | Acqua, fiumi |
| `grassland_structures.png` | 1895 | 3072×1536 | 16×2 tile | Edifici, rovine |
| `grassland_trees.png` | 2802 | 3072×1536 | 8×2 tile | Alberi, cespugli, rocce |
| `grassland_2x2.png` | 156 | 1536×1536 | 4×8 tile | Tile combinati 2×2 |

### Dettaglio Personaggi

| File | Dim. (KB) | Dimensione | Frame | Direzioni | Uso |
|------|-----------|------------|-------|-----------|-----|
| `knight.png` | 540 | 1013×492 | 4 stance | 8 dir | Player placeholder |
| `skeleton.png` | 7827 | 3886×2154 | animazioni varie | 8 dir | Enemy |

## Specifiche Tecniche Tile FLARE

- **Orientamento**: Isometrico (diamond)
- **Tile map**: 192×96 pixel (base diamante)
- **Tile sprite**: 192×384 pixel (full bounding box)
- **Origine rendering**: bottom-center del diamante
- **Render order**: right-down

## Note Legali

### Obblighi
1. **Attribuzione**: Tutti i credit devono essere inclusi (vedi CREDITS.txt)
2. **ShareAlike**: Opere derivate devono usare la stessa licenza CC-BY-SA 3.0
3. **Notifica modifiche**: Se modifichi gli asset, devi indicarlo
4. **Link alla licenza**: Includere link al testo completo della licenza

### Cosa NON fare
- Non rimuovere le attribuzioni
- Non cambiare la licenza in una più restrittiva
- Non usare questi asset in progetti che violano i diritti di terzi
- Non spacciare gli asset FLARE come propri

### Nota su Sacred
FLARE è un progetto originale. **NON** è un clone di Sacred.  
Nessun asset FLARE proviene da Sacred, Diablo o altri giochi commerciali.

## Riferimenti

- Repository FLARE: https://github.com/flareteam/flare-game
- Sito FLARE: https://flarerpg.org/
- Licenza CC-BY-SA 3.0: https://creativecommons.org/licenses/by-sa/3.0/
- OpenGameArt (autori aggiuntivi): https://opengameart.org/

---

## Hero Player Character (Isometric Hero)

**Fonte**: https://opengameart.org/content/isometric-hero-and-heroine  
**Autore**: Clint Bellanger (creatore di FLARE)  
**Licenza**: CC-BY 3.0  
**File**: res://assets/flare/characters/hero/hero_full.png (4096x1024, 651 KB)

**Sprite Sheet Layout**:
- 32 colonne (frame di animazione) x 8 righe (direzioni)
- Ogni frame: 128x128 pixel
- Righe: 0=S, 1=SW, 2=W, 3=NW, 4=N, 5=NE, 6=E, 7=SE

**Frame Ranges** (colonne):
- 0-3:   Idle/Stance (4 frame)
- 4-11:  Run (8 frame)
- 12-15: Melee Attack (4 frame)
- 16-17: Block (2 frame)
- 18-23: Hit/Die (6 frame)
- 24-27: Cast Spell (4 frame)
- 28-31: Shoot Bow (4 frame)

**Layers combinati**: steel_armor.png + male_head1.png + longsword.png  
**Nome in gioco**: "Campione delle Arene"
