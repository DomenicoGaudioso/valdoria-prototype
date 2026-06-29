# Pipeline Città Reali OSM per Valdoria Prototype
## Da OpenStreetMap a Godot — Guida Completa

---

## PANORAMICA

Questo documento spiega come ottenere una città reale 3D partendo dai dati
OpenStreetMap (OSM) e importarla come mappa giocabile in Valdoria.

```
OpenStreetMap (.osm.pbf) → OSM2World → .glb → Godot import → RealCityRegistry
```

**Nessuno streaming, nessuna dipendenza esterna a runtime. Solo asset locali.**

---

## PREREQUISITI

| Tool | Download | Note |
|------|----------|------|
| Java 17+ | https://adoptium.net/ | Richiesto da OSM2World |
| OSM2World | https://osm2world.org/download/ | Conversione OSM → OBJ/GLB |
| Godot 4.7 | https://godotengine.org/ | Engine di gioco |
| Blender (opzionale) | https://blender.org/ | Ottimizzazione modelli |

---

## STEP 1: Ottenere i dati OSM

### Opzione A: BBBike Extract (consigliata per città singole)
1. Apri https://extract.bbbike.org/
2. Seleziona il formato **OSM PBF** (Protocolbuffer Binary Format)
3. Scegli l'area: puoi usare il nome città o disegnare un rettangolo sulla mappa
4. **Dimensioni consigliate:** 3km x 3km (circa 50-150 MB di .osm.pbf)
5. Inserisci la tua email e clicca "Extract"
6. Riceverai il link per scaricare il file `.osm.pbf`

### Opzione B: Geofabrik (per regioni o Italia intera)
1. Apri https://download.geofabrik.de/europe/italy.html
2. Scarica il `.osm.pbf` della regione desiderata
3. **Attenzione:** Italia intera = ~1.4 GB. Meglio usare BBBike per aree mirate.
4. Puoi tagliare un file grande con `osmium extract` o `osmconvert`

### File generato:
```
bologna.osm.pbf  (~50-80 MB per 3km x 3km)
```

---

## STEP 2: Convertire con OSM2World

### 2.1 Creare il file di configurazione
OSM2World usa file `.xml` per configurare l'export. Crea `bologna_config.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<config>
    <!-- Area da processare (opzionale, restringe il bounding box) -->
    <boundingBox>
        <min lat="44.488" lon="11.335"/>
        <max lat="44.500" lon="11.355"/>
    </boundingBox>

    <!-- Qualità mesh -->
    <buildingSimplification>MEDIUM</buildingSimplification>
    <roofDetail>MEDIUM</roofDetail>
    <wallDetail>MEDIUM</wallDetail>

    <!-- Cosa esportare -->
    <exportBuildings>true</exportBuildings>
    <exportRoads>true</exportRoads>
    <exportWater>true</exportWater>
    <exportLanduse>true</exportLanduse>
    <exportTrees>false</exportTrees>       <!-- Troppi poligoni -->

    <!-- Scala (1 unità = 1 metro) -->
    <scale>1.0</scale>
    <offsetX>0</offsetX>
    <offsetZ>0</offsetZ>
</config>
```

### 2.2 Eseguire OSM2World
Da terminale:
```bash
java -jar OSM2World.jar \
  --input bologna.osm.pbf \
  --config bologna_config.xml \
  --output bologna_full.glb
```

Oppure da interfaccia grafica:
1. Apri OSM2World GUI
2. File → Open → seleziona `bologna.osm.pbf`
3. Configura i parametri di esportazione
4. File → Export → GLB/GLTF
5. Salva come `bologna_full.glb`

### File generato:
```
bologna_full.glb  (~20-80 MB per 3km x 3km, dipende dalla densità urbana)
```

---

## STEP 3: Importare in Godot

### 3.1 Copiare il file
Copia `bologna_full.glb` in:
```
res://assets/real_world/bologna/bologna_full.glb
```

### 3.2 Import automatico
Godot 4.7 importa automaticamente i file `.glb`.
- Apri il tab **FileSystem**
- Naviga fino a `res://assets/real_world/bologna/`
- Fai doppio clic su `bologna_full.glb` per vedere l'anteprima
- Il file viene automaticamente convertito in una scena importata (`.glb.import`)

### 3.3 Verificare l'import
1. Clicca su `bologna_full.glb` nel FileSystem
2. Nel pannello **Import**, verifica:
   - **Import As:** Scene
   - **Meshes > Generate Shadow Meshes:** On
   - **Meshes > Lightmap UV Generation:** Off (non serve per Valdoria)
3. Clicca **Reimport** se necessario

### 3.4 Test rapido
1. Apri `res://scenes/real_world/BolognaFull.tscn`
2. Premi **F6** per testare la scena
3. Dovresti vedere la città con il placeholder (perché il GLB non è ancora stato collegato)
4. Ora il modello è pronto per essere ottimizzato

