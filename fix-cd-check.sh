#!/usr/bin/env bash
# ============================================================================
# Battleship: Surface Thunder — eliminate the CD requirement
#
# Builds a permanent "fake CD" inside the Wine prefix and wires it up as
# drive D: with type CD-ROM and volume label SURFACETHUNDER. Mirrors the
# real disc's directory structure (using symlinks for the huge .mgf files
# so we don't waste 150 MB).
#
# Run ONCE with the disc inserted; never need it again afterwards.
#
# Usage:
#   ./fix-cd-check.sh             # auto-detect mounted disc
#   ./fix-cd-check.sh -s /media/bird/SURFACETHUNDER
# ============================================================================

set -euo pipefail

PREFIX="${BST_PREFIX:-$HOME/.local/share/wineprefixes/battleship-st}"
INSTALL_DIR="$PREFIX/drive_c/Program Files/Hasbro Interactive/BattleShip SURFACE THUNDER"
FAKE_CD="$PREFIX/fake-cd"
DOSDEV="$PREFIX/dosdevices"

SRC=""
while getopts ":s:" opt; do
  case "$opt" in
    s) SRC="$OPTARG" ;;
    *) echo "Usage: $0 [-s /path/to/mounted/disc]" >&2; exit 2 ;;
  esac
done

msg()  { printf '\033[1;36m[*]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[X]\033[0m %s\n' "$*" >&2; exit 1; }

[[ -d "$INSTALL_DIR" ]] || die "Game install not found at:
  $INSTALL_DIR
Run install-battleship-st.sh first."

[[ -f "$INSTALL_DIR/Resource/Music.Mgf" && -f "$INSTALL_DIR/Resource/Movies.Mgf" ]] || \
  die "Local Music.Mgf / Movies.Mgf missing — install looks incomplete."

# Locate the disc (need it once, to mirror the directory layout)
if [[ -z "$SRC" ]]; then
  msg "Looking for the inserted disc..."
  for d in "/media/$USER"/* "/run/media/$USER"/* /media/* /mnt/*; do
    [[ -d "$d" && -f "$d/data.tag" && -f "$d/data1.cab" ]] && SRC="$d" && break
  done
fi
[[ -n "$SRC" && -d "$SRC" ]] || die "Disc not found. Insert it (or pass -s /path)."
ok "Disc: $SRC"

# Build the fake CD
msg "Building fake CD at $FAKE_CD"
rm -rf "$FAKE_CD"
mkdir -p "$FAKE_CD"

# Copy everything from the disc EXCEPT the giant .mgf files — symlink those
# from the install dir to save ~150 MB.
shopt -s dotglob nullglob
for entry in "$SRC"/*; do
  name="$(basename "$entry")"
  # skip the big resource folder; we recreate it below with symlinks
  [[ "${name,,}" == "resource" ]] && continue
  cp -r "$entry" "$FAKE_CD/"
done
shopt -u dotglob nullglob

# Recreate Resource/ with symlinks to the already-installed files
mkdir -p "$FAKE_CD/Resource"
ln -sf "$INSTALL_DIR/Resource/Music.Mgf"  "$FAKE_CD/Resource/Music.Mgf"
ln -sf "$INSTALL_DIR/Resource/Movies.Mgf" "$FAKE_CD/Resource/Movies.Mgf"

# Volume label — Wine reads this file as the drive's label
echo -n "SURFACETHUNDER" > "$FAKE_CD/.windows-label"
ok "Fake CD built (label: SURFACETHUNDER)"

# Wire up Wine drive D:
msg "Mapping Wine drive D: → fake CD (type: cdrom)"
mkdir -p "$DOSDEV"
rm -f "$DOSDEV/d:" "$DOSDEV/d::"
ln -s "$FAKE_CD" "$DOSDEV/d:"

export WINEPREFIX="$PREFIX"
export WINEDEBUG=-all
wine reg add 'HKLM\Software\Wine\Drives' /v "D:" /t REG_SZ /d "cdrom" /f >/dev/null 2>&1 || \
  die "Failed to register D: as cdrom in the Wine registry."

ok "Drive D: registered as CD-ROM."
echo
ok "Fake CD installed permanently. The disc is no longer needed."
msg "Launch with:  battleship-st"
