#!/bin/bash
#
# Regenerates every Ectaro Print icon from the three SVGs in this directory.
# Run by hand when the art changes; the outputs are committed, so building the installer
# needs neither rsvg-convert nor ImageMagick.
#
#   branding/tray.svg         A: navy tile, white e. System tray (and warning/danger, with a dot)
#   branding/app.svg          B: A plus the filled printer badge. Installer, shortcut, Programs
#                             list, About box, Linux/macOS app icon
#   branding/ectaro-mark.svg  the bare e; becomes the black macOS tray template (qz-mask*)
#
# The e is TWO paths in every file. Never merge them into one `d`: the arm is a separate
# shape and merging punches a hole through it.
#
# Needs: rsvg-convert, ImageMagick (`magick`), and `iconutil` (macOS) for the .icns.
# Pixel sizes mirror upstream QZ Tray's, including its odd 21/25/41px mask files.

set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
RES="$ROOT/src/qz/ui/resources"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

NAVY="#152637"
render() { rsvg-convert -w "$2" -h "$2" -f png -o "$3" "$1"; }

# --- tray: default, warning, danger ------------------------------------------------------
# Upstream recolours the whole printer for a state. Ours keeps the brand tile and adds a
# white-ringed dot bottom-right (amber = warning, red = danger).
with_dot() { # <colour> <out.svg>
  sed "s|</svg>|<circle cx=\"47\" cy=\"47\" r=\"16\" fill=\"#ffffff\"/><circle cx=\"47\" cy=\"47\" r=\"12.5\" fill=\"$1\"/></svg>|" "$HERE/tray.svg" > "$2"
}
cp "$HERE/tray.svg" "$WORK/default.svg"
with_dot "#f5a300" "$WORK/warning.svg"
with_dot "#d62828" "$WORK/danger.svg"
for state in default warning danger; do
  render "$WORK/$state.svg" 16 "$RES/qz-$state.png"
  for size in 20 24 32 40 48; do
    render "$WORK/$state.svg" "$size" "$RES/qz-$state-$size.png"
  done
done

# --- macOS tray template: black e on transparent -----------------------------------------
sed "s|fill=\"$NAVY\"|fill=\"#000000\"|" "$HERE/ectaro-mark.svg" > "$WORK/mask.svg"
for pair in "mask:16" "mask-20:21" "mask-24:25" "mask-32:32" "mask-40:41" "mask-48:48"; do
  render "$WORK/mask.svg" "${pair#*:}" "$RES/qz-${pair%%:*}.png"
done

# --- About box ---------------------------------------------------------------------------
render "$HERE/app.svg" 260 "$RES/qz-logo.png"
# 320x130 banner: B on the left, the name beside it
{
  echo '<svg xmlns="http://www.w3.org/2000/svg" width="320" height="130" viewBox="0 0 320 130">'
  sed -e 's#^<svg #<svg x="10" y="10" width="110" height="110" #' "$HERE/app.svg"
  echo "<text x=\"130\" y=\"72\" font-family=\"Helvetica Neue, Helvetica, Arial, sans-serif\" font-weight=\"700\" font-size=\"27\" fill=\"$NAVY\">Ectaro Print</text>"
  echo '</svg>'
} > "$WORK/banner.svg"
rsvg-convert -w 320 -h 130 -f png -o "$RES/qz-banner.png" "$WORK/banner.svg"

# --- Windows: installer, shortcut, Programs list, uninstaller, debug console -------------
SIZES=(16 20 24 32 40 48 64 256)
color=(); grey=()
for s in "${SIZES[@]}"; do
  render "$HERE/app.svg" "$s" "$WORK/win-$s.png"
  magick "$WORK/win-$s.png" -colorspace gray "$WORK/grey-$s.png"
  color+=("$WORK/win-$s.png"); grey+=("$WORK/grey-$s.png")
done
magick "${color[@]}" "$ROOT/assets/branding/windows-icon.ico"
magick "${color[@]}" "$ROOT/ant/windows/nsis/console.ico"
magick "${grey[@]}" "$ROOT/ant/windows/nsis/uninstall.ico"

# --- Linux and macOS app icon ------------------------------------------------------------
cp "$HERE/app.svg" "$ROOT/assets/branding/linux-icon.svg"
cp "$HERE/app.svg" "$ROOT/assets/branding/apple-icon.svg"
if command -v iconutil > /dev/null; then
  set_dir="$WORK/apple-icon.iconset"; mkdir -p "$set_dir"
  for size in 16 32 128 256 512; do
    render "$HERE/app.svg" "$size" "$set_dir/icon_${size}x${size}.png"
    render "$HERE/app.svg" "$((size * 2))" "$set_dir/icon_${size}x${size}@2x.png"
  done
  iconutil -c icns "$set_dir" -o "$ROOT/assets/branding/apple-icon.icns"
fi

echo "Icons regenerated."
