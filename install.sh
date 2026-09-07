#!/usr/bin/env bash
#
# Installer for tg-ping.
#
# Author: Dr. Denys Dutykh (Mathematics Department, Khalifa University of
#         Science and Technology, Abu Dhabi, UAE).
#
# Usage:
#   ./install.sh                     install into ~/.local/bin
#   ./install.sh --prefix /usr/local install into /usr/local/bin (needs sudo)
#   ./install.sh --uninstall         remove the command and its completion
#   curl -fsSL https://raw.githubusercontent.com/dutykh/tg-ping/main/install.sh | bash

set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/dutykh/tg-ping/main"
PREFIX="${PREFIX:-$HOME/.local}"
UNINSTALL=0
NO_COMPLETION=0

while [ $# -gt 0 ]; do
    case "$1" in
        --prefix)         PREFIX="$2"; shift 2 ;;
        --uninstall)      UNINSTALL=1; shift ;;
        --no-completion)  NO_COMPLETION=1; shift ;;
        -h|--help)
            sed -n '3,12p' "$0" | sed -e 's/^# \{0,1\}//'
            exit 0 ;;
        *) printf 'install.sh: unknown option: %s\n' "$1" >&2; exit 2 ;;
    esac
done

BIN_DIR="$PREFIX/bin"
COMP_DIR="$PREFIX/share/bash-completion/completions"
TARGET="$BIN_DIR/tg-ping"
SOURCE_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd || echo "")

say()  { printf '%s\n' "$*"; }
warn() { printf 'install.sh: %s\n' "$*" >&2; }
die()  { printf 'install.sh: error: %s\n' "$*" >&2; exit 1; }

if [ "$UNINSTALL" -eq 1 ]; then
    removed=0
    for candidate in "$TARGET" "$HOME/.local/bin/tg-ping" "/usr/local/bin/tg-ping"; do
        if [ -f "$candidate" ]; then
            rm -f "$candidate" && say "removed $candidate" && removed=1
        fi
    done
    for candidate in "$COMP_DIR/tg-ping" \
                     "${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions/tg-ping"; do
        [ -f "$candidate" ] && rm -f "$candidate" && say "removed $candidate"
    done
    [ "$removed" -eq 1 ] || warn "nothing to remove"
    say ""
    say "The configuration in ${XDG_CONFIG_HOME:-$HOME/.config}/tg-ping was kept."
    say "Delete it by hand if you also want the credentials gone."
    exit 0
fi

command -v curl >/dev/null 2>&1 || die "curl is required. Install it with: sudo apt install -y curl"

mkdir -p "$BIN_DIR" || die "cannot create $BIN_DIR"

if [ -n "$SOURCE_DIR" ] && [ -f "$SOURCE_DIR/bin/tg-ping" ]; then
    install -m 0755 "$SOURCE_DIR/bin/tg-ping" "$TARGET" 2>/dev/null ||
        { cp "$SOURCE_DIR/bin/tg-ping" "$TARGET" && chmod 0755 "$TARGET"; }
    say "installed $TARGET from this checkout"
else
    say "downloading tg-ping from $REPO_RAW"
    curl -fsSL "$REPO_RAW/bin/tg-ping" -o "$TARGET.tmp" || die "download failed"
    head -n1 "$TARGET.tmp" | grep -q '^#!/usr/bin/env bash' || die "the downloaded file does not look like tg-ping"
    mv "$TARGET.tmp" "$TARGET"
    chmod 0755 "$TARGET"
    say "installed $TARGET"
fi

if [ "$NO_COMPLETION" -eq 0 ]; then
    user_comp="${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions"
    if [ -w "$PREFIX/share" ] 2>/dev/null || mkdir -p "$COMP_DIR" 2>/dev/null; then
        "$TARGET" completion bash > "$COMP_DIR/tg-ping" 2>/dev/null &&
            say "bash completion installed in $COMP_DIR"
    elif mkdir -p "$user_comp" 2>/dev/null; then
        "$TARGET" completion bash > "$user_comp/tg-ping" 2>/dev/null &&
            say "bash completion installed in $user_comp"
    fi
fi

case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *)
        say ""
        warn "$BIN_DIR is not on your PATH."
        say "Add it with:"
        say "    echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
        say "    source ~/.bashrc"
        ;;
esac

say ""
say "Next steps:"
say "    tg-ping init      create the bot configuration"
say "    tg-ping doctor    check that everything works"
say "    tg-ping 'hello'   send your first message"
