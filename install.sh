#!/usr/bin/env bash
# install.sh — make pve-tools usable from any shell on this machine.
#
#   ./install.sh
#
# Does four things, all idempotent: creates the socket directory, writes a
# per-machine pve-tools.conf if one is missing, symlinks bin/* into
# ~/.local/bin, and adds one source line to ~/.bashrc.
#
# It does not touch ~/.ssh/config, does not open any connection, and does not
# install anything system-wide.
set -euo pipefail

here=$(CDPATH= cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd)

bindir=$HOME/.local/bin
sockdir=$HOME/.ssh/sockets

install -d -m 700 "$sockdir"
echo "socket dir   $sockdir"

install -d "$bindir"
for cmd in pve pct push pull; do
    ln -sfn "$here/bin/$cmd" "$bindir/$cmd"
    echo "linked       $bindir/$cmd"
done

if [ ! -f "$here/pve-tools.conf" ]; then
    install -m 600 "$here/pve-tools.conf.example" "$here/pve-tools.conf"
    echo "config       EDIT THIS BEFORE USE: $here/pve-tools.conf"
else
    echo "config       kept: $here/pve-tools.conf"
fi

install -d "$here/stage"
echo "stage dir    $here/stage (gitignored)"

marker='# pve-tools (added by install.sh)'
rc=$HOME/.bashrc
if [ -f "$rc" ] && grep -qF "$marker" "$rc"; then
    echo "bashrc       already sourced"
else
    {
        printf '\n%s\n' "$marker"
        printf '. "%s/env.sh"\n' "$here"
    } >> "$rc"
    echo "bashrc       sourced from $rc"
fi

echo
echo "next: edit pve-tools.conf, then open the control socket yourself —"
. "$here/pve-tools.conf" 2>/dev/null || . "$here/pve-tools.conf.example"
printf '  ssh -M -S %s -fN %s\n' "$PVE_SOCK" "$PVE_HOST"
printf 'then smoke test:  pct list  ->  pct 103 %s\n' "'id'"
