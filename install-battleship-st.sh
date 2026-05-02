#!/usr/bin/env bash
# ============================================================================
# Battleship: Surface Thunder (Hasbro Interactive, 2000) — automated installer
# Target: Linux Mint / Ubuntu / Debian, x86_64
#
# Reads directly from the mounted CD. Skips InstallShield's setup.exe entirely
# (way more reliable on Wine), extracts data1.cab with `unshield`, places the
# files in a dedicated 32-bit Wine prefix, writes the registry keys the game
# expects, then launches.
#
# Usage:
#   ./install-battleship-st.sh             # auto-detect mounted CD
#   ./install-battleship-st.sh -y          # auto-detect, no prompts
#   ./install-battleship-st.sh -s /media/USER/SURFACETHUNDER   # explicit
# ============================================================================

set -euo pipefail

# ----- config ---------------------------------------------------------------
PREFIX="${BST_PREFIX:-$HOME/.local/share/wineprefixes/battleship-st}"
INSTALL_REL="drive_c/Program Files/Hasbro Interactive/BattleShip SURFACE THUNDER"
INSTALL_DIR="$PREFIX/$INSTALL_REL"
LAUNCHER="$HOME/.local/bin/battleship-st"
DESKTOP_FILE="$HOME/.local/share/applications/battleship-st.desktop"

SRC=""
ASSUME_YES=0

while getopts ":ys:h" opt; do
  case "$opt" in
    y) ASSUME_YES=1 ;;
    s) SRC="$OPTARG" ;;
    h) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "Unknown option. Try -h." >&2; exit 2 ;;
  esac
done

# ----- helpers --------------------------------------------------------------
msg()  { printf '\033[1;36m[*]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[X]\033[0m %s\n' "$*" >&2; exit 1; }

