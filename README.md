# pve-tools

> **Superseded.** This repo is archived. The generalized successor is
> [`agent-ssh-tools`](https://github.com/Neil925/agent-ssh-tools) — same design,
> five commands (`sshq`, `pct`, `qm`, `push`, `pull`), a multi-target registry,
> full-VM support through the QEMU guest agent, and an offline test suite.
> Do not install this one; `pct`, `push` and `pull` here collide by name with
> the successor's.

Four commands that run work on a Proxmox host and its LXC guests, over an SSH
control socket that **a human** opened.

```
pve 'pct list'
pct 103 'ls -l /root'
push 103 stage/search.conf /etc/nginx/sites-available/search.conf
pull 100 /etc/nginx/sites-available/somehost.conf
```

## Why this exists

The alternative is pasting commands into a terminal panel and reading the screen
back. That path is lossy in measured ways: long input is silently truncated,
the first character of a burst is eaten, trailing newlines disappear, `pct exec`
stdout does not appear, and reading the screen re-sends the whole scrollback
every time. Over a control socket there are no keystrokes to mangle. Commands
stay short enough to review before they run, and output arrives as text.

## The invariant

**Only a person opens the connection.** Nothing here authenticates. If the socket
is not live, the scripts exit 90 and print the exact command you need:

```
pve: no live SSH master on /home/neil/.ssh/sockets/pve.sock
open it first, as yourself:  ssh -M -S /home/neil/.ssh/sockets/pve.sock -fN root@pve.example.internal
```

The socket convention is `~/.ssh/sockets/pve.sock`, mode-700 directory. Not
`/tmp`: systemd sweeps `/tmp` entries idle for 10 days, so a socket path there
silently stops working.

## Layout

```
pve-tools/
├── README.md
├── env.sh                  source it to put bin/ on PATH
├── install.sh              symlinks + bashrc line + dirs; idempotent
├── pve-tools.conf          real host + socket path — gitignored
├── pve-tools.conf.example  placeholders — committed
├── lib/common.sh           config load + the one function that talks to the host
├── bin/{pve,pct,push,pull}
├── docs/patterns.md        recipes, and the panel traps this removes
└── stage/                  files being pushed in — gitignored, created on install
```

## Setup

```
git clone https://github.com/Neil925/pve-tools.git
cd pve-tools
./install.sh
$EDITOR pve-tools.conf            # PVE_HOST, PVE_SOCK
```

Then, as yourself, once — this is the only authentication in the design:

```
ssh -M -S ~/.ssh/sockets/pve.sock -fN root@pve.example.internal
```

Smoke test:

```
pve 'pct list'
pct 103 'id'
```

The master survives until it is closed or the host reboots. Check with
`ssh -S "$PVE_SOCK" -O check "$PVE_HOST"`, close with `-O exit` instead of
`kill`, which can leave the remote session running.

## Commands

| Command | What it does |
|---|---|
| `pve '<cmd>'` | runs `<cmd>` in a shell on the **host** |
| `pct <vmid> '<cmd>'` | runs `<cmd>` in a shell inside the **container** |
| `push <vmid> <file\|-> <remote-path> [--mode 0600]` | streams a file in; mkdir -p, atomic, sets mode |
| `pull <vmid> <remote-path> [local-path]` | streams a file out to `stage/`; compares byte counts |

All four take one argument string in single quotes. Inside those single quotes
write whatever you like: double quotes, `$vars`, pipes, redirections, heredocs.

`pct` guarantees the `--` that Proxmox's `pct exec` needs, and puts your shell
inside the guest. `pct exec 103 -- printf x > /root/f` writes the file on the
**host**; `pct 103 'printf x > /root/f'` writes it in the **container**. That
single distinction caused most of the pain in the session that motivated this.

## `pct` and the real `pct`

This wrapper shares a name with Proxmox's own `pct`, deliberately, because it is
the shape people reach for. Two guards keep it honest:

- `install.sh` and `env.sh` put this directory at the **end** of PATH, so on a
  genuine Proxmox host `/usr/bin/pct` wins.
- it refuses unless argument 1 is numeric, so `pct list` fails loudly instead of
  quietly doing something else.

## Streaming files, not typing them

Files get authored locally, staged, then pushed in one piece:

```
push 103 stage/app.env /root/app/.env --mode 0600
push 100 stage/search.conf /etc/nginx/sites-available/search.conf --mode 0644
pull  100 /etc/nginx/sites-available/somehost.conf
```

`push` stages into a temp file on the guest and `install`s it, so a file appears
complete or not at all, and prints only mode and byte counts — never contents.
`pull` measures the remote size first and errors out if the local file is short.

## Secrets

- `pve-tools.conf` is gitignored; the committed example has placeholders.
- `stage/` is gitignored. A secret belongs in a staged file with mode 0600, or
  typed by a human. Never in a command line, a README, or chat.
- Neither `push` nor `pull` prints file contents, so piping a secret through
  them does not expose it.

## Exit codes

| Code | Meaning |
|---|---|
| 90 | no live master socket — a human must open it |
| 2 | usage error, including a non-numeric VMID |
| 1 | local failure (missing file, size mismatch, bad `--mode`) |
| other | the remote command's own status, passed through |

## Not here, on purpose

No connection handling, no credentials, no interactive shell wrapper, no writes
to Proxmox configuration. Changing a running stack stays a human decision; these
commands make the human's typing cheaper, not optional.

## TODO

- `qm` wrapper for full VMs. `qm terminal <vmid>` is interactive, so a VM
  counterpart needs a different shape than `pct`. Deferred deliberately.
- Optional `~/.ssh/config` snippet so a bare `ssh root@pve` reuses the master:
  set `ControlPath ~/.ssh/sockets/%r@%h-%p`, and leave `ControlMaster auto`
  **off** — otherwise a client can silently open a new master and prompt.
