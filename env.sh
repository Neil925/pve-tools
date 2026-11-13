# env.sh — source this to get pve, pct, push and pull on PATH.
#
#   . ~/Source/pve-tools/env.sh
#
# Normally unnecessary: install.sh symlinks the four commands into ~/.local/bin,
# which is already on PATH. Use this for a shell that does not have them, or for
# a one-off session where you do not want to install anything.
#
# PATH is APPENDED, not prepended. On a real Proxmox host that keeps the genuine
# /usr/bin/pct ahead of this wrapper, so the wrapper can never shadow it.

_tools=$(CDPATH= cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd)

case ":$PATH:" in
    *":$_tools/bin:"*) ;;
    *) PATH=$PATH:$_tools/bin ;;
esac
export PATH

if [ -f "$_tools/pve-tools.conf" ]; then
    . "$_tools/pve-tools.conf"
elif [ -f "$_tools/pve-tools.conf.example" ]; then
    . "$_tools/pve-tools.conf.example"
fi
export PVE_HOST PVE_SOCK

unset _tools
