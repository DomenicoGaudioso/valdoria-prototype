# PLATFORM NOTES — Note Multipiattaforma

## 1. Web (HTML5/WebAssembly) vs Android (APK/AAB)

| Aspetto | Web | Android |
|---------|-----|---------|
| **Input primario** | Mouse + tastiera | Touch |
| **Input movimento** | Click sinistro su mappa | Tap su mappa |
| **Input UI** | Clic + tasti (I, Esc) | Pulsanti touch |
| **Risoluzione** | Variabile (finestra browser) | Fissa (schermo device) |
| **Performance** | Dipende dal browser | Nativa, generalmente migliore |
| **Salvataggi** | LocalStorage / IndexedDB | File interno (user://) |
| **Distribuzione** | URL / hosting statico | APK/AAB |
| **Aggiornamenti** | Istantanei (ricarica pagina) | Nuova installazione |
| **Audio** | Richiede interazione utente | Parte subito |
| **File system** | Limitato (virtual FS) | Completo (user://) |

## 2. Mouse/Tastiera vs Touch

### Desktop (Mouse + Tastiera)
- **Movimento**: Click sinistro → comando move
- **Attacco**: Click destro o tasto (vicino al nemico)
- **Inventario**: Tasto I
- **Interazione**: Click su oggetti/NPC (futuro)

### Mobile (Touch)
- **Movimento**: Tap breve su terreno
- **Attacco**: Tap su nemico (o pulsante dedicato)
- **Inventario**: Pulsante UI touch
- **Interazione**: Tap su oggetti (futuro)

### Input System Unificato

Tutti gli input convergono in `InputController`, che emette comandi astratti:
- `move_command(world_position: Vector2)`
- `attack_command(target: Node2D)`
- `toggle_inventory()`
- `interact_command(target: Node2D)`

Il resto del gioco non sa se l'input viene da mouse o touch.

## 3. UI Responsive

### Strategia
- Usare `Control` nodes con anchor per layout fluido
- Barra vita: `MarginContainer` ancorato in alto a sinistra
- Pulsanti: ancorati in basso a destra (mobile) o sostituiti da tasti (desktop)
- Finestra inventario: centrata, dimensioni percentuali
- Testo: font scalabile, dimensione relativa alla risoluzione

### Breakpoint
- **Desktop** (larghezza > 1024px): UI compatta, pulsanti piccoli
- **Tablet** (768-1024px): UI media
- **Phone** (< 768px): UI grande, pulsanti 64x64 minimo

### Godot Implementation
```
Control (root UI)
  ├─ MarginContainer (barra vita) [top-left, margins]
  ├─ MarginContainer (pulsanti) [bottom-right]
  └─ Panel (inventario) [center, popup]
```

## 4. Performance

### Limiti Iniziali
- **Nemici attivi**: massimo 20-30 a schermo
- **DroppedItem**: massimo 50 a terra
- **TileMap**: griglia massimo 200x200 tile
- **Texture**: massimo 1024x1024 per mobile, 2048x2048 per desktop
- **FPS target**: 30 su mobile, 60 su desktop

### Ottimizzazioni Future
- Object pooling per nemici e item
- Chunk-loading per mappe grandi
- LOD (Level of Detail) per distanza
- Culling fuori schermo
- Texture atlas per ridurre draw calls

## 5. Limiti Iniziali (MVP)

- **Nessuna mappa open world enorme**: area di test piccola (~50x50 tile)
- **Nessun multiplayer**: gioco single-player locale
- **Nessun cloud rendering**: tutto locale su dispositivo
- **Nessun server backend**: nessun login, nessun salvataggio cloud
- **Nessun networking**: nessuna comunicazione di rete
- **Nessun IAP o monetizzazione**: prototipo gratuito
- **Nessuna transizione di scena complessa**: una sola scena Main

## 6. Nessun Multiplayer

Questo prototipo NON implementa:
- Multiplayer online
- Co-op locale
- PvP
- Leaderboard
- Cloud save

Per una futura versione multiplayer, occorrerebbe:
- Riscrivere con architettura server-authoritative
- Usare `MultiplayerSpawner` e `MultiplayerSynchronizer` di Godot 4
- Implementare server dedicato (non browser-based)
- Questo è fuori scope per l'MVP attuale

## 7. Nessun Cloud Rendering

Il gioco gira interamente sul dispositivo dell'utente:
- **Web**: nel browser (WebAssembly + WebGL)
- **Android**: nativo (Godot runtime)

NON usa:
- Stadia-like streaming
- Cloud gaming
- Render farm
- GPU server

Questo mantiene il progetto semplice, gratuito e indipendente da servizi esterni.

## 8. Nessun Open World Enorme (Per Ora)

L'MVP ha un'area di test piccola.
Il caricamento di aree future sarà gestito con:
- `ResourceLoader.load_interactive()` per caricamento in background
- Scene chunking (dividere mappa in quadranti)
- Trigger di cambio area (portali, bordi mappa)

NON implementare streaming open world finché:
- Il core gameplay non è solido
- L'export Web non è stabile
- Non ci sono asset sufficienti
