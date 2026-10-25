#!/bin/sh
# Installs desk for the current user (~/.local): the command, the panel switcher widget,
# its icon and a menu entry. Themes are never touched, also not by --uninstall.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
bin="$HOME/.local/bin"
data="${XDG_DATA_HOME:-$HOME/.local/share}"
plasmoid="$data/plasma/plasmoids/local.desk.switcher"
icon="$data/icons/hicolor/scalable/apps/desk-themes-symbolic.svg"
menu="$data/applications/desk-themes.desktop"

if [ "${1:-}" = "--uninstall" ]; then
    rm -rf "$bin/desk" "$plasmoid" "$icon" "$menu"
    echo "desk removed. Themes stay in $data/desk-themes"
    exit 0
fi

for cmd in python3 kreadconfig6 plasma-apply-colorscheme systemctl; do
    command -v "$cmd" >/dev/null || { echo "missing: $cmd (desk needs KDE Plasma 6)" >&2; exit 1; }
done
command -v kdialog >/dev/null || echo "note: install kdialog for the 'desk' picker window"
command -v ffmpeg >/dev/null || echo "note: install ffmpeg for theme previews in the panel switcher"
command -v kscreen-doctor >/dev/null || echo "note: install kscreen-doctor (kscreen) for desk swap / desk screens"

install -Dm755 "$here/desk" "$bin/desk"
rm -rf "$plasmoid"
mkdir -p "$(dirname "$plasmoid")"
cp -r "$here/plasmoid" "$plasmoid"
install -Dm644 "$here/icons/desk-themes-symbolic.svg" "$icon"
mkdir -p "$(dirname "$menu")"
sed "s|@BINDIR@|$bin|" "$here/desk-themes.desktop" > "$menu"

echo "desk installed: $bin/desk"
echo "Add the \"Desktop Themes\" widget to a panel; if it was already there, restart Plasma:"
echo "    systemctl --user restart plasma-plasmashell"
case ":$PATH:" in *":$bin:"*) ;; *) echo "note: $bin is not in PATH" ;; esac
