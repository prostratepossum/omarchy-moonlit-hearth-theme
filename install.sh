#!/bin/bash
# Moonlit Hearth for Omarchy.
#
#   ./install.sh                 theme + cursors + live wallpaper, lock screen, intro, click effects
#   ./install.sh --all           ...plus terminal rice and login chime
#   ./install.sh --dotfiles      also install starship, fastfetch, lazygit, eza/fzf colors
#   ./install.sh --sound         also play the Moonlit Hearth chime at login
#   ./install.sh --no-plugins    no shell plugins (theme + cursors only)
#   ./install.sh --no-cursors    keep your current mouse cursor
#   ./install.sh --uninstall     restore the stock Omarchy plugins and remove extras
#
# Boot splash and login screen are separate (both need sudo):
#   ~/.config/omarchy/themes/moonlit-hearth/plymouth-hearth/install.sh
#   ./greeter/install.sh
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
THEME_DIR="$HOME/.config/omarchy/themes/moonlit-hearth"
PLUGINS_DIR="$HOME/.config/omarchy/plugins"
STAMP=$(date +%s)
PLUGINS=(io.github.prostratepossum.moonlit-hearth-background io.github.prostratepossum.moonlit-hearth-lock io.github.prostratepossum.moonlit-hearth-intro io.github.prostratepossum.moonlit-hearth-clicks)
CURSOR_DIR="$HOME/.local/share/icons/MoonlitHearth"
LOOKNFEEL="$HOME/.config/hypr/looknfeel.lua"

plugins=1 cursors=1 dotfiles=0 sound=0 uninstall=0
for arg in "$@"; do
  case "$arg" in
  --all) dotfiles=1 sound=1 ;;
  --dotfiles) dotfiles=1 ;;
  --sound) sound=1 ;;
  --no-plugins) plugins=0 ;;
  --no-cursors) cursors=0 ;;
  --uninstall) uninstall=1 ;;
  -h | --help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) echo "unknown option: $arg" >&2; exit 1 ;;
  esac
done

command -v omarchy >/dev/null || { echo "This needs Omarchy (https://omarchy.org)." >&2; exit 1; }

# Copy a file into place, keeping a timestamped backup of anything it replaces.
place() {
  local from="$1" to="$2"
  mkdir -p "$(dirname "$to")"
  if [[ -e $to ]] && ! cmp -s "$from" "$to"; then
    cp -a "$to" "$to.bak.$STAMP"
    echo "  backed up $to -> $to.bak.$STAMP"
  fi
  cp "$from" "$to"
}

if (( uninstall )); then
  for id in "${PLUGINS[@]}"; do omarchy plugin remove "$id" --yes 2>/dev/null || true; done
  omarchy plugin enable omarchy.background >/dev/null 2>&1 || true
  omarchy plugin enable omarchy.lock >/dev/null 2>&1 || true
  systemctl --user disable --now moonlit-hearth-login-sound.service 2>/dev/null || true
  rm -f "$HOME/.config/systemd/user/moonlit-hearth-login-sound.service"
  sed -i '/# >>> moonlit-hearth >>>/,/# <<< moonlit-hearth <<</d' "$HOME/.bashrc" 2>/dev/null || true
  if grep -q -- '-- >>> moonlit-hearth cursor >>>' "$LOOKNFEEL" 2>/dev/null; then
    sed -i '/-- >>> moonlit-hearth cursor >>>/,/-- <<< moonlit-hearth cursor <<</d' "$LOOKNFEEL"
    gsettings reset org.gnome.desktop.interface cursor-theme 2>/dev/null || true
    hyprctl setcursor Adwaita "${XCURSOR_SIZE:-24}" >/dev/null 2>&1 || true
  fi
  rm -rf "$CURSOR_DIR"
  echo "Removed the Moonlit Hearth plugins, cursors, login chime and shell colors."
  echo "Pick another theme with: omarchy theme set <name>"
  echo "Dotfiles you replaced are next to their originals as *.bak.<timestamp>."
  exit 0
fi

echo "❄ Installing the Moonlit Hearth theme"
mkdir -p "$THEME_DIR"
# Skip the copy when run from a clone made by `omarchy theme install`.
[[ $SRC -ef $THEME_DIR ]] || cp -a "$SRC"/{colors.toml,btop.theme,icons.theme,hyprland.lua,chromium.theme,preview.png,unlock.png,backgrounds,plymouth,plymouth-hearth,sounds} "$THEME_DIR/"
omarchy theme set moonlit-hearth
# theme set may pick a random wallpaper; start on the cabin under the moon.
omarchy theme bg set "$THEME_DIR/backgrounds/0-moonlithearth-hearth.jpg" >/dev/null 2>&1 || true

