# Patterns

Recipes that work over these commands, and the panel failure modes they replace.

## Panel traps, and what removes each

| Trap when typing into a terminal panel | Why it cannot happen here |
|---|---|
| Long input silently truncated (~1300 chars lost, no error) | `push` sends bytes on stdin; keystroke length is not a limit |
| First character of each burst eaten | nothing is typed |
| Trailing newline lost, last command sits unexecuted | nothing is typed; each call is one complete argv |
| `pct exec` child stdout never appears | output returns on the ssh channel; verified against 100 and 103 |
| Redirects run on the host you typed into, not in the container | `pct <vmid> '<cmd>'` wraps the command in `sh -c` inside the guest |
| `pct` parsing container flags as its own | `--` is always inserted |
| Screen read lags one command behind and re-sends the whole scrollback | output is captured once, per call |
| Closing the panel only detaches; the PTY and its scrollback survive | one call, one process, no scrollback to leak |

## Read a big remote file

Do not `cat` a 300-line file into a screen. Pull it and read it properly:

```
pull 100 /etc/nginx/sites-available/somehost.conf
```

Lands in `stage/somehost.conf`, byte count checked against the remote size. If
you only need a window, slice on the far side instead:

```
pct 100 'sed -n "1,60p" /etc/nginx/sites-available/somehost.conf'
pct 103 'grep -n "limiter\|formats" /root/app/core-config/settings.yml'
```

## Write a config file

Author locally where it can be read back and diffed, then push:

```
push 103 stage/docker-compose.override.yml /root/stack/docker-compose.override.yml --mode 0644
pct 103 'cd /root/stack && docker compose config --quiet && echo ok'
```

Validate before starting. Compose merges `docker-compose.override.yml`
automatically, which is the usual place for resource caps.

## Secrets

Stage the file, never the command line, and let a human own the credential:

```
push 103 stage/api-token.env /root/stack/.env --mode 0600
pct 103 'stat -c "%a %s %n" /root/stack/.env'
pct 103 'cut -d= -f1 /root/stack/.env'      # key names only, never values
```

`push` and `pull` print modes and byte counts, never contents. `chmod 600`
`stage/*` if a secret has to sit locally between steps.

## Service bring-up, reviewed in pieces

```
pct 103 'cd /root/stack && docker compose up -d'
pct 103 'docker ps --filter name=app --format "{{.Names}} {{.Status}}"'
pct 103 'cd /root/stack && docker compose logs --tail 30 app'
pct 103 'free -m; df -h / | tail -1'
```

## Probe a service before its DNS exists

Reach the front door by IP and fake the hostname, so a vhost can be proven
without publishing a name:

```
pct 100 'curl -sk -o /dev/null -w "%{http_code}\n" https://127.0.0.1/ -H "Host: app.example.internal"'
pct 100 'curl -sk "https://127.0.0.1/search?q=test&format=json" -H "Host: app.example.internal" | head -c 300'
```

## Read-only against a running stack, writes by a human

Reviewing another container is safe and routine:

```
pct 100 'cat /etc/nginx/conf.d/upstreams.conf'
pct 100 'nginx -t'
```

Applying a change to something already serving traffic is a different class of
action — plan it, show the diff, let the person decide when it lands.

## Reverse direction: what never goes in a script here

Proxmox host configuration (`pct set`, `qm set`, storage, network), firewall
rules, DNS records, and anything that deletes data. `pve` can run them; whether
it should is a human call, which is why every call shows up as an approval card.
