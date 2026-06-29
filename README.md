# Eldrath

Action RPG isometrico dark fantasy in Godot 4.7, nato come prototipo Sacred-like e ora orientato a una build Android distribuibile su Amazon Appstore.

## Stato

- Main scene: `scenes/main/Main.tscn`.
- Core runtime: `scripts/systems/GameBootstrap.gd`.
- 37 mappe classiche/dungeon/snowplains con portali.
- Citta locali 3D e citta OSM integrate nel registro mappe.
- 20 tipi nemici in tier progressivi.
- 6 classi giocabili e lore con eroi, Arconti, stagioni e Bastione di Velar.
- Equipaggiamento a 8 slot: arma, armatura, elmo, stivali, anello, amuleto, cintura, reliquia.
- Rarita: common, uncommon, rare, epic, legendary, mythic, archontic, infinite.
- Loot con ranghi E-SSS/National/Monarch, set, oggetti corrotti e potere Ascensione.
- Progressione infinita con livelli oltre 100, ascension level, ascension points e portal depth.
- Salvataggi account/local profile in `user://account_saves/<account_id>.json`.
- Controlli Android con joystick virtuale e pulsanti touch.

## Avvio

```powershell
$godot = "C:\Users\Domenico\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe"
Start-Process -FilePath $godot -ArgumentList "--editor","--path","C:\Users\Domenico\Desktop\Sacred"
```

## Android / Amazon Appstore

Preset: `Android` in `export_presets.cfg`.

- Package: `com.eldrath.game`.
- Output Amazon: `build/amazon/Eldrath.apk`.
- Min SDK: 24.
- Target SDK: 35.
- Architettura: arm64-v8a.

Guida: `docs/ANDROID_EXPORT.md`.

## Salvataggi

Il profilo default e `local_player`. Si puo avviare/testare un profilo separato con:

```powershell
& $godot --path "C:\Users\Domenico\Desktop\Sacred" -- --account=nome_utente
```

Il sistema protegge il livello massimo gia salvato: un profilo avanzato non viene sovrascritto da uno stato di livello piu basso.

## Controlli

| Input | Azione |
|---|---|
| Click sinistro / tap | Movimento |
| Spazio / click destro | Attacco |
| I | Inventario |
| E | Interazione |
| Varchi | Cambio mappa |

## Crediti

- Tileset e mappe: FLARE Team, CC-BY-SA 3.0.
- Sprite eroe: Clint Bellanger, CC-BY 3.0.
- Sprite nemici: FLARE art source, CC-BY-SA 3.0.
- Engine: Godot Engine, MIT.

*"Chi attraversa il buio deve diventare piu affilato del buio."*
