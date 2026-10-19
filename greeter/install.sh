#!/bin/bash
# Install the Moonlit Hearth SDDM login screen (needs sudo; run in a real terminal).
#   ./install.sh           install/update and make it the active greeter
#   ./install.sh --revert  back to your previous greeter
# Preview without installing:
#   sddm-greeter-qt6 --test-mode --theme "$(dirname "$0")"
set -euo pipefail
SRC=$(cd "$(dirname "$0")" && pwd)
DEST=/usr/share/sddm/themes/moonlit-hearth
CONF=/etc/sddm.conf.d/zz-moonlit-hearth.conf

if [[ ${1:-} == --revert ]]; then
  sudo rm -f "$CONF"
  sudo rm -rf "$DEST"
  echo "Reverted: SDDM uses its previous theme again."
  exit 0
fi

sudo mkdir -p "$DEST/assets"
sudo install -m644 "$SRC"/Main.qml "$SRC"/metadata.desktop "$SRC"/theme.conf "$DEST/"
sudo install -m644 "$SRC"/assets/* "$DEST/assets/"
sudo mkdir -p "$(dirname "$CONF")"
printf '[Theme]\nCurrent=moonlit-hearth\n' | sudo tee "$CONF" >/dev/null
echo "Installed. The next logout shows the Moonlit Hearth login screen."
echo "Change the wallpaper with Scene= in $DEST/theme.conf; undo with: $0 --revert"
