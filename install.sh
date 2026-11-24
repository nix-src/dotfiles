#!/usr/bin/env bash
# Установка окружения Arch Linux + Hyprland одним скриптом.
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/nix-src/dotfiles/main/install.sh)
#
# Флаги:
#   --links-only   только связать конфиги (без установки пакетов и системных настроек)
#   --no-nvidia    не ставить драйвер NVIDIA, даже если карта найдена
#   -h, --help     справка

set -Eeuo pipefail

REPO_URL="https://github.com/nix-src/dotfiles.git"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"

LINKS_ONLY=0
NO_NVIDIA=0
for arg in "$@"; do
    case "$arg" in
        --links-only) LINKS_ONLY=1 ;;
        --no-nvidia)  NO_NVIDIA=1 ;;
        -h|--help)    sed -n '2,11p' "$0" 2>/dev/null || true; exit 0 ;;
        *) echo "Неизвестный флаг: $arg" >&2; exit 1 ;;
    esac
done

msg()  { printf '\033[1;37m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

trap 'die "Ошибка в строке $LINENO: $BASH_COMMAND"' ERR

[[ $EUID -ne 0 ]] || die "Запускай от обычного пользователя, не от root (sudo спросится сам)."
command -v pacman >/dev/null || die "Это не Arch Linux (нет pacman)."

# ---------------------------------------------------------------------------
# Бутстрап: если скрипт запущен не из репозитория (через curl) — клонируем его
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
if [[ ! -f "$SCRIPT_DIR/packages/pacman.txt" ]]; then
    msg "Клонирую dotfiles в $DOTFILES_DIR"
    command -v git >/dev/null || sudo pacman -S --needed --noconfirm git
    if [[ -d "$DOTFILES_DIR/.git" ]]; then
        git -C "$DOTFILES_DIR" pull --ff-only
    else
        git clone "$REPO_URL" "$DOTFILES_DIR"
    fi
    exec bash "$DOTFILES_DIR/install.sh" "$@"
fi
DOTFILES_DIR="$SCRIPT_DIR"

read_list() { sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$1"; }

# ---------------------------------------------------------------------------
# Пакеты
# ---------------------------------------------------------------------------
keep_sudo_alive() {
    sudo -v
    while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &
}

install_paru() {
    command -v paru >/dev/null && return
    msg "Устанавливаю paru (AUR-хелпер)"
    sudo pacman -S --needed --noconfirm base-devel git
    local tmp; tmp="$(mktemp -d)"
    git clone https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin"
    (cd "$tmp/paru-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
}

install_packages() {
    msg "Обновляю систему и ставлю пакеты из репозиториев"
    mapfile -t pkgs < <(read_list "$DOTFILES_DIR/packages/pacman.txt")
    sudo pacman -Syu --needed --noconfirm "${pkgs[@]}"

    install_paru
    mapfile -t aur < <(read_list "$DOTFILES_DIR/packages/aur.txt")
    if ((${#aur[@]})); then
        msg "Ставлю пакеты из AUR"
        paru -S --needed --noconfirm --skipreview "${aur[@]}"
    fi

    if compgen -G "/sys/class/bluetooth/*" >/dev/null; then
        msg "Найден Bluetooth — ставлю bluez"
        sudo pacman -S --needed --noconfirm bluez bluez-utils
        sudo systemctl enable --now bluetooth.service
    fi
}

# ---------------------------------------------------------------------------
# NVIDIA: Maxwell/Pascal/Volta -> ветка 580xx (AUR), Turing и новее -> nvidia-open
# ---------------------------------------------------------------------------
setup_nvidia() {
    ((NO_NVIDIA)) && return 0
    local gpu
    gpu="$(lspci | grep -Ei 'vga|3d|display' | grep -i nvidia || true)"
    [[ -n $gpu ]] || return 0
    msg "Найдена видеокарта NVIDIA: ${gpu#*: }"

    local headers=() k
    for k in linux linux-lts linux-zen linux-hardened; do
        pacman -Qq "$k" &>/dev/null && headers+=("$k-headers")
    done
    sudo pacman -S --needed --noconfirm dkms "${headers[@]}" libva-nvidia-driver egl-wayland

    if grep -qE '\b(GM|GP|GV)[0-9]{3}' <<<"$gpu"; then
        msg "Старая архитектура — ставлю nvidia-580xx из AUR"
        paru -S --needed --noconfirm --skipreview nvidia-580xx-dkms nvidia-580xx-utils
    else
        sudo pacman -S --needed --noconfirm nvidia-open-dkms nvidia-utils
    fi

    echo 'options nvidia_drm modeset=1 fbdev=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1' | sudo tee /etc/modprobe.d/nvidia.conf >/dev/null

    # Ранняя загрузка модулей и отключение kms-хука (он подтягивает nouveau)
    local conf=/etc/mkinitcpio.conf
    sudo cp -n "$conf" "$conf.bak"
    sudo sed -i -E '/^HOOKS=/ s/ kms//' "$conf"
    if ! grep -qE '^MODULES=.*nvidia_drm' "$conf"; then
        sudo sed -i -E 's/^MODULES=\((.*)\)/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/; s/^MODULES=\( /MODULES=(/' "$conf"
    fi
    sudo mkinitcpio -P

    sudo systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service
    NEED_REBOOT=1
}

# ---------------------------------------------------------------------------
# Конфиги: симлинки из репозитория, старые файлы уходят в бэкап
# ---------------------------------------------------------------------------
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

link() {
    local src="$1" dst="$2"
    if [[ -L $dst && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
        return
    fi
    if [[ -e $dst || -L $dst ]]; then
        local rel="${dst#"$HOME"/}"
        mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
        mv "$dst" "$BACKUP_DIR/$rel"
        warn "Бэкап: ~/$rel -> $BACKUP_DIR/$rel"
    fi
    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
}

link_configs() {
    msg "Связываю конфиги"
    local f
    for f in "$DOTFILES_DIR"/config/*; do
        link "$f" "$HOME/.config/$(basename "$f")"
    done
    for f in "$DOTFILES_DIR"/home/.[!.]*; do
        [[ -e $f ]] && link "$f" "$HOME/$(basename "$f")"
    done
    chmod +x "$DOTFILES_DIR"/config/hypr/scripts/*
}

# ---------------------------------------------------------------------------
# Темы, приложения по умолчанию, оболочка, сервисы
# ---------------------------------------------------------------------------
apply_theme() {
    msg "Применяю тёмную тему"
    mkdir -p "$HOME/.config/qt6ct/colors"
    cp "$DOTFILES_DIR/extra/qt6ct/mono.conf" "$HOME/.config/qt6ct/colors/mono.conf"
    cat > "$HOME/.config/qt6ct/qt6ct.conf" <<EOF
[Appearance]
color_scheme_path=$HOME/.config/qt6ct/colors/mono.conf
custom_palette=true
icon_theme=Papirus-Dark
standard_dialogs=default
style=Fusion
EOF

    if command -v gsettings >/dev/null; then
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
        gsettings set org.gnome.desktop.interface gtk-theme    'adw-gtk3-dark'
        gsettings set org.gnome.desktop.interface icon-theme   'Papirus-Dark'
        gsettings set org.gnome.desktop.interface cursor-theme 'Adwaita'
        gsettings set org.gnome.desktop.interface cursor-size  24
        gsettings set org.gnome.desktop.interface font-name    'Noto Sans 10'
        gsettings set org.gnome.desktop.wm.preferences button-layout ':'
    fi

    xdg-user-dirs-update || true
    xdg-mime default thunar.desktop inode/directory || true
    xdg-settings set default-web-browser firefox.desktop 2>/dev/null || true
}

setup_shell() {
    local current
    current="$(getent passwd "$USER" | cut -d: -f7)"
    if [[ $current != */zsh ]]; then
        msg "Делаю zsh оболочкой по умолчанию"
        sudo chsh -s /usr/bin/zsh "$USER"
    fi
}

setup_services() {
    msg "Включаю пользовательские сервисы"
    systemctl --user enable hyprpolkitagent.service 2>/dev/null || true
}

# ---------------------------------------------------------------------------
NEED_REBOOT=0
if ((LINKS_ONLY)); then
    link_configs
    apply_theme
else
    keep_sudo_alive
    install_packages
    setup_nvidia
    link_configs
    apply_theme
    setup_shell
    setup_services
fi

if pgrep -x Hyprland >/dev/null && command -v hyprctl >/dev/null; then
    hyprctl reload >/dev/null || true
fi

msg "Готово."
((NEED_REBOOT)) && warn "Установлен драйвер NVIDIA — перезагрузи компьютер." \
                || msg "Перезайди в сессию (SUPER+SHIFT+Escape -> logout), чтобы всё применилось."
