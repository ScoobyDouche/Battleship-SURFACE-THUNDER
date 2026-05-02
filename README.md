# Battleship: Surface Thunder — Linux installer

Automated installer for *Battleship: Surface Thunder* (Hasbro Interactive, 2000) on Linux Mint, Ubuntu, and Debian via Wine. Bypasses InstallShield with `unshield`, extracts straight into a dedicated 32-bit Wine prefix, writes the registry keys the game expects, and builds a fake CD-ROM drive so the disc is never needed again. One command from disc to playable.

## What's in here

`install-battleship-st.sh` does the install and launches the game. `fix-cd-check.sh` builds a permanent fake CD-ROM drive so you don't need the disc to play. Run them in that order.

## Requirements

A 64-bit Linux Mint, Ubuntu, or Debian system with `sudo` access. The first run will install `wine`, `unshield`, and `wine32:i386` if any are missing, enabling the `i386` foreign architecture along the way. You also need the original *Battleship: Surface Thunder* CD inserted — on a default Mint desktop this auto-mounts at `/media/$USER/SURFACETHUNDER`. The disc is needed for the install and once more when running the no-CD fix; after that, never again.

## Usage

Insert the disc and let it auto-mount, then from the directory containing the scripts:

```bash
chmod +x install-battleship-st.sh fix-cd-check.sh
./install-battleship-st.sh -y
./fix-cd-check.sh
```

The first script handles everything from dependency install through launching the game. If the game complains that the disc is required (this build does runtime CD-presence checking), quit and run the second script — with the disc still inserted — to set up the permanent fake CD. From then on, `battleship-st` from a terminal or "Battleship: Surface Thunder" from your application menu will start the game with no disc needed.

If the auto-detect fails to find the mounted disc, pass it explicitly:

```bash
./install-battleship-st.sh -y -s /media/$USER/SURFACETHUNDER
./fix-cd-check.sh           -s /media/$USER/SURFACETHUNDER
```

## Under the hood

The installer scans `/media/$USER/`, `/run/media/$USER/`, `/media/`, and `/mnt/` looking for a directory containing `data1.cab` plus `music.mgf`. Filename matching is case-insensitive and works whether the audio and video files are at the disc root or nested in a `resource/` subfolder — which they are, on the actual pressed CD. Once it locates the disc, it creates a fresh 32-bit Wine prefix at `~/.local/share/wineprefixes/battleship-st`, sets the reported Windows version to Win98, and uses `unshield` to extract `data1.cab` (the InstallShield archive containing `Battleship2.exe`, `binkw32.dll` for Bink video playback, and the game data files) directly into the prefix. The music and movies are copied off the CD into a `Resource/` subdirectory next to the executable, where the game looks for them at runtime. Three values get written under `HKLM\Software\Hasbro Interactive\BattleShip SURFACE THUNDER\Setup` so the game finds its install path on startup. A launcher lands at `~/.local/bin/battleship-st` and a `.desktop` entry in `~/.local/share/applications/`.

The CD-fix script builds a "fake CD" directory at `<prefix>/fake-cd` that mirrors the real disc layout — small files copied verbatim, the giant `Music.Mgf` and `Movies.Mgf` symlinked back to the install dir to save ~150 MB of disk. A `.windows-label` file is written containing `SURFACETHUNDER` so Wine reports the correct volume label to anything that asks. The fake-cd folder is symlinked into Wine's `dosdevices/` as drive D:, and a registry value under `HKLM\Software\Wine\Drives` registers it as type `cdrom`. From the game's perspective, the disc is permanently in the drive.

## File locations

Everything lives under your home directory. The Wine prefix is `~/.local/share/wineprefixes/battleship-st/`, with the game installed at `<prefix>/drive_c/Program Files/Hasbro Interactive/BattleShip SURFACE THUNDER/` and the fake CD at `<prefix>/fake-cd/`. The launcher script is `~/.local/bin/battleship-st` and the desktop menu entry is `~/.local/share/applications/battleship-st.desktop`. Set `BST_PREFIX` in the environment before running either script if you want a different prefix path.

## Troubleshooting

If the intro video crashes Wine on launch (a common issue with late-90s Bink games), run `battleship-st -novideo` to skip it — the flag is documented in the original game's readme.

If display behavior is weird (mouse trapped, wrong resolution, blank screen), try running the game inside a Wine virtual desktop. Edit `~/.local/bin/battleship-st` and replace the final `exec` line with:

```bash
exec wine explorer /desktop=bst,1024x768 Battleship2.exe "$@"
```

To start over from scratch — useful if something gets into a weird state — wipe the prefix and re-run the installer with the disc inserted:

```bash
rm -rf ~/.local/share/wineprefixes/battleship-st
./install-battleship-st.sh -y
./fix-cd-check.sh
```

## Uninstall

Remove the prefix, the launcher, and the menu entry, then refresh the desktop database. The `chmod` step is needed because some files copied off the CD inherit its read-only mode, which blocks `rm -rf` from removing the directory tree:

```bash
chmod -R u+w ~/.local/share/wineprefixes/battleship-st
rm -rf ~/.local/share/wineprefixes/battleship-st
rm -f ~/.local/bin/battleship-st
rm -f ~/.local/share/applications/battleship-st.desktop
update-desktop-database ~/.local/share/applications 2>/dev/null
```

## Notes

These scripts assume you own the original CD. Nothing here patches the game binary; the no-CD setup works by exposing a synthetic Wine drive that satisfies the runtime CD-presence check. Wine version requirements are loose — anything from the last several years should work.
