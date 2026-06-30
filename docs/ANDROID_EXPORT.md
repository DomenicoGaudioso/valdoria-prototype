# Android / Amazon Appstore Export

App: **Eldrath**
Package: `com.eldrath.game`
Output Amazon: `build/amazon/Eldrath.apk`

## Stato

- Preset Android configurato in `export_presets.cfg`.
- Formato export: APK release firmato.
- Min SDK: 24.
- Target SDK: 35.
- Architettura: `arm64-v8a`.
- Orientamento: landscape.
- Keystore release locale: `secrets/eldrath-release.jks`.
- Credenziali keystore locale: `secrets/android_release_keystore_credentials.txt`.

La cartella `secrets/` e ignorata da git. Non pubblicare il keystore e non perderlo: serve per aggiornare l'app in futuro.

## Toolchain installata

- Godot 4.7.
- JDK 17.
- Android SDK in `C:\Android\Sdk`.
- Platform tools: `C:\Android\Sdk\platform-tools\adb.exe`.
- Build tools: `C:\Android\Sdk\build-tools\35.0.0\apksigner.bat` e `zipalign.exe`.
- Export templates Godot in `%APPDATA%\Godot\export_templates\4.7.stable`.

## Build Amazon Appstore

```powershell
$godot = "C:\Users\Domenico\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe"
& $godot --headless --path "C:\Users\Domenico\Desktop\Sacred" --export-release "Android" "build/amazon/Eldrath.apk"
```

Se il preset non contiene le password, inserirle temporaneamente da `secrets/android_release_keystore_credentials.txt`, esportare, poi rimuoverle.

## QA locale mobile

Smoke headless dei controlli mobile:

```powershell
$env:ELDRATH_FORCE_MOBILE_CONTROLS = "1"
& $godot --headless --path "C:\Users\Domenico\Desktop\Sacred" --script tools/smoke_mobile_controls.gd
Remove-Item Env:\ELDRATH_FORCE_MOBILE_CONTROLS
```

APK debug non pubblicabile, utile per installazione locale:

```powershell
& $godot --headless --path "C:\Users\Domenico\Desktop\Sacred" --export-debug "Android" "build/qa/Eldrath-debug.apk"
& "C:\Android\Sdk\build-tools\35.0.0\apksigner.bat" verify --verbose --print-certs "build/qa/Eldrath-debug.apk"
& "C:\Android\Sdk\build-tools\35.0.0\zipalign.exe" -c -p 4 "build/qa/Eldrath-debug.apk"
```

Installazione su device/emulatore, solo se `adb devices -l` mostra almeno un dispositivo:

```powershell
& "C:\Android\Sdk\platform-tools\adb.exe" devices -l
& "C:\Android\Sdk\platform-tools\adb.exe" install -r "build/qa/Eldrath-debug.apk"
```

## Upload Amazon

Nella Amazon Developer Console:

1. Creare una nuova app Android.
2. Inserire nome app `Eldrath`.
3. Caricare `build/amazon/Eldrath.apk` nella sezione binari/app files.
4. Compilare descrizione, immagini, classificazione eta, privacy e territori.
5. Testare su dispositivo Fire/Android prima di inviare a review.

Amazon Appstore supporta app Android caricate come APK o AAB; per questo progetto usiamo APK release firmato.

## Checklist

- App avvia senza crash.
- Joystick mobile muove il player.
- Attacco, inventario e viaggio funzionano.
- Salvataggio automatico conserva livello, oro, equip e inventario.
- Chiudere e riaprire l'app non resetta il profilo.
- Prestazioni almeno 30 FPS su dispositivo medio.
- Nessun permesso inutile richiesto.

## Salvataggi account

Il sistema attuale usa profili locali:

- Default: `local_player`.
- Override da riga comando: `--account=nome_utente`.
- Override da ambiente: `ARCONTI_ACCOUNT_ID`.
- File: `user://account_saves/<account_id>.json`.

Per salvataggi cloud su Amazon servira integrare un backend o servizi dedicati. L'APK attuale funziona offline e conserva i progressi localmente.
