# LEGAL STYLE GUIDE — Linee Guida Legali e di Stile

## Principio Fondamentale

Questo progetto è **ispirato** agli Action RPG isometrici classici dei primi anni 2000,
ma è un'opera **completamente originale**.

**Non è un clone, un port, una mod o una derivazione di Sacred o di qualsiasi altro gioco commerciale.**

## Cosa NON Usare

### Nomi Protetti

- Sacred™, Sacred Underworld™, Sacred 2™, Sacred 3™, Sacred Citadel™
- Ancaria
- Ascaron Entertainment
- Qualsiasi nome ufficiale della serie Sacred

### Personaggi / Classi Ufficiali

- Seraphim
- Gladiator
- Vampiress
- Battle-Mage
- Dark Elf
- Wood Elf
- Dwarf
- Daemon
- Dryad
- Inquisitor
- Temple Guardian
- High Elf
- Shadow Warrior
- Dragon Mage

### Asset Protetti

- Sprite, texture, icone, modelli da Sacred
- Mappe, tile, layout dei livelli di Sacred
- Musiche, effetti sonori, voci di Sacred
- Qualsiasi file estratto dal gioco originale
- Qualsiasi mod o derivazione di Sacred
- Screenshot di Sacred usati come asset

### Lore e Contenuti

- Storia, dialoghi, quest di Sacred
- Nomi di luoghi (Ancaria, Bellevue, Porto Vallum, etc.)
- Nomi di PNG ufficiali
- Testi, descrizioni, manuali di Sacred

## Cosa Usare (e Come)

### Asset

Solo asset con licenza libera compatibile:

| Licenza | Uso consentito | Note |
|---------|---------------|------|
| **CC0** (Creative Commons Zero) | Uso illimitato, commerciale incluso | Preferita, nessuna attribuzione obbligatoria |
| **CC-BY** (Attribution) | Uso consentito, richiede attribuzione | Registrare autore e link |
| **CC-BY-SA** (ShareAlike) | Uso consentito, richiede attribuzione e stessa licenza | Compatibile con GPL |
| **GPL 2.0/3.0** | Uso consentito, richiede stesso licensing | Codice e asset |
| **OGA-BY** (OpenGameArt Attribution) | Uso consentito, richiede attribuzione | Standard OpenGameArt |
| **MIT** | Uso illimitato | Codice |
| **Asset creati dal team** | Uso proprio illimitato | Originali |

### Attribuzione

Per ogni asset terzo, **sempre** conservare:
- Nome dell'autore
- Fonte (URL)
- Licenza
- Data di acquisizione

Registrare tutto in `docs/ASSETS.md`.

### Contenuti Non Protetti

I seguenti elementi **generici** del genere fantasy sono utilizzabili:
- Guerrieri, maghi, arcieri, ladri, chierici (archetipi generici)
- Scheletri, goblin, orchi, draghi, non-morti (creature fantasy generiche)
- Spade, archi, bastoni, scudi, armature (equipaggiamento generico)
- Pozioni, pergamene, rune (oggetti magici generici)
- Foreste, dungeon, caverne, rovine, villaggi (ambientazioni generiche)
- Visuale isometrica, movimento point-and-click (meccaniche generiche)

**Attenzione**: questi elementi devono essere implementati in modo originale.
Non copiare design, nomi o aspetto specifico da giochi protetti.

## Archetipi "Equivalenti Spirituali"

Creiamo classi con identità propria, che evocano archetipi fantasy universali,
senza copiare classi specifiche di Sacred.

| Archetipo Fantasy | Nostra Classe | NON è |
|-------------------|---------------|-------|
| Guerriero dell'arena | **Campione delle Arene** | Gladiator |
| Assassino oscuro | **Lama d'Ombra** | Dark Elf |
| Arciere della natura | **Custode dei Boschi** | Wood Elf |
| Mago guerriero | **Arcanista da Battaglia** | Battle-Mage |
| Vampiro gotico | **Erede Cremisi** | Vampiress |
| Guerriero sacro alato | **Ascendente Alata** | Seraphim |

## Mondo Originale

Il mondo del gioco è **Valdoria** (nome provvisorio, modificabile).

Nomi di luoghi originali (non copiati da Sacred):
- Sentiero delle Rovine (area tutorial)
- Villaggio di Pietragrigia
- Foresta di Brumafosca
- Cripta dei Senza Nome
- Passo del Corvo
- Miniere di Ferrovecchio
- Paludi di Lunasangue

## Sistema di Progressione

Il sistema "Frammenti di Maestria" è ispirato al concetto di rune/abilità
comune a molti ARPG, ma con nome, implementazione e bilanciamento originali.

## Fallimento Software House

**Il fallimento di Ascaron Entertainment NON rende automaticamente liberi gli asset di Sacred.**
I diritti potrebbero essere stati trasferiti ad altre entità (es. Deep Silver, THQ Nordic).
In ogni caso, anche se fossero orfani, gli asset non sarebbero automaticamente di pubblico dominio.

Usare asset estratti da Sacred, in qualsiasi circostanza, costituirebbe violazione del copyright,
indipendentemente dallo stato dell'azienda originale.

## Riferimenti e Ispirazione

Citare Sacred come ispirazione è lecito (fair use concettuale), ma:
- Non usare il nome Sacred nel titolo del gioco
- Non usare il logo di Sacred
- Non implicare affiliazione o endorsement
- Essere chiari che si tratta di un progetto originale ispirato al genere

## Checklist di Conformità

Prima di ogni release, verificare:
- [ ] Nessun nome ufficiale Sacred nel codice, asset, documentazione pubblica
- [ ] Nessun asset estratto da giochi commerciali
- [ ] Tutti gli asset terzi hanno attribuzione in ASSETS.md
- [ ] Le classi hanno nomi originali
- [ ] Il mondo ha nomi originali
- [ ] La UI non è una copia riconoscibile
- [ ] I placeholder non assomigliano a personaggi protetti
- [ ] Le descrizioni pubbliche menzionano "ispirato al genere ARPG classico", non "clone di Sacred"
