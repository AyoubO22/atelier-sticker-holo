#!/bin/bash
# Compile « Atelier sticker holo », l'installe dans ~/Applications et régénère la version web.
set -euo pipefail
cd "$(dirname "$0")"

NAME="Atelier sticker holo"
APP="build/$NAME.app"
ARCH="$(uname -m)"
FONTS_URL='https://fonts.googleapis.com/css2?family=Bagel+Fat+One&family=Bricolage+Grotesque:opsz,wght@12..96,400..700&family=Bungee&family=Caveat:wght@700&family=Chewy&family=Creepster&family=Fredoka:wght@600;700&family=JetBrains+Mono:wght@500;700&family=Knewave&family=Luckiest+Guy&family=Pacifico&family=Press+Start+2P&family=Rammetto+One&family=Rye&family=Shrikhand&family=Titan+One&display=swap'
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15'

rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/AppIcon.iconset build/fonts

echo "• Icône"
xcrun swiftc -O -swift-version 5 Sources/Icon.swift -o build/make-icon
./build/make-icon build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

echo "• Polices embarquées (pour travailler hors ligne)"
if curl -fsSL -A "$UA" "$FONTS_URL" -o build/fonts/remote.css; then
  grep -o 'https://fonts.gstatic.com/[^)]*' build/fonts/remote.css | sort -u | while read -r url; do
    curl -fsSL "$url" -o "$APP/Contents/Resources/$(basename "$url")" || echo "  police manquante : $url"
  done
  sed -E 's#https://fonts.gstatic.com/[^)]*/([^/)]+)#\1#g' build/fonts/remote.css > "$APP/Contents/Resources/fonts.css"
else
  echo "  pas de réseau : les polices seront chargées en ligne au lancement"
  printf '@import url("%s");\n' "$FONTS_URL" > "$APP/Contents/Resources/fonts.css"
fi

echo "• Version web (web/index.html)"
mkdir -p web
WEB_FONTS="<link rel=\"preconnect\" href=\"https://fonts.googleapis.com\"><link rel=\"preconnect\" href=\"https://fonts.gstatic.com\" crossorigin><link rel=\"stylesheet\" href=\"$FONTS_URL\">" \
  perl -pe 's#<link rel="stylesheet" href="fonts.css">#$ENV{WEB_FONTS}#' Resources/atelier.html > web/index.html

echo "• App ($ARCH)"
cp Resources/atelier.html "$APP/Contents/Resources/atelier.html"
cp Info.plist "$APP/Contents/Info.plist"
xcrun swiftc -O -swift-version 5 -target "$ARCH-apple-macos12.0" Sources/main.swift -o "$APP/Contents/MacOS/AtelierSticker"
codesign --force --deep --sign - "$APP"

echo "• Installation"
mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/$NAME.app"
cp -R "$APP" "$HOME/Applications/"
echo "OK : $HOME/Applications/$NAME.app"
