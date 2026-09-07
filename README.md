# Javis

Lokaler Sprachassistent für **macOS 15 / 26 / 27**.

Wispr bleibt das **Eingabe-Werkzeug**, LM Studio das **Gehirn**, eine zweite KI die **Stimme**. Beide Partner-Apps bleiben verborgen. Du redest — Javis antwortet.

```
Mikrofon → Wispr (verborgen) → LM Studio (verborgen) → Ausgabe-KI spricht
```

Repository: [github.com/bpms9cmnxc-debug/Javis](https://github.com/bpms9cmnxc-debug/Javis)

## Was Javis tut

1. Sitzt in der Menüleiste, ohne Dock-Icon (`LSUIElement`).
2. Hotkey **Control + Option + Leertaste** startet eine Äußerung.
3. Ein unsichtbares Textfeld nimmt den Fokus. Wispr diktiert dorthin — nicht in ein sichtbares Chatfenster.
4. Javis schickt den Text an den OpenAI-kompatiblen Server von LM Studio (`http://127.0.0.1:1234/v1`).
5. Sätze werden gestreamt und von der Ausgabe-KI gesprochen: Apple-Stimme lokal oder eine OpenAI-kompatible TTS (Kokoro, ElevenLabs-Proxy, xAI, …).
6. Ein Timer hält Wispr Flow und LM Studio versteckt, solange sie laufen.

## Voraussetzungen

- macOS 15 oder neuer (entwickelt gegen Golden Gate / macOS 27)
- [Wispr Flow](https://wisprflow.ai)
- [LM Studio](https://lmstudio.ai) mit geladenem Chat-Modell und laufendem Server
- Optional: lokale TTS unter `http://127.0.0.1:8880/v1` (z. B. Kokoro-FastAPI)

Beim ersten Start:

- Bedienungshilfen erlauben (Hotkey + Verstecken fremder Fenster)
- Mikrofon erlauben

## Installation

DMG aus den GitHub Releases ziehen (Actions baut auf `macos-15` ein UDZO-Image), **Javis.app** nach Programme bewegen, öffnen.

Selbst bauen:

```bash
make dmg
```

`make` kompiliert mit `swiftc`, packt `Javis.app` und erzeugt `dist/Javis-1.0.0.dmg` über `hdiutil`. Ohne fertiges Binary kompiliert der App-Launcher beim ersten Start einmal selbst.

## Hotkeys & Stimme

| Aktion | Standard |
|---|---|
| Sprechen | ⌃⌥ Space |
| Wispr auslösen | Fn Space (Wispr-Standard) |
| Stopp / neue Unterhaltung | per Sprache: „stopp“, „neue Unterhaltung“ |

Ausgabe:

- **Apple Stimme** — nichts verlässt den Mac
- **TTS-KI** — OpenAI-kompatibles `/audio/speech` an eine konfigurierbare Base-URL

## Datenschutz

Javis lädt selbst kein Audio hoch. Wispr folgt seinem eigenen Pfad. LM Studio bleibt lokal. Die Ausgabe-KI ist wählbar (lokal oder remote).

## Status v1.0.0

Menüleiste, verborgenes Capture-Feld, Wispr-Trigger, LM-Studio-Streaming, Satz-TTS, Auto-Hide, Auto-Start `lms server start`, deutscher/englischer UI-String, Fallback auf Apple Speech wenn Wispr fehlt.

Nächste Ideen: [FEATURES.md](FEATURES.md)
