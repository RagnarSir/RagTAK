#!/usr/bin/env bash
# =============================================================================
#  RagTAK -- TAK Server Installation Script
#  Version   : 2.0
#  Target OS : Ubuntu 22.04 / 24.04, Debian 11/12, Linux Mint 21+
#  Installs  : TAK Server 5.7, PostgreSQL 15, Full PKI, MediaMTX, Mumble,
#              Node-RED, RagTAK Admin Panel, OpenVPN (default on), UFW firewall
#
# =============================================================================
#  OVERVIEW
# =============================================================================
#
#  This script performs a fully automated TAK Server installation including:
#    - PostgreSQL 15 + PostGIS database setup
#    - TAK Server .deb installation and configuration
#    - Full PKI certificate generation (Root CA, server, admin, 5 client certs)
#    - Automatic Firefox certificate import (desktop installs)
#    - Let's Encrypt SSL certificate (optional, set DOMAIN= -- non-fatal if it
#      fails, falls back to self-signed automatically)
#    - MediaMTX RTSP/HLS/WebRTC video streaming server
#    - Mumble voice communication server
#    - Node-RED flow automation (dedicated user, port 1880)
#    - RagTAK Admin Panel (Flask web UI -- service control, user/cert creation)
#    - OpenVPN (default on -- locks all services behind VPN tunnel for security;
#      pass --no-openvpn to skip)
#    - UFW firewall configuration
#
#  With OpenVPN enabled (the default), only SSH (22) and OpenVPN (1194/UDP) are
#  exposed to the internet. All other services are VPN-only (reachable at
#  10.8.0.1). Inline .ovpn configs for each user are generated automatically
#  in certs/.
#
# =============================================================================
#  STEP 1 -- DOWNLOAD THE TAK SERVER PACKAGE
# =============================================================================
#
#  TAK Server is export-controlled software -- you must register to download it.
#
#    1. Create a free account at https://tak.gov
#    2. Go to Products > TAK Server
#    3. Download the "Full" release:
#          takserver_5.7-RELEASE8_all.deb
#    4. Place the .deb file in the same directory as this script
#
# =============================================================================
#  STEP 2 -- PREPARE YOUR SYSTEM
# =============================================================================
#
#  LOCAL MACHINE (Ubuntu/Debian/Mint desktop):
#    No special preparation needed. The script handles everything.
#
#  VPS / CLOUD SERVER:
#    Open the following ports in your provider's firewall BEFORE running the
#    script (AWS Security Groups, DigitalOcean Firewall, OVH Network ACL, etc.).
#    The script configures UFW automatically, but the provider firewall is
#    separate -- both must allow traffic.
#
#    WITHOUT OpenVPN (--no-openvpn -- all services public):
#      Port 22    / TCP  -- SSH
#      Port 8089  / TCP  -- ATAK / WinTAK / iTAK (CoT over SSL)
#      Port 8443  / TCP  -- TAK web admin interface
#      Port 8446  / TCP  -- Certificate enrollment
#      Port 8554  / TCP  -- MediaMTX RTSP video (optional)
#      Port 8554  / UDP  -- MediaMTX RTSP/UDP video (optional)
#      Port 8888  / TCP  -- MediaMTX HLS video (optional)
#      Port 8889  / TCP  -- MediaMTX WebRTC video (optional)
#      Port 8189  / UDP  -- MediaMTX WebRTC ICE/STUN (optional)
#      Port 64738 / TCP  -- Mumble voice
#      Port 64738 / UDP  -- Mumble voice/UDP
#      Port 1880  / TCP  -- Node-RED web UI
#      Port 8080  / TCP  -- RagTAK Admin Panel
#
#    WITH OpenVPN (default -- all services behind VPN):
#      Port 22   / TCP  -- SSH
#      Port 1194 / UDP  -- OpenVPN
#      (All other ports are blocked from the internet; reachable via VPN only)
#
# =============================================================================
#  STEP 3 -- RUN THE SCRIPT
# =============================================================================
#
#    Default (installs OpenVPN; services are VPN-only):
#      sudo bash install_tak.sh
#
#    Skip OpenVPN (all services exposed directly):
#      sudo bash install_tak.sh --no-openvpn
#
#    With Let's Encrypt TLS (recommended for public-facing installs):
#      sudo DOMAIN=tak.example.com bash install_tak.sh
#
#    Skip OpenVPN + Let's Encrypt:
#      sudo DOMAIN=tak.example.com bash install_tak.sh --no-openvpn
#
#    See --help for all CLI options.
#
#  The script takes approximately 5-10 minutes to complete.
#  Do NOT interrupt it once started.
#
# =============================================================================
#  STEP 4 -- ACCESS THE WEB ADMIN (BROWSER)
# =============================================================================
#
#  On a LOCAL machine:
#    The script automatically imports the admin certificate and Root CA into
#    Firefox. After install, close and reopen Firefox, then go to:
#      https://<your-ip>:8443
#    Firefox will prompt you to select the tak-admin certificate -- select it.
#
#  On a VPS (no desktop):
#    Copy these two files from the certs/ directory to your local machine:
#      tak-admin.p12      -- your admin client certificate
#      root-ca.pem        -- the certificate authority
#    Then import them into Firefox manually:
#      1. Open Firefox > Settings > Privacy & Security > View Certificates
#      2. Authorities tab > Import > select root-ca.pem
#         Check "Trust this CA to identify websites"
#      3. Your Certificates tab > Import > select tak-admin.p12
#         Password: atakatak
#    Then open: https://<your-server-ip-or-domain>:8443
#
#    With OpenVPN: connect to VPN first, then open https://10.8.0.1:8443
#
# =============================================================================
#  STEP 5 -- OPENVPN (if installed)
# =============================================================================
#
#  Install the OpenVPN Connect app on each device (Android, iOS, Windows, Linux).
#  Transfer the appropriate .ovpn file from certs/ to the device and import it:
#
#    tak-admin.ovpn    -- for the admin / your main device
#    client1.ovpn      -- for additional ATAK/WinTAK/iTAK devices
#    client2-5.ovpn    -- for further devices
#    wintak.ovpn       -- for a dedicated WinTAK machine
#
#  Once connected to the VPN, use 10.8.0.1 as the server address for all
#  services (TAK, Mumble, Node-RED, Admin Panel).
#
# =============================================================================
#  STEP 6 -- CONNECT ATAK / iTAK (ANDROID / iOS)
# =============================================================================
#
#  WITHOUT Let's Encrypt (self-signed):
#    Transfer these files to the device (USB, email, cloud storage):
#      truststore-root.p12   -- server trust store
#      client1.p12           -- client identity certificate (one per device)
#
#    In ATAK / iTAK:
#      1. Settings > Network Preferences > TAK Servers > Add (+)
#      2. Server address: <your-ip-or-domain> (or 10.8.0.1 if using OpenVPN)
#         Port: 8089 / Protocol: SSL
#      3. Trust Store  : truststore-root.p12  password: atakatak
#      4. Client Cert  : client1.p12          password: atakatak
#      5. Tap OK -- the status indicator should turn green
#
#  WITH Let's Encrypt (DOMAIN set):
#    Transfer only the client cert to the device:
#      client1.p12           -- client identity certificate (one per device)
#
#    In ATAK / iTAK:
#      1. Settings > Network Preferences > TAK Servers > Add (+)
#      2. Server address: <your-domain> / Port: 8089 / Protocol: SSL
#      3. Client Cert  : client1.p12  password: atakatak
#         (No trust store needed -- Let's Encrypt is trusted automatically)
#      4. Tap OK -- the status indicator should turn green
#
#  Each device should use its own client cert (client1 through client5).
#  Do not reuse the same cert on multiple devices.
#
# =============================================================================
#  STEP 7 -- CONNECT WINTAK (WINDOWS)
# =============================================================================
#
#  Transfer these files to the Windows machine:
#    truststore-root.p12   -- server trust store (not needed with Let's Encrypt)
#    client2.p12           -- client identity certificate
#
#  In WinTAK, follow the same server connection steps as ATAK above.
#
#  Optionally create a named WinTAK user account on the server:
#    sudo java -jar /opt/tak/utils/UserManager.jar usermod -A -p 'YourPassword' WinTAK
#
# =============================================================================
#  STEP 8 -- CONNECT MUMBLE (VOICE)
# =============================================================================
#
#  Download the Mumble client from https://www.mumble.info
#
#  Connect using:
#    Address  : <your-server-ip-or-domain>  (or 10.8.0.1 if using OpenVPN)
#    Port     : 64738
#    Username : anything
#    Password : (the server password shown in the install summary, if set)
#
#  The SuperUser password is printed at the end of the install -- save it.
#  Use it to create channels and manage permissions via the Mumble client.
#
# =============================================================================
#  STEP 9 -- ACCESS NODE-RED
# =============================================================================
#
#  Open in a browser:
#    http://<your-server-ip-or-domain>:1880  (or http://10.8.0.1:1880 via VPN)
#
#  Login with the credentials printed at the end of the install summary.
#
#  Useful Node-RED integrations for TAK:
#    - Receive CoT events from TAK and forward to external systems
#    - Trigger alerts based on ATAK position reports
#    - Bridge TAK to MQTT, webhooks, or databases
#
# =============================================================================
#  STEP 10 -- RAGTAK ADMIN PANEL
# =============================================================================
#
#  Open in a browser:
#    http://<your-server-ip>:8080  (or http://10.8.0.1:8080 via VPN)
#
#  Login with the admin password printed at the end of the install summary.
#
#  The admin panel allows you to:
#    - Start / stop / restart all services
#    - Create new TAK users (generates client cert + registers in TAK Server)
#    - View live service status
#
# =============================================================================
#  CERTIFICATE SUMMARY
# =============================================================================
#
#  All certificates are generated with password: atakatak
#  Stored in the certs/ subdirectory next to this script.
#
#    root-ca.pem            -- Root CA (import into Firefox Authorities)
#    truststore-root.p12    -- Trust store for ATAK/WinTAK/iTAK devices
#    tak-admin.p12          -- Admin cert for browser access to TAK web admin
#    client1-5.p12          -- Client certs for ATAK/WinTAK/iTAK devices
#    tak-admin.ovpn         -- OpenVPN config for admin device (if OpenVPN installed)
#    client1-5.ovpn         -- OpenVPN configs for each client (if OpenVPN installed)
#    wintak.ovpn            -- OpenVPN config for WinTAK (if OpenVPN installed)
#
# =============================================================================
#  TROUBLESHOOTING
# =============================================================================
#
#  TAK Server not starting:
#    sudo systemctl status takserver
#    sudo tail -f /opt/tak/logs/takserver-messaging.log
#
#  Database connection errors:
#    sudo systemctl status postgresql@15-main
#    sudo -u postgres psql -c "\du martiuser"
#
#  Certificate errors in browser:
#    Make sure BOTH root-ca.pem (Authorities) and tak-admin.p12
#    (Your Certificates) are imported, then fully restart Firefox.
#
#  ATAK "Socket is closed" or IO errors:
#    - Confirm the device is on the same network / VPN as the server
#    - Confirm port 8089 is open in all firewalls (or device is on VPN)
#    - Use truststore-root.p12 (not root-ca.pem) on ATAK devices
#
#  OpenVPN not connecting:
#    sudo systemctl status openvpn@server
#    sudo journalctl -u openvpn@server
#    Confirm port 1194/UDP is open in the provider firewall
#
#  Mumble not starting:
#    sudo systemctl status mumble-server
#    sudo journalctl -u mumble-server
#
#  Node-RED not starting:
#    sudo systemctl status node-red
#    sudo journalctl -u node-red
#
#  MediaMTX HLS/WebRTC not working:
#    sudo systemctl status mediamtx
#    sudo journalctl -u mediamtx
#    Confirm port 8189/UDP is open for WebRTC ICE
#
#  Clean reinstall (wipe everything and start fresh):
#    sudo bash reset_vps.sh
#    # Then re-run:
#    sudo bash install_tak.sh
#
# =============================================================================
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# ─── Colour helpers ──────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
die()     { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ─── CLI flags ───────────────────────────────────────────────────────────────
# OpenVPN is installed by default; pass --no-openvpn to skip it.
while [[ $# -gt 0 ]]; do
    case "$1" in
        --openvpn)       INSTALL_OPENVPN=yes ;;
        --no-openvpn)    INSTALL_OPENVPN=no  ;;
        -h|--help)
            cat << 'HELP'
Usage: sudo bash install_tak.sh [options]

Options:
  --openvpn         Install OpenVPN (default — listed for clarity).
  --no-openvpn      Skip OpenVPN installation.
  -h, --help        Show this help and exit.

Environment variables (see README for the full list):
  DOMAIN=…          Enable Let's Encrypt for this domain.
  LE_EMAIL=…        Contact email for Let's Encrypt.
  PUBLIC_IP=…       Override auto-detected public IP.
  INSTALL_OPENVPN=yes|no   Override OpenVPN default (flags take precedence).
HELP
            exit 0 ;;
        *)  die "Unknown argument: $1 (try --help)" ;;
    esac
    shift
done

# ─── Configuration ───────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TAK_DEB_PATH="${TAK_DEB_PATH:-}"

