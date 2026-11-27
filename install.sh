#!/usr/bin/env bash
set -Eeuo pipefail

REPO_URL="https://github.com/nix-src/dotfiles.git"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
WALL_DIR="$HOME/.local/share/wallpapers"

LINKS_ONLY=0
NO_NVIDIA=0
NO_GAMING=0
for arg in "$@"; do
    case "$arg" in
        --links-only) LINKS_ONLY=1 ;;
        --no-nvidia)  NO_NVIDIA=1 ;;
        --no-gaming)  NO_GAMING=1 ;;
        -h|--help)    printf '%s\n' "Flags: --links-only, --no-nvidia, --no-gaming"; exit 0 ;;
        *) echo "Unknown flag / неизвестный флаг: $arg" >&2; exit 1 ;;
    esac
done

[[ ${DOTFILES_LANG:-en} == ru ]] && UI_RU=1 || UI_RU=0
t() { if ((UI_RU)); then printf '%s' "$2"; else printf '%s' "$1"; fi; }

msg()  { printf '\033[1;37m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

trap 'die "$(t "Error at line $LINENO: $BASH_COMMAND" "Ошибка в строке $LINENO: $BASH_COMMAND")"' ERR

[[ $EUID -ne 0 ]] || die "$(t "Run as a regular user, not root (sudo will ask when needed)." "Запускай от обычного пользователя, не от root (sudo спросится сам).")"
command -v pacman >/dev/null || die "$(t "This is not Arch Linux (pacman not found)." "Это не Arch Linux (нет pacman).")"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
if [[ ! -f "$SCRIPT_DIR/packages/pacman.txt" ]]; then
    msg "$(t "Cloning dotfiles into $DOTFILES_DIR" "Клонирую dotfiles в $DOTFILES_DIR")"
    command -v git >/dev/null || sudo pacman -Sy --needed --noconfirm git
    if [[ -d "$DOTFILES_DIR/.git" ]]; then
        git -C "$DOTFILES_DIR" pull --ff-only
    else
        git clone --depth 1 "$REPO_URL" "$DOTFILES_DIR"
    fi
    exec bash "$DOTFILES_DIR/install.sh" "$@"
fi
DOTFILES_DIR="$SCRIPT_DIR"

read_list() { sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$1"; }
installed() { pacman -Qq "$1" &>/dev/null; }

remove_if_installed() {
    local p found=()
    for p in "$@"; do installed "$p" && found+=("$p"); done
    if ((${#found[@]})); then
        warn "$(t "Removing conflicting packages: ${found[*]}" "Удаляю конфликтующие пакеты: ${found[*]}")"
        sudo pacman -Rdd --noconfirm "${found[@]}"
    fi
}

keep_sudo_alive() {
    sudo -v
    ( trap - ERR; while kill -0 "$$" 2>/dev/null; do sudo -n true 2>/dev/null; sleep 50; done ) &
}

install_paru() {
    command -v paru >/dev/null && return 0
    msg "$(t "Installing paru (AUR helper)" "Устанавливаю paru (AUR-хелпер)")"
    sudo pacman -S --needed --noconfirm base-devel git
    local tmp; tmp="$(mktemp -d)"
    git clone --depth 1 https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin"
    (cd "$tmp/paru-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
}

install_packages() {
    remove_if_installed pulseaudio pulseaudio-bluetooth pulseaudio-alsa

    msg "$(t "Updating the system and installing repository packages" "Обновляю систему и ставлю пакеты из репозиториев")"
    mapfile -t pkgs < <(read_list "$DOTFILES_DIR/packages/pacman.txt")
    sudo pacman -Syu --needed --noconfirm "${pkgs[@]}"

    install_paru
    mapfile -t aur < <(read_list "$DOTFILES_DIR/packages/aur.txt")
    if ((${#aur[@]})); then
        msg "$(t "Installing AUR packages" "Ставлю пакеты из AUR")"
        paru -S --needed --noconfirm --skipreview "${aur[@]}"
    fi

    if compgen -G "/sys/class/bluetooth/*" >/dev/null; then
        msg "$(t "Bluetooth found — installing bluez" "Найден Bluetooth — ставлю bluez")"
        sudo pacman -S --needed --noconfirm bluez bluez-utils
        sudo systemctl enable bluetooth.service
    fi
}

setup_nvidia() {
    ((NO_NVIDIA)) && return 0
    local gpu
    gpu="$(lspci | grep -Ei 'vga|3d|display' | grep -i nvidia || true)"
    [[ -n $gpu ]] || return 0
    msg "$(t "NVIDIA GPU found: ${gpu#*: }" "Найдена видеокарта NVIDIA: ${gpu#*: }")"

    local changed=0 headers=() k
    for k in linux linux-lts linux-zen linux-hardened; do
        installed "$k" && headers+=("$k-headers")
    done
    sudo pacman -S --needed --noconfirm dkms "${headers[@]}" libva-nvidia-driver egl-wayland

    if grep -qE '\b(GM|GP|GV)[0-9]{3}' <<<"$gpu"; then
        if ! installed nvidia-580xx-utils; then
            msg "$(t "Legacy architecture — installing nvidia-580xx from AUR" "Старая архитектура — ставлю nvidia-580xx из AUR")"
            local had_lib32=0
            installed lib32-nvidia-utils && had_lib32=1
            remove_if_installed nvidia nvidia-lts nvidia-dkms nvidia-open nvidia-open-lts \
                nvidia-open-dkms nvidia-utils lib32-nvidia-utils opencl-nvidia nvidia-settings
            paru -S --needed --noconfirm --skipreview nvidia-580xx-dkms nvidia-580xx-utils
            if ((had_lib32)); then
                paru -S --needed --noconfirm --skipreview lib32-nvidia-580xx-utils
            fi
            changed=1
        fi
    else
        if ! installed nvidia-open-dkms; then
            remove_if_installed nvidia nvidia-lts nvidia-dkms
            sudo pacman -S --needed --noconfirm nvidia-open-dkms nvidia-utils
            changed=1
        fi
    fi

    local modprobe=/etc/modprobe.d/nvidia.conf
    local want='options nvidia_drm modeset=1 fbdev=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1'
    if [[ "$(cat "$modprobe" 2>/dev/null)" != "$want" ]]; then
        printf '%s\n' "$want" | sudo tee "$modprobe" >/dev/null
        changed=1
    fi

    local conf=/etc/mkinitcpio.conf before
    before="$(sha256sum "$conf")"
    [[ -e $conf.bak ]] || sudo cp "$conf" "$conf.bak"
    sudo sed -i -E '/^HOOKS=/ s/ kms//' "$conf"
    if ! grep -qE '^MODULES=.*nvidia_drm' "$conf"; then
        sudo sed -i -E 's/^MODULES=\((.*)\)/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/; s/^MODULES=\( /MODULES=(/' "$conf"
    fi
    [[ "$(sha256sum "$conf")" == "$before" ]] || changed=1

    if ((changed)); then
        sudo mkinitcpio -P
    fi
    sudo systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service

    if ((changed)) || [[ ! -e /proc/driver/nvidia/version ]]; then
        NEED_REBOOT=1
    fi
}

setup_gaming() {
    ((NO_GAMING)) && return 0
    msg "$(t "Setting up gaming: Steam, 32-bit drivers, gamemode" "Настраиваю игры: Steam, 32-битные драйверы, gamemode")"

    if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
        sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
        grep -q '^\[multilib\]' /etc/pacman.conf \
            || printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' | sudo tee -a /etc/pacman.conf >/dev/null
        sudo pacman -Sy --noconfirm
    fi

    local gpus
    gpus="$(lspci | grep -Ei 'vga|3d|display' || true)"
    if grep -qi nvidia <<<"$gpus" && ((! NO_NVIDIA)); then
        if installed nvidia-580xx-utils; then
            paru -S --needed --noconfirm --skipreview lib32-nvidia-580xx-utils
        else
            sudo pacman -S --needed --noconfirm lib32-nvidia-utils
        fi
    fi
    if grep -qE 'AMD|ATI|Radeon' <<<"$gpus"; then
        sudo pacman -S --needed --noconfirm lib32-mesa lib32-vulkan-radeon vulkan-radeon
    fi
    if grep -q 'Intel' <<<"$gpus"; then
        sudo pacman -S --needed --noconfirm lib32-mesa lib32-vulkan-intel vulkan-intel
    fi

    mapfile -t pkgs < <(read_list "$DOTFILES_DIR/packages/gaming.txt")
    sudo pacman -S --needed --noconfirm "${pkgs[@]}"

    if getent group gamemode >/dev/null && ! id -nG "$USER" | grep -qw gamemode; then
        sudo usermod -aG gamemode "$USER"
        NEED_REBOOT=1
    fi
}

BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

link() {
    local src="$1" dst="$2"
    if [[ -L $dst && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
        return 0
    fi
    if [[ -e $dst || -L $dst ]]; then
        local rel="${dst#"$HOME"/}"
        mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
        mv "$dst" "$BACKUP_DIR/$rel"
        warn "$(t "Backup" "Бэкап"): ~/$rel -> $BACKUP_DIR/$rel"
    fi
    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
}

link_configs() {
    msg "$(t "Linking configs" "Связываю конфиги")"
    local f
    for f in "$DOTFILES_DIR"/config/*; do
        link "$f" "$HOME/.config/$(basename "$f")"
    done
    for f in "$DOTFILES_DIR"/home/.[!.]*; do
        if [[ -e $f ]]; then link "$f" "$HOME/$(basename "$f")"; fi
    done
    chmod +x "$DOTFILES_DIR"/config/hypr/scripts/*

    local apps="$HOME/.local/share/applications"
    mkdir -p "$apps"
    for f in "$DOTFILES_DIR"/extra/applications/*.desktop; do
        sed "s#@SETTINGS@#$HOME/.config/hypr/scripts/settings#" "$f" > "$apps/$(basename "$f")"
    done
}

setup_wallpaper() {
    [[ -f $WALL_DIR/drift.mp4 && -f $WALL_DIR/drift.png ]] && return 0
    if ! command -v ffmpeg >/dev/null || ! command -v python3 >/dev/null; then
        warn "$(t "ffmpeg/python3 missing — wallpaper skipped" "Нет ffmpeg/python3 — обои пропущены")"
        return 0
    fi
    local size="1920x1080"
    if command -v hyprctl >/dev/null && hyprctl monitors &>/dev/null; then
        size="$(hyprctl monitors | awk '/^\t[0-9]+x[0-9]+@/ {split($1, a, "@"); print a[1]; exit}')"
        [[ $size =~ ^[0-9]+x[0-9]+$ ]] || size="1920x1080"
    fi
    msg "$(t "Generating animated wallpaper ($size)" "Генерирую анимированные обои ($size)")"
    python3 -I "$DOTFILES_DIR/extra/wallpaper/generate.py" "$WALL_DIR" --size "$size"
}

setup_sddm() {
    msg "$(t "Setting up the SDDM login screen" "Настраиваю экран входа SDDM")"
    local theme=/usr/share/sddm/themes/mono
    sudo rm -rf "$theme"
    sudo cp -r "$DOTFILES_DIR/extra/sddm/mono" "$theme"
    if [[ -f $WALL_DIR/drift.png ]]; then
        sudo cp "$WALL_DIR/drift.png" "$theme/background.png"
    fi
    sudo mkdir -p /etc/sddm.conf.d
    printf '%s\n' '[Theme]' 'Current=mono' 'CursorTheme=Adwaita' 'CursorSize=24' \
        | sudo tee /etc/sddm.conf.d/10-mono.conf >/dev/null

    if ! systemctl is-enabled display-manager.service &>/dev/null; then
        sudo systemctl enable sddm.service
    fi
}

apply_theme() {
    msg "$(t "Applying the dark theme" "Применяю тёмную тему")"
    mkdir -p "$HOME/.config/qt6ct/colors"
    cp "$DOTFILES_DIR/extra/qt6ct/mono.conf" "$HOME/.config/qt6ct/colors/mono.conf"
    cat > "$HOME/.config/qt6ct/qt6ct.conf" <<EOF
[Appearance]
color_scheme_path=$HOME/.config/qt6ct/colors/mono.conf
custom_palette=true
icon_theme=Papirus-Dark
standard_dialogs=default
style=Fusion

[Fonts]
fixed="JetBrainsMono Nerd Font,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
general="JetBrainsMono Nerd Font,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
EOF

    if command -v gsettings >/dev/null; then
        local kv
        for kv in "color-scheme 'prefer-dark'" "gtk-theme 'adw-gtk3-dark'" \
                  "icon-theme 'Papirus-Dark'" "cursor-theme 'Adwaita'" \
                  "cursor-size 24" "font-name 'JetBrainsMono Nerd Font 10'" \
                  "document-font-name 'JetBrainsMono Nerd Font 10'" \
                  "monospace-font-name 'JetBrainsMono Nerd Font 10'"; do
            eval "gsettings set org.gnome.desktop.interface $kv" 2>/dev/null || true
        done
        gsettings set org.gnome.desktop.wm.preferences button-layout ':' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface accent-color 'slate' 2>/dev/null || true
    fi

    xdg-user-dirs-update 2>/dev/null || true
    xdg-mime default thunar.desktop inode/directory 2>/dev/null || true
    xdg-settings set default-web-browser firefox.desktop 2>/dev/null || true
}

setup_shell() {
    local current
    current="$(getent passwd "$USER" | cut -d: -f7)"
    if [[ $current != */zsh ]]; then
        msg "$(t "Setting zsh as the default shell" "Делаю zsh оболочкой по умолчанию")"
        sudo chsh -s /usr/bin/zsh "$USER"
    fi
}

setup_services() {
    msg "$(t "Enabling user services" "Включаю пользовательские сервисы")"
    systemctl --user enable hyprpolkitagent.service 2>/dev/null || true
}

NEED_REBOOT=0
if ((LINKS_ONLY)); then
    link_configs
    setup_wallpaper
    apply_theme
else
    keep_sudo_alive
    install_packages
    setup_nvidia
    setup_gaming
    link_configs
    setup_wallpaper
    setup_sddm
    apply_theme
    setup_shell
    setup_services
fi

if pgrep -x Hyprland >/dev/null && command -v hyprctl >/dev/null; then
    hyprctl reload >/dev/null 2>&1 || true
fi

msg "$(t "Done." "Готово.")"
if ((NEED_REBOOT)); then
    warn "$(t "Reboot to apply everything (new driver / groups)." "Перезагрузи компьютер, чтобы всё применилось (новый драйвер / группы).")"
else
    msg "$(t "Log out and back in (Super+Shift+Escape -> logout) to apply everything." "Перезайди в сессию (Super+Shift+Escape -> выход), чтобы всё применилось.")"
fi
