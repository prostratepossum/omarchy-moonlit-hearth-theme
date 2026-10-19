# Changelog

## 1.1.0

- The live wallpaper, lock screen, login intro, click effects and login screen now come from [Omarchy Living Themes](https://github.com/prostratepossum/omarchy-living-themes), shared with Alpine Marmot. Switching between the two themes (or to any other) swaps the scene, cursor, prompt, terminal colors, login chime and login screen.
- The terminal rice (`extras/`) is now a theme package that switches with the theme instead of being copied over your dotfiles. `--dotfiles` is no longer needed.
- Boot splash: install it with `living-themes boot`, or from the notification after switching to this theme.
- Upgrading: the installer removes the 1.0 `moonlit-hearth-*` plugins, the old `~/.bashrc` and `looknfeel.lua` blocks and login-chime unit, and restores the prompt and lazygit files that `--dotfiles` replaced. It also tells you if the 1.0 login screen is still installed, since it would override the shared one.

## 1.0.0

- First release.
