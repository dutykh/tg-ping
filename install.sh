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
#   ./install.sh --uninstall         remove the command and its completions
#   curl -fsSL https://raw.githubusercontent.com/dutykh/tg-ping/main/install.sh | bash

set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/dutykh/tg-ping/main"
PREFIX="${PREFIX:-$HOME/.local}"
UNINSTALL=0
NO_COMPLETION=0

say()  { printf '%s\n' "$*"; }
warn() { printf 'install.sh: %s\n' "$*" >&2; }
die()  { printf 'install.sh: error: %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<'EOS'
Installer for tg-ping.

  ./install.sh                     install into ~/.local/bin
  ./install.sh --prefix /usr/local install into /usr/local/bin (needs sudo)
  ./install.sh --uninstall         remove the command and its completions
  ./install.sh --no-completion     skip the bash and zsh completions
  curl -fsSL https://raw.githubusercontent.com/dutykh/tg-ping/main/install.sh | bash
EOS
}

while [ $# -gt 0 ]; do
    case "$1" in
        --prefix)
            [ $# -ge 2 ] || die "--prefix needs a folder, for example: --prefix /usr/local"
            PREFIX="$2"; shift 2 ;;
        --uninstall)      UNINSTALL=1; shift ;;
        --no-completion)  NO_COMPLETION=1; shift ;;
        -h|--help)        usage; exit 0 ;;
        *) die "unknown option: $1 (see --help)" ;;
    esac
done

BIN_DIR="$PREFIX/bin"
COMP_DIR="$PREFIX/share/bash-completion/completions"
ZSH_DIR="$PREFIX/share/zsh/site-functions"
TARGET="$BIN_DIR/tg-ping"

# A checkout is used only when this script runs from a file inside it. Piped
# into bash, the script has no file, and the current folder must not be
# mistaken for a checkout: the program is downloaded instead.
SOURCE_DIR=""
script="${BASH_SOURCE[0]:-}"
if [ -n "$script" ] && [ -f "$script" ]; then
    SOURCE_DIR=$(cd "$(dirname "$script")" && pwd)
fi

if [ "$UNINSTALL" -eq 1 ]; then
    removed=0
    if [ -f "$TARGET" ]; then
        rm -f "$TARGET" && say "removed $TARGET" && removed=1
    fi
    for candidate in "$COMP_DIR/tg-ping" "$ZSH_DIR/_tg-ping"; do
        if [ -f "$candidate" ]; then rm -f "$candidate" && say "removed $candidate"; fi
    done
    # The completion in the user's own folder serves whichever tg-ping is on
    # the PATH: it goes only when none is left.
    user_comp="${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions/tg-ping"
    if [ "$removed" -eq 1 ] && [ -f "$user_comp" ] && ! command -v tg-ping >/dev/null 2>&1; then
        rm -f "$user_comp" && say "removed $user_comp"
    fi
    [ "$removed" -eq 1 ] || warn "no tg-ping found in $BIN_DIR"
    say ""
    say "The settings in ${XDG_CONFIG_HOME:-$HOME/.config}/tg-ping were kept."
    say "Delete them by hand if you also want the credentials gone."
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
    tmp="$TARGET.tmp.$$"
    if ! curl -fsSL "$REPO_RAW/bin/tg-ping" -o "$tmp"; then
        rm -f "$tmp"
        die "download failed"
    fi
    if ! head -n1 "$tmp" | grep -q '^#!/usr/bin/env bash'; then
        rm -f "$tmp"
        die "the downloaded file does not look like tg-ping"
    fi
    mv "$tmp" "$TARGET"
    chmod 0755 "$TARGET"
    say "installed $TARGET"
fi

if [ "$NO_COMPLETION" -eq 0 ]; then
    user_comp="${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions"
    # Always mkdir the full completion path. "$PREFIX/share" being writable does
    # not mean bash-completion/completions already exists underneath it.
    if mkdir -p "$COMP_DIR" 2>/dev/null && [ -w "$COMP_DIR" ]; then
        "$TARGET" completion bash > "$COMP_DIR/tg-ping" 2>/dev/null &&
            say "bash completion installed in $COMP_DIR"
    elif mkdir -p "$user_comp" 2>/dev/null && [ -w "$user_comp" ]; then
        "$TARGET" completion bash > "$user_comp/tg-ping" 2>/dev/null &&
            say "bash completion installed in $user_comp"
    else
        warn "could not install the bash completion (no writable completions folder)"
    fi
    if mkdir -p "$ZSH_DIR" 2>/dev/null && [ -w "$ZSH_DIR" ]; then
        "$TARGET" completion zsh > "$ZSH_DIR/_tg-ping" 2>/dev/null &&
            say "zsh completion installed in $ZSH_DIR (add it to fpath if zsh does not see it)"
    fi
fi

case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *)
        say ""
        warn "$BIN_DIR is not on your PATH."
        say "Add it with:"
        say "    echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.bashrc"
        say "    source ~/.bashrc"
        ;;
esac

say ""
say "Next steps:"
say "    tg-ping init                        create the bot settings"
say "    tg-ping config set machine laptop   name this machine in every message"
say "    tg-ping doctor                      check that everything works"
say "    tg-ping 'hello'                     send your first message"