if (( plugins )); then
  echo "❄ Installing the Moonlit Hearth shell plugins (live wallpaper, lock screen, intro, click effects)"
  mkdir -p "$PLUGINS_DIR"
  for id in "${PLUGINS[@]}"; do
    if [[ -d $PLUGINS_DIR/$id ]]; then
      mv "$PLUGINS_DIR/$id" "$PLUGINS_DIR/.$id.bak.$STAMP"
      echo "  backed up existing $id -> .$id.bak.$STAMP"
    fi
    cp -a "$SRC/plugins/$id" "$PLUGINS_DIR/$id"
  done
  # Enabling the background and lock forks switches off the stock ones
  # (they declare clonedFrom), and removing them brings the stock ones back.
  for id in "${PLUGINS[@]}"; do omarchy plugin enable "$id" >/dev/null; done
  omarchy-restart-shell >/dev/null 2>&1 || true

  # The Starwatch intro and click plugins answer to the same IPC names.
  for other in io.github.prostratepossum.starwatch-intro io.github.prostratepossum.starwatch-clicks; do
    if [[ -d $PLUGINS_DIR/$other ]]; then
      echo "  $other is also installed; disable one of them (omarchy plugin disable $other)"
    fi
  done

  # The click effects read mouse buttons through evdev.
  if ! /usr/bin/python3 -c 'import evdev' 2>/dev/null; then
    echo "  click effects need python-evdev:  sudo pacman -S python-evdev"
  fi
  if ! id -nG | grep -qw input; then
    echo "  click effects need the input group:  sudo usermod -aG input \$USER  (then log out and back in)"
  fi
fi

if (( cursors )); then
  echo "❄ Installing the Moonlit Hearth cursors"
  rm -rf "$CURSOR_DIR"
  mkdir -p "$(dirname "$CURSOR_DIR")"
  cp -a "$SRC/cursors/MoonlitHearth" "$CURSOR_DIR"
  if [[ -f $LOOKNFEEL ]] && ! grep -q -- '-- >>> moonlit-hearth cursor >>>' "$LOOKNFEEL"; then
    cp -a "$LOOKNFEEL" "$LOOKNFEEL.bak.$STAMP"
    printf '\n-- >>> moonlit-hearth cursor >>>\nhl.env("XCURSOR_THEME", "MoonlitHearth")\n-- <<< moonlit-hearth cursor <<<\n' >> "$LOOKNFEEL"
    echo "  set XCURSOR_THEME in $LOOKNFEEL (backup: $LOOKNFEEL.bak.$STAMP)"
  fi
  gsettings set org.gnome.desktop.interface cursor-theme MoonlitHearth 2>/dev/null || true
  hyprctl setcursor MoonlitHearth "${XCURSOR_SIZE:-24}" >/dev/null 2>&1 || true
fi

if (( dotfiles )); then
  echo "❄ Installing the terminal rice"
  place "$SRC/extras/starship.toml" "$HOME/.config/starship.toml"
  place "$SRC/extras/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
  place "$SRC/extras/fastfetch/moonlit-hearth.txt" "$HOME/.config/fastfetch/moonlit-hearth.txt"
  place "$SRC/extras/lazygit/config.yml" "$HOME/.config/lazygit/config.yml"
  if ! grep -q '# >>> moonlit-hearth >>>' "$HOME/.bashrc" 2>/dev/null; then
    { echo; echo '# >>> moonlit-hearth >>>'; cat "$SRC/extras/bash/moonlit-hearth.sh"; echo '# <<< moonlit-hearth <<<'; } >> "$HOME/.bashrc"
    echo "  added eza/fzf colors to ~/.bashrc"
  fi
  btop_conf="$HOME/.config/btop/btop.conf"
  [[ -f $btop_conf ]] && sed -i 's/^theme_background = .*/theme_background = false/' "$btop_conf"
fi

if (( sound )); then
  echo "❄ Enabling the login chime"
  place "$SRC/extras/systemd/moonlit-hearth-login-sound.service" "$HOME/.config/systemd/user/moonlit-hearth-login-sound.service"
  systemctl --user daemon-reload
  systemctl --user enable moonlit-hearth-login-sound.service
fi

cat <<DONE

❄ Done. Try:
  omarchy-shell -q intro play                  replay the login intro
  omarchy-shell lock previewInteractive        preview the lock screen (closes after 90s)
  omarchy-shell -q background toggleAnimation  pause/resume the live wallpaper
  omarchy-shell -q clicks toggle               turn the click effects on/off

Optional (sudo; each has --revert):
  $THEME_DIR/plymouth-hearth/install.sh      animated boot splash (rebuilds initramfs)
  $SRC/greeter/install.sh                    SDDM login screen
DONE
