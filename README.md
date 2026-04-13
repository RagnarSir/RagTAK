# TAKStack

Automated TAK Server installation script for Ubuntu 22.04 / 24.04, Debian, and Linux Mint.

## What it installs

| Component | Purpose |
|-----------|---------|
| TAK Server 5.7 | Tactical awareness server (CoT, mission packages, data sync) |
| PostgreSQL 15 + PostGIS | Database backend |
| Java 17 | TAK Server runtime |
| Full PKI | Self-signed CA, server cert, admin cert, 5 client certs |
| Let's Encrypt | Optional trusted SSL certificate (set `DOMAIN=`) |
| MediaMTX | RTSP / HLS / WebRTC video streaming |
| Mumble | Low-latency voice communications |
| Node-RED | Flow-based automation and TAK data integration |
| WireGuard | VPN tunnel — client configs and QR codes generated automatically |
| UFW | Firewall configured for all services |

---

## Prerequisites

1. Create a free account at [tak.gov](https://tak.gov)
2. Download the TAK Server package: `takserver_5.7-RELEASE8_all.deb`
3. Place the `.deb` in the same directory as `install_tak.sh`

---

## Usage

### Basic install (self-signed certificates)
```bash
sudo bash install_tak.sh
```

### With Let's Encrypt (requires a domain pointed at the server)
```bash
DOMAIN=tak.example.com sudo bash install_tak.sh
```

### With Let's Encrypt + email notifications
```bash
DOMAIN=tak.example.com LE_EMAIL=you@example.com sudo bash install_tak.sh
```

### Custom options
All options can be combined:
```bash
DOMAIN=tak.example.com \
MUMBLE_SERVER_NAME="My Unit" \
MUMBLE_PASS="voicepassword" \
NODERED_USER=admin \
NODERED_PASS=mypassword \
sudo bash install_tak.sh
```

---

## Configuration variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DOMAIN` | *(empty)* | Domain name — enables Let's Encrypt |
| `LE_EMAIL` | *(empty)* | Email for Let's Encrypt expiry notifications |
| `CERT_PASS` | `atakatak` | Password for all PKI certificates |
| `MUMBLE_SERVER_NAME` | `TAK Mumble` | Mumble server display name |
| `MUMBLE_PASS` | *(empty)* | Mumble server password (empty = no password) |
| `MUMBLE_MAX_USERS` | `50` | Maximum simultaneous Mumble users |
| `NODERED_USER` | `admin` | Node-RED admin username |
| `NODERED_PASS` | *(auto-generated)* | Node-RED admin password |
| `WG_PORT` | `51820` | WireGuard listen port |
| `WG_SUBNET` | `10.13.13` | WireGuard VPN subnet (/24) |
| `WG_DNS` | `1.1.1.1` | DNS server pushed to WireGuard clients |

---

## Ports

| Port | Protocol | Service |
|------|----------|---------|
| 8089 | TCP | ATAK / WinTAK CoT (SSL) |
| 8443 | TCP | TAK web admin |
| 8446 | TCP | Certificate enrollment |
| 8554 | TCP/UDP | MediaMTX RTSP video |
| 8888 | TCP | MediaMTX HLS video |
| 8889 | TCP | MediaMTX WebRTC video |
| 64738 | TCP/UDP | Mumble voice |
| 1880 | TCP | Node-RED UI |
| 51820 | UDP | WireGuard VPN |

> **VPS users:** Open all required ports in your provider's firewall (AWS Security Groups, DigitalOcean Firewall, etc.) in addition to the UFW rules the script configures.

---

## Connecting clients

### ATAK (Android)
**Without Let's Encrypt:**
- Trust Store: `truststore-root.p12` — password: `atakatak`
- Client Cert: `client1.p12` — password: `atakatak`
- Server: `ssl://<server-ip>:8089`

**With Let's Encrypt:**
- Client Cert: `client1.p12` — password: `atakatak`
- Server: `ssl://<your-domain>:8089`
- No trust store needed

Use a separate client cert per device (`client1` through `client5`).

### WinTAK (Windows)
Same as ATAK. Create a named user account:
```bash
sudo java -jar /opt/tak/utils/UserManager.jar usermod -A -p 'YourPassword' WinTAK
```

### Mumble
Connect to `<server>:64738` with any Mumble client. The SuperUser password is printed at the end of the install.

### Node-RED
Open `http://<server>:1880` — credentials printed at end of install.

### WireGuard
Client configs and QR codes are written to the install directory:

| File | Device |
|------|--------|
| `wg-tak-admin.conf` / `.png` | Admin workstation |
| `wg-client1.conf` / `.png` | ATAK device 1 |
| `wg-client2.conf` / `.png` | ATAK device 2 |
| `wg-wintak.conf` / `.png` | WinTAK workstation |

- **Android / iOS:** Scan the `.png` QR code in the WireGuard app
- **Windows / Linux:** Import the `.conf` file in the WireGuard client

Once connected, reach TAK at `10.13.13.1` instead of the public IP.

---

## Web admin

Import into Firefox before opening the admin UI:
1. **Authorities tab** → import `root-ca.pem` → trust for websites
2. **Your Certificates tab** → import `tak-admin.p12` → password: `atakatak`

Then open: `https://<server>:8443`

> With Let's Encrypt, only `tak-admin.p12` needs to be imported.

---

## Logs

```bash
sudo tail -f /opt/tak/logs/takserver-messaging.log
sudo journalctl -u mumble-server -f
sudo journalctl -u node-red -f
sudo journalctl -u wg-quick@wg0 -f
```

## Clean reinstall

```bash
sudo systemctl stop takserver mediamtx mumble-server node-red wg-quick@wg0
sudo apt-get purge -y takserver mumble-server
sudo rm -rf /opt/tak
sudo -u postgres dropdb --if-exists cot
sudo -u postgres dropuser --if-exists martiuser
sudo npm uninstall -g node-red
sudo userdel -r nodered 2>/dev/null || true
sudo rm -rf /etc/wireguard /etc/letsencrypt/renewal-hooks/deploy/takserver.sh
sudo systemctl daemon-reload
sudo bash install_tak.sh
```