confirm() {
  (( ASSUME_YES )) && return 0
  local ans
  read -rp "$1 [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

# Case-insensitive lookup of a file at a relative path inside a directory.
# Walks each segment so e.g. "Resource/Music.Mgf" matches "resource/music.mgf".
# Echoes the resolved absolute path; returns non-zero if any segment misses.
find_ci_path() {
  local base="$1" rel="$2"
  local current="$base"
  local seg hit
  local -a segments
  IFS='/' read -ra segments <<<"$rel"
  for seg in "${segments[@]}"; do
    [[ -z "$seg" ]] && continue
    hit="$(find "$current" -maxdepth 1 -mindepth 1 -iname "$seg" -print -quit 2>/dev/null)"
    [[ -n "$hit" ]] || return 1
    current="$hit"
  done
  printf '%s\n' "$current"
}

# Find music.mgf / movies.mgf — try CD layout first, fall back to flat layout.
locate_music()  { find_ci_path "$1" "resource/music.mgf"  || find_ci_path "$1" "music.mgf";          }
locate_movies() { find_ci_path "$1" "resource/movies.mgf" || find_ci_path "$1" "resource_movies.mgf"; }

is_bst_disc() {
  local d="$1"
  [[ -d "$d" ]] || return 1
  find_ci_path "$d" "data1.cab" >/dev/null || return 1
  locate_music  "$d" >/dev/null || return 1
  locate_movies "$d" >/dev/null || return 1
  return 0
}

# ----- 1. locate the disc --------------------------------------------------
if [[ -z "$SRC" ]]; then
  msg "Looking for a mounted Battleship: Surface Thunder disc..."
  for base in "/media/$USER" "/run/media/$USER" /media /mnt; do
    [[ -d "$base" ]] || continue
    while IFS= read -r -d '' d; do
      if is_bst_disc "$d"; then
        SRC="$d"
        break 2
      fi
    done < <(find "$base" -mindepth 1 -maxdepth 2 -type d -print0 2>/dev/null)
  done
  [[ -n "$SRC" ]] || die "Couldn't auto-find the disc. Pass it explicitly:
  $0 -y -s /media/$USER/SURFACETHUNDER"
fi

is_bst_disc "$SRC" || die "Doesn't look like the BST disc: $SRC
(needs data1.cab, plus music.mgf and movies.mgf either at root or inside resource/)"

ok "Disc found: $SRC"

DATA1_CAB="$(find_ci_path "$SRC" "data1.cab")"
MUSIC_MGF="$(locate_music  "$SRC")"
MOVIES_MGF="$(locate_movies "$SRC")"
BS2_ICO="$(find_ci_path    "$SRC" "bs2.ico"    2>/dev/null || true)"
README_TXT="$(find_ci_path "$SRC" "readme.txt" 2>/dev/null || true)"
README_HTM="$(find_ci_path "$SRC" "readme.htm" 2>/dev/null || true)"

# ----- 2. install host packages --------------------------------------------
need=()
command -v wine     >/dev/null 2>&1 || need+=(wine)
command -v unshield >/dev/null 2>&1 || need+=(unshield)
if [[ "$(uname -m)" == "x86_64" ]]; then
  if ! dpkg -s wine32 >/dev/null 2>&1 && ! dpkg -s wine32:i386 >/dev/null 2>&1; then
    need+=(wine32)
  fi
fi

if (( ${#need[@]} )); then
  msg "Need to install: ${need[*]}"
  if confirm "Run sudo apt to install these now?"; then
    sudo dpkg --add-architecture i386 >/dev/null 2>&1 || true
    sudo apt-get update
    for p in "${need[@]}"; do
      if [[ "$p" == "wine32" ]]; then
        sudo apt-get install -y wine32:i386 || sudo apt-get install -y wine32 || \
          warn "wine32 install failed — game will only work if Wine has 32-bit support already."
      else
        sudo apt-get install -y "$p"
      fi
    done
  else
    die "Cannot continue without required packages."
  fi
fi
ok "Host packages ready."

# ----- 3. create the Wine prefix -------------------------------------------
if [[ -d "$PREFIX" ]]; then
  warn "Existing prefix found at $PREFIX"
  if confirm "Wipe it and start fresh?"; then
    rm -rf "$PREFIX"
  else
    die "Aborted by user."
  fi
fi

msg "Creating 32-bit Wine prefix at $PREFIX"
export WINEPREFIX="$PREFIX"
export WINEARCH=win32
export WINEDLLOVERRIDES="mscoree=;mshtml="   # silence Mono / Gecko prompts
export WINEDEBUG=-all
mkdir -p "$(dirname "$PREFIX")"
wineboot --init >/dev/null 2>&1
ok "Prefix initialised."

msg "Setting Windows version → Windows 98"
wine reg add 'HKCU\Software\Wine' /v Version /t REG_SZ /d win98 /f >/dev/null 2>&1 || \
  warn "Could not set Wine version (non-fatal)."

# ----- 4. extract data1.cab ------------------------------------------------
msg "Extracting game files from $(basename "$DATA1_CAB") (~30 MB)"
mkdir -p "$INSTALL_DIR"
TMP_EXTRACT="$(mktemp -d)"
trap 'rm -rf "$TMP_EXTRACT"' EXIT
unshield -d "$TMP_EXTRACT" x "$DATA1_CAB" >/dev/null
cp -r "$TMP_EXTRACT"/Program_Executable_Files/. "$INSTALL_DIR"/
# Make sure everything is writable — uninstall and Wine save files need this.
chmod -R u+rwX "$INSTALL_DIR"
ok "Game files installed."

# ----- 5. copy music + movies into Resource\ ------------------------------
msg "Copying music + movies into Resource/ (~150 MB — slow from CD, be patient)"
mkdir -p "$INSTALL_DIR/Resource"
cp "$MUSIC_MGF"  "$INSTALL_DIR/Resource/Music.Mgf"
cp "$MOVIES_MGF" "$INSTALL_DIR/Resource/Movies.Mgf"
chmod u+rw "$INSTALL_DIR/Resource/Music.Mgf" "$INSTALL_DIR/Resource/Movies.Mgf"
ok "Resources copied."

[[ -n "$BS2_ICO"    ]] && cp "$BS2_ICO"    "$INSTALL_DIR/" || true
[[ -n "$README_TXT" ]] && cp "$README_TXT" "$INSTALL_DIR/" || true
[[ -n "$README_HTM" ]] && cp "$README_HTM" "$INSTALL_DIR/" || true

# ----- 6. registry entries the game expects --------------------------------
msg "Writing game registry keys"
RKEY='HKLM\Software\Hasbro Interactive\BattleShip SURFACE THUNDER\Setup'
WPATH='C:\Program Files\Hasbro Interactive\BattleShip SURFACE THUNDER'
wine reg add "$RKEY" /v Path       /t REG_SZ /d "$WPATH"  /f >/dev/null 2>&1
wine reg add "$RKEY" /v Version    /t REG_SZ /d "1.0"     /f >/dev/null 2>&1
wine reg add "$RKEY" /v LanguageID /t REG_SZ /d "English" /f >/dev/null 2>&1
ok "Registry keys written."

# ----- 7. launcher + desktop entry -----------------------------------------
mkdir -p "$(dirname "$LAUNCHER")" "$(dirname "$DESKTOP_FILE")"

cat > "$LAUNCHER" <<EOF
#!/usr/bin/env bash
# Auto-generated launcher for Battleship: Surface Thunder
export WINEPREFIX="$PREFIX"
export WINEARCH=win32
export WINEDEBUG=-all
cd "$INSTALL_DIR"
# If the intro video crashes Wine, run with -novideo:
#   battleship-st -novideo
exec wine Battleship2.exe "\$@"
EOF
chmod +x "$LAUNCHER"

ICON_LINE=""
[[ -f "$INSTALL_DIR/bs2.ico" ]] && ICON_LINE="Icon=$INSTALL_DIR/bs2.ico"

cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=Battleship: Surface Thunder
Comment=Hasbro Interactive (2000) — via Wine
Exec=$LAUNCHER
$ICON_LINE
Categories=Game;
Terminal=false
EOF

update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

ok "Launcher script:  $LAUNCHER"
ok "Menu entry:       $DESKTOP_FILE"

case ":$PATH:" in
  *":$HOME/.local/bin:"*) : ;;
  *) warn "$HOME/.local/bin is not on your PATH — add it to ~/.bashrc to launch by name." ;;
esac

# ----- 8. launch -----------------------------------------------------------
echo
ok "Install complete."
msg "Launching the game..."
echo
exec "$LAUNCHER"
