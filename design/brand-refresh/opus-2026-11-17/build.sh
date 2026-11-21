#!/bin/zsh
# Regenerate every file in this proposal. Local only: python3, rsvg-convert, Xcode's ictool.
# Writes only inside design/brand-refresh/opus-2026-11-17/.
set -euo pipefail
HERE=${0:A:h}
cd "$HERE"
python3 -I build.py

ICTOOL="$(dirname "$(xcode-select -p)")/Applications/Icon Composer.app/Contents/Executables/ictool"
mkdir -p exports
for look in Default Dark TintedLight TintedDark ClearLight ClearDark; do
  "$ICTOOL" icon/AppIcon.icon --export-image --output-file "exports/icon-$look.png" \
    --platform macOS --rendition "$look" --width 512 --height 512 --scale 1
done

render() { rsvg-convert "$@"; }
render -w 512 mark/mark.svg -o exports/mark-512.png
render -w 512 mark/mark-dark.svg -o exports/mark-dark-512.png
for state in on off; do
  for s in 18 36 54; do render -w $s -h $s "menubar/menubar-$state.svg" -o "exports/menubar-$state-$s.png"; done
done
render -w 1280 lockup/lockup-stacked.svg -o exports/lockup-stacked.png
render -w 1280 lockup/lockup-stacked-dark.svg -o exports/lockup-stacked-dark.png
render -w 760 lockup/lockup-horizontal.svg -o exports/lockup-horizontal.png
render -w 1600 banner/banner.svg -o exports/banner.png
python3 -I sheet.py
echo "Rendered into $HERE/exports"
