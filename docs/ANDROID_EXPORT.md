# ANDROID EXPORT — Guida Configurazione

## Prerequisiti

### 1. Java Development Kit (JDK)

Godot 4 richiede **OpenJDK 17**.

```powershell
# Verifica versione Java
java -version

# Se non installato, scaricare da:
# https://adoptium.net/download/
# Scegliere: OpenJDK 17, Windows x64, .msi installer
```

### 2. Android SDK

**Opzione A — Android Studio (consigliato)**:
1. Scaricare Android Studio da https://developer.android.com/studio
2. Installare con componenti di default
3. Aprire Android Studio > SDK Manager
4. Installare:
   - Android SDK Platform 33 o superiore
   - Android SDK Build-Tools
   - Android SDK Platform-Tools
   - NDK (se richiesto da Godot)

**Opzione B — Solo SDK (senza Android Studio)**:
1. Scaricare commandline-tools da https://developer.android.com/studio#command-line-tools
2. Estrarre in `C:\Android\cmdline-tools\`
3. Installare piattaforme tramite `sdkmanager`

### 3. Godot Export Templates

```
Editor > Manage Export Templates > Download & Install
```

Scaricare anche i template Android.

## Configurazione Godot

### Editor > Editor Settings

1. **Export > Android**:
   - **Android SDK Path**: `C:\Users\TUO_UTENTE\AppData\Local\Android\Sdk`
   - **Debug Keystore**: Godot ne crea uno di default per debug, oppure:
     ```
     keytool -genkey -v -keystore debug.keystore -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000
     ```

2. Verificare che Godot riconosca l'SDK:
   - I percorsi dovrebbero autocompletarsi
   - Se vuoti, impostare manualmente

### Installare Android Build Template

```
Editor > Manage Export Templates > Android > Install Build Template
```

Questo crea la cartella `android/` nel progetto con build.gradle, manifest, icone etc.

## Configurazione Preset Android

### Editor > Export > Add... > Android

1. **Name**: Android
2. **Export Path**: `build/android/build.apk`

### Impostazioni:

```
[package]
unique_name: org.librearpg.prototype
name: Valdoria Prototype
icon: res://assets/icons/icon.png

[version]
code: 1
name: "0.1.0"

[screen]
orientation: landscape
support_large: true
support_xlarge: true

[permissions]
ACCESS_NETWORK_STATE: false
ACCESS_WIFI_STATE: false
INTERNET: false (per ora offline)

[graphics]
opengl_debug: false

[architecture]
arm64: true
arm32: false
x86_64: false

[user_data_backup]
allow: false

[keystore]
release: (da configurare per release)
```

### Orientamento consigliato

```
[capabilities]
screen/landscape: on
screen/portrait: off

[screen]
orientation: landscape
```

## Build

### Build Debug (APK per test)

```
Editor > Export > Android > Export Project
```

Output: `build/android/build.apk`

Questo APK è firmato con keystore debug e può essere installato su dispositivo Android con "Install from unknown sources" abilitato.

### Build Release (AAB per Play Store, futuro)

```
[keystore]
release: user
release/user: percorso/keystore.jks
release/password: ****

Editor > Export > Android > Export Project (selezionando AAB)
```

## Test su Dispositivo

### Trasferimento APK

**Opzione A — USB + adb**:
```powershell
adb install build/android/build.apk
```

**Opzione B — Google Drive / Email**:
- Caricare APK su Drive
- Scaricare su telefono
- Aprire e installare (abilitare "Origini sconosciute")

**Opzione C — Copia diretta**:
- Collegare telefono via USB (File Transfer mode)
- Copiare APK nella cartella Download
- Aprire file manager sul telefono e installare

### Checklist Test

- [ ] App si apre senza crash
- [ ] Tap sullo schermo = movimento player
- [ ] Pulsanti UI touch grandi e raggiungibili
- [ ] Barra vita visibile
- [ ] Inventario apribile/chiudibile
- [ ] Performance fluida (almeno 30 FPS)
- [ ] Audio funzionante (se implementato)
- [ ] Orientamento corretto (landscape fisso)
- [ ] Nessun consumo batteria anomalo

## Note Specifiche Android

### Touch Input

- Usare `InputEventScreenTouch` e `InputEventScreenDrag`
- Per tap-to-move: rilevare pressione breve, non drag
- Distinguere tap su UI da tap su mondo di gioco
- Implementare pulsanti UI grandi (minimo 48x48 dp, consigliato 64x64)

### UI Scaling

- Usare Container (MarginContainer, HBoxContainer) per layout flessibili
- Impostare `expand` e `stretch_ratio` appropriati
- Testare su diverse risoluzioni (720p, 1080p, tablet)
- Usare `theme` con font scalabili

### Performance Mobile

- Limitare numero di nemici attivi a schermo
- Evitare shader complessi
- Ridurre draw calls (batch sprite vicini)
- Disabilitare VSync se causa input lag
- Mantenere texture sotto 1024x1024 per mobile

### Permessi

- **NON** richiedere INTERNET se non serve
- **NON** richiedere permessi non necessari
- L'app deve funzionare offline

## Troubleshooting

| Problema | Soluzione |
|----------|-----------|
| "SDK not found" | Verificare percorso SDK in Editor Settings |
| Build fallisce | Aggiornare Android Build Template |
| App crash all'avvio | Controllare logcat: `adb logcat` |
| Schermata nera | Renderer Compatibility consigliato |
| APK non installa | Firmato con keystore debug, abilitare origini sconosciute |
| Touch non risponde | Controllare Input Map e gestione eventi touch |
