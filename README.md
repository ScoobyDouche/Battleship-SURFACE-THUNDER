Too lazy to proofread soo might be errors in this README file also let me know if my private directories are showing and of course where the errors in this file are

Battleship: Surface Thunder — Linux Installer

Automated installer for Battleship: Surface Thunder (Hasbro Interactive, 2000) on Linux Mint, Ubuntu, and Debian via Wine.

This script bypasses the legacy InstallShield wizard using unshield, extracts files into a dedicated 32-bit Wine prefix, writes the necessary registry keys, and builds a synthetic CD-ROM drive so the physical disc is no longer required after setup. One command from disc to playable.
What's in here

    install-battleship-st.sh: Handles dependency installation, file extraction, and the initial launch.

    fix-cd-check.sh: Builds a permanent "fake" CD-ROM drive to satisfy runtime disc checks.

Requirements

    OS: 64-bit Linux Mint, Ubuntu, or Debian.

    Privileges: sudo access. The script will install wine, unshield, and wine32:i386, enabling the i386 foreign architecture if necessary.

    Media: Original Battleship: Surface Thunder CD. On a default desktop, this usually auto-mounts at /media/$USER/SURFACETHUNDER.

Usage

    Insert the disc and let it auto-mount.

    From the directory containing the scripts, run:

Bash

chmod +x install-battleship-st.sh fix-cd-check.sh
./install-battleship-st.sh -y
./fix-cd-check.sh

The first script handles the installation and initial launch. If the game complains that the disc is required, quit and run the second script—with the disc still inserted—to set up the permanent fake CD. From then on, you can launch from your application menu with no disc needed.
Manual Mount Point

If the scripts fail to auto-detect your CD, pass the path explicitly:
Bash

./install-battleship-st.sh -y -s /media/$USER/SURFACETHUNDER
./fix-cd-check.sh           -s /media/$USER/SURFACETHUNDER

Under the Hood
The Installer

The script scans for data1.cab and music.mgf (case-insensitive). Once found, it:

    Creates a 32-bit Wine prefix at ~/.local/share/wineprefixes/battleship-st.

    Sets the Wine environment to Windows 98.

    Uses unshield to extract the game files directly into the prefix.

    Copies music and movies into the local Resource/ directory.

    Injects registry keys under HKLM\Software\Hasbro Interactive\BattleShip SURFACE THUNDER\Setup so the game finds its assets.

The No-CD Fix

To bypass runtime disc checks:

    It creates a folder at <prefix>/fake-cd mirroring the disc layout.

    Large media files are symlinked back to the install directory to save ~150 MB of space.

    It writes a .windows-label file and registers the folder as a cdrom drive in the Wine registry.

Troubleshooting

    Intro Video Crash: If the game crashes on startup, launch with: battleship-st -novideo.

    Display Issues: If the resolution is buggy, try a Wine Virtual Desktop. Edit ~/.local/bin/battleship-st and change the final line to:
    exec wine explorer /desktop=bst,1024x768 Battleship2.exe "$@"

    Clean Slate: To wipe everything and restart the install:
    rm -rf ~/.local/share/wineprefixes/battleship-st

Uninstall
Bash

rm -rf ~/.local/share/wineprefixes/battleship-st
rm -f ~/.local/bin/battleship-st
rm -f ~/.local/share/applications/battleship-st.desktop
update-desktop-database ~/.local/share/applications 2>/dev/null

Notes

These scripts assume you own the original CD. Nothing here patches the game binary; the no-CD setup works by exposing a synthetic Wine drive that satisfies the runtime CD-presence check. Wine version requirements are loose—anything from the last several years should work.
