# lib/common.sh — shared setup for bin/pve, bin/pct, bin/push, bin/pull.
# Sourced, never run directly.
#
# Resolves the repo even when the caller reached us through a symlink in
# ~/.local/bin, loads pve-tools.conf, and defines the one place that talks
# to the host.

_libdir=$(CDPATH= cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd)
here=$(dirname "$_libdir")

die() {
    printf '%s: %s\n' "${0##*/}" "$*" >&2
    exit 1
}

# Config precedence: environment > pve-tools.conf > pve-tools.conf.example.
# Both conf files use ${VAR:-default} so an exported variable still wins.
_conf=""
if [ -f "$here/pve-tools.conf" ]; then
    _conf="$here/pve-tools.conf"
elif [ -f "$here/pve-tools.conf.example" ]; then
    _conf="$here/pve-tools.conf.example"
    printf '%s: using the example host; copy pve-tools.conf.example to pve-tools.conf\n' "${0##*/}" >&2
fi
[ -n "$_conf" ] && . "$_conf"

: "${PVE_HOST:?PVE_HOST is unset: copy pve-tools.conf.example to pve-tools.conf}"
: "${PVE_SOCK:?PVE_SOCK is unset: copy pve-tools.conf.example to pve-tools.conf}"

# The socket the human opens. Never opened by these scripts.
open_hint() {
    printf 'open it first, as yourself:  ssh -M -S %s -fN %s\n' "$PVE_SOCK" "$PVE_HOST" >&2
}

# Fail closed: if the master is gone, stop. Without this ssh would silently
# open a NEW connection and sit waiting for a password nobody is watching.
require_master() {
    if ! ssh -S "$PVE_SOCK" -O check "$PVE_HOST" 2>/dev/null; then
        printf '%s: no live SSH master on %s\n' "${0##*/}" "$PVE_SOCK" >&2
        open_hint
        exit 90
    fi
}

# One call to the host over the existing master. -T: no tty, so output is raw.
pve_ssh() {
    ssh -S "$PVE_SOCK" -T -o BatchMode=yes -o ConnectTimeout=5 "$PVE_HOST" "$@"
}

# Quote one string so it survives arrival in a remote sh unchanged.
rq() { printf '%q' "$1"; }