# PKI — server cert name must match CoreConfig.xml default (takserver)
CA_NAME="${CA_NAME:-TAK-CA}"
SERVER_NAME="${SERVER_NAME:-takserver}"
ADMIN_USER="${ADMIN_USER:-tak-admin}"
CLIENT_NAMES=("client1" "client2" "client3" "client4" "client5")
CERT_PASS="${CERT_PASS:-atakatak}"

# Certificate metadata
export STATE="${STATE:-NA}"
export CITY="${CITY:-NA}"
export ORGANIZATION="${ORGANIZATION:-RagTAK}"
export ORGANIZATIONAL_UNIT="${ORGANIZATIONAL_UNIT:-TAK}"

# Database credentials (must match CoreConfig.xml)
DB_USER="martiuser"
DB_PASS="${DB_PASS:-$(openssl rand -hex 16)}"
DB_NAME="cot"

# Let's Encrypt (optional — set DOMAIN to enable)
# Usage: DOMAIN=tak.example.com sudo bash install_tak.sh
#        DOMAIN=tak.example.com LE_EMAIL=you@example.com sudo bash install_tak.sh
DOMAIN="${DOMAIN:-}"
LE_EMAIL="${LE_EMAIL:-}"

# MediaMTX version
MEDIAMTX_VER="${MEDIAMTX_VER:-1.9.3}"

# Mumble server
MUMBLE_PORT="${MUMBLE_PORT:-64738}"
MUMBLE_SERVER_NAME="${MUMBLE_SERVER_NAME:-TAK Mumble}"
MUMBLE_MAX_USERS="${MUMBLE_MAX_USERS:-50}"
MUMBLE_PASS="${MUMBLE_PASS:-}"          # leave empty for no server password

# Node-RED
NODERED_PORT="${NODERED_PORT:-1880}"
NODERED_USER="${NODERED_USER:-admin}"
NODERED_PASS="${NODERED_PASS:-}"        # leave empty to auto-generate

# TAK Admin Panel
TAKADMIN_PORT="${TAKADMIN_PORT:-8080}"
TAKADMIN_PASS="${TAKADMIN_PASS:-}"     # leave empty to auto-generate

# OpenVPN (installed by default; use --no-openvpn or INSTALL_OPENVPN=no to skip)
OPENVPN_PORT="${OPENVPN_PORT:-1194}"
OPENVPN_PROTO="${OPENVPN_PROTO:-udp}"
OPENVPN_SUBNET="${OPENVPN_SUBNET:-10.8.0}"  # /24 — server gets .1, clients get .2+

# Ports
TAK_COT_PORT=8089
TAK_ADMIN_PORT=8443
TAK_ENROLL_PORT=8446
RTSP_PORT=8554
HLS_PORT=8888
WEBRTC_PORT=8889
WEBRTC_ICE_PORT=8189   # UDP — required for WebRTC peer connections

TAK_DIR="/opt/tak"
CERT_DIR="${TAK_DIR}/certs/files"

# ─── 1. Pre-flight ───────────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo "  TAK Server Installer"
echo "============================================================"
echo ""

[[ $EUID -eq 0 ]] || die "Run as root: sudo bash $0"
command -v apt-get &>/dev/null || die "Requires a Debian/Ubuntu-based system."

# Warn on non-LTS Ubuntu — TAK Server is only validated against LTS releases
if grep -qi 'ubuntu' /etc/os-release 2>/dev/null; then
    if ! grep -q 'LTS' /etc/os-release 2>/dev/null; then
        _ver="$(grep -oP '(?<=VERSION_ID=")[^"]+' /etc/os-release 2>/dev/null || echo 'unknown')"
        echo ""
        echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║              UNSUPPORTED UBUNTU VERSION WARNING              ║${NC}"
        echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "  Detected Ubuntu ${_ver}, which is a ${RED}non-LTS release${NC}."
        echo ""
        echo "  TAK Server is only validated against Ubuntu LTS releases"
        echo "  (22.04, 24.04). On non-LTS versions the .deb package may"
        echo "  fail to install due to library version differences."
        echo ""
        echo "  Recommended: reinstall with Ubuntu 24.04 LTS."
        echo ""
        echo -e "${YELLOW}  Proceed anyway at your own risk.${NC}"
        echo ""
        read -r -p "  Type YES to continue anyway, or press Enter to abort: " _confirm
        echo ""
        [[ "$_confirm" == "YES" ]] || { echo "Aborted."; exit 1; }
        warn "Continuing on unsupported Ubuntu ${_ver} — good luck."
        echo ""
    fi
fi

# OpenVPN is installed by default; the --no-openvpn flag or INSTALL_OPENVPN=no
# env var opts out. Resolved before IP detection because it governs whether
# we need the external WAN IP (for .ovpn remote endpoints) at all.
INSTALL_OPENVPN="${INSTALL_OPENVPN:-yes}"
if [[ "$INSTALL_OPENVPN" == "yes" ]]; then
    info "OpenVPN will be installed (pass --no-openvpn to skip)."
else
    info "OpenVPN will be skipped (--no-openvpn / INSTALL_OPENVPN=no)."
fi

# Resolve server IP(s). MACHINE_IP is the primary interface address — what
# clients on the same network dial. On a VPS this is usually also the public
# IP (NIC-bound); on a LAN host it is the LAN address.
MACHINE_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
[[ -n "$MACHINE_IP" ]] || die "Could not determine machine IP from 'hostname -I'."

# PUBLIC_IP (WAN IP) is only needed when OpenVPN is installed — it becomes the
# 'remote' endpoint in generated .ovpn configs. Without OpenVPN, MACHINE_IP is
# what gets surfaced in the summary and admin panel. A manual PUBLIC_IP= env
# override still triggers the external lookup path.
if [[ "$INSTALL_OPENVPN" == "yes" || -n "${PUBLIC_IP:-}" ]]; then
    PUBLIC_IP="${PUBLIC_IP:-$(curl -fsSL --max-time 5 https://api.ipify.org 2>/dev/null \
        || curl -fsSL --max-time 5 https://ifconfig.me 2>/dev/null \
        || echo "$MACHINE_IP")}"
else
    PUBLIC_IP="$MACHINE_IP"
fi
[[ -n "$PUBLIC_IP" ]] || die "Could not determine server IP. Set it manually: PUBLIC_IP=x.x.x.x sudo bash $0"

# SERVER_IP is what user-facing URLs (summary, admin panel) point at. DOMAIN
# wins when set; otherwise fall back to MACHINE_IP so LAN installs print a
# reachable address rather than a WAN IP clients cannot route to.
SERVER_IP="${DOMAIN:-$MACHINE_IP}"

ARCH="$(uname -m)"
case "$ARCH" in
    x86_64)  MEDIAMTX_ARCH="amd64" ;;
    aarch64) MEDIAMTX_ARCH="arm64v8" ;;
    armv7l)  MEDIAMTX_ARCH="armv7" ;;
    *)       die "Unsupported architecture: $ARCH" ;;
esac

# Find TAK .deb
if [[ -z "$TAK_DEB_PATH" ]]; then
    mapfile -t debs < <(find "$SCRIPT_DIR" -maxdepth 1 \( -name "takserver*_all.deb" -o -name "takserver*.deb" \) 2>/dev/null | sort -V | tail -1)
    if [[ ${#debs[@]} -eq 0 || -z "${debs[0]}" ]]; then
        echo -e "${RED}TAK Server .deb not found.${NC}"
        echo "  Download takserver_5.7-RELEASE8_all.deb from https://tak.gov/products/tak-server"
        echo "  Place it in: $SCRIPT_DIR"
        exit 1
    fi
    TAK_DEB_PATH="${debs[0]}"
fi
[[ -f "$TAK_DEB_PATH" ]] || die "TAK Server .deb not found at: $TAK_DEB_PATH"
info "TAK Server package: $(basename "$TAK_DEB_PATH")"

# ─── 2. Stop Docker containers that conflict with TAK ports ──────────────────
if command -v docker &>/dev/null; then
    info "Checking for Docker port conflicts..."
    for port in 5432 8089 8443 8444 8446; do
        while IFS= read -r container; do
            [[ -z "$container" ]] && continue
            warn "  Stopping Docker container '$container' (port $port conflict)..."
            docker stop "$container" 2>/dev/null || true
            docker rm "$container" 2>/dev/null || true
        done < <(docker ps --format "{{.Names}}" --filter "publish=${port}" 2>/dev/null)
    done
fi

# ─── 3. Add PostgreSQL 15 repo (before first apt-get update) ─────────────────
# TAK 5.7 requires PG15. Ubuntu 24.04 ships PG16.
# Linux Mint uses its own codename — read Ubuntu base from /etc/os-release.
# Ensure lsb-release is available on minimal Debian installs before we need it.
apt-get install -y --no-install-recommends lsb-release gnupg curl 2>/dev/null || true

UBUNTU_CODENAME="$(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release 2>/dev/null \
    || grep -oP '(?<=DISTRIB_CODENAME=).*' /etc/upstream-release/lsb-release 2>/dev/null \
    || lsb_release -cs)"
info "Ubuntu base codename: ${UBUNTU_CODENAME}"

curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    | gpg --batch --yes --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg

echo "deb https://apt.postgresql.org/pub/repos/apt ${UBUNTU_CODENAME}-pgdg main" \
    > /etc/apt/sources.list.d/pgdg.list

# ─── 4. Install dependencies ──────────────────────────────────────────────────
info "Updating package lists..."
apt-get update -qq

info "Installing base tools and Java 17..."
apt-get install -y \
    openjdk-17-jdk ufw curl wget unzip ffmpeg openssl \
    net-tools lsof gnupg lsb-release 2>/dev/null

info "Installing PostgreSQL 15 + PostGIS 3..."
apt-get install -y \
    postgresql-15 postgresql-15-postgis-3 postgresql-client-15 2>/dev/null

# Set Java 17 as default and export JAVA_HOME
JAVA17_PATH="$(update-alternatives --list java 2>/dev/null | grep java-17 | head -1 || true)"
if [[ -n "$JAVA17_PATH" ]]; then
    update-alternatives --set java "$JAVA17_PATH" 2>/dev/null || true
    export JAVA_HOME="${JAVA17_PATH%/bin/java}"
else
    export JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(which java)")")")"
fi
export PATH="$JAVA_HOME/bin:$PATH"
success "Java: $(java -version 2>&1 | head -1)  (JAVA_HOME=$JAVA_HOME)"

# ─── 5. Start PostgreSQL 15 on port 5432 ─────────────────────────────────────
info "Configuring PostgreSQL 15 on port 5432..."

# Stop PG16 if it exists (occupies 5432 by default)
if pg_lsclusters 2>/dev/null | grep -q "^16 "; then
    info "  Stopping PG16 cluster (port conflict)..."
    pg_ctlcluster 16 main stop 2>/dev/null || true
    systemctl stop postgresql@16-main 2>/dev/null || true
    systemctl disable postgresql@16-main 2>/dev/null || true
fi

# Pin PG15 to port 5432
PG15_CONF="/etc/postgresql/15/main/postgresql.conf"
[[ -f "$PG15_CONF" ]] && sed -i "s/^#*port = .*/port = 5432/" "$PG15_CONF"

systemctl enable postgresql@15-main --now
sleep 5
systemctl is-active --quiet postgresql@15-main || die "PostgreSQL 15 failed to start."
success "PostgreSQL 15 running on port 5432."

export PGCLUSTER=15/main
export PGPORT=5432

# ─── 6. Install TAK Server .deb ──────────────────────────────────────────────
info "Installing TAK Server..."
# Skip dpkg -i if the exact version is already installed — re-running dpkg on an
# already-installed TAK package causes the postinstall to wipe CoreConfig.xml.
TAK_DEB_VERSION="$(dpkg-deb -f "$TAK_DEB_PATH" Version 2>/dev/null || true)"
if dpkg -l takserver 2>/dev/null | awk '/^ii/{print $3}' | grep -qF "$TAK_DEB_VERSION"; then
    info "TAK Server ${TAK_DEB_VERSION} already installed — skipping dpkg."
else
    dpkg -i "$TAK_DEB_PATH" || apt-get install -f -y
fi
[[ -d "$TAK_DIR" ]] || die "TAK Server installation failed — $TAK_DIR not found."
# CoreConfig.xml is created by the .deb postinstall; if missing (e.g. after a
# failed prior run that re-ran dpkg), recreate it from the example.
if [[ ! -f "${TAK_DIR}/CoreConfig.xml" ]]; then
    [[ -f "${TAK_DIR}/CoreConfig.example.xml" ]] || \
        die "TAK Server install incomplete — CoreConfig.xml and CoreConfig.example.xml both missing."
    cp "${TAK_DIR}/CoreConfig.example.xml" "${TAK_DIR}/CoreConfig.xml"
    info "CoreConfig.xml recreated from example."
fi
id tak &>/dev/null || die "TAK Server install incomplete — 'tak' user not created by .deb."
success "TAK Server installed to $TAK_DIR"

# ─── 7. Set up TAK database manually ─────────────────────────────────────────
# TAK's own setup-db.sh fails on Linux Mint due to pg_wrapper cluster issues.
# We do it directly instead.
info "Setting up TAK database..."

# Restart PG15 in case TAK's post-install script touched it
systemctl restart postgresql@15-main
sleep 5

# Wait for socket
PG_SOCKET="/var/run/postgresql/.s.PGSQL.5432"
for i in {1..20}; do
    [[ -S "$PG_SOCKET" ]] && break
    sleep 1
done
[[ -S "$PG_SOCKET" ]] || die "PostgreSQL socket not available — check: journalctl -u postgresql@15-main"

# Create user and database (always sync password in case deb set a different one)
sudo -u postgres psql -tc "SELECT 1 FROM pg_user WHERE usename='${DB_USER}'" \
    | grep -q 1 || sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}';"
sudo -u postgres psql -c "ALTER USER ${DB_USER} WITH PASSWORD '${DB_PASS}';"

sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" \
    | grep -q 1 || sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};"

sudo -u postgres psql -d "$DB_NAME" -c "CREATE EXTENSION IF NOT EXISTS postgis;" 2>/dev/null || true
sudo -u postgres psql -d "$DB_NAME" -c "CREATE EXTENSION IF NOT EXISTS postgis_topology;" 2>/dev/null || true
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};"

