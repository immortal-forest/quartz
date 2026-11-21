#!/usr/bin/env bash
# quartz installer: checks what quartz needs, then links the shell into
# ~/.config/quickshell/quartz. It does not touch your Hyprland config — it
# prints the two lines to add.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
qs_dir="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
ok=1

say()  { printf '%s\n' "$*"; }
miss() { printf '  ✗ %-22s %s\n' "$1" "$2"; ok=0; }
have() { printf '  ✓ %s\n' "$1"; }

say "quartz — checking dependencies"
check() { # command  package
    if command -v "$1" >/dev/null 2>&1; then have "$1"; else miss "$1" "($2)"; fi
}
check qs            quickshell
check hyprctl       hyprland
check matugen       matugen
check awww          awww
check wl-copy       wl-clipboard
check cliphist      cliphist
check brightnessctl brightnessctl
check wpctl         wireplumber
check nmcli         networkmanager
check gdbus         glib2
check busctl        systemd
check setpriv       util-linux
check udevadm       systemd

say "  optional:"
for c in hyprshot playerctl; do
    if command -v "$c" >/dev/null 2>&1; then have "$c"; else say "  · $c (nice to have)"; fi
done

say "  fonts:"
font() { # family  where-to-get-it
    local all
    all=$(fc-list : family)
    if [[ "$all" == *"$1"* ]]; then have "$1"; else miss "$1" "$2"; fi
}
font "Adwaita Sans"             "(adwaita-fonts)"
font "Material Symbols Rounded" "(ttf-material-symbols-variable)"
font "Outfit"                   "(https://fonts.google.com/specimen/Outfit → ~/.local/share/fonts)"

if [ $ok -eq 0 ]; then
    say ""
    say "Some things are missing. On Arch:"
    say "  sudo pacman -S quickshell matugen awww wl-clipboard cliphist brightnessctl \\"
    say "                 wireplumber networkmanager bluez upower adwaita-fonts ttf-material-symbols-variable"
    say "Continuing anyway — quartz runs without them but the matching parts won't work."
fi

say ""
mkdir -p "$qs_dir"
target="$qs_dir/quartz"
if [ -L "$target" ] && [ "$(readlink -f "$target")" = "$here/shell" ]; then
    say "~/.config/quickshell/quartz already points here."
else
    if [ -e "$target" ] || [ -L "$target" ]; then
        bak="$target.bak.$(date +%Y%m%d-%H%M%S)"
        mv "$target" "$bak"
        say "Moved the existing $target to $bak"
    fi
    ln -s "$here/shell" "$target"
    say "Linked $target → $here/shell"
fi

cat <<MSG

Last step — add quartz to your Hyprland config:

  Lua config (hyprland.lua):
    local quartz = dofile("$here/hypr/quartz.lua")
    quartz.setup({ mod = "SUPER", autostart = true })

  Classic hyprland.conf: see "Classic hyprland.conf" in README.md.

Then start it now with:  qs -c quartz -d
MSG
