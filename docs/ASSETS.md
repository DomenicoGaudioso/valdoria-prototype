# ASSETS — Fonti e Licenze

## Linee Guida

Tutti gli asset devono essere:
- CC0, CC-BY, CC-BY-SA (compatibile), GPL o OGA-BY
- Attribuiti correttamente con autore, fonte, link e licenza
- Mai estratti da Sacred o altri giochi commerciali
- Originali o da fonti open source verificate

## Fonti Raccomandate

### Tileset Isometrici
| Fonte | Descrizione | Licenza |
|-------|-------------|---------|
| FLARE (Free Libre Action Roleplaying Engine) | Tileset isometrico completo, erba, sentieri, dungeon | CC-BY-SA 3.0 / GPL 3.0 |
| OpenGameArt.org | Tileset fantasy medievali, rovine, foreste | Varie (CC0, CC-BY, CC-BY-SA) |
| Kenney.nl | Tileset generici, alcuni isometrici | CC0 |
| Liberated Pixel Cup (LPC) | Tileset fantasy ampio, stile coerente | CC-BY-SA 3.0 / GPL 3.0 |

### Personaggi / Sprite Sheet
| Fonte | Descrizione | Licenza |
|-------|-------------|---------|
| FLARE | Sprite sheet 8 direzioni per varie classi fantasy | CC-BY-SA 3.0 |
| OpenGameArt.org | Sprite fantasy medievali, guerrieri, scheletri | Varie |
| LPC | Sprite sheet completi, 8 direzioni, animazioni | CC-BY-SA 3.0 / GPL 3.0 |

### Icone e UI
| Fonte | Descrizione | Licenza |
|-------|-------------|---------|
| OpenGameArt.org | Icone fantasy per pozioni, armi, rune, pergamene | Varie |
| Kenney.nl | UI pack, icone generiche | CC0 |
| FLARE | Icone inventario, equipaggiamento | CC-BY-SA 3.0 |

### Audio e Musica
| Fonte | Descrizione | Licenza |
|-------|-------------|---------|
| OpenGameArt.org | Musica fantasy, suoni ambientali | Varie |
| Freesound.org | Effetti sonori (passi, combattimento, etc.) | CC0 / CC-BY |
| Kenney.nl | Audio pack | CC0 |

## Placeholder Attuali

### Player
- Rettangolo colorato 32x48 (blu scuro)
- Cerchio ombra sotto i piedi
- Da sostituire con sprite sheet 8 direzioni (FLARE/LPC guerriero)

### Enemy (Scheletro errante)
- Rettangolo colorato 32x48 (bianco/grigio)
- Cerchio ombra sotto i piedi
- Da sostituire con sprite sheet scheletro 8 direzioni

### Terreno
- Rettangolo verde per erba
- Rettangolo marrone per sentiero
- Cerchi grigi per rocce
- Da sostituire con TileMap isometrico da FLARE/LPC

### UI
- Rettangoli scuri semitrasparenti
- Testo bianco su sfondo
- Da sostituire con texture pergamena/pietra fantasy

## Procedura Sostituzione

1. Scaricare asset dalla fonte scelta
2. Verificare la licenza
3. Posizionare nella cartella `assets/` appropriata
4. Registrare in questo file con attribuzione completa
5. Aggiornare sprite/texture nelle scene Godot
6. Testare che funzioni in Web + Android

## Registro Asset (da compilare)

| # | Nome | Autore | Fonte | Licenza | Link | Data |
|---|------|--------|-------|---------|------|------|
| 1 | placeholder_player | Team | Interno | CC0 | - | - |
| 2 | placeholder_enemy | Team | Interno | CC0 | - | - |
| ... | ... | ... | ... | ... | ... | ... |
