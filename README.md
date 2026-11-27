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

Flags: `--links-only` (configs only), `--no-nvidia`, `--no-gaming` (skip Steam and 32-bit drivers).

## What's inside

| Role | Tool |
|---|---|
| Compositor | Hyprland (via uwsm) |
| Bar | waybar |
| Wallpaper | mpvpaper + generated video (paused when covered by windows) |
| Login screen | SDDM, `mono` theme: pick an account from the list (↑/↓ to switch), type the password |
| Launcher / menus | fuzzel |
| Notifications | mako |
| Lock / idle | hyprlock / hypridle (lock after 10 min, screen off after 15) |
| Terminal / shell | kitty / zsh + starship |
| Editor | neovim (no plugins, `quiet` colorscheme) |
| Files | thunar |
| Network / audio | iwd + impala (or NetworkManager + nmtui) / pipewire + pavucontrol |
| Media | current track from any MPRIS player (browser, Spotify, mpv…) in the bar, hidden when nothing plays; click opens the mini player under the cursor (cover, seek, controls; closes when the mouse leaves, on Esc or a second click), right click play/pause, middle click next |
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
| Games | tearing (no vsync wait), extra game window classes |
| Infinite canvas | window spread and scale, edge margin, inertia |
| Power | lock, screen off and suspend on idle |
| Applications | terminal, browser, file manager |
| System | sound, Wi-Fi, Bluetooth, system update, dotfiles folder |

Values are stored in `~/.config/dotfiles-local/`, outside the repo, so every machine keeps its own.
The "Defaults" button deletes it and restores the repository defaults.

## Session

Pick **Hyprland (uwsm-managed)** on the login screen — services then run as systemd units.
A plain **Hyprland** session works too: autostart, environment variables, the polkit agent
and logout handle both.

## Gaming

Wayland has no exclusive fullscreen like Windows: games always go through the compositor, which
waits for vsync by default — that is the extra input lag. The config fixes it for game windows
(CS2, Steam/Proton `steam_app_*`, gamescope, Wine `*.exe`):

- **tearing** (`immediate`): frames reach the screen without waiting for vsync, like exclusive
  fullscreen on Windows;
- **direct scanout**: a fullscreen game is shown directly, bypassing compositing;
- **VRR** in fullscreen games when the monitor supports it;
- the screen does not dim or lock while playing.

The installer enables `multilib`, installs the 32-bit driver for your GPU first (for GTX 9xx/10xx —
`lib32-nvidia-580xx-utils`, so Steam does not pull a conflicting one), then Steam and gamemode, and
adds you to the `gamemode` group. No Steam launch options are needed: while a game window is open,
Hyprland enables gamemode for it and turns off mouse acceleration and the system speed multiplier
(flat, sensitivity 0), so aim depends only on DPI and in-game settings, like raw input on Windows.
Mouse settings are restored when the game closes. In CS2, use "Fullscreen Windowed" at the
monitor's native resolution; avoid gamescope — tearing does not work with it.
Tearing and extra game window classes can be changed in Settings → Games.
To check that tearing works, run `hyprctl monitors` while playing: `activelyTearing: true`.

## Performance

- The video wallpaper only plays while it is actually visible (empty workspace or canvas mode);
  otherwise the process is frozen on its last frame, so it costs nothing.
- The mini player and the settings window live in one background process with GTK preloaded,
  and the settings window is prepared in advance: clicks in the bar open them in ~60–80 ms.
- The media module and the mini player react to player events instead of polling.

## Language

The interface (bar, power menu, notifications, settings window, login screen, installer) is
available in English and Russian. English is the default; switch it in the settings window
(Appearance → Interface language), in `lang=` of the SDDM `theme.conf`, or run the installer
with `DOTFILES_LANG=ru`.

All of the environment (terminal, bar, launcher, notifications, GTK/Qt apps, lock and login
screens) uses one font: JetBrainsMono Nerd Font; `~/.config/fontconfig/fonts.conf` maps
sans-serif, serif and monospace to it.

## Making changes

Configs are symlinks, so edits in `~/.config/...` land in the repo right away:

```bash
cd ~/dotfiles && git add -A && git commit -m "..." && git push
```
