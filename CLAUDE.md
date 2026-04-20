# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Two bash scripts and a README. No build system, no package manager, no test harness — everything ships as a single executable.

- `install_tak.sh` — monolithic installer (~2200 lines). Runs on a Debian/Ubuntu LTS host and installs TAK Server 5.7 + PostgreSQL 15 + PKI + MediaMTX + Mumble + Node-RED + RagTAK Admin Panel + optional OpenVPN + UFW rules.
- `reset_vps.sh` — companion script that tears everything `install_tak.sh` installs back to a clean Ubuntu base. Keep its sections aligned with the installer when you add new components.
- `README.md` — end-user documentation. The `## Customisation` table of env vars and the VPS port table are the contract — keep them in sync with the actual `ufw allow` rules and `"${VAR:-default}"` lines in the script.

## Running / testing

There is no unit-test suite. The only way to test a change is end-to-end on a disposable Linux VM:

```bash
# On a fresh Debian/Ubuntu LTS VM with the takserver .deb in the same dir:
sudo bash install_tak.sh
# To test iteratively, wipe and re-run:
sudo bash reset_vps.sh && sudo bash install_tak.sh
```

Useful non-interactive env overrides when iterating:
- `INSTALL_OPENVPN=yes|no` — skip the interactive prompt
- `DOMAIN=tak.example.com` — trigger the Let's Encrypt path
- `SKIP_MEDIAMTX=1` — skip video server on slow hosts
- `DB_PASS=…`, `CERT_PASS=…`, `TAKADMIN_PASS=…`, `NODERED_PASS=…` — pin credentials for reproducible runs

Shell-level sanity check without running: `bash -n install_tak.sh` (syntax) and `shellcheck install_tak.sh` (lint) if available.

## Architecture of `install_tak.sh`

The script is laid out as numbered sections (grep `^# ─── N\.` to jump between them). Order matters — later sections assume earlier ones completed.

1. Pre-flight — root check, non-LTS Ubuntu warning, public IP discovery, `INSTALL_OPENVPN` prompt, locating the `takserver*.deb`.
2. Docker port-conflict cleanup.
3. PostgreSQL 15 apt repo (must run **before** the first `apt-get update` — TAK 5.7 requires PG15 even on Ubuntu 24.04 which ships PG16).
4. Base deps + Java 17 + PG15 + PostGIS.
5. Pin PG15 to port 5432, stop PG16 if present.
6. `dpkg -i` the TAK .deb. Skip re-install when the exact version is already present — re-running `dpkg` on an already-installed TAK package wipes `CoreConfig.xml`.
7. Create TAK DB and user manually (TAK's own `setup-db.sh` fails on Linux Mint / pg_wrapper), then patch `CoreConfig.xml` with the generated DB password.
8. PKI generation via TAK's own `makeRootCa.sh` / `makeCert.sh`. Existing `*.p12` / `*.jks` are wiped first to prevent keytool "alias already exists" prompts on re-run. Certs copied to `${SCRIPT_DIR}/certs/` and auto-imported into Firefox for the invoking user.
9. Let's Encrypt (optional, non-fatal — falls back to self-signed). Writes a renewal deploy hook at `/etc/letsencrypt/renewal-hooks/deploy/takserver.sh` that regenerates the TAK PKCS12 on each renewal.
10. MediaMTX (download binary tarball; systemd unit).
11. Mumble (apt package; custom `/etc/mumble-server.ini`).
12. Node-RED (NodeSource LTS + global npm install; dedicated `nodered` user; systemd unit).
13. **RagTAK Admin Panel** — a full Python/Flask web app embedded as a `<<'PYEOF'` heredoc (≈ lines 972–1875). See below.
14. OpenVPN (easy-rsa PKI, inline-cert `.ovpn` files, NAT masquerade installed via UFW's `before.rules` rather than `iptables-persistent` because the latter removes UFW on Ubuntu 24.04).
15. UFW rules — two completely different rule sets depending on `INSTALL_OPENVPN` (VPN-only: only SSH + 1194 exposed to internet; services scoped to `${OPENVPN_SUBNET}.0/24`).
16. Start TAK, wait up to 90 s for `:8089` to listen.
17. Register admin cert with `UserManager.jar certmod -A`.
18. Summary output (the "save this" block the user is told to capture from the README).

### The embedded Flask admin panel

The Python source is written verbatim to `/opt/takadmin/takadmin.py` by a single heredoc. Notes that aren't obvious from reading it:

- Runs as root (needs `systemctl restart`, `UserManager.jar`, access to `/opt/tak/certs/files`).
- All runtime config comes from systemd `Environment=…` lines in `/etc/systemd/system/takadmin.service` — edit the heredoc at both the Python side (`os.environ.get(...)`) and the systemd unit when adding new config.
- `_share_tokens` is an in-process dict for the QR-code single-use download feature (15-min TTL, purged by a daemon thread). It does not survive restarts — acceptable, tokens are short-lived by design.
- When `OPENVPN_INSTALLED` is set, the panel advertises `VPN_IP` (`10.8.0.1`) in bundle READMEs and download links rather than the public IP, because services are unreachable from the internet in that mode.
- `_PROTECTED_USERS` prevents deleting the system certs (`takserver`, `tak-admin`, `root-ca`, `truststore-root`).
- Username validation is `[a-zA-Z0-9_-]{1,32}` and is applied at **every** entry point that feeds a shell/filename (create, delete, bundle download, share token). Preserve this when adding new routes — user input flows into `bash makeCert.sh` and into `zipfile` paths.

## Conventions to follow when editing

- **Idempotency is the bar.** Every section must be safe to re-run after a partial failure. Check existing state before destructive operations (see the `dpkg -l takserver` guard in §6, the keystore wipe in §8, the `grep -q` check before appending to `pg_hba.conf` in §7).
- **Fail fast at the top, degrade gracefully below.** The pre-flight dies if root/apt/.deb/public-IP aren't available. Once the install is underway, prefer `warn` + continue over `die` for non-critical services (Let's Encrypt, Firefox cert import, MediaMTX download, etc.) so a partial install still produces something useful.
- **Mirror additions in `reset_vps.sh`.** If you install a new package, systemd unit, or state dir, add the corresponding purge/rm to the matching numbered section of the reset script. Stop services first (it already kills `tak` processes before `dpkg --purge` because `userdel` in the postrm fails otherwise).
- **Update three things together** when you add a new port: the `ufw allow` rules (both VPN and non-VPN branches of §15), the port table in `README.md`, and the banner comment at the top of `install_tak.sh`.
- **Env-var defaults use `${VAR:-default}`** and are documented in the Customisation table of the README. Add new ones at the top of the script in the "Configuration" block, not inline.
- **TAK-specific constraints that look wrong but aren't:** server cert CN must be `takserver` (matches `CoreConfig.xml` default); DB user must be `martiuser`; DB name must be `cot`; cert password default is `atakatak` (hardcoded in ATAK docs — don't change the default even though it's weak).
- **Heredoc quoting matters.** `<<'EOF'` disables shell expansion (use when the content is a verbatim config file or Python source); unquoted `<<EOF` expands `${VAR}` (use when baking install-time values into a generated file). Several bugs in history have come from getting this wrong — double-check when editing the Python `PYEOF` block or the systemd unit heredocs.

## Commit style

Short imperative subject, no body unless needed. Scope prefix is optional but common (`Fix …`, `Add …`, `README: …`). Examples from recent history:

```
Add delete user to admin panel Users page
Fix qrcode install: try apt before pip3
README: note iTAK uses same certs and steps as ATAK
```
