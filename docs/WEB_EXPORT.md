# WEB EXPORT — Guida Configurazione

## Prerequisiti

1. **Godot Engine 4.x** (stabile)
2. **Export templates** installati:
   - Editor > Manage Export Templates > Download & Install
3. **Python 3** (per server locale di test)
4. **Browser moderno**: Chrome, Edge, o Firefox

## Progetto — Requisiti per Web

- **Renderer**: Compatibility (più sicuro per Web, evita problemi GPU mobile)
- **Thread**: Preferire single-threaded export per compatibilità
- **Niente C#**: GDScript only
- **Texture**: Mantenere sotto 2048x2048, evitare texture atlas enormi
- **Audio**: Formati compatibili (OGG Vorbis, MP3)
- **Nessun plugin nativo**: Solo GDScript puro

## Configurazione Preset Web

### Editor > Export > Add... > Web

1. **Name**: Web (HTML5)
2. **Export Path**: `build/web/index.html`

### Impostazioni chiave:

```
[html]
Head Include:
  <style>
    body { margin: 0; background: #000; }
    canvas { display: block; margin: 0 auto; }
  </style>

[progressive_web_app]
Enabled: false (per ora; attivabile in futuro per installazione PWA)

[variant]
extensions: GDScript only (no C#)
```

### Opzioni importanti:

- **Vram Texture Compression**: For Mobile/Desktop (S3TC + ETC2)
- **Threaded Export**: Prefer Off (single-threaded, più compatibile)
- **Ensure Singleton**: On
- **Expand Resources**: On

## Build e Test

### 1. Esportare

```
Editor > Export > Web > Export Project
```

Genera:
- `build/web/index.html`
- `build/web/index.js`
- `build/web/index.wasm`
- `build/web/index.pck`
- `build/web/index.service.worker.js` (se PWA)

### 2. Avviare server locale

**IMPORTANTE**: NON aprire index.html direttamente. Serve un server HTTP.

```powershell
# PowerShell (Windows)
python -m http.server 8000

# Oppure con Node.js
npx http-server build/web -p 8000
```

### 3. Testare

Aprire nel browser:
```
http://localhost:8000
```

### 4. Debug

Se schermata nera:
- Apri Console browser (F12)
- Controlla errori JavaScript
- Verifica che il file .pck sia caricato
- Controlla SharedArrayBuffer (se threaded)
- Prova in modalità incognito (cache pulita)

## Hosting

### Opzioni gratuite:

1. **itch.io**
   - Upload ZIP contenente tutti i file di build/web/
   - Impostare "This file will be played in the browser"
   - Viewport: impostare larghezza/altezza fissa o responsive
   - Supporta fullscreen

2. **GitHub Pages**
   - Pushare build/web/ su branch `gh-pages` o cartella `/docs`
   - Abilitare GitHub Pages nelle impostazioni repo
   - URL: `https://username.github.io/repo/`

3. **Netlify / Cloudflare Pages**
   - Collegare repo GitHub
   - Build command: (nessuno, upload manuale)
   - Publish directory: `build/web`

### Note hosting:

- Tutti i file devono essere nella stessa directory
- Il server deve servire i file WASM con MIME type corretto
- HTTPS potrebbe essere richiesto per SharedArrayBuffer
- Configurare CORS se necessario

## Ottimizzazioni

- Compressione asset: Editor > Export > Resources > Compress Binary
- Ridurre texture (non serve 4K per un ARPG isometrico)
- Rimuovere risorse non usate: Editor > Project > Tools > Orphan Resource Explorer
- Test su diverse risoluzioni finestra

## Limitazioni note

- Nessun accesso file system nativo (per salvataggi usare FileAccess o user://)
- Nessun threading per GDScript puro (singolo thread)
- Performance inferiori a nativo (ma accettabili per 2D)
- Input tastiera catturato dalla pagina (gestire focus)
- Audio potrebbe richiedere interazione utente prima di partire (policy browser)
