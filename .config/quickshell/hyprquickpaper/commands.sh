#!/usr/bin/env bash
# Central wallpaper hook, called by hyprquickpaper with the chosen image path.

img="$1"
[[ -f "$img" ]] || { echo "commands.sh: not a file: $img" >&2; exit 1; }

# Fundido cruzado siempre; 0.6 s con ease-in-out a 60 fps (con -t random a veces
# salía "simple", que ignora la duración y tarda ~4 s, y a 30 fps se veía a saltos).
awww img "$img" -t fade --transition-duration 0.6 --transition-fps 60 \
    --transition-bezier .42,0,.58,1

mkdir -p "$HOME/.cache/43pr"
setsid -f python3 "$HOME/.config/43pr/bin/theme.py" wallpaper "$img" \
    >>"$HOME/.cache/43pr/theme.log" 2>&1
