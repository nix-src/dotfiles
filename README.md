# dotfiles

**English** · [Русский](README.ru.md)

A minimal dark environment for Arch Linux + Hyprland (0.57+, Lua config):
monochrome, no rounded corners, no blur, no shadows.

## Install on a new system

On a fresh Arch install (user in the `wheel` group, working network):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/nix-src/dotfiles/main/install.sh)
```

The script clones the repo into `~/dotfiles` and:

1. updates the system and installs packages from `packages/pacman.txt` (+ `packages/aur.txt` via paru);
2. on NVIDIA, installs the driver (GTX 9xx/10xx → `nvidia-580xx` from AUR, newer → `nvidia-open`),
   sets up early module loading and rebuilds the initramfs;
3. installs Bluetooth support if the hardware is present;
4. symlinks `config/*` → `~/.config/*`, `home/.*` → `~/` (existing files go to `~/.dotfiles-backup/`);
5. generates the animated wallpaper (`extra/wallpaper/generate.py`) for your monitor resolution;
6. installs the `mono` SDDM theme and enables SDDM if no other display manager is set up;
7. applies the dark GTK/Qt theme and makes zsh the default shell.

Conflicting packages (pulseaudio, repository NVIDIA drivers on legacy cards) are removed
automatically, so the script never stops on prompts. sudo asks for the password once at the start.

Flags: `--links-only` (configs only), `--no-nvidia`.

## What's inside

| Role | Tool |
|---|---|
| Compositor | Hyprland (via uwsm) |
| Bar | waybar |
| Wallpaper | mpvpaper + generated video (paused when covered by windows) |
| Login screen | SDDM, `mono` theme |
| Launcher / menus | fuzzel |
| Notifications | mako |
| Lock / idle | hyprlock / hypridle (lock after 10 min, screen off after 15) |
| Terminal / shell | kitty / zsh + starship |
| Editor | neovim (no plugins, `quiet` colorscheme) |
| Files | thunar |
| Network / audio | iwd + impala / pipewire + pavucontrol |
| Media | mpris module in the bar: track from any player, click to pause, right click for next |
| Clipboard / screenshots | cliphist / grim + slurp |

## Keybindings

| Keys | Action |
|---|---|
| `Super + Enter` | terminal |
| `Super + D` | app launcher |
| `Super + E` / `Super + B` | files / browser |
| `Super + I` | settings window |
| `Super + Q` | close window |
| `Super + F` | tiling ↔ infinite canvas |
| `Super + Shift + F` / `Super + M` | fullscreen / maximize |
| `Super + V` | toggle floating |
| `Super + T` | toggle split direction |
| `Super + ←↓↑→` or `H J K L` | move focus |
| `Super + Shift + arrows/HJKL` | move window |
| `Super + Ctrl + arrows/HJKL` | resize window |
| `Super + 1..0` / `Super + Shift + 1..0` | switch workspace / move window to workspace |
| `Super + Tab` | previous workspace |
| `Super + S` / `Super + Shift + S` | scratchpad |
| drag empty space with LMB | pan the canvas (with inertia) |
| `Super + middle button` (drag) | pan the canvas, even over a window |
| wheel over empty space (`Shift` for horizontal) | scroll the canvas |
| `Super + Alt + arrows/HJKL` | smooth canvas pan |
| `Super + Alt + C` | center the camera on the active window |
| `Super + C` | clipboard history |
| `Super + N` | dismiss notifications |
| `Print` / `Shift + Print` | screenshot area / screen |
| `Super + Print` | color picker |
| `Super + Escape` | lock |
| `Super + Shift + Escape` | power menu (also the ⏻ button in the bar) |
| `Super + Shift + R` | reload config |
| `Alt + Shift` | switch keyboard layout |

## Infinite canvas

`Super + F` switches the current workspace between tiling and a canvas. On entering, windows
become floating, shrink slightly and spread out from the center. Drag any empty spot to pan
the canvas; on release it keeps gliding with inertia while the wallpaper stays put. New windows
open in the middle of the screen. While the canvas is active the bar shows `∞ infinite`.
Press `Super + F` again to tile the windows back. Logic lives in `config/hypr/canvas.lua`;
parameters are adjustable in the settings window.

The canvas is bounded: the view can't move further than the outermost windows plus a margin
(35% of the screen by default). More windows spread wider mean a larger field; hitting the edge
stops the inertia.

## Settings

`Super + I` or the gear in the bar opens the settings window (GTK4):

| Section | What you can change |
|---|---|
| Display | resolution and refresh rate, scale, position of each monitor |
| Keyboard and mouse | layouts, layout switch, key repeat, sensitivity, acceleration, scrolling |
| Appearance | gaps, border, animations, rotating border, dimming, wallpaper mode, interface language |
| Infinite canvas | window spread and scale, edge margin, inertia |
| Power | lock, screen off and suspend on idle |
| Applications | terminal, browser, file manager |
| System | sound, Wi-Fi, Bluetooth, system update, dotfiles folder |

Values are stored in `~/.config/dotfiles-local/`, outside the repo, so every machine keeps its own.
The "Defaults" button deletes it and restores the repository defaults.

## Language

The interface (bar, power menu, notifications, settings window, login screen, installer) is
available in English and Russian. The language follows the system locale (`LANG`) and can be
set manually in the settings window (Appearance → Interface language).

## Making changes

Configs are symlinks, so edits in `~/.config/...` land in the repo right away:

```bash
cd ~/dotfiles && git add -A && git commit -m "..." && git push
```
