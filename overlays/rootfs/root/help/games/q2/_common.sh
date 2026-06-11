#!/bin/bash
# Common functions for Quake II install scripts.
# Sourced by install-kmsdrm.sh, install-kmsdrm-sdl3.sh, install-vulkan.sh.

HELPDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

download_shareware() {
  local Q2DIR="$1"
  [ -f "$Q2DIR/pak0.pak" ] && return 0
  echo "Downloading Quake II shareware demo..."
  local TMPDIR
  TMPDIR=$(mktemp -d)
  cd "$TMPDIR"
  wget -q --show-progress -O q2-demo.zip \
    "https://deponie.yamagi.org/quake2/idstuff/q2-314-demo-x86.exe" 2>&1 || \
  wget -q --show-progress -O q2-demo.zip \
    "https://archive.org/download/quake-2-demo/q2-314-demo-x86.exe" 2>&1 || true
  if [ -f q2-demo.zip ]; then
    mkdir -p extracted
    unzip -o -j q2-demo.zip 'Install/Data/baseq2/*' -d extracted/ 2>/dev/null || \
    unzip -o -j q2-demo.zip '*/baseq2/*' -d extracted/ 2>/dev/null || true
    cp extracted/*.pak "$Q2DIR/" 2>/dev/null || true
  fi
  cd /
  rm -rf "$TMPDIR"
}

print_game_status() {
  local INSTALLDIR="$1"
  local Q2DIR="$INSTALLDIR/baseq2"
  if [ -f "$Q2DIR/pak0.pak" ]; then
    echo "Game data: $(ls "$Q2DIR"/*.pak 2>/dev/null | wc -l) pak file(s) in $Q2DIR/"
  else
    echo "WARNING: No game data found."
    echo ""
    echo "Next steps — copy game files to $Q2DIR/:"
    echo "  # From GOG (on PC):"
    echo "  innoextract setup_quake2*.exe"
    echo "  scp -r game/baseq2/* root@<board-ip>:$Q2DIR/"
    echo ""
    echo "  # From Steam (on PC):"
    echo "  scp -r ~/.local/share/Steam/steamapps/common/Quake\\ 2/baseq2/* root@<board-ip>:$Q2DIR/"
    echo ""
    echo "  # Shareware demo (auto-downloaded if available)"
    echo "  # Includes pak0.pak with first few levels"
  fi
}

create_desktop_entry() {
  local NAME="$1"
  local COMMENT="$2"
  local EXEC="$3"
  local FILENAME="$4"
  local TERMINAL="${5:-false}"
  mkdir -p /usr/share/applications
  cat > "/usr/share/applications/${FILENAME}.desktop" << EOF
[Desktop Entry]
Name=$NAME
Comment=$COMMENT
Exec=$EXEC
Terminal=$TERMINAL
Type=Application
Categories=Game;ActionGame;
Icon=applications-games
EOF
}
