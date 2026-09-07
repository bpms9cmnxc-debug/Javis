#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/Javis.app"
STAGE="$ROOT/dist/dmg"
OUT="$ROOT/dist/Javis-1.0.0.dmg"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/Javis.app"
ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/Lies-mich.txt" <<'EOF'
Javis 1.0.0  —  macOS 15 / 26 / 27

1. Javis.app in den Ordner Programme ziehen.
2. Beim ersten Start: Bedienungshilfen + Mikrofon erlauben.
3. Wispr Flow und LM Studio installieren, ein Modell laden, Server starten.
4. Control + Option + Leertaste: sprechen.
   Wispr schreibt verborgen, LM Studio denkt verborgen,
   die Ausgabe-KI spricht die Antwort.

Hotkey und Stimme: Menüleiste → Javis → Einstellungen.
EOF
if command -v hdiutil >/dev/null 2>&1; then
  rm -f "$OUT"
  hdiutil create -volname Javis -srcfolder "$STAGE" -ov -format UDZO "$OUT"
  echo "DMG: $OUT"
else
  echo "hdiutil fehlt — Stage liegt in $STAGE"
fi