# Allow martiuser to connect via pg_hba.conf
PG15_HBA="/etc/postgresql/15/main/pg_hba.conf"
if ! grep -q "$DB_USER" "$PG15_HBA"; then
    cat >> "$PG15_HBA" << EOF
# TAK Server
host    ${DB_NAME}      ${DB_USER}      127.0.0.1/32            md5
host    ${DB_NAME}      ${DB_USER}      ::1/128                 md5
EOF
    systemctl reload postgresql@15-main
    sleep 2
fi

# Run TAK's schema manager to create all tables
info "  Running SchemaManager..."
sudo -u tak java -jar "${TAK_DIR}/db-utils/SchemaManager.jar" upgrade \
    > /tmp/tak_schema.log 2>&1 || \
    warn "SchemaManager may have failed — check /tmp/tak_schema.log if TAK Server fails to start"
grep -E "INFO|ERROR|WARN" /tmp/tak_schema.log | tail -10 || true

success "TAK database configured."

# Patch CoreConfig.xml to use the DB credentials defined above
CORECONFIG="${TAK_DIR}/CoreConfig.xml"
if [[ -f "$CORECONFIG" ]]; then
    info "Patching CoreConfig.xml with DB credentials..."
    sed -i "s|username=\"martiuser\" password=\"[^\"]*\"|username=\"${DB_USER}\" password=\"${DB_PASS}\"|g" "$CORECONFIG"
    if grep -q "password=\"${DB_PASS}\"" "$CORECONFIG"; then
        success "CoreConfig.xml updated (DB password: ${DB_PASS})"
    else
        warn "CoreConfig.xml patch may not have applied — verify DB credentials manually in ${CORECONFIG}"
    fi
fi

# ─── 8. Generate PKI certificates ────────────────────────────────────────────
info "Generating PKI certificates..."

CERTS_SCRIPT_DIR="${TAK_DIR}/certs"
[[ -d "$CERTS_SCRIPT_DIR" ]] || die "TAK certs dir not found: $CERTS_SCRIPT_DIR"
[[ -f "${CERTS_SCRIPT_DIR}/makeRootCa.sh" ]] || die "makeRootCa.sh not found"

export TAKPASS="$CERT_PASS"
export CAPASS="$CERT_PASS"
export PASS="$CERT_PASS"

