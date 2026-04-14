# RagTAK

A single script that sets up a complete tactical communications server — ready for ATAK, WinTAK, voice, video, and VPN.

---

## What does it do?

Running one command installs and configures everything:

- **TAK Server** — the core. ATAK and WinTAK devices connect here to share locations, maps, and messages
- **RagTak Admin Panel** — a web interface to manage services, create users, and download connection bundles
- **Mumble** — low-latency voice comms, like a self-hosted TeamSpeak
- **Node-RED** — visual automation tool to connect TAK data to other systems
- **WireGuard** — VPN so your devices connect securely over the internet
- **MediaMTX** — video streaming (RTSP/HLS/WebRTC) for drone feeds and cameras
- **Certificates** — automatically generated so all connections are encrypted
- **Firewall** — configured automatically

---

## Before you start

### 1. Get the TAK Server package

TAK Server is free but requires registration — it is export-controlled software.

1. Go to [tak.gov](https://tak.gov) and create a free account
2. Navigate to **Products → TAK Server**
3. Download the file named `takserver_5.7-RELEASE8_all.deb`
4. Put that file in the same folder as `install_tak.sh`

### 2. Check your system

This script works on:
- Ubuntu 22.04 or 24.04 LTS
- Debian 11 or 12
- Linux Mint 21+

It does **not** work on:
- Windows or macOS (run it on a Linux server or VM)
- Non-LTS Ubuntu releases (e.g. 23.10, 24.10, 25.04) — TAK Server is only validated against LTS releases and the `.deb` package may fail to install on non-LTS due to library version differences

### 3. If you are using a VPS (cloud server)

Your VPS provider has its own firewall separate from the one on your server. You need to open these ports in your provider's control panel **before** running the script:

| Port | Protocol | What it's for |
|------|----------|---------------|
| 22 | TCP | SSH — **keep this open or you will lose access** |
| 8089 | TCP | ATAK / WinTAK connections |
| 8443 | TCP | TAK web admin panel |
| 8446 | TCP | Certificate enrollment |
| 8554 | TCP + UDP | Video streaming (RTSP) |
| 8888 | TCP | Video streaming (HLS) |
| 8889 | TCP | Video streaming (WebRTC) |
| 64738 | TCP + UDP | Mumble voice |
| 1880 | TCP | Node-RED |
| 51820 | UDP | WireGuard VPN |

> **Port 8080 (RagTak Admin Panel) is intentionally not listed** — it is only reachable over the WireGuard VPN. Do not open it to the internet.

> Where to find this setting: AWS → Security Groups, DigitalOcean → Firewall, Hetzner → Firewall, Vultr → Firewall Rules.

---

## Installation

### Option A — Basic install (no domain name)

Use this if you just have an IP address.

```bash
sudo bash install_tak.sh
```

### Option B — With a domain name (recommended for internet-facing servers)

If you have a domain name pointed at your server, the script will automatically get a trusted SSL certificate from Let's Encrypt. This means:
- No certificate warnings in the browser
- ATAK connects without needing to import a trust store

```bash
DOMAIN=tak.example.com sudo bash install_tak.sh
```

Add an email to receive expiry notifications:
```bash
DOMAIN=tak.example.com LE_EMAIL=you@example.com sudo bash install_tak.sh
```

> The script takes about 2–5 minutes. Do not close the terminal while it runs.

---

## After installation

At the end of the script you will see a summary like this:

```
============================================================
  TAK Server Installation Complete
============================================================

  Service status
    TAK Server : active
    PostgreSQL : active
    Mumble     : active
    Node-RED   : active
    WireGuard  : active
    MediaMTX   : active
    RagTak     : active

  Endpoints
    Web Admin  : https://192.168.1.11:8443
    CoT/ATAK   : ssl://192.168.1.11:8089
    Mumble     : 192.168.1.11:64738
    Node-RED   : http://192.168.1.11:1880
    WireGuard  : 192.168.1.11:51820/UDP  (server IP: 10.13.13.1)
    RagTak     : http://10.13.13.1:8080  (WireGuard VPN only)

  WireGuard
    Configs    : wg-client1.conf, wg-client1.png ...

  Mumble
    Superuser  : SuperUser / <generated-password>

  Node-RED
    Username   : admin
    Password   : <generated-password>

  RagTak Admin Panel
    URL        : http://10.13.13.1:8080
    Username   : Admin
    Password   : <generated-password>
    Note       : Connect to WireGuard VPN first, then open in browser
```

**Save this output** — it contains generated passwords you will need.

### Where are my files?

All certificates and WireGuard configs are copied to a `certs/` folder next to `install_tak.sh`:

```
install_tak.sh
certs/
  root-ca.pem          ← import into your browser
  tak-admin.p12        ← admin certificate for the web panel
  truststore-root.p12  ← trust store for ATAK / WinTAK
  client1.p12          ← device certificate (one per device)
  client2.p12
  ...
  wg-client1.conf      ← WireGuard config for device 1
  wg-client1.png       ← QR code for device 1
  ...
```

---

## RagTak Admin Panel

The admin panel is the easiest way to manage your server after install. It is only reachable over the WireGuard VPN — connect WireGuard first, then open:

```
http://10.13.13.1:8080
```

Log in with `Admin` and the password printed in the install summary.

### What you can do

- **Dashboard** — see which services are running and restart any of them
- **Users** — create a new TAK user in one click. It generates a TAK certificate, registers it on the server, and adds a WireGuard peer automatically
- **Downloads** — download ready-to-use bundles:
  - **Browser bundle** — root CA + admin cert, packaged with import instructions for Firefox
  - **ATAK bundle** — client cert + WireGuard config + QR code per user, ready to copy to a phone

---

## Connecting your browser (TAK web admin)

The TAK web admin at port 8443 uses client certificates for login — a password alone is not enough. You need to import two files into your browser first.

### Firefox

**Step 1 — Import the certificate authority**

1. Open Firefox → type `about:preferences#privacy` in the address bar
2. Scroll down to **Certificates** → click **View Certificates**
3. Go to the **Authorities** tab → click **Import**
4. Select `root-ca.pem` from the `certs/` folder
5. Check **Trust this CA to identify websites** → click OK

**Step 2 — Import your admin certificate**

1. Still in the Certificate Manager → go to **Your Certificates** tab
2. Click **Import** → select `tak-admin.p12` from the `certs/` folder
3. Password: `atakatak`

**Step 3 — Open the admin panel**

Close and reopen Firefox completely, then go to:
```
https://<your-server-ip>:8443
```

Firefox will ask which certificate to use — select `tak-admin`.

### Chrome / Chromium

1. Go to `chrome://settings/certificates`
2. Under **Authorities** → click **Import** → select `root-ca.pem` → check **Trust this certificate for identifying websites**
3. Under **Your certificates** → click **Import** → select `tak-admin.p12` → enter password `atakatak`
4. Fully restart Chrome, then go to `https://<your-server-ip>:8443`

> **With Let's Encrypt:** Skip the CA import step entirely. Only import `tak-admin.p12`.

> **Tip:** The RagTak Admin Panel at port 8080 has a **Downloads → Browser bundle** link that packages both files with step-by-step instructions.

---

## Connecting ATAK (Android)

Each device needs its own client certificate. The script generates five: `client1.p12` through `client5.p12`. Use one per device — do not share the same `.p12` between two devices.

### Without Let's Encrypt

1. Copy these two files to your phone (USB cable, email, or cloud storage):
   - `truststore-root.p12` — password: `atakatak`
   - `client1.p12` — password: `atakatak`

2. In ATAK: **Settings → Network Preferences → TAK Servers → +**
3. Fill in:
   - Server address: your server IP or domain
   - Port: `8089`
   - Protocol: `SSL`
   - Trust Store: `truststore-root.p12` — password: `atakatak`
   - Client Certificate: `client1.p12` — password: `atakatak`
4. Tap OK — the dot next to the server should turn green

### With Let's Encrypt

1. Copy only `client1.p12` to your phone
2. Follow the same steps above but leave the Trust Store field empty
3. Connect to your domain name instead of an IP

> **Tip:** The RagTak Admin Panel has a **Downloads** page where you can grab a per-user ATAK bundle (cert + WireGuard config + QR code) in one zip.

---

## Connecting WinTAK (Windows)

Same files and same steps as ATAK above. Use `client2.p12` (or any unused client cert).

To create a named password-based account for WinTAK (in addition to the certificate):
```bash
sudo java -jar /opt/tak/utils/UserManager.jar usermod -A -p 'YourPassword' WinTAK
```

> `-A` grants administrator rights. Leave it out if you want a regular user account.

---

## Connecting WireGuard (VPN)

WireGuard lets your devices connect to the TAK server securely over the internet. Once connected via VPN, devices reach TAK at `10.13.13.1` instead of the public IP.

The script generates a config file and a QR code for each device in the `certs/` folder:

| File | For |
|------|-----|
| `wg-tak-admin.conf` + `.png` | Admin workstation |
| `wg-client1.conf` + `.png` | ATAK device 1 |
| `wg-client2.conf` + `.png` | ATAK device 2 |
| `wg-client3.conf` + `.png` | ATAK device 3 |
| `wg-client4.conf` + `.png` | ATAK device 4 |
| `wg-client5.conf` + `.png` | ATAK device 5 |
| `wg-wintak.conf` + `.png` | WinTAK workstation |

### Android / iOS
1. Install the **WireGuard** app from the Play Store or App Store
2. Tap **+** → **Scan from QR code**
3. Scan the `.png` file for that device
4. Toggle the tunnel on

### Windows / Linux / macOS
1. Install WireGuard from [wireguard.com/install](https://www.wireguard.com/install/)
2. Click **Import tunnel(s) from file** → select the `.conf` file
3. Click **Activate**

> By default only traffic to `10.13.13.0/24` goes through the tunnel (split tunnel). If you want all internet traffic routed through the server, change `AllowedIPs` in the `.conf` file to `0.0.0.0/0, ::/0`.

---

## Connecting Mumble (voice)

1. Download the Mumble client from [mumble.info](https://www.mumble.info)
2. Add a new server:
   - Address: your server IP or domain
   - Port: `64738`
   - Username: anything you like
   - Password: the server password from the install summary (if one was set)
3. Connect

The **SuperUser** password printed in the summary lets you create channels and manage permissions from the Mumble client.

---

## Node-RED

Open in any browser:
```
http://<your-server>:1880
```

Log in with the username and password from the install summary.

Node-RED lets you visually wire together TAK events, MQTT, webhooks, databases, and more — no coding required for basic flows.

---

## MediaMTX (video streaming)

MediaMTX receives video streams and re-publishes them in multiple formats. Useful for drone feeds, IP cameras, or body cameras.

### Sending a stream to the server

From a drone controller, camera, or OBS:
```
rtsp://<your-server-ip>:8554/<stream-name>
```

Replace `<stream-name>` with any name you choose (e.g. `drone1`).

### Watching a stream

| Format | URL |
|--------|-----|
| RTSP | `rtsp://<server>:8554/<stream-name>` |
| HLS (browser) | `http://<server>:8888/<stream-name>` |
| WebRTC (browser) | `http://<server>:8889/<stream-name>` |

Open the HLS or WebRTC URL directly in a browser — no app needed. Use RTSP in VLC or any RTSP-capable player.

---

## Customisation

You can override any of these before running the script:

| Variable | Default | Description |
|----------|---------|-------------|
| `DOMAIN` | *(empty)* | Your domain name — enables Let's Encrypt |
| `LE_EMAIL` | *(empty)* | Email for Let's Encrypt expiry warnings |
| `CERT_PASS` | `atakatak` | Password for all generated certificates |
| `MUMBLE_SERVER_NAME` | `TAK Mumble` | Name shown in Mumble server browser |
| `MUMBLE_PASS` | *(empty)* | Mumble server password (empty = open server) |
| `MUMBLE_MAX_USERS` | `50` | Max simultaneous Mumble connections |
| `NODERED_USER` | `admin` | Node-RED login username |
| `NODERED_PASS` | *(auto-generated)* | Node-RED login password |
| `WG_PORT` | `51820` | WireGuard listen port |
| `WG_SUBNET` | `10.13.13` | VPN subnet — server gets `.1`, clients get `.2+` |
| `WG_DNS` | `1.1.1.1` | DNS server sent to VPN clients |
| `TAKADMIN_PORT` | `8080` | RagTak Admin Panel port (VPN only) |
| `TAKADMIN_PASS` | *(auto-generated)* | RagTak Admin Panel password |
| `SKIP_MEDIAMTX` | *(unset)* | Set to any value to skip MediaMTX install |

Example:
```bash
DOMAIN=tak.myunit.com \
MUMBLE_SERVER_NAME="Alpha Team" \
MUMBLE_PASS="voicepass" \
NODERED_PASS="flowpass" \
sudo bash install_tak.sh
```

---

## Troubleshooting

**TAK Server not starting**
```bash
sudo systemctl status takserver
sudo tail -50 /opt/tak/logs/takserver-messaging.log
```

**ATAK shows "Socket is closed" or "IO Error"**
- Make sure the phone is on WiFi (not mobile data) or connected via WireGuard
- Confirm port 8089 is open on all firewalls (both UFW and your VPS provider's)
- Use `truststore-root.p12` as the trust store, not `root-ca.pem`

**Browser shows certificate error**
- Make sure you imported both `root-ca.pem` (Authorities) and `tak-admin.p12` (Your Certificates)
- Close and reopen the browser completely after importing

**RagTak Admin Panel not loading**
- Make sure you are connected to WireGuard first
- The panel is only reachable at `http://10.13.13.1:8080` — it is not accessible from the internet
```bash
sudo systemctl status takadmin
sudo journalctl -u takadmin -n 50
```

**Mumble not connecting**
```bash
sudo systemctl status mumble-server
sudo journalctl -u mumble-server -n 50
```

**Node-RED not loading**
```bash
sudo systemctl status node-red
sudo journalctl -u node-red -n 50
```

**WireGuard not connecting**
```bash
sudo systemctl status wg-quick@wg0
sudo journalctl -u wg-quick@wg0 -n 50
```

---

## Clean reinstall

If something goes wrong and you want to start fresh:

```bash
sudo systemctl stop takserver mediamtx mumble-server node-red wg-quick@wg0 takadmin
sudo apt-get purge -y takserver mumble-server
sudo rm -rf /opt/tak /opt/takadmin
sudo -u postgres dropdb --if-exists cot
sudo -u postgres dropuser --if-exists martiuser
sudo npm uninstall -g node-red
sudo userdel -r nodered 2>/dev/null || true
sudo rm -rf /etc/wireguard /etc/letsencrypt/renewal-hooks/deploy/takserver.sh
sudo rm -f /etc/systemd/system/takadmin.service
sudo systemctl daemon-reload
sudo bash install_tak.sh
```