---

## STEP 4: Ottimizzare (RealCityOptimizer)

### 4.1 Esecuzione automatica
Quando carichi la scena, `RealCityOptimizer` applica automaticamente:
- Palette dark fantasy (desaturazione 40%)
- Rimozione mesh < 20cm
- Generazione collisioni semplificate (BoxShape3D)
- Disattivazione ombre su mesh piccole (< 1m)
- Rimozione luci/camere importate

### 4.2 Ottimizzazione manuale con Blender (opzionale ma consigliato)
Se il modello è troppo pesante (> 50 MB o > 500k triangoli):

```bash
# In Blender:
1. Importa bologna_full.glb
2. Seleziona tutti gli edifici
3. Object → Join (Ctrl+J) per unire mesh simili
4. Aggiungi modificatore Decimate:
   - Ratio: 0.3 (riduce del 70% i triangoli)
   - Applica
5. Esporta come bologna_full_opt.glb
```

### 4.3 Divisione in distretti (per città chunked)
Per città grandi come Milano, Roma, New York:

```bash
# In Blender o OSM2World:
1. Identifica 4 quadranti (es: NW, NE, SW, SE)
2. Seleziona edifici per quadrante
3. Esporta ogni quadrante separatamente:
   chunk_duomo.glb
   chunk_centrale.glb
   chunk_navigli.glb
   chunk_portanuova.glb
4. Registra i chunk in RealCityRegistry.gd
```

---

## STEP 5: Registrare in RealCityRegistry.gd

Aggiorna lo stato nel file `data/RealCityRegistry.gd`:

```gdscript
"bologna": {
    "id": "bologna",
    "status": CityStatus.READY,   # ← cambia da TODO a READY
    # ...
}
```

---

## STEP 6: Configurare spawn e nemici

Modifica la voce in `RealCityRegistry.gd`:

```gdscript
"enemy_spawns": [
    {"type": "skeleton", "pos_3d": Vector3(8, 1, -4)},
    {"type": "goblin", "pos_3d": Vector3(-5, 1, 6)},
    {"type": "mage", "pos_3d": Vector3(0, 1, -8)},
],
"portals_to_real": [
    # Portali verso altre città reali
    {"target": "milano", "pos_3d": Vector3(12, 1, -10), "label": "Milano"},
],
```

---

## CHECKLIST FINALE

### Per ogni città importata:

- [ ] File .osm.pbf scaricato da BBBike/Geofabrik
- [ ] Convertito con OSM2World → .glb
- [ ] .glb copiato in `res://assets/real_world/{città}/`
- [ ] OSM_ATTRIBUTION.txt presente nella cartella
- [ ] .glb importato correttamente in Godot (visibile nel FileSystem)
- [ ] Scena .tscn creata in `res://scenes/real_world/`
- [ ] Stato aggiornato in `RealCityRegistry.gd` a READY
- [ ] Test F6: la scena si carica senza errori
- [ ] Player spawn funzionante
- [ ] Portale di ritorno a Valdoria presente
- [ ] Camera isometrica corretta
- [ ] Stile dark fantasy applicato (RealCityOptimizer)
- [ ] FPS accettabile (>30 FPS su hardware target)
- [ ] Memoria < 500 MB per la scena

---

## PERFORMANCE TARGET

| Dimensione città | Triangoli | FPS target | Memoria |
|-----------------|-----------|------------|---------|
| Piccola (2x2 km) | < 200k | 60 | < 200 MB |
| Media (3x3 km) | < 500k | 45 | < 350 MB |
| Grande (5x5 km) | < 1M (chunked) | 30 | < 500 MB |

---

## LICENZA

Tutti i dati provengono da **OpenStreetMap**, licenza **ODbL 1.0**.
Attribuzione richiesta: "© OpenStreetMap contributors" + link a openstreetmap.org/copyright.

I modelli 3D derivati (usati come asset di gioco) sono considerati "Produced Works"
e non richiedono la condivisione del codice sorgente del gioco.
Non è necessario rilasciare gli asset .glb sotto ODbL.

Vedi `OSM_ATTRIBUTION.txt` in ogni cartella città per i dettagli completi.

---

## TODO NOTI

- Le collisioni generate sono BoxShape3D semplificate. Per gameplay preciso, servono
  collider manuali su edifici chiave e superfici calpestabili.
- I nemici sono placeholder 3D. Per integrazione completa col sistema 2D esistente,
  collegare gli script Enemy.gd ai nodi CharacterBody3D.
- La divisione in chunk richiede test empirici sulla dimensione ottimale.
- Il portale di ritorno a Valdoria usa `change_scene_to_file`. Verificare che
  lo stato del player (HP, oro, inventario) sia preservato tramite SaveManager.