# Wipe existing keystores/certs so keytool never hits an "alias already exists"
# interactive prompt, which would hang the script on re-runs.
CERT_FILES_DIR="${CERTS_SCRIPT_DIR}/files"
if [[ -d "$CERT_FILES_DIR" ]]; then
    info "  Clearing existing cert files to prevent keytool prompts on re-run..."
    rm -f "${CERT_FILES_DIR}"/*.p12 "${CERT_FILES_DIR}"/*.jks \
          "${CERT_FILES_DIR}"/*.pem "${CERT_FILES_DIR}"/*.csr 2>/dev/null || true
fi

pushd "$CERTS_SCRIPT_DIR" > /dev/null

info "  Generating Root CA: $CA_NAME"
bash makeRootCa.sh --ca-name "$CA_NAME" </dev/null 2>&1 | grep -E "Certificate|error|Error" | head -5 || true

info "  Generating server cert: $SERVER_NAME"
bash makeCert.sh server "$SERVER_NAME" </dev/null 2>&1 | grep -E "ok|error|Error" | head -3 || true

info "  Generating admin cert: $ADMIN_USER"
bash makeCert.sh client "$ADMIN_USER" </dev/null 2>&1 | grep -E "ok|error|Error" | head -3 || true

for name in "${CLIENT_NAMES[@]}"; do
    info "  Generating client cert: $name"
    bash makeCert.sh client "$name" </dev/null 2>&1 | grep -E "ok|error|Error" | head -2 || true
done

popd > /dev/null

# CoreConfig.xml needs fed-truststore.jks
cp "${CERT_DIR}/truststore-root.jks" "${CERT_DIR}/fed-truststore.jks" 2>/dev/null || true

# Copy all certificates to $SCRIPT_DIR/certs/ for easy access
CERT_OUT_DIR="${SCRIPT_DIR}/certs"
mkdir -p "$CERT_OUT_DIR"

[[ -f "${CERT_DIR}/${ADMIN_USER}.p12" ]] && \
    cp "${CERT_DIR}/${ADMIN_USER}.p12" "${CERT_OUT_DIR}/${ADMIN_USER}.p12" && \
    success "Admin cert copied to: ${CERT_OUT_DIR}/${ADMIN_USER}.p12"

[[ -f "${CERT_DIR}/root-ca.pem" ]] && \
    cp "${CERT_DIR}/root-ca.pem" "${CERT_OUT_DIR}/root-ca.pem" && \
    success "Root CA copied to: ${CERT_OUT_DIR}/root-ca.pem"

[[ -f "${CERT_DIR}/truststore-root.jks" ]] && \
    cp "${CERT_DIR}/truststore-root.jks" "${CERT_OUT_DIR}/truststore-root.jks" && \
    success "Truststore (JKS) copied to: ${CERT_OUT_DIR}/truststore-root.jks"

# Use the real PKCS12 truststore for ATAK/WinTAK — do NOT rename the JKS file
if [[ -f "${CERT_DIR}/truststore-root.p12" ]]; then
    cp "${CERT_DIR}/truststore-root.p12" "${CERT_OUT_DIR}/truststore-root.p12"
    success "Truststore (PKCS12) copied to: ${CERT_OUT_DIR}/truststore-root.p12"
elif [[ -f "${CERT_DIR}/truststore-root.jks" ]]; then
    # Convert JKS → PKCS12 so ATAK gets a valid .p12 file
    keytool -importkeystore \
        -srckeystore  "${CERT_DIR}/truststore-root.jks" \
        -destkeystore "${CERT_OUT_DIR}/truststore-root.p12" \
        -deststoretype PKCS12 \
        -srcstorepass  "$CERT_PASS" \
        -deststorepass "$CERT_PASS" \
        -noprompt 2>/dev/null && \
        success "Truststore converted JKS→PKCS12: ${CERT_OUT_DIR}/truststore-root.p12" || \
        warn "Truststore PKCS12 conversion failed — copy truststore-root.jks to ATAK manually"
fi

for client_p12 in "${CERT_DIR}"/client*.p12 "${CERT_DIR}"/client*.jks; do
    [[ -f "$client_p12" ]] || continue
    cp "$client_p12" "${CERT_OUT_DIR}/" && \
        success "Client cert copied to: ${CERT_OUT_DIR}/$(basename "$client_p12")"
done

# Auto-import certs into Firefox for the invoking user
REAL_USER="${SUDO_USER:-${USER:-root}}"
REAL_HOME="$(getent passwd "$REAL_USER" 2>/dev/null | cut -d: -f6 || true)"
FF_PROFILE="$(find "${REAL_HOME}/.mozilla/firefox" "${REAL_HOME}/.config/mozilla/firefox" \
    -maxdepth 2 -name "cert9.db" 2>/dev/null | head -1 | xargs -r dirname 2>/dev/null || true)"

if [[ -n "$FF_PROFILE" ]]; then
    info "Importing certificates into Firefox profile: $FF_PROFILE"
    sudo -u "$REAL_USER" pk12util \
        -i "${CERT_OUT_DIR}/${ADMIN_USER}.p12" \
        -d "sql:${FF_PROFILE}" \
        -W "$CERT_PASS" 2>/dev/null && \
        success "Admin cert imported into Firefox." || \
        warn "Firefox admin cert import failed — import manually: ${CERT_OUT_DIR}/${ADMIN_USER}.p12"
    sudo -u "$REAL_USER" certutil \
        -A -n "TAK-CA" -t "CT,," \
        -i "${CERT_OUT_DIR}/root-ca.pem" \
        -d "sql:${FF_PROFILE}" 2>/dev/null && \
        success "Root CA imported into Firefox." || \
        warn "Firefox CA import failed — import manually: ${CERT_OUT_DIR}/root-ca.pem"
else
    warn "Firefox profile not found — import certs manually:"
    warn "  CA:    ${CERT_OUT_DIR}/root-ca.pem"
    warn "  Admin: ${CERT_OUT_DIR}/${ADMIN_USER}.p12  (pass: ${CERT_PASS})"
fi

# Fix permissions
chown -R tak:tak "$CERT_DIR" 2>/dev/null || chown -R root:root "$CERT_DIR"
chmod 640 "${CERT_DIR}"/*.p12 2>/dev/null || true
chmod 644 "${CERT_DIR}"/*.pem 2>/dev/null || true
chmod 644 "${CERT_DIR}"/*.jks 2>/dev/null || true

success "All certificates generated in: $CERT_DIR"

# ─── 9. Let's Encrypt (optional) ─────────────────────────────────────────────
if [[ -n "$DOMAIN" ]]; then
    info "Setting up Let's Encrypt certificate for: $DOMAIN"

    # Verify domain resolves before attempting certbot — fail early with a clear message
    if ! getent hosts "$DOMAIN" &>/dev/null; then
        die "Domain '$DOMAIN' does not resolve. Point your DNS A record to ${PUBLIC_IP} and wait for propagation, then re-run."
    fi

    apt-get install -y certbot

    # Open port 80 temporarily for the ACME HTTP challenge
    ufw allow 80/tcp comment "Certbot ACME challenge" 2>/dev/null || true

    # Build certbot options
    # --cert-name is required when changing key type on re-run (certbot safeguard)
    CERTBOT_OPTS=(certonly --standalone --non-interactive --agree-tos
                  --key-type rsa --cert-name "$DOMAIN" -d "$DOMAIN")
    if [[ -n "$LE_EMAIL" ]]; then
        CERTBOT_OPTS+=(--email "$LE_EMAIL")
    else
        CERTBOT_OPTS+=(--register-unsafely-without-email)
    fi

    USE_LE=0
    if certbot "${CERTBOT_OPTS[@]}"; then
        # Create deploy hook — runs on initial deploy and every renewal
        LE_DEPLOY="/etc/letsencrypt/renewal-hooks/deploy/takserver.sh"
        mkdir -p "$(dirname "$LE_DEPLOY")"
        cat > "$LE_DEPLOY" << EOF
#!/bin/bash
# Converts renewed Let's Encrypt cert to PKCS12 and redeploys to TAK Server
LE_LIVE="/etc/letsencrypt/live/${DOMAIN}"
CERT_DIR="/opt/tak/certs/files"
PASS="${CERT_PASS}"

openssl pkcs12 -export \\
    -in  "\${LE_LIVE}/fullchain.pem" \\
    -inkey "\${LE_LIVE}/privkey.pem" \\
    -out "\${CERT_DIR}/takserver.p12" \\
    -name takserver \\
    -passout "pass:\${PASS}"

# TAK also reads a .jks — keep it in sync
cp "\${CERT_DIR}/takserver.p12" "\${CERT_DIR}/takserver.jks"
chown tak:tak "\${CERT_DIR}/takserver.p12" "\${CERT_DIR}/takserver.jks"
chmod 640 "\${CERT_DIR}/takserver.p12" "\${CERT_DIR}/takserver.jks"

# Restart TAK only if it is already running (skip during initial install)
systemctl is-active --quiet takserver && systemctl restart takserver || true
EOF
        chmod +x "$LE_DEPLOY"

        # Apply cert immediately
        bash "$LE_DEPLOY"

        success "Let's Encrypt certificate installed and auto-renewal configured."
        USE_LE=1
    else
        warn "Let's Encrypt failed (rate limit, DNS, or port 80 blocked). Continuing without LE — using self-signed certs."
        warn "Re-run with DOMAIN=${DOMAIN} once the issue is resolved to get a trusted certificate."
        DOMAIN=""
    fi

    # Remove temporary port 80 rule
    ufw delete allow 80/tcp 2>/dev/null || true
else
    USE_LE=0
fi

# ─── 10. Install MediaMTX (video streaming) ──────────────────────────────────
if [[ -n "${SKIP_MEDIAMTX:-}" ]]; then
    info "Skipping MediaMTX (SKIP_MEDIAMTX is set)."
else
info "Installing MediaMTX v${MEDIAMTX_VER}..."
MEDIAMTX_URL="https://github.com/bluenviron/mediamtx/releases/download/v${MEDIAMTX_VER}/mediamtx_v${MEDIAMTX_VER}_linux_${MEDIAMTX_ARCH}.tar.gz"
MEDIAMTX_TMP="/tmp/mediamtx_install"
mkdir -p "$MEDIAMTX_TMP"

if wget -q --show-progress -O "${MEDIAMTX_TMP}/mediamtx.tar.gz" "$MEDIAMTX_URL"; then
    tar -xzf "${MEDIAMTX_TMP}/mediamtx.tar.gz" -C "$MEDIAMTX_TMP"
    install -m 755 "${MEDIAMTX_TMP}/mediamtx" /usr/local/bin/mediamtx
    rm -rf "$MEDIAMTX_TMP"

    mkdir -p /etc/mediamtx
    cat > /etc/mediamtx/mediamtx.yml << 'MEDIAMTX_CONF'
logLevel: info
logDestinations: [stdout]
rtspAddress: :8554
rtmpAddress: :1935
hlsAddress: :8888
webrtcAddress: :8889
# Use standard MPEG-TS segments — avoids the default LL-HLS muxer stalling
# when clients connect before enough partial segments have accumulated.
hlsVariant: mpegts
hlsSegmentDuration: 2s
api: yes
apiAddress: 127.0.0.1:9997
readTimeout: 10s
writeTimeout: 10s
writeQueueSize: 512
paths:
  "~^.*$":
    source: publisher
    record: no
MEDIAMTX_CONF

    cat > /etc/systemd/system/mediamtx.service << 'SYSTEMD_UNIT'
[Unit]
Description=MediaMTX RTSP/HLS/WebRTC Media Server
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/mediamtx /etc/mediamtx/mediamtx.yml
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
SYSTEMD_UNIT

    systemctl daemon-reload
    systemctl enable --now mediamtx
    sleep 3
    systemctl is-active --quiet mediamtx && \
        success "MediaMTX running (RTSP :${RTSP_PORT}, HLS :${HLS_PORT})" || \
        warn "MediaMTX may not have started — check: journalctl -u mediamtx"
else
    warn "MediaMTX download failed — skipping video setup."
    SKIP_MEDIAMTX=1
fi
fi # end SKIP_MEDIAMTX check

# ─── 11. Install Mumble Server ────────────────────────────────────────────────
info "Installing Mumble server..."
apt-get install -y mumble-server

# Generate superuser password
MUMBLE_SUPERUSER_PASS="$(openssl rand -base64 16)"

# Write configuration
cat > /etc/mumble-server.ini << EOF
# Mumble Server Configuration
welcometext=<br />Welcome to <b>${MUMBLE_SERVER_NAME}</b>.<br />
port=${MUMBLE_PORT}
serverpassword=${MUMBLE_PASS}
bandwidth=320000
users=${MUMBLE_MAX_USERS}
registerName=${MUMBLE_SERVER_NAME}
autobanAttempts=10
autobanTimeframe=120
autobanTime=300
logfile=/var/log/mumble-server/mumble-server.log
EOF

# Set the superuser password (-supw expects the password as a positional argument)
mumble-server -supw "$MUMBLE_SUPERUSER_PASS" -ini /etc/mumble-server.ini 2>/dev/null || \
    warn "Mumble SuperUser password may not have been set — set it manually with: mumble-server -supw <password>"

systemctl enable --now mumble-server
sleep 2
systemctl is-active --quiet mumble-server && \
    success "Mumble server running on port ${MUMBLE_PORT}." || \
    warn "Mumble server may not have started — check: journalctl -u mumble-server"

# ─── 12. Install Node-RED ────────────────────────────────────────────────────
info "Installing Node-RED..."

# Install Node.js LTS via NodeSource
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - 2>/dev/null
apt-get install -y nodejs

# Install Node-RED globally
npm install -g --unsafe-perm node-red 2>/dev/null

# Resolve the node-red binary path (varies: /usr/bin or /usr/local/bin depending on npm prefix)
NODERED_BIN="$(command -v node-red 2>/dev/null)"
[[ -x "$NODERED_BIN" ]] || NODERED_BIN="$(npm prefix -g 2>/dev/null)/bin/node-red"
[[ -x "$NODERED_BIN" ]] || NODERED_BIN="$(find /usr/local/bin /usr/bin -name node-red 2>/dev/null | head -1)"
[[ -x "$NODERED_BIN" ]] || die "node-red binary not found after install — check: npm install -g node-red"
info "node-red binary: $NODERED_BIN"

# Create dedicated user and home directory
id nodered &>/dev/null || useradd -r -m -d /home/nodered -s /usr/sbin/nologin nodered

# Generate password hash for the admin UI
[[ -z "$NODERED_PASS" ]] && NODERED_PASS="$(openssl rand -base64 16)"
NODERED_HASH="$(echo "$NODERED_PASS" | timeout 30 "$NODERED_BIN" admin hash-pw 2>/dev/null | sed 's/^Password: //' || true)"
[[ -n "$NODERED_HASH" ]] || die "node-red admin hash-pw produced no output — Node-RED may not have installed correctly. Check: $NODERED_BIN admin hash-pw"

# Write settings file
mkdir -p /home/nodered/.node-red
cat > /home/nodered/.node-red/settings.js << EOF
module.exports = {
    uiPort: ${NODERED_PORT},
    mqttReconnectTime: 15000,
    serialReconnectTime: 15000,
    debugMaxLength: 1000,
    adminAuth: {
        type: "credentials",
        users: [{
            username: "${NODERED_USER}",
            password: "${NODERED_HASH}",
            permissions: "*"
        }]
    },
    editorTheme: {
        projects: { enabled: false }
    },
    logging: {
        console: { level: "info", metrics: false, audit: false }
    }
}
EOF

chown -R nodered:nodered /home/nodered

# Create systemd service
cat > /etc/systemd/system/node-red.service << EOF
[Unit]
Description=Node-RED
After=network.target

[Service]
Type=simple
User=nodered
WorkingDirectory=/home/nodered
ExecStart=${NODERED_BIN} --settings /home/nodered/.node-red/settings.js
Restart=on-failure
RestartSec=10
KillSignal=SIGINT
SyslogIdentifier=node-red

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now node-red
sleep 3
systemctl is-active --quiet node-red && \
    success "Node-RED running on port ${NODERED_PORT}." || \
    warn "Node-RED may not have started — check: journalctl -u node-red"

# Give the invoking user ownership of the certs output dir so they can SCP
# without needing sudo (script runs as root, dir is otherwise root-owned)
chown -R "${REAL_USER}:${REAL_USER}" "${CERT_OUT_DIR}" 2>/dev/null || true

# ─── 13. TAK Admin Panel ─────────────────────────────────────────────────────
info "Installing RagTak Admin Panel..."

[[ -z "$TAKADMIN_PASS" ]] && TAKADMIN_PASS="$(openssl rand -base64 12 | tr -d '/+=')"
TAKADMIN_SECRET="$(openssl rand -hex 32)"
TAKADMIN_DIR="/opt/takadmin"
mkdir -p "$TAKADMIN_DIR"

# Install Flask
apt-get install -y python3-flask 2>/dev/null || \
    pip3 install flask 2>/dev/null || \
    die "Flask install failed — cannot set up admin panel"

apt-get install -y python3-qrcode -q 2>/dev/null || \
    pip3 install "qrcode[pure]" --break-system-packages -q 2>/dev/null || \
    pip3 install qrcode --break-system-packages -q 2>/dev/null || \
    true  # non-fatal: QR feature degrades gracefully without it

cat > "${TAKADMIN_DIR}/takadmin.py" << 'PYEOF'
#!/usr/bin/env python3
"""RagTAK Admin Panel — unified management for TAK Server and companion services."""

import io, os, re, secrets, shutil, subprocess, threading, time, zipfile
from functools import wraps
from pathlib import Path
from flask import (Flask, flash, jsonify, redirect, render_template_string,
                   request, send_file, session, url_for)

app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY', secrets.token_hex(32))

ADMIN_USER   = os.environ.get('TAKADMIN_USER', 'Admin')
ADMIN_PASS   = os.environ.get('TAKADMIN_PASS', 'changeme')
TAK_DIR      = '/opt/tak'
CERT_DIR     = f'{TAK_DIR}/certs/files'
CERTS_SCRIPT = f'{TAK_DIR}/certs'
PUBLIC_IP    = os.environ.get('PUBLIC_IP', '')
SERVER_IP    = os.environ.get('SERVER_IP', '')
CERT_PASS    = os.environ.get('CERT_PASS', 'atakatak')
CERT_OUT_DIR = os.environ.get('CERT_OUT_DIR', '/opt/tak/certs/files')
DOMAIN       = os.environ.get('DOMAIN', '')
VPN_IP       = os.environ.get('VPN_IP', '')
# When OpenVPN is installed all services are VPN-only — use VPN IP for links.
# Otherwise use SERVER_IP (machine IP or domain), never the raw WAN IP.
HOST         = VPN_IP if os.environ.get('OPENVPN_INSTALLED') and VPN_IP else SERVER_IP or DOMAIN or PUBLIC_IP

SERVICES = [
    ('takserver',          'TAK Server'),
    ('postgresql@15-main', 'PostgreSQL 15'),
    ('mediamtx',           'MediaMTX'),
    ('mumble-server',      'Mumble'),
    ('node-red',           'Node-RED'),
]
if os.environ.get('OPENVPN_INSTALLED'):
    SERVICES.append(('openvpn@server', 'OpenVPN'))
SAFE_SERVICES = {s for s, _ in SERVICES}


def run(*cmd, input=None, **kw):
    return subprocess.run(list(cmd), capture_output=True, text=True, input=input, **kw)


def svc_status(name):
    return run('systemctl', 'is-active', name).stdout.strip() or 'unknown'


def system_stats():
    stats = {}
    try:
        with open('/proc/loadavg') as f:
            parts = f.read().split()
            stats['load1'] = parts[0]
            stats['load5'] = parts[1]
    except Exception:
        stats['load1'] = stats['load5'] = '?'
    try:
        lines = run('free', '-m').stdout.splitlines()
        mem = lines[1].split()
        total, used = int(mem[1]), int(mem[2])
        stats['ram_used'] = used
        stats['ram_total'] = total
        stats['ram_pct'] = int(used / total * 100) if total else 0
    except Exception:
        stats['ram_used'] = stats['ram_total'] = stats['ram_pct'] = 0
    try:
        lines = run('df', '-m', '/').stdout.splitlines()
        parts = lines[1].split()
        total, used = int(parts[1]), int(parts[2])
        stats['disk_used'] = used // 1024
        stats['disk_total'] = total // 1024
        stats['disk_pct'] = int(used / total * 100) if total else 0
    except Exception:
        stats['disk_used'] = stats['disk_total'] = stats['disk_pct'] = 0
    try:
        uptime_sec = float(open('/proc/uptime').read().split()[0])
        h = int(uptime_sec // 3600)
        m = int((uptime_sec % 3600) // 60)
        stats['uptime'] = f'{h}h {m}m'
    except Exception:
        stats['uptime'] = '?'
    return stats


def login_required(f):
    @wraps(f)
    def g(*a, **kw):
        if not session.get('ok'):
            return redirect(url_for('login'))
        return f(*a, **kw)
    return g


# ── Share tokens (QR cert transfer) ─────────────────────────────────────────

_share_tokens: dict = {}   # token -> {'type': str, 'arg': str, 'exp': float}
_share_lock = threading.Lock()

def _purge_expired():
    while True:
        time.sleep(60)
        now = time.time()
        with _share_lock:
            for k in [k for k, v in _share_tokens.items() if v['exp'] < now]:
                del _share_tokens[k]

threading.Thread(target=_purge_expired, daemon=True).start()


# ── Auth ──────────────────────────────────────────────────────────────────────

@app.route('/login', methods=['GET', 'POST'])
def login():
    err = None
    if request.method == 'POST':
        if (request.form.get('username') == ADMIN_USER and
                request.form.get('password') == ADMIN_PASS):
            session['ok'] = True
            return redirect(url_for('dashboard'))
        err = 'Invalid username or password.'
    return render_template_string(T_LOGIN, err=err)


@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))


# ── Dashboard ─────────────────────────────────────────────────────────────────

@app.route('/')
@login_required
def dashboard():
    statuses = [(svc, label, svc_status(svc)) for svc, label in SERVICES]
    stats = system_stats()
    return render_template_string(T_DASH, statuses=statuses, stats=stats, host=HOST)


@app.route('/api/stats')
@login_required
def api_stats():
    statuses = {label: svc_status(svc) for svc, label in SERVICES}
    stats = system_stats()
    return jsonify(services=statuses, **stats)


@app.route('/service/<name>/restart', methods=['POST'])
@login_required
def restart(name):
    if name not in SAFE_SERVICES:
        return 'Forbidden', 403
    run('systemctl', 'restart', name)
    flash(f'Restarted {name}.', 'success')
    return redirect(url_for('dashboard'))


# ── Users ─────────────────────────────────────────────────────────────────────

@app.route('/users')
@login_required
def users():
    p12s = sorted(p.stem for p in Path(CERT_DIR).glob('*.p12')
                  if p.stem != 'takserver')
    return render_template_string(T_USERS, users=p12s, cert_pass=CERT_PASS)


@app.route('/users/create', methods=['POST'])
@login_required
def create_user():
    name = request.form.get('username', '').strip()
    if not name or not re.fullmatch(r'[a-zA-Z0-9_-]{1,32}', name):
        flash('Invalid username — letters, numbers, hyphens, underscores only (max 32).', 'error')
        return redirect(url_for('users'))

    cert_p12 = Path(CERT_DIR) / f'{name}.p12'
    if cert_p12.exists():
        flash(f'User "{name}" already exists.', 'error')
        return redirect(url_for('users'))

    # 1. Generate TAK certificate
    env = {**os.environ,
           'TAKPASS': CERT_PASS, 'CAPASS': CERT_PASS, 'PASS': CERT_PASS,
           'STATE':               os.environ.get('STATE', 'NA'),
           'CITY':                os.environ.get('CITY', 'NA'),
           'ORGANIZATION':        os.environ.get('ORGANIZATION', 'RagTAK'),
           'ORGANIZATIONAL_UNIT': os.environ.get('ORGANIZATIONAL_UNIT', 'TAK')}
    r = run('bash', 'makeCert.sh', 'client', name, cwd=CERTS_SCRIPT, env=env)
    if not cert_p12.exists():
        flash(f'Certificate generation failed: {r.stderr[:300]}', 'error')
        return redirect(url_for('users'))

    # Copy cert to output dir
    out = Path(CERT_OUT_DIR)
    out.mkdir(parents=True, exist_ok=True)
    shutil.copy(cert_p12, out / cert_p12.name)

    # Also copy .pem for TAK registration
    pem = Path(CERT_DIR) / f'{name}.pem'
    if pem.exists():
        shutil.copy(pem, out / pem.name)

    # 2. Register with TAK Server
    if pem.exists():
        run('java', '-jar', f'{TAK_DIR}/utils/UserManager.jar', 'certmod', '-A', str(pem))

    flash(f'User "{name}" created — TAK certificate ready.', 'success')
    return redirect(url_for('users'))


_PROTECTED_USERS = {'takserver', 'tak-admin', 'root-ca', 'truststore-root'}

@app.route('/users/delete', methods=['POST'])
@login_required
def delete_user():
    name = request.form.get('username', '').strip()
    if not name or not re.fullmatch(r'[a-zA-Z0-9_-]{1,32}', name):
        flash('Invalid username.', 'error')
        return redirect(url_for('users'))
    if name in _PROTECTED_USERS:
        flash(f'Cannot delete protected user "{name}".', 'error')
        return redirect(url_for('users'))

    # Remove from TAK Server (non-fatal)
    run('java', '-jar', f'{TAK_DIR}/utils/UserManager.jar', 'usermod', '-D', name)

    # Delete cert files from both directories
    deleted = []
    for d in [Path(CERT_DIR), Path(CERT_OUT_DIR)]:
        for f in d.glob(f'{name}.*'):
            try:
                f.unlink()
                deleted.append(f.name)
            except OSError:
                pass

    if deleted:
        flash(f'User "{name}" deleted.', 'success')
    else:
        flash(f'User "{name}" not found.', 'error')
    return redirect(url_for('users'))


# ── Downloads ─────────────────────────────────────────────────────────────────

@app.route('/downloads')
@login_required
def downloads():
    out   = Path(CERT_OUT_DIR)
    p12s  = sorted(p.name for p in out.glob('*.p12'))  if out.exists() else []
    ovpns = sorted(p.name for p in out.glob('*.ovpn')) if out.exists() else []
    return render_template_string(T_DL, p12s=p12s, ovpns=ovpns, cert_pass=CERT_PASS)


@app.route('/download/file/<filename>')
@login_required
def dl_file(filename):
    out    = Path(CERT_OUT_DIR).resolve()
    target = (out / filename).resolve()
    if not str(target).startswith(str(out)) or not target.exists():
        return 'Not found', 404
    return send_file(target, as_attachment=True)


@app.route('/download/bundle/browser')
@login_required
def dl_browser():
    buf = io.BytesIO()
    out = Path(CERT_OUT_DIR)
    with zipfile.ZipFile(buf, 'w', zipfile.ZIP_DEFLATED) as z:
        for fn in ['root-ca.pem', 'tak-admin.p12']:
            p = out / fn
            if p.exists():
                z.write(p, fn)
        z.writestr('README.txt',
            f'TAK Browser Certificates\n'
            f'========================\n\n'
            f'1. Firefox > Settings > Privacy & Security > View Certificates\n'
            f'2. Authorities tab  > Import > root-ca.pem\n'
            f'   Check "Trust this CA to identify websites"\n'
            f'3. Your Certificates > Import > tak-admin.p12  (password: {CERT_PASS})\n'
            f'4. Fully restart Firefox, then open: https://{HOST}:8443\n'
            f'   Select the tak-admin certificate when prompted.\n')
    buf.seek(0)
    return send_file(buf, mimetype='application/zip',
                     as_attachment=True, download_name='tak-browser-bundle.zip')


@app.route('/download/bundle/atak/<username>')
@login_required
def dl_atak(username):
    if not re.fullmatch(r'[a-zA-Z0-9_-]{1,32}', username):
        return 'Invalid', 400
    buf = io.BytesIO()
    out = Path(CERT_OUT_DIR)
    with zipfile.ZipFile(buf, 'w', zipfile.ZIP_DEFLATED) as z:
        for fn in ['truststore-root.p12', f'{username}.p12', f'{username}.ovpn']:
            p = out / fn
            if p.exists():
                z.write(p, fn)
        ovpn_line = (f'  OpenVPN    : {username}.ovpn  (import into OpenVPN Connect app)\n'
                     if (out / f'{username}.ovpn').exists() else '')
        z.writestr('README.txt',
            f'TAK Device Bundle — {username}\n'
            f'==============================\n\n'
            f'ATAK / iTAK / WinTAK connection\n'
            f'  Server     : ssl://{HOST}:8089\n'
            f'  Trust Store: truststore-root.p12  (password: {CERT_PASS})\n'
            f'  Client Cert: {username}.p12        (password: {CERT_PASS})\n'
            + ovpn_line)
    buf.seek(0)
    return send_file(buf, mimetype='application/zip',
                     as_attachment=True, download_name=f'tak-atak-{username}.zip')


@app.route('/share/create', methods=['POST'])
@login_required
def share_create():
    share_type = request.form.get('type', '')
    arg        = request.form.get('arg', '')
    if share_type == 'atak':
        if not re.fullmatch(r'[a-zA-Z0-9_-]{1,32}', arg):
            return jsonify(error='Invalid username'), 400
    elif share_type == 'file':
        out    = Path(CERT_OUT_DIR).resolve()
        target = (out / arg).resolve()
        if not str(target).startswith(str(out)) or not target.exists():
            return jsonify(error='File not found'), 404
    else:
        return jsonify(error='Unknown type'), 400
    token = secrets.token_urlsafe(32)
    with _share_lock:
        _share_tokens[token] = {'type': share_type, 'arg': arg, 'exp': time.time() + 900}
    share_url = request.host_url.rstrip('/') + f'/share/{token}'
    try:
        import qrcode, qrcode.image.svg
        qr  = qrcode.make(share_url, image_factory=qrcode.image.svg.SvgPathImage,
                          box_size=8, border=2)
        buf = io.BytesIO()
        qr.save(buf)
        svg = buf.getvalue().decode('utf-8')
        if svg.startswith('<?xml'):
            svg = svg[svg.index('<svg'):]
    except ImportError:
        svg = None
    return jsonify(url=share_url, svg=svg)


@app.route('/share/<token>')
def share_download(token):
    with _share_lock:
        entry = _share_tokens.get(token)
        if not entry or entry['exp'] < time.time():
            _share_tokens.pop(token, None)
            return 'Link expired or already used.', 410
        del _share_tokens[token]
    share_type = entry['type']
    arg        = entry['arg']
    if share_type == 'atak':
        if not re.fullmatch(r'[a-zA-Z0-9_-]{1,32}', arg):
            return 'Invalid', 400
        buf = io.BytesIO()
        out = Path(CERT_OUT_DIR)
        with zipfile.ZipFile(buf, 'w', zipfile.ZIP_DEFLATED) as z:
            for fn in ['truststore-root.p12', f'{arg}.p12', f'{arg}.ovpn']:
                p = out / fn
                if p.exists():
                    z.write(p, fn)
            ovpn_line = (f'  OpenVPN    : {arg}.ovpn  (import into OpenVPN Connect app)\n'
                         if (out / f'{arg}.ovpn').exists() else '')
            z.writestr('README.txt',
                f'TAK Device Bundle - {arg}\n'
                f'==============================\n\n'
                f'ATAK / iTAK / WinTAK connection\n'
                f'  Server     : ssl://{HOST}:8089\n'
                f'  Trust Store: truststore-root.p12  (password: {CERT_PASS})\n'
                f'  Client Cert: {arg}.p12             (password: {CERT_PASS})\n'
                + ovpn_line)
        buf.seek(0)
        return send_file(buf, mimetype='application/zip',
                         as_attachment=True, download_name=f'tak-atak-{arg}.zip')
    elif share_type == 'file':
        out    = Path(CERT_OUT_DIR).resolve()
        target = (out / arg).resolve()
        if not str(target).startswith(str(out)) or not target.exists():
            return 'Not found', 404
        return send_file(target, as_attachment=True)
    return 'Invalid token type', 400


# ── Templates ─────────────────────────────────────────────────────────────────

_BASE = '''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>RagTAK Admin</title>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    :root {
      --bg:        #0a0e14;
      --surface:   #111720;
      --surface2:  #161d2a;
      --border:    #1e2d3d;
      --border2:   #2a3a4e;
      --text:      #cdd9e5;
      --muted:     #6b8099;
      --accent:    #1f7a3a;
      --accent-h:  #26a148;
      --accent-glow: rgba(38,161,72,.15);
      --danger:    #c0392b;
      --danger-bg: #1a0f0f;
      --warn:      #b7860d;
      --warn-bg:   #1a1505;
      --ok-bg:     #0a1a0f;
      --link:      #4fa3e0;
      --radius:    8px;
      --font:      -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }
    body { background: var(--bg); color: var(--text); font-family: var(--font);
           font-size: 14px; line-height: 1.6; min-height: 100vh; }
    a { color: var(--link); text-decoration: none; }
    a:hover { color: #7dc4f5; text-decoration: none; }
    code { background: var(--surface2); padding: .15em .45em; border-radius: 4px;
           font-size: .85em; font-family: "SFMono-Regular", Consolas, monospace;
           color: #e2c97e; border: 1px solid var(--border); }

    /* ── Scrollbar ── */
    ::-webkit-scrollbar { width: 6px; } ::-webkit-scrollbar-track { background: var(--bg); }
    ::-webkit-scrollbar-thumb { background: var(--border2); border-radius: 3px; }

    /* ── Nav ── */
    nav { background: var(--surface); border-bottom: 1px solid var(--border);
          padding: 0 2rem; display: flex; align-items: center;
          justify-content: space-between; height: 54px;
          position: sticky; top: 0; z-index: 100;
          box-shadow: 0 1px 12px rgba(0,0,0,.4); }
    .nav-brand { font-weight: 700; font-size: .95rem; letter-spacing: .02em;
                 color: var(--text); display: flex; align-items: center; gap: .4rem; }
    .nav-brand .tri { color: var(--accent-h); font-size: 1.1rem; }
    .nav-brand .sub { color: var(--accent-h); }
    .nav-links { display: flex; gap: .25rem; }
    .nav-links a { color: var(--muted); font-size: .875rem; padding: .4rem .85rem;
                   border-radius: 6px; transition: background .15s, color .15s; }
    .nav-links a:hover { background: var(--surface2); color: var(--text); }
    .nav-links a.active { background: var(--surface2); color: var(--text);
                          border: 1px solid var(--border2); }
    .nav-links a.logout { color: #8b4a4a; }
    .nav-links a.logout:hover { background: #1a0f0f; color: #e07070; }

    /* ── Layout ── */
    .page { max-width: 1100px; margin: 0 auto; padding: 1.75rem 2rem; }

    /* ── Flash ── */
    .flash { padding: .75rem 1rem; border-radius: var(--radius); margin-bottom: 1.25rem;
             font-size: .875rem; border: 1px solid; display: flex; align-items: center; gap: .5rem; }
    .flash-success { background: var(--ok-bg);     border-color: #1f7a3a; color: #4ecb71; }
    .flash-error   { background: var(--danger-bg); border-color: #7a1f1f; color: #e07070; }
    .flash-warning { background: var(--warn-bg);   border-color: #7a5a10; color: #e2b84a; }
    .flash-info    { background: #0a1520;           border-color: #1f5080; color: #4fa3e0; }

    /* ── Section heading ── */
    .section-title { font-size: .7rem; font-weight: 700; color: var(--muted);
                     text-transform: uppercase; letter-spacing: .1em;
                     margin-bottom: .75rem; margin-top: 1.75rem; }
    .section-title:first-child { margin-top: 0; }

    /* ── Metric cards ── */
    .metrics { display: grid; grid-template-columns: repeat(4, 1fr); gap: 1rem; margin-bottom: .25rem; }
    .metric { background: var(--surface); border: 1px solid var(--border);
              border-radius: var(--radius); padding: 1rem 1.25rem;
              display: flex; flex-direction: column; gap: .25rem; }
    .metric-label { font-size: .7rem; color: var(--muted); text-transform: uppercase;
                    letter-spacing: .08em; font-weight: 600; }
    .metric-value { font-size: 1.6rem; font-weight: 700; color: var(--text); line-height: 1.2; }
    .metric-sub   { font-size: .75rem; color: var(--muted); }
    .progress { height: 3px; background: var(--border); border-radius: 2px; margin-top: .4rem; }
    .progress-bar { height: 100%; border-radius: 2px; transition: width .3s; }
    .bar-ok   { background: var(--accent-h); }
    .bar-warn { background: #d29922; }
    .bar-crit { background: var(--danger); }

    /* ── Service grid ── */
    .svc-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: .75rem; }
    .svc-card { background: var(--surface); border: 1px solid var(--border);
                border-radius: var(--radius); padding: 1rem 1.1rem;
                display: flex; flex-direction: column; gap: .6rem;
                transition: border-color .15s; position: relative; overflow: hidden; }
    .svc-card::before { content: ''; position: absolute; left: 0; top: 0; bottom: 0;
                        width: 3px; border-radius: var(--radius) 0 0 var(--radius); }
    .svc-card.ok::before      { background: var(--accent-h); }
    .svc-card.failed::before  { background: var(--danger); }
    .svc-card.activating::before { background: var(--warn); }
    .svc-card.inactive::before   { background: var(--border2); }
    .svc-card.unknown::before    { background: var(--border2); }
    .svc-card:hover { border-color: var(--border2); }
    .svc-name { font-weight: 600; font-size: .9rem; }
    .svc-status { display: flex; align-items: center; gap: .4rem; font-size: .8rem; }
    .dot { width: 7px; height: 7px; border-radius: 50%; flex-shrink: 0; }
    .dot-ok         { background: var(--accent-h); box-shadow: 0 0 6px var(--accent-h); }
    .dot-failed     { background: #e05050; box-shadow: 0 0 6px #e05050; }
    .dot-activating { background: #d29922; box-shadow: 0 0 6px #d29922; }
    .dot-inactive   { background: var(--muted); }
    .dot-unknown    { background: var(--muted); }
    .status-text-ok         { color: #4ecb71; }
    .status-text-failed     { color: #e07070; }
    .status-text-activating { color: #e2b84a; }
    .status-text-inactive   { color: var(--muted); }
    .status-text-unknown    { color: var(--muted); }

    /* ── Quick links ── */
    .links-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: .75rem; }
    .link-card { background: var(--surface); border: 1px solid var(--border);
                 border-radius: var(--radius); padding: .9rem 1.1rem;
                 display: flex; align-items: center; gap: .75rem;
                 transition: border-color .15s, background .15s; }
    .link-card:hover { border-color: var(--border2); background: var(--surface2); }
    .link-icon { font-size: 1.3rem; flex-shrink: 0; }
    .link-title { font-size: .875rem; font-weight: 600; color: var(--text); }
    .link-desc  { font-size: .75rem; color: var(--muted); }

    /* ── Buttons ── */
    .btn { display: inline-flex; align-items: center; gap: .35rem;
           padding: .4rem .9rem; border-radius: 6px; font-size: .825rem;
           font-weight: 500; cursor: pointer; border: 1px solid;
           text-align: center; line-height: 1.4; transition: all .15s;
           font-family: var(--font); }
    .btn-primary   { background: var(--accent);  border-color: var(--accent-h); color: #fff; }
    .btn-primary:hover { background: var(--accent-h); }
    .btn-secondary { background: transparent; border-color: var(--border2); color: var(--text); }
    .btn-secondary:hover { border-color: var(--muted); background: var(--surface2); }
    .btn-danger    { background: transparent; border-color: #7a1f1f; color: #e07070; }
    .btn-danger:hover { background: var(--danger-bg); }
    .btn-sm { padding: .25rem .6rem; font-size: .78rem; }
    .btn-full { width: 100%; justify-content: center; }

    /* ── Card ── */
    .card { background: var(--surface); border: 1px solid var(--border);
            border-radius: var(--radius); margin-bottom: 1rem; overflow: hidden; }
    .card-header { padding: .7rem 1.1rem; border-bottom: 1px solid var(--border);
                   font-weight: 600; font-size: .78rem; color: var(--muted);
                   text-transform: uppercase; letter-spacing: .07em;
                   display: flex; align-items: center; justify-content: space-between; }
    .card-body { padding: 1.1rem; }

    /* ── Forms ── */
    input[type=text], input[type=password] {
      background: var(--bg); border: 1px solid var(--border2); color: var(--text);
      border-radius: 6px; padding: .5rem .8rem; font-size: .875rem;
      width: 100%; font-family: var(--font); transition: border-color .15s; }
    input:focus { outline: none; border-color: var(--link); box-shadow: 0 0 0 3px rgba(79,163,224,.1); }
    label { display: block; margin-bottom: .3rem; font-size: .8rem; color: var(--muted); font-weight: 500; }
    .form-group { margin-bottom: 1rem; }
    .input-row { display: flex; gap: .5rem; }
    .input-row input { flex: 1; }

    /* ── Table ── */
    table { width: 100%; border-collapse: collapse; font-size: .875rem; }
    th { text-align: left; padding: .6rem 1rem; color: var(--muted); font-weight: 600;
         border-bottom: 1px solid var(--border); font-size: .72rem;
         text-transform: uppercase; letter-spacing: .07em; }
    td { padding: .65rem 1rem; border-bottom: 1px solid var(--border); color: var(--text); }
    tr:last-child td { border-bottom: none; }
    tr:hover td { background: var(--surface2); }

    /* ── Login ── */
    .login-wrap { min-height: 100vh; display: flex; align-items: center;
                  justify-content: center; background: var(--bg); }
    .login-box { background: var(--surface); border: 1px solid var(--border);
                 border-radius: 10px; padding: 2rem 2.25rem; width: 360px;
                 box-shadow: 0 8px 32px rgba(0,0,0,.5); }
    .login-logo { font-size: 1.4rem; font-weight: 800; margin-bottom: .2rem; }
    .login-logo span { color: var(--accent-h); }
    .login-sub { color: var(--muted); font-size: .85rem; margin-bottom: 1.75rem; }
    .login-err { background: var(--danger-bg); border: 1px solid #7a1f1f;
                 color: #e07070; padding: .6rem .9rem; border-radius: 6px;
                 font-size: .85rem; margin-bottom: 1rem; }

    p { color: var(--muted); font-size: .875rem; margin-bottom: .75rem; }
    small { font-size: .78rem; color: var(--muted); }

    /* ── QR Modal ── */
    .modal-bg { display:none; position:fixed; inset:0; background:rgba(0,0,0,.72);
                z-index:500; align-items:center; justify-content:center; }
    .modal-bg.open { display:flex; }
    .modal-box { background:var(--surface); border:1px solid var(--border2);
                 border-radius:var(--radius); padding:1.5rem; max-width:360px;
                 width:90%; box-shadow:0 12px 40px rgba(0,0,0,.6);
                 display:flex; flex-direction:column; align-items:center; gap:1rem; }
    .modal-title { font-size:.875rem; font-weight:600; color:var(--text); text-align:center; }
    .modal-qr { background:#fff; padding:10px; border-radius:6px; line-height:0; }
    .modal-qr svg { width:200px; height:200px; }
    .modal-url { font-size:.72rem; color:var(--muted); word-break:break-all; text-align:center; }
    .modal-note { font-size:.75rem; color:#c9971c; background:rgba(201,151,28,.1);
                  border:1px solid #7a5a10; border-radius:6px;
                  padding:.5rem .75rem; width:100%; box-sizing:border-box; text-align:center; }
    .modal-close { align-self:flex-end; background:none; border:none; color:var(--muted);
                   cursor:pointer; font-size:1.1rem; padding:.2rem .4rem; border-radius:4px; }
    .modal-close:hover { color:var(--text); background:var(--surface2); }
  </style>
</head>
<body>
{% if request.path != "/login" %}
<nav>
  <div class="nav-brand">
    <span class="tri">&#9650;</span> RagTAK <span class="sub">Admin</span>
  </div>
  <div class="nav-links">
    <a href="/" {% if request.path == "/" %}class="active"{% endif %}>Dashboard</a>
    <a href="/users" {% if request.path == "/users" %}class="active"{% endif %}>Users</a>
    <a href="/downloads" {% if request.path == "/downloads" %}class="active"{% endif %}>Downloads</a>
    <a href="/logout" class="logout">Logout</a>
  </div>
</nav>
{% endif %}
<div class="page">
  {% with msgs = get_flashed_messages(with_categories=True) %}
    {% for cat, msg in msgs %}
      <div class="flash flash-{{ cat }}">{{ msg }}</div>
    {% endfor %}
  {% endwith %}
  CONTENT_PLACEHOLDER
</div>
</body>
</html>'''

def page(content):
    return _BASE.replace('CONTENT_PLACEHOLDER', content)


T_LOGIN = page('''
<div class="login-wrap">
  <div class="login-box">
    <div class="login-logo">&#9650; RagTAK <span>Admin</span></div>
    <div class="login-sub">Tactical Operations Center</div>
    {% if err %}<div class="login-err">{{ err }}</div>{% endif %}
    <form method="post">
      <div class="form-group">
        <label>Username</label>
        <input type="text" name="username" autofocus required>
      </div>
      <div class="form-group">
        <label>Password</label>
        <input type="password" name="password" required>
      </div>
      <button type="submit" class="btn btn-primary btn-full">Sign in</button>
    </form>
  </div>
</div>
''')

T_DASH = page('''
<div class="section-title">System</div>
<div class="metrics">
  {% set lf = stats.load1|float %}
  <div class="metric">
    <div class="metric-label">CPU Load (1m)</div>
    <div class="metric-value">{{ stats.load1 }}</div>
    <div class="metric-sub">5m avg: {{ stats.load5 }}</div>
  </div>
  <div class="metric">
    <div class="metric-label">Memory</div>
    <div class="metric-value">{{ stats.ram_pct }}<span style="font-size:.9rem;color:var(--muted)">%</span></div>
    <div class="metric-sub">{{ stats.ram_used }} / {{ stats.ram_total }} MB</div>
    <div class="progress"><div class="progress-bar {% if stats.ram_pct > 85 %}bar-crit{% elif stats.ram_pct > 65 %}bar-warn{% else %}bar-ok{% endif %}"
         style="width:{{ stats.ram_pct }}%"></div></div>
  </div>
  <div class="metric">
    <div class="metric-label">Disk</div>
    <div class="metric-value">{{ stats.disk_pct }}<span style="font-size:.9rem;color:var(--muted)">%</span></div>
    <div class="metric-sub">{{ stats.disk_used }} / {{ stats.disk_total }} GB</div>
    <div class="progress"><div class="progress-bar {% if stats.disk_pct > 85 %}bar-crit{% elif stats.disk_pct > 65 %}bar-warn{% else %}bar-ok{% endif %}"
         style="width:{{ stats.disk_pct }}%"></div></div>
  </div>
  <div class="metric">
    <div class="metric-label">Uptime</div>
    <div class="metric-value" style="font-size:1.2rem">{{ stats.uptime }}</div>
    <div class="metric-sub">server runtime</div>
  </div>
</div>

<div class="section-title">Services</div>
<div class="svc-grid">
{% for svc, label, status in statuses %}
  <div class="svc-card {{ status }}">
    <div class="svc-name">{{ label }}</div>
    <div class="svc-status">
      <div class="dot dot-{{ status }}"></div>
      <span class="status-text-{{ status }}">{{ status }}</span>
    </div>
    <form method="post" action="/service/{{ svc }}/restart" style="margin:0">
      <button type="submit" class="btn btn-secondary btn-sm">&#8635; Restart</button>
    </form>
  </div>
{% endfor %}
</div>

<div class="section-title">Quick Links</div>
<div class="links-grid">
  <a href="https://{{ host }}:8443" target="_blank" class="link-card">
    <div class="link-icon">&#127760;</div>
    <div><div class="link-title">TAK Web Admin</div>
         <div class="link-desc">Mission management UI</div></div>
  </a>
  <a href="http://{{ host }}:1880" target="_blank" class="link-card">
    <div class="link-icon">&#9654;</div>
    <div><div class="link-title">Node-RED</div>
         <div class="link-desc">Flow automation</div></div>
  </a>
  <a href="/users" class="link-card">
    <div class="link-icon">&#128101;</div>
    <div><div class="link-title">Manage Users</div>
         <div class="link-desc">TAK certificates</div></div>
  </a>
  <a href="/downloads" class="link-card">
    <div class="link-icon">&#128190;</div>
    <div><div class="link-title">Downloads</div>
         <div class="link-desc">Certs, bundles, configs</div></div>
  </a>
</div>
''')

T_USERS = page('''
<div class="section-title">Create User</div>
<div class="card" style="margin-bottom:1.5rem">
  <div class="card-body">
    <form method="post" action="/users/create">
      <div class="input-row">
        <input type="text" name="username" placeholder="e.g. soldier1"
               pattern="[a-zA-Z0-9_-]+" maxlength="32" required>
        <button type="submit" class="btn btn-primary">&#43; Create</button>
      </div>
    </form>
    <small style="margin-top:.6rem;display:block">Generates a TAK client certificate and registers it on the server.</small>
  </div>
</div>

<div class="section-title">Existing Users</div>
{% if users %}
<div class="card">
  <div class="card-header">
    <span>{{ users|length }} user(s)</span>
    <span>Cert password: <code>{{ cert_pass }}</code></span>
  </div>
  <table>
    <thead><tr>
      <th>Name</th>
      <th>TAK Certificate</th>
      <th>ATAK Bundle</th>
      <th></th>
    </tr></thead>
    <tbody>
    {% for u in users %}
      <tr>
        <td>{{ u }}</td>
        <td><a href="/download/file/{{ u }}.p12" download>&#8659; {{ u }}.p12</a></td>
        <td><a href="/download/bundle/atak/{{ u }}" download>&#8659; ATAK bundle</a></td>
        <td>
          <form method="post" action="/users/delete" style="margin:0"
                onsubmit="return confirm(&quot;Delete user {{ u }}? This cannot be undone.&quot;)">
            <input type="hidden" name="username" value="{{ u }}">
            <button type="submit" class="btn btn-danger" style="padding:.3rem .7rem;font-size:.8rem">Delete</button>
          </form>
        </td>
      </tr>
    {% endfor %}
    </tbody>
  </table>
</div>
{% else %}
<p>No certificates found in cert directory.</p>
{% endif %}
''')

T_DL = page('''
<div class="section-title">Browser Access</div>
<div class="card" style="margin-bottom:1.5rem">
  <div class="card-body" style="display:flex;align-items:center;justify-content:space-between;gap:1rem;flex-wrap:wrap">
    <div>
      <p style="margin:0 0 .25rem">Root CA + Admin certificate for browser access to
         <code>https://{{ request.host.split(":")[0] }}:8443</code>.</p>
      <small>Import into Firefox/Chrome to access the TAK web admin UI.</small>
    </div>
    <a href="/download/bundle/browser" class="btn btn-primary" download>&#8659; browser-bundle.zip</a>
  </div>
</div>

<div class="section-title">Individual Certificates &nbsp;<small style="text-transform:none;font-weight:400">password: <code>{{ cert_pass }}</code></small></div>
<div class="card" style="margin-bottom:1.5rem">
  <table>
    <thead><tr><th>File</th><th>Download</th></tr></thead>
    <tbody>
    {% for fn in p12s %}
      <tr>
        <td><code>{{ fn }}</code></td>
        <td><a href="/download/file/{{ fn }}" download>&#8659; Download</a></td>
      </tr>
    {% endfor %}
    </tbody>
  </table>
</div>

{% if ovpns %}
<div class="section-title">OpenVPN Configs &nbsp;<small style="text-transform:none;font-weight:400">import into OpenVPN Connect app</small></div>
<div class="card" style="margin-bottom:1.5rem">
  <table>
    <thead><tr><th>File</th><th>Download</th><th>Mobile QR</th></tr></thead>
    <tbody>
    {% for fn in ovpns %}
      <tr>
        <td><code>{{ fn }}</code></td>
        <td><a href="/download/file/{{ fn }}" download>&#8659; Download</a></td>
        <td><button class="btn btn-secondary" style="padding:.3rem .7rem;font-size:.8rem"
                    onclick="showQr(&quot;file&quot;,&quot;{{ fn }}&quot;)">&#9636; QR</button></td>
      </tr>
    {% endfor %}
    </tbody>
  </table>
</div>
{% endif %}

<div class="section-title">Device Bundles</div>
<div class="card">
  <div class="card-header">TAK certificate bundles per device</div>
  <table>
    <thead><tr>
      <th>User</th><th>ATAK Bundle (cert + README)</th><th>Mobile QR</th>
    </tr></thead>
    <tbody>
    {% for fn in p12s %}
      {% set u = fn[:-4] %}
      {% if u != 'takserver' %}
      <tr>
        <td>{{ u }}</td>
        <td><a href="/download/bundle/atak/{{ u }}" download>&#8659; tak-atak-{{ u }}.zip</a></td>
        <td><button class="btn btn-secondary" style="padding:.3rem .7rem;font-size:.8rem"
                    onclick="showQr(&quot;atak&quot;,&quot;{{ u }}&quot;)">&#9636; QR</button></td>
      </tr>
      {% endif %}
    {% endfor %}
    </tbody>
  </table>
</div>

<div class="modal-bg" id="qrModal">
  <div class="modal-box">
    <button class="modal-close" onclick="closeQr()">&#10005;</button>
    <div class="modal-title">Scan to download on mobile</div>
    <div class="modal-qr" id="qrSvg" style="color:#888;font-size:.85rem;padding:1rem">Generating...</div>
    <div class="modal-url" id="qrUrl"></div>
    <div class="modal-note" id="qrNote"></div>
  </div>
</div>
<script>
function showQr(type, arg) {
  var modal = document.getElementById("qrModal");
  var svgEl = document.getElementById("qrSvg");
  var urlEl = document.getElementById("qrUrl");
  var note  = document.getElementById("qrNote");
  svgEl.innerHTML = "Generating...";
  svgEl.style.padding = "1rem";
  urlEl.textContent = "";
  note.textContent = "";
  modal.classList.add("open");
  var fd = new FormData();
  fd.append("type", type);
  fd.append("arg",  arg);
  fetch("/share/create", {method:"POST", body:fd})
    .then(function(r){ return r.json(); })
    .then(function(data) {
      if (data.error) {
        svgEl.innerHTML = data.error;
        return;
      }
      if (data.svg) {
        svgEl.innerHTML = data.svg;
        svgEl.style.padding = "10px";
      } else {
        svgEl.innerHTML = "Install qrcode on server to enable QR.";
      }
      urlEl.textContent = data.url;
      if (type === "file") {
        note.textContent = "Link valid 15 min, single use. In VPN mode: connect OpenVPN on the phone first, then scan.";
      } else {
        note.textContent = "Link valid 15 min, single use. In VPN mode: connect OpenVPN first, then scan.";
      }
    })
    .catch(function() { svgEl.innerHTML = "Request failed."; });
}
function closeQr() {
  document.getElementById("qrModal").classList.remove("open");
}
document.getElementById("qrModal").addEventListener("click", function(e) {
  if (e.target === this) { closeQr(); }
});
</script>
''')


if __name__ == '__main__':
    bind_host = os.environ.get('BIND_HOST', '0.0.0.0')
    port      = int(os.environ.get('TAKADMIN_PORT', '8080'))
    app.run(host=bind_host, port=port, debug=False)
PYEOF

# Write systemd service with all config baked in as environment variables
cat > /etc/systemd/system/takadmin.service << EOF
[Unit]
Description=RagTak Admin Panel
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${TAKADMIN_DIR}
ExecStart=/usr/bin/env python3 ${TAKADMIN_DIR}/takadmin.py
Restart=on-failure
RestartSec=5
Environment=TAKADMIN_USER=Admin
Environment=TAKADMIN_PASS=${TAKADMIN_PASS}
Environment=CERT_PASS=${CERT_PASS}
Environment=CERT_OUT_DIR=${CERT_OUT_DIR}
Environment=PUBLIC_IP=${PUBLIC_IP}
Environment=SERVER_IP=${SERVER_IP}
Environment=DOMAIN=${DOMAIN}
Environment=TAKADMIN_PORT=${TAKADMIN_PORT}
Environment=BIND_HOST=0.0.0.0
Environment=SECRET_KEY=${TAKADMIN_SECRET}
Environment=OPENVPN_INSTALLED=$([[ "${INSTALL_OPENVPN:-no}" == "yes" ]] && echo 1 || echo "")
Environment=VPN_IP=$([[ "${INSTALL_OPENVPN:-no}" == "yes" ]] && echo "${OPENVPN_SUBNET}.1" || echo "")
Environment=STATE=${STATE:-NA}
Environment=CITY=${CITY:-NA}
Environment=ORGANIZATION=${ORGANIZATION:-RagTAK}
Environment=ORGANIZATIONAL_UNIT=${ORGANIZATIONAL_UNIT:-TAK}

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now takadmin
sleep 2
systemctl is-active --quiet takadmin && \
    success "RagTak Admin Panel running on port ${TAKADMIN_PORT}." || \
    warn "RagTak Admin Panel may not have started — check: journalctl -u takadmin"

# ─── 14. OpenVPN ─────────────────────────────────────────────────────────────
if [[ "${INSTALL_OPENVPN:-no}" == "yes" ]]; then
    info "Installing OpenVPN..."
    apt-get install -y openvpn easy-rsa || die "openvpn/easy-rsa install failed"

    EASYRSA_DIR="/etc/openvpn/easy-rsa"
    # Remove any previous run so make-cadir gets a clean directory
    rm -rf "$EASYRSA_DIR"
    make-cadir "$EASYRSA_DIR" || die "make-cadir failed — is easy-rsa installed?"
    [[ -x "${EASYRSA_DIR}/easyrsa" ]] || die "easyrsa not found at ${EASYRSA_DIR}/easyrsa"

    # Build PKI — separate from TAK certs
    cd "$EASYRSA_DIR"
    ./easyrsa init-pki </dev/null
    ./easyrsa --batch build-ca nopass </dev/null
    ./easyrsa --batch gen-req server nopass </dev/null
    ./easyrsa --batch sign-req server server </dev/null

    # TLS authentication key — syntax changed between OpenVPN 2.5 and 2.6; try both
    openvpn --genkey secret /etc/openvpn/ta.key 2>/dev/null \
        || openvpn --genkey --secret /etc/openvpn/ta.key \
        || die "Failed to generate OpenVPN TLS auth key"
    [[ -s /etc/openvpn/ta.key ]] || die "OpenVPN TLS auth key is empty — genkey failed silently"

    # Server config — ECDH avoids slow DH parameter generation
    mkdir -p /var/log/openvpn
    cat > /etc/openvpn/server.conf << EOF
port ${OPENVPN_PORT}
proto ${OPENVPN_PROTO}
dev tun
ca   ${EASYRSA_DIR}/pki/ca.crt
cert ${EASYRSA_DIR}/pki/issued/server.crt
key  ${EASYRSA_DIR}/pki/private/server.key
dh none
ecdh-curve prime256v1
server ${OPENVPN_SUBNET}.0 255.255.255.0
push "route ${OPENVPN_SUBNET}.0 255.255.255.0"
keepalive 10 120
tls-auth /etc/openvpn/ta.key 0
cipher AES-256-GCM
auth SHA256
persist-key
persist-tun
status /var/log/openvpn/status.log
log-append /var/log/openvpn/openvpn.log
verb 3
EOF

    # Generate one client .ovpn per device (inline certs — single file to import)
    VPN_ENDPOINT="${DOMAIN:-$PUBLIC_IP}"
    VPN_CLIENTS=("tak-admin" "${CLIENT_NAMES[@]}" "wintak")
    for CLIENT in "${VPN_CLIENTS[@]}"; do
        cd "$EASYRSA_DIR"
        ./easyrsa --batch gen-req  "$CLIENT" nopass </dev/null
        ./easyrsa --batch sign-req client "$CLIENT" </dev/null

        # Inline all keys/certs so the .ovpn is a single self-contained import file
        {
            cat << OVPN_HEADER
client
dev tun
proto ${OPENVPN_PROTO}
remote ${VPN_ENDPOINT} ${OPENVPN_PORT}
resolv-retry infinite
nobind
persist-key
persist-tun
key-direction 1
cipher AES-256-GCM
auth SHA256
verb 3
OVPN_HEADER
            echo "<ca>"
            cat "${EASYRSA_DIR}/pki/ca.crt"
            echo "</ca>"
            echo "<cert>"
            openssl x509 -in "${EASYRSA_DIR}/pki/issued/${CLIENT}.crt"
            echo "</cert>"
            echo "<key>"
            cat "${EASYRSA_DIR}/pki/private/${CLIENT}.key"
            echo "</key>"
            echo "<tls-auth>"
            cat /etc/openvpn/ta.key
            echo "</tls-auth>"
        } > "${CERT_OUT_DIR}/${CLIENT}.ovpn"
        chmod 600 "${CERT_OUT_DIR}/${CLIENT}.ovpn"
        success "  OpenVPN config: ${CERT_OUT_DIR}/${CLIENT}.ovpn"
    done

    # Fix ownership so user can SCP the new .ovpn files
    chown -R "${REAL_USER}:${REAL_USER}" "${CERT_OUT_DIR}" 2>/dev/null || true

    cd /

    # Enable IP forwarding so VPN clients can reach the server's services
    sysctl -w net.ipv4.ip_forward=1 >/dev/null
    cat > /etc/sysctl.d/99-ragtak-openvpn.conf << 'EOF'
net.ipv4.ip_forward = 1
EOF

    # NAT masquerade so traffic from the VPN subnet routes correctly.
    # We use UFW's before.rules rather than iptables-persistent because
    # iptables-persistent conflicts with and removes ufw on Ubuntu 24.04.
    # Exclude loopback, tunnel (tun/tap), and VPN interfaces from WAN detection
    WAN_IF="$(ip route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}' | head -1 || true)"
    [[ -z "$WAN_IF" ]] && \
        WAN_IF="$(ip -o link show | awk -F': ' '!/^[0-9]+: *(lo|tun|tap|docker|veth|virbr)/{print $2; exit}')"
    [[ -n "$WAN_IF" ]] || die "Could not detect WAN interface for OpenVPN NAT"
    info "OpenVPN NAT via interface: $WAN_IF"

    # Inject NAT masquerade into UFW's before.rules (persists across reboots via UFW)
    if ! grep -q "RAGTAK-OPENVPN-NAT" /etc/ufw/before.rules 2>/dev/null; then
        sed -i "1s|^|# RAGTAK-OPENVPN-NAT\n*nat\n:POSTROUTING ACCEPT [0:0]\n-A POSTROUTING -s ${OPENVPN_SUBNET}.0/24 -o ${WAN_IF} -j MASQUERADE\nCOMMIT\n\n|" \
            /etc/ufw/before.rules
    fi
    # UFW also needs forward policy set to ACCEPT
    sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw

    systemctl enable --now openvpn@server
    sleep 2
    systemctl is-active --quiet openvpn@server && \
        success "OpenVPN running on port ${OPENVPN_PORT}/${OPENVPN_PROTO}." || \
        warn "OpenVPN may not have started — check: journalctl -u openvpn@server"
fi

# ─── 15. Firewall ─────────────────────────────────────────────────────────────
info "Configuring firewall..."
# Explicit default policy — must be set before adding rules so VPN-only mode works
ufw default deny incoming
ufw default allow outgoing
# Always allow the actual SSH port — read from sshd_config to handle non-standard ports
SSH_PORT="$(grep -E '^[[:space:]]*Port[[:space:]]+[0-9]+' /etc/ssh/sshd_config 2>/dev/null \
    | awk '{print $2}' | head -1 || true)"
SSH_PORT="${SSH_PORT:-22}"
ufw allow "${SSH_PORT}/tcp" comment "SSH"
[[ "$SSH_PORT" != "22" ]] && ufw allow ssh 2>/dev/null || true   # also allow 22 if non-standard

if [[ "${INSTALL_OPENVPN:-no}" == "yes" ]]; then
    # OpenVPN installed: only SSH + VPN port are reachable from the internet.
    # All services are locked to the VPN subnet.
    ufw allow "${OPENVPN_PORT}/${OPENVPN_PROTO}"  comment "OpenVPN"
    ufw allow from "${OPENVPN_SUBNET}.0/24" to any port "${NODERED_PORT}"    proto tcp comment "Node-RED (VPN)"
    ufw allow from "${OPENVPN_SUBNET}.0/24" to any port "${MUMBLE_PORT}"     proto tcp comment "Mumble voice (VPN)"
    ufw allow from "${OPENVPN_SUBNET}.0/24" to any port "${MUMBLE_PORT}"     proto udp comment "Mumble voice/UDP (VPN)"
    ufw allow from "${OPENVPN_SUBNET}.0/24" to any port "${TAK_COT_PORT}"    proto tcp comment "TAK CoT (VPN)"
    ufw allow from "${OPENVPN_SUBNET}.0/24" to any port "${TAK_ADMIN_PORT}"  proto tcp comment "TAK web admin (VPN)"
    ufw allow from "${OPENVPN_SUBNET}.0/24" to any port "${TAK_ENROLL_PORT}" proto tcp comment "TAK enrollment (VPN)"
    ufw allow from "${OPENVPN_SUBNET}.0/24" to any port "${TAKADMIN_PORT}"   proto tcp comment "RagTAK Admin Panel (VPN)"
    if [[ -z "${SKIP_MEDIAMTX:-}" ]]; then
        ufw allow from "${OPENVPN_SUBNET}.0/24" to any port "${RTSP_PORT}"    proto tcp comment "MediaMTX RTSP (VPN)"
        ufw allow from "${OPENVPN_SUBNET}.0/24" to any port "${RTSP_PORT}"    proto udp comment "MediaMTX RTSP/UDP (VPN)"
        ufw allow from "${OPENVPN_SUBNET}.0/24" to any port "${HLS_PORT}"          proto tcp comment "MediaMTX HLS (VPN)"
        ufw allow from "${OPENVPN_SUBNET}.0/24" to any port "${WEBRTC_PORT}"      proto tcp comment "MediaMTX WebRTC (VPN)"
        ufw allow from "${OPENVPN_SUBNET}.0/24" to any port "${WEBRTC_ICE_PORT}"  proto udp comment "MediaMTX WebRTC ICE (VPN)"
    fi
else
    # No VPN — all service ports open directly
    ufw allow "${NODERED_PORT}/tcp"    comment "Node-RED"
    ufw allow "${MUMBLE_PORT}/tcp"     comment "Mumble voice"
    ufw allow "${MUMBLE_PORT}/udp"     comment "Mumble voice/UDP"
    ufw allow "${TAK_COT_PORT}/tcp"    comment "TAK CoT"
    ufw allow "${TAK_ADMIN_PORT}/tcp"  comment "TAK web admin"
    ufw allow "${TAK_ENROLL_PORT}/tcp" comment "TAK cert enrollment"
    if [[ -z "${SKIP_MEDIAMTX:-}" ]]; then
        ufw allow "${RTSP_PORT}/tcp"   comment "MediaMTX RTSP"
        ufw allow "${RTSP_PORT}/udp"   comment "MediaMTX RTSP/UDP"
        ufw allow "${HLS_PORT}/tcp"         comment "MediaMTX HLS"
        ufw allow "${WEBRTC_PORT}/tcp"      comment "MediaMTX WebRTC"
        ufw allow "${WEBRTC_ICE_PORT}/udp"  comment "MediaMTX WebRTC ICE"
    fi
    ufw allow "${TAKADMIN_PORT}/tcp"   comment "RagTAK Admin Panel"
fi

ufw --force enable
success "Firewall rules applied."

# ─── 16. Start TAK Server ────────────────────────────────────────────────────
info "Starting TAK Server..."
systemctl enable takserver
systemctl restart takserver
info "Waiting for TAK Server to start listening on port 8089 (up to 90 seconds)..."
_TAK_UP=0
for _i in {1..90}; do
    if ss -tln 2>/dev/null | grep -q ':8089 '; then
        _TAK_UP=1; break
    fi
    sleep 1
done
[[ $_TAK_UP -eq 1 ]] && success "TAK Server is listening on port 8089." || \
    warn "TAK Server did not start within 90 seconds — admin cert registration may fail."

# ─── 17. Register admin certificate ──────────────────────────────────────────
ADMIN_PEM="${CERT_DIR}/${ADMIN_USER}.pem"
if [[ -f "$ADMIN_PEM" ]]; then
    info "Registering admin certificate..."
    java -jar "${TAK_DIR}/utils/UserManager.jar" certmod -A "$ADMIN_PEM" 2>/dev/null && \
        success "Admin cert registered." || \
        warn "Admin cert registration failed — TAK may not be fully up yet. Run manually:"
    warn "  sudo java -jar ${TAK_DIR}/utils/UserManager.jar certmod -A ${ADMIN_PEM}"
fi

# ─── 18. Summary ──────────────────────────────────────────────────────────────

echo ""
echo "============================================================"
echo -e "  ${GREEN}TAK Server Installation Complete${NC}"
echo "============================================================"
echo ""
echo -e "  ${CYAN}Service status${NC}"
echo "    TAK Server : $(systemctl is-active takserver 2>/dev/null || echo 'unknown')"
echo "    PostgreSQL : $(systemctl is-active postgresql@15-main 2>/dev/null || echo 'unknown')"
echo "    Mumble     : $(systemctl is-active mumble-server 2>/dev/null || echo 'unknown')"
echo "    Node-RED   : $(systemctl is-active node-red 2>/dev/null || echo 'unknown')"
[[ -z "${SKIP_MEDIAMTX:-}" ]] && \
echo "    MediaMTX   : $(systemctl is-active mediamtx 2>/dev/null || echo 'unknown')"
echo "    RagTak     : $(systemctl is-active takadmin 2>/dev/null || echo 'unknown')"
[[ "${INSTALL_OPENVPN:-no}" == "yes" ]] && \
echo "    OpenVPN    : $(systemctl is-active openvpn@server 2>/dev/null || echo 'unknown')"
echo ""
echo -e "  ${CYAN}Endpoints${NC}"
if [[ "${INSTALL_OPENVPN:-no}" == "yes" ]]; then
echo "    NOTE: All services are VPN-only. Connect OpenVPN first, then use ${OPENVPN_SUBNET}.1"
echo "    Web Admin  : https://${OPENVPN_SUBNET}.1:${TAK_ADMIN_PORT}"
echo "    CoT/ATAK   : ssl://${OPENVPN_SUBNET}.1:${TAK_COT_PORT}"
echo "    Enrollment : https://${OPENVPN_SUBNET}.1:${TAK_ENROLL_PORT}"
[[ -z "${SKIP_MEDIAMTX:-}" ]] && \
echo "    RTSP Video : rtsp://${OPENVPN_SUBNET}.1:${RTSP_PORT}/<stream-name>"
echo "    Mumble     : ${OPENVPN_SUBNET}.1:${MUMBLE_PORT}"
echo "    Node-RED   : http://${OPENVPN_SUBNET}.1:${NODERED_PORT}"
echo "    RagTak     : http://${OPENVPN_SUBNET}.1:${TAKADMIN_PORT}"
else
echo "    Web Admin  : https://${SERVER_IP}:${TAK_ADMIN_PORT}"
echo "    CoT/ATAK   : ssl://${SERVER_IP}:${TAK_COT_PORT}"
echo "    Enrollment : https://${SERVER_IP}:${TAK_ENROLL_PORT}"
[[ -z "${SKIP_MEDIAMTX:-}" ]] && \
echo "    RTSP Video : rtsp://${SERVER_IP}:${RTSP_PORT}/<stream-name>"
echo "    Mumble     : ${SERVER_IP}:${MUMBLE_PORT}"
echo "    Node-RED   : http://${SERVER_IP}:${NODERED_PORT}"
echo "    RagTak     : http://${SERVER_IP}:${TAKADMIN_PORT}"
fi
[[ $USE_LE -eq 1 ]] && \
echo "" && \
echo -e "  ${CYAN}Let's Encrypt${NC}" && \
echo "    Domain     : ${DOMAIN}" && \
echo "    Renewal    : automatic (certbot systemd timer)" && \
echo "    ATAK note  : No trust store import needed — LE cert is trusted automatically"
echo ""
echo -e "  ${CYAN}Certificates${NC}  (${CERT_OUT_DIR})"
echo "    Root CA    : ${CERT_OUT_DIR}/root-ca.pem          <-- import into Firefox (Authorities)"
echo "    Server     : ${CERT_DIR}/${SERVER_NAME}.p12  (pass: ${CERT_PASS})"
echo "    Admin      : ${CERT_OUT_DIR}/${ADMIN_USER}.p12  <-- import into Firefox (Your Certificates)"
echo "               (pass: ${CERT_PASS})"
echo ""
echo "    Clients:"
for name in "${CLIENT_NAMES[@]}"; do
    echo "      ${CERT_OUT_DIR}/${name}.p12  (pass: ${CERT_PASS})"
done
echo ""
echo -e "  ${CYAN}Next steps${NC}"
echo "    1. Import ${CERT_OUT_DIR}/${ADMIN_USER}.p12 into Firefox/Chrome"
echo "       (password: ${CERT_PASS})"
echo "    2. Open: https://${SERVER_IP}:${TAK_ADMIN_PORT}"
echo "    3. On each ATAK/WinTAK device:"
echo "       a. Trust Store : ${CERT_OUT_DIR}/truststore-root.p12  (pass: ${CERT_PASS})"
echo "       b. Client Cert : ${CERT_OUT_DIR}/client1.p12 .. client5.p12  (pass: ${CERT_PASS})"
echo "       c. Server      : ssl://${SERVER_IP}:${TAK_COT_PORT}"
echo ""
echo -e "  ${CYAN}Mumble${NC}"
echo "    Port       : ${MUMBLE_PORT} (TCP+UDP)"
echo "    Superuser  : SuperUser / ${MUMBLE_SUPERUSER_PASS}"
[[ -n "$MUMBLE_PASS" ]] && \
echo "    Server pw  : ${MUMBLE_PASS}" || \
echo "    Server pw  : (none)"
echo ""
echo -e "  ${CYAN}Node-RED${NC}"
echo "    URL        : http://${SERVER_IP}:${NODERED_PORT}"
echo "    Username   : ${NODERED_USER}"
echo "    Password   : ${NODERED_PASS}"
echo ""
echo -e "  ${CYAN}RagTak Admin Panel${NC}"
if [[ "${INSTALL_OPENVPN:-no}" == "yes" ]]; then
echo "    URL        : http://${OPENVPN_SUBNET}.1:${TAKADMIN_PORT}  (VPN only)"
else
echo "    URL        : http://${SERVER_IP}:${TAKADMIN_PORT}"
fi
echo "    Username   : Admin"
echo "    Password   : ${TAKADMIN_PASS}"
if [[ "${INSTALL_OPENVPN:-no}" == "yes" ]]; then
echo ""
echo -e "  ${CYAN}OpenVPN${NC}"
echo "    Port       : ${OPENVPN_PORT}/$(tr '[:lower:]' '[:upper:]' <<< "$OPENVPN_PROTO")"
echo "    VPN subnet : ${OPENVPN_SUBNET}.0/24  (server: ${OPENVPN_SUBNET}.1)"
echo "    Configs    : (in ${CERT_OUT_DIR})"
for _c in "tak-admin" "${CLIENT_NAMES[@]}" "wintak"; do
    echo "      ${_c}.ovpn"
done
echo "    Import into OpenVPN Connect app (Android / iOS / Windows / Linux)"
echo "    Once connected: use ${OPENVPN_SUBNET}.1 as the TAK server address"
fi
echo ""
echo -e "  ${YELLOW}Logs:${NC} sudo tail -f /opt/tak/logs/takserver-messaging.log"
echo ""
echo "============================================================"
