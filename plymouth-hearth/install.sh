#!/bin/bash
# Install the Moonlit Hearth plymouth theme and rebuild the initramfs.
#   ./install.sh            install + activate
#   ./install.sh --revert   switch back to the stock Omarchy splash
# Run as your user; it asks for sudo itself.
set -euo pipefail
cd "$(dirname "$0")"

rebuild() {
  if command -v limine-mkinitcpio >/dev/null; then
    sudo limine-mkinitcpio
  else
    sudo mkinitcpio -P
  fi
}

if [[ ${1:-} == "--revert" ]]; then
  sudo plymouth-set-default-theme omarchy
  rebuild
  echo "Stock Omarchy boot splash restored."
  exit 0
fi

files=(hearth.plymouth hearth.script background.png badge.png halo.png window.png
       flake_far.png flake_mid.png flake_near.png title.png motto.png
       bullet.png entry.png progress_box.png progress_bar.png)
for f in "${files[@]}"; do [[ -f $f ]] || { echo "missing $f (run build-assets.sh)" >&2; exit 1; }; done

sudo install -d -m 755 /usr/share/plymouth/themes/hearth
sudo install -m 644 "${files[@]}" /usr/share/plymouth/themes/hearth/
sudo plymouth-set-default-theme hearth
rebuild
echo "Moonlit Hearth boot splash installed. Revert any time with: $0 --revert"
echo "If the splash ever misbehaves at boot, press Esc for the text password prompt."
