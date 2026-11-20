#!/usr/bin/env bash
# Link this checkout into the local Factorio installs as an unpacked mod, so
# the game loads the working tree.
set -euo pipefail

# This file lives in scripts/ and the mod is the folder above it. Release zips
# leave scripts/ out, and the Mod Portal rejects a zip that holds a .sh file.
MOD_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INFO="$MOD_DIR/info.json"

field() { grep -o "\"$1\": *\"[^\"]*\"" "$INFO" | head -1 | sed 's/.*"\([^"]*\)"/\1/'; }
NAME=$(field name)
GAME=$(field factorio_version)
# Unversioned folder name: Factorio accepts either "<name>" or
# "<name>_<version>" for an unpacked mod, and refuses "<name>_<version>" when
# the version differs from info.json. The unversioned name keeps working after
# a version bump or a branch switch.
LINK_NAME="${NAME}"

# A game refuses a mod made for another game version ("Incompatible Factorio
# version"), so the link goes only where the checked-out branch can load and is
# taken out of the other set.
#   2.1: ~/.factorio/mods is the shared 2.1 mod set (Steam, ~/factorio and
#        ~/factorio-2.1 all use it).
#   2.0: ~/factorio-2.0/bin/x64/factorio --mod-directory ~/factorio-2.0/expanse-dev-mods
MODS_21=("$HOME/.factorio/mods" "$HOME/factorio/mods" "$HOME/factorio-2.1/mods")
MODS_20=("$HOME/factorio-2.0/expanse-dev-mods" "$HOME/factorio2/mods")
if [[ "$GAME" == "2.0" ]]; then
    MOD_DIRS=("${MODS_20[@]}"); OTHER_DIRS=("${MODS_21[@]}")
else
    MOD_DIRS=("${MODS_21[@]}"); OTHER_DIRS=("${MODS_20[@]}")
fi
echo "$NAME targets Factorio $GAME"

remove_links() {
    # Old symlinks pointing to this mod: versioned names and the unversioned one.
    for link in "$1/${NAME}_"* "$1/${NAME}"; do
        if [[ -L "$link" ]]; then
            echo "Removing old link: $link"
            rm "$link"
        fi
    done
}

for dir in "${OTHER_DIRS[@]}"; do
    [[ -d "$dir" ]] && remove_links "$dir"
done

declare -A seen
for dir in "${MOD_DIRS[@]}"; do
    if [[ ! -d "$dir" ]]; then
        echo "Skipping $dir (not found)"
        continue
    fi
    # Several of these paths are one folder behind symlinks.
    real="$(realpath "$dir")"
    [[ -n "${seen[$real]:-}" ]] && continue
    seen[$real]=1

    remove_links "$dir"

    # Remove old packaged zips of this mod
    for zip in "$dir/${NAME}_"*.zip; do
        if [[ -f "$zip" ]]; then
            echo "Removing old zip: $zip"
            rm "$zip"
        fi
    done

    ln -s "$MOD_DIR" "$dir/$LINK_NAME"
    echo "Created: $dir/$LINK_NAME -> $MOD_DIR"
done
