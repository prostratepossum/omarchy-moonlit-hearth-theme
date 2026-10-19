# Moonlit Hearth

A winter-night theme for [Omarchy](https://omarchy.org): a frosted tree, a full moon and a small cabin with one lit window. Snow falls on the desktop, and the lock screen, login intro, login screen, boot splash, mouse cursor and click effects all match.

![Desktop](previews/desktop.jpg)

| Live wallpaper | Login intro | Lock screen |
|---|---|---|
| ![Live wallpaper](previews/live-wallpaper.gif) | ![Intro](previews/intro.gif) | ![Lock screen](previews/lock.gif) |

**Cursors** and **click effects** (a snowflake drifts down on left and right click, a faint frost ring on middle):

![Cursors](cursors/preview.png)

![Click effect](previews/clicks.gif)

**Boot splash** (LUKS password prompt) and **login screen** (SDDM):

![Boot splash](previews/boot-splash.jpg)

![Login screen](previews/login.jpg)

**Wallpapers**: Hearth, Snowfall, Frost Moon, Porch. All four are animated.

![Wallpapers](previews/wallpapers.jpg)

## What's inside

| Piece | What it does |
|---|---|
| **Theme** (`colors.toml`, `backgrounds/`, `btop.theme`, `icons.theme`, `hyprland.lua`) | Deep navy background, moonlight-blue accent, snow-white text, and hearth amber for the warm colors. Window borders run from moonlight to amber. Includes 4 wallpapers. |
| **Live wallpaper** (`plugins/…-background`) | A GPU shader over each wallpaper. Snow falls in three layers, the moon's halo breathes, a faint mist drifts across the sky, the cabin windows flicker like firelight, chimney smoke curls away, and frost glints on the snow. Runs at 30 fps and pauses when a window is fullscreen. |
| **Lock screen** (`plugins/…-lock`) | The live scene with a slow zoom, the moon-and-cabin badge in a turning ring, a short line ("come in from the cold"), a serif clock, and a password pill with a soft firelight glow. Snow drifts down the screen, and each keystroke drops a few snowflakes off the field. Wrong passwords shake red. |
| **Login intro** (`plugins/…-intro`) | A ~5 s overlay once per boot. The scene fades in, snow gathers into the badge, "Moonlit Hearth" appears, then an iris opens onto your desktop. It's click-through, so it never blocks you. |
| **Cursors** (`cursors/`) | A Moonlit Hearth XCursor theme: snow-white arrows with a navy outline and a small snowflake that twinkles at the tip. The link hand has a crescent moon, and the wait cursor is a lantern with a flickering flame. 14 shapes plus aliases; anything not drawn falls back to Adwaita. Rebuild with `cursors/build.py`. |
| **Click effects** (`plugins/…-clicks`) | A snowflake turns as it drifts down from wherever you click (left drifts left, right drifts right). Middle click leaves a faint frost ring. Click-through, and skipped over fullscreen windows. Needs `python-evdev` and the `input` group (see below). |
| **Boot splash** (`plymouth-hearth/`) | Animated Plymouth theme: snow falling over the scene, the badge in a breathing halo with its window glowing, and a frosted password pill with snowflake bullets. Optional, and needs sudo. |
| **Login screen** (`greeter/`) | The lock screen brought to SDDM, with the live scene, snow and the warm-lit password field. Optional, and needs sudo. |
| **Login chime** (`sounds/`) | A soft synthesized winter chime played at login: wind, a few glassy bells, and a low wooden tone. Optional. |
| **Keyboard lighting** (`extras/keyboard/`) | Per-key RGB from night navy down to snow white, with a slow snowfall twinkle and a snow-white flash on every keypress. Razer BlackWidow V4 Low Profile TKL via OpenRGB; adaptable to other boards. Optional, manual setup. |
| **Terminal rice** (`extras/`) | Starship prompt, fastfetch badge logo, lazygit, eza and fzf colors, and a transparent btop. Optional. |

## Install

Requires an up-to-date Omarchy (the Quickshell-based `omarchy-shell`).

```bash
git clone https://github.com/prostratepossum/omarchy-moonlit-hearth-theme.git
cd omarchy-moonlit-hearth-theme
./install.sh            # theme + cursors + live wallpaper, lock screen, intro, click effects
./install.sh --all      # ...plus terminal rice and login chime
```

Other options: `--dotfiles`, `--sound`, `--no-plugins`, `--no-cursors`. Any file the installer replaces is backed up next to the original as `*.bak.<timestamp>`.

**Just the colors and wallpapers?** Use `omarchy theme install https://github.com/prostratepossum/omarchy-moonlit-hearth-theme.git`.

**Coming from Alpine Marmot?** Its intro and click plugins answer to the same `omarchy-shell` commands, so keep only one set enabled. The installer tells you if it finds them.

**Click effects setup:** the plugin reads mouse buttons through evdev, so it needs:

```bash
sudo pacman -S python-evdev
sudo usermod -aG input $USER   # then log out and back in
```

The helper only opens mouse-type devices and only reads button presses, never keyboards or movement. Note that the `input` group lets any program you run read input devices, so skip the click effects if that trade-off isn't for you (`omarchy plugin remove io.github.prostratepossum.moonlit-hearth-clicks`).

**Boot splash (optional):**

```bash
~/.config/omarchy/themes/moonlit-hearth/plymouth-hearth/install.sh           # install
~/.config/omarchy/themes/moonlit-hearth/plymouth-hearth/install.sh --revert  # back to stock
```

This rebuilds your initramfs. If the splash ever misbehaves, press **Esc** at boot for the plain text password prompt, then run `--revert`.

**Login screen (optional):**

```bash
./greeter/install.sh            # install and make it the active SDDM theme
./greeter/install.sh --revert   # back to your previous login screen
sddm-greeter-qt6 --test-mode --theme ./greeter   # preview without installing
```

Pick which wallpaper it shows with `Scene=` in `/usr/share/sddm/themes/moonlit-hearth/theme.conf`.

The boot splash and login screen were checked with mockups and SDDM's test mode.

## Try it out

```bash
omarchy-shell -q intro play                  # replay the login intro
omarchy-shell lock previewInteractive        # preview the lock screen without locking (closes after 90 s)
omarchy-shell -q background toggleAnimation  # pause/resume the live wallpaper
omarchy-shell -q clicks test                 # play a click effect in the middle of the screen
omarchy-shell -q clicks toggle               # turn the click effects on/off
```

The live wallpaper uses about 7% GPU busy on a Radeon RX 9070 XT. Turn it off with the toggle above if you're on battery.

## Uninstall

```bash
./install.sh --uninstall      # restores the stock Omarchy background + lock plugins and cursor
omarchy theme set <another-theme>
```

## Notes

- **Keyboard lighting** ([`extras/keyboard/`](extras/keyboard/)): per-key RGB for a Razer BlackWidow V4 Low Profile TKL through OpenRGB. It's not installed automatically; see its README for setup and how to adapt it to other keyboards.
- Shaders ship precompiled (`.qsb`). After editing `hearth.frag`, rebuild with
  `/usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o hearth.frag.qsb hearth.frag`.
- The positions of the moon, windows and chimney for each wallpaper are in `HearthLayer.qml`. A new wallpaper named `*moonlithearth*` without its own entry there uses the Hearth wallpaper's positions, so add one for it.
- The background and lock plugins are forks of Omarchy's built-in `omarchy.background` and `omarchy.lock` (MIT).

## Credits

- Wallpapers generated with [FLUX.1 [schnell]](https://huggingface.co/black-forest-labs/FLUX.1-schnell) (Apache-2.0) from original prompts, then upscaled.
- [Cormorant Garamond](https://github.com/CatharsisFonts/Cormorant) (SIL Open Font License 1.1) for the lock screen, intro and login screen. The license is bundled next to each copy.

## License

Code: MIT (see `LICENSE`). Artwork (wallpapers, badge, splash images, chime): free for personal use. Please don't resell it or use it in other products without asking.
