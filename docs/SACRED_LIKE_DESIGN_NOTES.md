# SACRED-LIKE DESIGN NOTES — Note di Design "Evocativo"

## Obiettivo

Questo documento descrive gli elementi di game design che devono **evocare**
il feeling di Sacred e degli ARPG isometrici classici, **senza copiarli direttamente**.

## Elementi da Evocare

### 1. Visuale Isometrica

- Camera fissa con angolazione ~45° (tipica isometrica 2D o 2.5D)
- Terreno a griglia romboidale o simulata
- Personaggi e oggetti ordinati per Y (painter's algorithm) per profondità corretta
- Ombre a terra per ancorare i personaggi al terreno
- Sprite pre-rendered style (da sostituire con asset liberi simili)

### 2. Movimento Point-and-Click

- Click sinistro su terreno → personaggio cammina verso quel punto
- Pathfinding semplice (diretto o A* base)
- Il personaggio si ferma vicino al target (non sul pixel esatto)
- Click su nemico → attacco
- Sensazione di controllo diretto, fluido, reattivo

### 3. Mondo Fantasy Semi-Aperto

- Aree esplorabili senza caricamenti (nella stessa zona)
- Confini naturali (fiumi, montagne, muri)
- Transizioni tra zone (portali, bordi mappa, passaggi)
- Sensazione di continuità geografica
- Diversi biomi: praterie, foreste, paludi, montagne, deserti (futuri)
- Giorno/notte opzionale futuro

### 4. Classi Molto Caratterizzate

- Ogni classe ha un'identità visiva e meccanica distinta
- Stile di gioco diverso per ogni classe
- Armature e armi con aspetto unico per classe
- Abilità esclusive che definiscono il gameplay
- Progressione differenziata
- Scelta della classe significativa e con impatto duraturo

### 5. Rune/Frammenti per Abilità

- Le abilità non si sbloccano solo con il livello
- I nemici droppano "Frammenti di Maestria" (rune equivalenti)
- I frammenti sbloccano o potenziano abilità specifiche
- Sistema di scambio/combinazione (futuro)
- Sensazione di scoperta e caccia al frammento
- Ogni classe ha il proprio set di frammenti/abilità

### 6. Loot Abbondante

- I nemici droppano frequentemente oggetti
- Varietà di rarità: comune, non comune, raro, epico, leggendario
- Oggetti con statistiche randomizzate (affissi)
- Sensazione di ricompensa costante
- Inventario che si riempie e va gestito
- Equipaggiamento visibile sul personaggio (futuro)

### 7. Equipaggiamento

- Armi, armature, anelli, amuleti, cinture, stivali, guanti, elmi
- Ogni slot ha impatto sulle statistiche
- Set item con bonus (futuro)
- Oggetti unici con nomi evocativi
- Confronto oggetti nell'inventario
- Sensazione di progressione tramite equipaggiamento migliore

### 8. Villaggi e Dungeon

- Villaggi come hub sicuri con PNG
- Quest giver, mercanti, fabbri, alchimisti (futuro)
- Dungeon: cripte, caverne, rovine, fortezze
- Boss di fine dungeon con loot garantito
- Sensazione di esplorazione e scoperta
- Mappe interne ed esterne

### 9. Humour Leggero (Futuro)

- Dialoghi con tono non sempre serissimo
- Nomi di oggetti o nemici buffi occasionali
- Easter egg
- Non rompe l'atmosfera dark fantasy, la alleggerisce in punti mirati

### 10. Quest Secondarie (Futuro)

- Quest da PNG nei villaggi
- Ricompense: oro, oggetti, esperienza
- Varietà: uccidi X, raccogli Y, esplora Z, consegna W
- Catene di quest
- Scelte con conseguenze leggere

### 11. Cavalcature (Futuro)

- Cavalli, creature fantasy come cavalcature
- Aumento velocità movimento
- Attacco da cavalcatura
- Animazioni dedicate
- Chiamata/smonta

### 12. Nemici Fantasy Classici

- Scheletri, zombie, fantasmi (non-morti)
- Goblin, orchi, troll (umanoidi)
- Lupi, orsi, ragni giganti (bestie)
- Draghi, golem, elementali (boss)
- Banditi, cultisti, stregoni (umani nemici)
- Varietà di comportamenti e abilità nemiche

## Cosa NON Copiare

| Elemento | Sacred | Nostra Alternativa |
|----------|--------|-------------------|
| Nome gioco | Sacred | Valdoria Prototype (provvisorio) |
| Mondo | Ancaria | Valdoria |
| Guerriero gladiatore | Gladiator | Campione delle Arene |
| Assassino elfo oscuro | Dark Elf | Lama d'Ombra |
| Arciere elfo silvano | Wood Elf | Custode dei Boschi |
| Mago guerriero | Battle-Mage | Arcanista da Battaglia |
| Vampiro | Vampiress | Erede Cremisi |
| Angelo guerriero | Seraphim | Ascendente Alata |
| Sistema rune | Rune di Sacred | Frammenti di Maestria |
| Mappa tutorial | Bellevue | Sentiero delle Rovine |
| Villaggio principale | Porto Vallum | Villaggio di Pietragrigia |
| UI specifica | Pannelli Sacred | UI fantasy personalizzata |
| Logo | Logo Sacred | Logo originale (futuro) |
| Musiche | OST Sacred | Musiche libere/commissionate |
| Sprite | Sprite Sacred | Sprite FLARE/LPC/Kenney o custom |
| Icone | Icone Sacred | Icone libere o custom |

## Feeling Target

Il giocatore dovrebbe sentire:

1. **Libertà di esplorazione** — posso andare dove voglio nella zona
2. **Potenza crescente** — il mio personaggio diventa più forte visibilmente
3. **Ricompensa costante** — ogni nemico può droppare qualcosa di utile
4. **Identità di classe** — la mia classe definisce come gioco
5. **Scoperta** — trovo cose interessanti esplorando
6. **Nostalgia** — mi ricorda i vecchi ARPG, ma è fresco e nuovo
7. **Dark fantasy** — il mondo è pericoloso e cupo, ma non deprimente
8. **Accessibilità** — controlli semplici, curva di apprendimento dolce
9. **Profondità opzionale** — posso ignorare sistemi complessi e divertirmi comunque
10. **Community** — essendo open source, posso contribuire e modificare

## Riferimenti di Genere (Ispirazione, NON Copia)

- Sacred / Sacred Underworld (Ascaron, 2004-2005)
- Diablo II (Blizzard, 2000)
- Titan Quest (Iron Lore, 2006)
- Divine Divinity (Larian, 2002)
- Baldur's Gate: Dark Alliance (Snowblind, 2001)
- Dungeon Siege (Gas Powered Games, 2002)
- FLARE (Free Libre Action Roleplaying Engine, open source)

Questi giochi definiscono il genere. Ci ispiriamo al loro design,
ma implementiamo tutto in modo originale.
