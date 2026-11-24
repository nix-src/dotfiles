# dotfiles

Минималистичное тёмное окружение для Arch Linux + Hyprland (0.57+, Lua-конфиг):
монохром, без скруглений, blur и теней.

## Установка на новую систему

На свежем Arch (с пользователем в группе `wheel` и рабочей сетью):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/nix-src/dotfiles/main/install.sh)
```

Скрипт клонирует репозиторий в `~/dotfiles` и:

1. обновляет систему и ставит пакеты из `packages/pacman.txt` (+ `packages/aur.txt` через paru);
2. если есть NVIDIA — ставит драйвер (GTX 9xx/10xx → `nvidia-580xx` из AUR, новее → `nvidia-open`),
   настраивает раннюю загрузку модулей и пересобирает initramfs;
3. ставит Bluetooth, если он есть;
4. делает симлинки `config/*` → `~/.config/*`, `home/.*` → `~/` (старые файлы — в `~/.dotfiles-backup/`);
5. включает тёмную тему GTK/Qt, делает zsh оболочкой по умолчанию.

Флаги: `--links-only` (только конфиги), `--no-nvidia`.

## Состав

| Что | Чем |
|---|---|
| Композитор | Hyprland (через uwsm) |
| Панель | waybar |
| Лаунчер / меню | fuzzel |
| Уведомления | mako |
| Блокировка / idle | hyprlock / hypridle (блок через 10 мин, экран off через 15) |
| Терминал / shell | kitty / zsh + starship |
| Редактор | neovim (без плагинов, тема `quiet`) |
| Файлы | thunar |
| Сеть / звук | iwd + impala / pipewire + pavucontrol |
| Буфер / скриншоты | cliphist / grim + slurp |

## Горячие клавиши

| Клавиши | Действие |
|---|---|
| `Super + Enter` | терминал |
| `Super + D` | запуск приложений |
| `Super + E` / `Super + B` | файлы / браузер |
| `Super + Q` | закрыть окно |
| `Super + F` / `Super + Shift + F` | полный экран / развернуть |
| `Super + V` | плавающее окно |
| `Super + T` | сменить направление разделения |
| `Super + ←↓↑→` или `H J K L` | фокус |
| `Super + Shift + стрелки/HJKL` | переместить окно |
| `Super + Ctrl + стрелки/HJKL` | изменить размер |
| `Super + 1..0` / `Super + Shift + 1..0` | рабочий стол / перенести окно |
| `Super + Tab` | предыдущий рабочий стол |
| `Super + S` / `Super + Shift + S` | scratchpad |
| `Super + C` | история буфера обмена |
| `Super + N` | скрыть уведомления |
| `Print` / `Shift + Print` | скриншот области / экрана |
| `Super + Print` | пипетка цвета |
| `Super + Escape` | заблокировать |
| `Super + Shift + Escape` | меню питания |
| `Super + Shift + R` | перечитать конфиг |
| `Alt + Shift` | раскладка us/ru |

## Изменение

Конфиги — симлинки, так что правки в `~/.config/...` сразу попадают в репозиторий:

```bash
cd ~/dotfiles && git add -A && git commit -m "..." && git push
```
