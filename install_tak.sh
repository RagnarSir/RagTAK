#!/usr/bin/env bash
# =============================================================================
#  TAK Server Installation Script
#  Version   : 1.0
#  Target OS : Ubuntu 22.04 / 24.04, Debian, Linux Mint
#  Installs  : TAK Server 5.7, PostgreSQL 15, Java 17, MediaMTX (video), PKI
#
# =============================================================================
#  OVERVIEW
# =============================================================================
#
#  This script performs a fully automated TAK Server installation including:
#    - PostgreSQL 15 database setup
#    - TAK Server .deb installation and configuration
#    - Full PKI certificate generation (CA, server, admin, 5 client certs)
#    - Automatic Firefox certificate import (desktop installs)
#    - Let's Encrypt SSL certificate (optional, set DOMAIN=)
#    - MediaMTX RTSP/HLS/WebRTC video streaming server
#    - Mumble voice communication server
#    - Node-RED flow automation
#    - WireGuard VPN (client configs + QR codes generated automatically)
#    - UFW firewall configuration
#
# =============================================================================
#  STEP 1 — DOWNLOAD THE TAK SERVER PACKAGE
# =============================================================================
#
#  TAK Server is export-controlled software — you must register to download it.
#
#    1. Create a free account at https://tak.gov
#    2. Go to Products > TAK Server
#    3. Download the "Full" release:
#          takserver_5.7-RELEASE8_all.deb
#    4. Place the .deb file in the same directory as this script
#
# =============================================================================
#  STEP 2 — PREPARE YOUR SYSTEM
# =============================================================================
#
#  LOCAL MACHINE (Ubuntu/Debian/Mint desktop):
#    No special preparation needed. The script handles everything.
#
#  VPS / CLOUD SERVER:
#    You must open the following ports in your provider's firewall BEFORE
#    running the script (AWS Security Groups, DigitalOcean Firewall, etc.):
#
#      Port 22    / TCP  — SSH (keep this open or you'll lose access)
#      Port 8089  / TCP  — ATAK / WinTAK device connections (CoT over SSL)
#      Port 8443  / TCP  — Web admin interface
#      Port 8446  / TCP  — Certificate enrollment
#      Port 8554  / TCP  — MediaMTX RTSP video (optional)
#      Port 8554  / UDP  — MediaMTX RTSP/UDP video (optional)
#      Port 8888  / TCP  — MediaMTX HLS video (optional)
#      Port 8889  / TCP  — MediaMTX WebRTC video (optional)
#      Port 64738 / TCP  — Mumble voice
#      Port 64738 / UDP  — Mumble voice/UDP
#      Port 1880  / TCP  — Node-RED web UI
#      Port 51820 / UDP  — WireGuard VPN
#
#    Note: The script configures UFW (Linux firewall) automatically, but on
#    cloud providers UFW and the provider's firewall are independent — both
#    must allow the ports.
#
# =============================================================================
#  STEP 3 — RUN THE SCRIPT
# =============================================================================
#
#    sudo bash install_tak.sh
#
#  The script takes approximately 2-5 minutes to complete.
#  Do NOT interrupt it once started.
#
# =============================================================================
#  STEP 4 — ACCESS THE WEB ADMIN (BROWSER)
# =============================================================================
#
#  On a LOCAL machine:
#    The script automatically imports the admin certificate and Root CA into
#    Firefox. After install, close and reopen Firefox, then go to:
#      https://<your-ip>:8443
#    Firefox will prompt you to select the tak-admin certificate — select it.
#
#  On a VPS (no desktop):
#    Copy these two files from the install directory to your local machine:
#      tak-admin.p12      — your admin client certificate
#      root-ca.pem        — the certificate authority
#    Then import them into Firefox manually:
#      1. Open Firefox > Settings > Privacy & Security > View Certificates
#      2. Authorities tab > Import > select root-ca.pem
#         Check "Trust this CA to identify websites"
#      3. Your Certificates tab > Import > select tak-admin.p12
#         Password: atakatak
#    Then open: https://<your-server-ip>:8443
#
# =============================================================================
#  STEP 5 — CONNECT ATAK (ANDROID)
# =============================================================================
#
#  WITHOUT Let's Encrypt (self-signed):
#    Transfer these files to the Android device (USB, email, cloud storage):
#      truststore-root.p12   — server trust store (lets ATAK trust your server)
#      client1.p12           — client identity certificate (use one per device)
#
#    In ATAK:
#      1. Settings > Network Preferences > TAK Servers > Add (+)
#      2. Enter your server address and port 8089, protocol SSL
#      3. Trust Store  : truststore-root.p12  password: atakatak
#      4. Client Cert  : client1.p12          password: atakatak
#      5. Tap OK — the status indicator should turn green
#
#  WITH Let's Encrypt (DOMAIN set):
#    Transfer only the client cert to the device:
#      client1.p12           — client identity certificate (use one per device)
#
#    In ATAK:
#      1. Settings > Network Preferences > TAK Servers > Add (+)
#      2. Enter your domain and port 8089, protocol SSL
#      3. Client Cert  : client1.p12  password: atakatak
#         (No trust store needed — Let's Encrypt is trusted automatically)
#      4. Tap OK — the status indicator should turn green
#
#  Each device should use its own client cert (client1 through client5).
#  Do not reuse the same cert on multiple devices.
#
# =============================================================================
#  STEP 6 — CONNECT WINTAK (WINDOWS)
# =============================================================================
#
#  Transfer these files to the Windows machine:
#    truststore-root.p12   — server trust store (not needed with Let's Encrypt)
#    client2.p12           — client identity certificate
#
#  In WinTAK, follow the same server connection steps as ATAK above.
#
#  Optionally create a named WinTAK user account on the server:
#    sudo java -jar /opt/tak/utils/UserManager.jar usermod -A -p 'YourPassword' WinTAK
#
# =============================================================================
#  STEP 7 — CONNECT MUMBLE (VOICE)
# =============================================================================
#
#  Download the Mumble client from https://www.mumble.info
#
#  Connect using:
#    Address  : <your-server-ip-or-domain>
#    Port     : 64738
#    Username : anything
#    Password : (the server password shown in the install summary, if set)
#
#  The SuperUser password is printed at the end of the install — save it.
#  Use it to create channels and manage permissions via the Mumble client.
#
# =============================================================================
#  STEP 8 — ACCESS NODE-RED
# =============================================================================
#
#  Open in a browser:
#    http://<your-server-ip-or-domain>:1880
#
#  Login with the credentials printed at the end of the install summary.
#
#  Useful Node-RED integrations for TAK:
#    - Receive CoT events from TAK and forward to external systems
#    - Trigger alerts based on ATAK position reports
#    - Bridge TAK to MQTT, webhooks, or databases
#
# =============================================================================
#  STEP 9 — CONNECT WIREGUARD (VPN)
# =============================================================================
#
#  Client config files and QR codes are generated in the install directory:
#    wg-tak-admin.conf / .png   — admin workstation
#    wg-client1.conf  / .png    — ATAK device 1
#    wg-client2.conf  / .png    — ATAK device 2  (and so on)
#    wg-wintak.conf   / .png    — WinTAK workstation
#
#  ANDROID / iOS:
#    1. Install the WireGuard app from the Play Store / App Store
#    2. Tap + > Scan QR code > scan the .png for that device
#    3. Enable the tunnel — the device is now on the VPN
#    4. Connect ATAK to 10.13.13.1:8089 (VPN address) instead of public IP
#
#  WINDOWS / LINUX:
#    1. Install WireGuard from https://www.wireguard.com/install/
#    2. Import the .conf file for that device
#    3. Activate the tunnel
#    4. Connect WinTAK to 10.13.13.1:8089
#
#  NOTE: By default, only traffic to 10.13.13.0/24 goes through the VPN
#  (split tunnel). To route ALL traffic through the VPN, change AllowedIPs
#  in the client .conf to: 0.0.0.0/0, ::/0
#
#  VPS port to open: 51820/UDP
#
# =============================================================================
#  CERTIFICATE SUMMARY
# =============================================================================
#
#  All certificates are generated with password: atakatak
#  They are stored in /opt/tak/certs/files/ and copied to this directory.
#
#    root-ca.pem            — Root CA (import into Firefox Authorities)
#    truststore-root.p12    — Trust store for ATAK/WinTAK devices
#    tak-admin.p12          — Admin cert for browser access
#    client1-5.p12          — Client certs for ATAK/WinTAK devices
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
#    - Confirm port 8089 is open in all firewalls
#    - Use truststore-root.p12 (not root-ca.pem) on ATAK devices
#
#  Mumble not starting:
#    sudo systemctl status mumble-server
#    sudo journalctl -u mumble-server
#
#  Node-RED not starting:
#    sudo systemctl status node-red
#    sudo journalctl -u node-red
#
#  WireGuard not starting:
#    sudo systemctl status wg-quick@wg0
#    sudo journalctl -u wg-quick@wg0
#
#  Re-running the script (clean reinstall):
#    sudo systemctl stop takserver mediamtx mumble-server node-red wg-quick@wg0
#    sudo apt-get purge -y takserver mumble-server
#    sudo npm uninstall -g node-red
#    sudo userdel -r nodered 2>/dev/null || true
#    sudo rm -rf /etc/wireguard
#    sudo rm -rf /opt/tak
#    sudo -u postgres dropdb --if-exists cot
#    sudo -u postgres dropuser --if-exists martiuser
#    sudo rm -f /etc/systemd/system/mediamtx.service \
#               /usr/local/bin/mediamtx /etc/mediamtx/mediamtx.yml \
#               /etc/letsencrypt/renewal-hooks/deploy/takserver.sh
#    sudo systemctl daemon-reload
#    sudo bash install_tak.sh
#    # With Let's Encrypt:
#    DOMAIN=tak.example.com sudo bash install_tak.sh
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
export STATE="${STATE:-CPH}"
export CITY="${CITY:-Roskilde}"
export ORGANIZATION="${ORGANIZATION:-SSR}"
export ORGANIZATIONAL_UNIT="${ORGANIZATIONAL_UNIT:-S6}"

# Database credentials (must match CoreConfig.xml)
DB_USER="martiuser"
DB_PASS="martipass"
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

# WireGuard
WG_PORT="${WG_PORT:-51820}"
WG_SUBNET="${WG_SUBNET:-10.13.13}"     # /24 — server gets .1, clients get .2+
WG_DNS="${WG_DNS:-1.1.1.1}"

# Ports
TAK_COT_PORT=8089
TAK_ADMIN_PORT=8443
TAK_ENROLL_PORT=8446
RTSP_PORT=8554
HLS_PORT=8888
WEBRTC_PORT=8889

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
JAVA17_PATH="$(update-alternatives --list java 2>/dev/null | grep java-17 | head -1)"
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
dpkg -i "$TAK_DEB_PATH" || apt-get install -f -y
[[ -d "$TAK_DIR" ]] || die "TAK Server installation failed — $TAK_DIR not found."
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
sudo -u tak java -jar "${TAK_DIR}/db-utils/SchemaManager.jar" upgrade 2>&1 \
    | grep -E "INFO|ERROR|WARN" | tail -10 || true

success "TAK database configured."

# Patch CoreConfig.xml to use the DB credentials defined above
CORECONFIG="${TAK_DIR}/CoreConfig.xml"
if [[ -f "$CORECONFIG" ]]; then
    info "Patching CoreConfig.xml with DB credentials..."
    sed -i "s|username=\"martiuser\" password=\"[^\"]*\"|username=\"${DB_USER}\" password=\"${DB_PASS}\"|g" "$CORECONFIG"
    success "CoreConfig.xml updated (DB password: ${DB_PASS})"
fi

# ─── 8. Generate PKI certificates ────────────────────────────────────────────
info "Generating PKI certificates..."

CERTS_SCRIPT_DIR="${TAK_DIR}/certs"
[[ -d "$CERTS_SCRIPT_DIR" ]] || die "TAK certs dir not found: $CERTS_SCRIPT_DIR"
[[ -f "${CERTS_SCRIPT_DIR}/makeRootCa.sh" ]] || die "makeRootCa.sh not found"

export TAKPASS="$CERT_PASS"
export CAPASS="$CERT_PASS"
export PASS="$CERT_PASS"

pushd "$CERTS_SCRIPT_DIR" > /dev/null

info "  Generating Root CA: $CA_NAME"
bash makeRootCa.sh --ca-name "$CA_NAME" 2>&1 | grep -E "Certificate|error|Error" | head -5

info "  Generating server cert: $SERVER_NAME"
bash makeCert.sh server "$SERVER_NAME" 2>&1 | grep -E "ok|error|Error" | head -3

info "  Generating admin cert: $ADMIN_USER"
bash makeCert.sh client "$ADMIN_USER" 2>&1 | grep -E "ok|error|Error" | head -3

for name in "${CLIENT_NAMES[@]}"; do
    info "  Generating client cert: $name"
    bash makeCert.sh client "$name" 2>&1 | grep -E "ok|error|Error" | head -2
done

popd > /dev/null

# CoreConfig.xml needs fed-truststore.jks
cp "${CERT_DIR}/truststore-root.jks" "${CERT_DIR}/fed-truststore.jks" 2>/dev/null || true

# Copy admin cert and Root CA to install directory for easy access
[[ -f "${CERT_DIR}/${ADMIN_USER}.p12" ]] && \
    cp "${CERT_DIR}/${ADMIN_USER}.p12" "${SCRIPT_DIR}/${ADMIN_USER}.p12" && \
    success "Admin cert copied to: ${SCRIPT_DIR}/${ADMIN_USER}.p12"

[[ -f "${CERT_DIR}/root-ca.pem" ]] && \
    cp "${CERT_DIR}/root-ca.pem" "${SCRIPT_DIR}/root-ca.pem" && \
    success "Root CA copied to: ${SCRIPT_DIR}/root-ca.pem"

[[ -f "${CERT_DIR}/truststore-root.jks" ]] && \
    cp "${CERT_DIR}/truststore-root.jks" "${SCRIPT_DIR}/truststore-root.jks" && \
    cp "${CERT_DIR}/truststore-root.jks" "${SCRIPT_DIR}/truststore-root.p12" && \
    success "Truststore copied to: ${SCRIPT_DIR}/truststore-root.jks / .p12"

for client_p12 in "${CERT_DIR}"/client*.p12 "${CERT_DIR}"/client*.jks; do
    [[ -f "$client_p12" ]] || continue
    cp "$client_p12" "${SCRIPT_DIR}/" && \
        success "Client cert copied to: ${SCRIPT_DIR}/$(basename "$client_p12")"
done

# Auto-import certs into Firefox for the invoking user
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
FF_PROFILE="$(find "${REAL_HOME}/.mozilla/firefox" "${REAL_HOME}/.config/mozilla/firefox" \
    -maxdepth 2 -name "cert9.db" 2>/dev/null | head -1 | xargs dirname 2>/dev/null)"

if [[ -n "$FF_PROFILE" ]]; then
    info "Importing certificates into Firefox profile: $FF_PROFILE"
    sudo -u "$REAL_USER" pk12util \
        -i "${SCRIPT_DIR}/${ADMIN_USER}.p12" \
        -d "sql:${FF_PROFILE}" \
        -W "$CERT_PASS" 2>/dev/null && \
        success "Admin cert imported into Firefox." || \
        warn "Firefox admin cert import failed — import manually: ${SCRIPT_DIR}/${ADMIN_USER}.p12"
    sudo -u "$REAL_USER" certutil \
        -A -n "TAK-CA" -t "CT,," \
        -i "${SCRIPT_DIR}/root-ca.pem" \
        -d "sql:${FF_PROFILE}" 2>/dev/null && \
        success "Root CA imported into Firefox." || \
        warn "Firefox CA import failed — import manually: ${SCRIPT_DIR}/root-ca.pem"
else
    warn "Firefox profile not found — import certs manually:"
    warn "  CA:    ${SCRIPT_DIR}/root-ca.pem"
    warn "  Admin: ${SCRIPT_DIR}/${ADMIN_USER}.p12  (pass: ${CERT_PASS})"
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
    apt-get install -y certbot

    # Open port 80 temporarily for the ACME HTTP challenge
    ufw allow 80/tcp comment "Certbot ACME challenge" 2>/dev/null || true

    # Build certbot options
    CERTBOT_OPTS=(certonly --standalone --non-interactive --agree-tos -d "$DOMAIN")
    if [[ -n "$LE_EMAIL" ]]; then
        CERTBOT_OPTS+=(--email "$LE_EMAIL")
    else
        CERTBOT_OPTS+=(--register-unsafely-without-email)
    fi

    certbot "${CERTBOT_OPTS[@]}" || die "Let's Encrypt failed. Make sure $DOMAIN resolves to this server's public IP and port 80 is reachable."

    # Remove temporary port 80 rule
    ufw delete allow 80/tcp 2>/dev/null || true

    # Create deploy hook — runs on initial deploy and every renewal
    LE_DEPLOY="/etc/letsencrypt/renewal-hooks/deploy/takserver.sh"
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
    USE_LE=0
fi

# ─── 10. Install MediaMTX (video streaming) ──────────────────────────────────
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
rtspTransports: [tcp, udp, udp-multicast]
rtspEncryption: no
rtmpAddress: :1935
rtmpEncryption: no
hlsAddress: :8888
hlsEncryption: no
webrtcAddress: :8889
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

# Set the superuser password
(echo "$MUMBLE_SUPERUSER_PASS" | mumble-server -ini /etc/mumble-server.ini -supw 2>/dev/null) || true

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

# Create dedicated user and home directory
id nodered &>/dev/null || useradd -r -m -d /home/nodered -s /usr/sbin/nologin nodered

# Generate password hash for the admin UI
[[ -z "$NODERED_PASS" ]] && NODERED_PASS="$(openssl rand -base64 16)"
NODERED_HASH="$(node-red admin hash-pw "$NODERED_PASS" 2>/dev/null)"

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
cat > /etc/systemd/system/node-red.service << 'UNIT'
[Unit]
Description=Node-RED
After=network.target

[Service]
Type=simple
User=nodered
WorkingDirectory=/home/nodered
ExecStart=/usr/bin/node-red --settings /home/nodered/.node-red/settings.js
Restart=on-failure
RestartSec=10
KillSignal=SIGINT
SyslogIdentifier=node-red

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now node-red
sleep 3
systemctl is-active --quiet node-red && \
    success "Node-RED running on port ${NODERED_PORT}." || \
    warn "Node-RED may not have started — check: journalctl -u node-red"

# ─── 13. Install WireGuard ────────────────────────────────────────────────────
info "Installing WireGuard..."
apt-get install -y wireguard wireguard-tools qrencode

# Enable IP forwarding
sed -i 's/#*net.ipv4.ip_forward=.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sed -i 's/#*net.ipv6.conf.all.forwarding=.*/net.ipv6.conf.all.forwarding=1/' /etc/sysctl.conf
sysctl -w net.ipv4.ip_forward=1 >/dev/null

# Detect WAN interface
WAN_IF="$(ip route | awk '/default/ {print $5; exit}')"

# Generate server keys
wg genkey | tee /etc/wireguard/server.key | wg pubkey > /etc/wireguard/server.pub
chmod 600 /etc/wireguard/server.key /etc/wireguard/server.pub
WG_SERVER_PRIV="$(cat /etc/wireguard/server.key)"
WG_SERVER_PUB="$(cat /etc/wireguard/server.pub)"

# Resolve endpoint (domain if LE, otherwise public IP)
WG_PUBLIC_IP="$(curl -fsSL --max-time 5 https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')"
WG_ENDPOINT="${DOMAIN:-$WG_PUBLIC_IP}"

# Build server config and client configs
WG_CLIENTS=("tak-admin" "${CLIENT_NAMES[@]}" "wintak")
WG_SERVER_CONF="[Interface]
Address = ${WG_SUBNET}.1/24
ListenPort = ${WG_PORT}
PrivateKey = ${WG_SERVER_PRIV}
PostUp   = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o ${WAN_IF} -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o ${WAN_IF} -j MASQUERADE
"

for i in "${!WG_CLIENTS[@]}"; do
    CLIENT="${WG_CLIENTS[$i]}"
    CLIENT_IP="${WG_SUBNET}.$((i + 2))"
    CLIENT_PRIV="$(wg genkey)"
    CLIENT_PUB="$(echo "$CLIENT_PRIV" | wg pubkey)"

    # Add peer block to server config
    WG_SERVER_CONF+="
[Peer]
# ${CLIENT}
PublicKey = ${CLIENT_PUB}
AllowedIPs = ${CLIENT_IP}/32
"

    # Write client config
    cat > "${SCRIPT_DIR}/wg-${CLIENT}.conf" << EOF
[Interface]
PrivateKey = ${CLIENT_PRIV}
Address = ${CLIENT_IP}/32
DNS = ${WG_DNS}

[Peer]
# TAK Server
PublicKey = ${WG_SERVER_PUB}
Endpoint = ${WG_ENDPOINT}:${WG_PORT}
# Routes only VPN subnet through tunnel (split tunnel).
# Change to 0.0.0.0/0, ::/0 to route ALL traffic through the VPN.
AllowedIPs = ${WG_SUBNET}.0/24
PersistentKeepalive = 25
EOF

    # Generate QR code for mobile import
    qrencode -t png -o "${SCRIPT_DIR}/wg-${CLIENT}.png" \
        < "${SCRIPT_DIR}/wg-${CLIENT}.conf" 2>/dev/null && \
        success "  WireGuard config + QR: ${SCRIPT_DIR}/wg-${CLIENT}.conf"
done

# Write and lock down server config
echo "$WG_SERVER_CONF" > /etc/wireguard/wg0.conf
chmod 600 /etc/wireguard/wg0.conf

# Enable and start
systemctl enable --now wg-quick@wg0
sleep 2
systemctl is-active --quiet wg-quick@wg0 && \
    success "WireGuard running on port ${WG_PORT}/UDP." || \
    warn "WireGuard may not have started — check: journalctl -u wg-quick@wg0"

# ─── 14. Firewall ─────────────────────────────────────────────────────────────
info "Configuring firewall..."
ufw allow ssh 2>/dev/null || true
ufw allow "${WG_PORT}/udp"        comment "WireGuard VPN"
ufw allow "${NODERED_PORT}/tcp"   comment "Node-RED"
ufw allow "${MUMBLE_PORT}/tcp"    comment "Mumble voice"
ufw allow "${MUMBLE_PORT}/udp"    comment "Mumble voice/UDP"
ufw allow "${TAK_COT_PORT}/tcp"   comment "TAK CoT"
ufw allow "${TAK_ADMIN_PORT}/tcp" comment "TAK web admin"
ufw allow "${TAK_ENROLL_PORT}/tcp" comment "TAK cert enrollment"
if [[ -z "${SKIP_MEDIAMTX:-}" ]]; then
    ufw allow "${RTSP_PORT}/tcp"  comment "MediaMTX RTSP"
    ufw allow "${RTSP_PORT}/udp"  comment "MediaMTX RTSP/UDP"
    ufw allow "${HLS_PORT}/tcp"   comment "MediaMTX HLS"
    ufw allow "${WEBRTC_PORT}/tcp" comment "MediaMTX WebRTC"
fi
ufw --force enable
success "Firewall rules applied."

# ─── 15. Start TAK Server ────────────────────────────────────────────────────
info "Starting TAK Server..."
systemctl enable takserver
systemctl restart takserver
info "Waiting 45 seconds for TAK to fully initialise..."
sleep 45

# ─── 16. Register admin certificate ──────────────────────────────────────────
ADMIN_PEM="${CERT_DIR}/${ADMIN_USER}.pem"
if [[ -f "$ADMIN_PEM" ]]; then
    info "Registering admin certificate..."
    java -jar "${TAK_DIR}/utils/UserManager.jar" certmod -A "$ADMIN_PEM" 2>/dev/null && \
        success "Admin cert registered." || \
        warn "Admin cert registration failed — TAK may not be fully up yet. Run manually:"
    warn "  sudo java -jar ${TAK_DIR}/utils/UserManager.jar certmod -A ${ADMIN_PEM}"
fi

# ─── 17. Summary ──────────────────────────────────────────────────────────────
HOST_IP="$(hostname -I | awk '{print $1}')"
PUBLIC_IP="$(curl -fsSL --max-time 5 https://api.ipify.org 2>/dev/null || echo "$HOST_IP")"
DISPLAY_HOST="${DOMAIN:-$PUBLIC_IP}"

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
echo "    WireGuard  : $(systemctl is-active wg-quick@wg0 2>/dev/null || echo 'unknown')"
[[ -z "${SKIP_MEDIAMTX:-}" ]] && \
echo "    MediaMTX   : $(systemctl is-active mediamtx 2>/dev/null || echo 'unknown')"
echo ""
echo -e "  ${CYAN}Endpoints${NC}"
echo "    Web Admin  : https://${DISPLAY_HOST}:${TAK_ADMIN_PORT}"
echo "    CoT/ATAK   : ssl://${DISPLAY_HOST}:${TAK_COT_PORT}"
echo "    Enrollment : https://${DISPLAY_HOST}:${TAK_ENROLL_PORT}"
[[ -z "${SKIP_MEDIAMTX:-}" ]] && \
echo "    RTSP Video : rtsp://${DISPLAY_HOST}:${RTSP_PORT}/<stream-name>"
echo "    Mumble     : ${DISPLAY_HOST}:${MUMBLE_PORT}"
echo "    Node-RED   : http://${DISPLAY_HOST}:${NODERED_PORT}"
echo "    WireGuard  : ${WG_ENDPOINT}:${WG_PORT}/UDP  (server IP: ${WG_SUBNET}.1)"
[[ $USE_LE -eq 1 ]] && \
echo "" && \
echo -e "  ${CYAN}Let's Encrypt${NC}" && \
echo "    Domain     : ${DOMAIN}" && \
echo "    Renewal    : automatic (certbot systemd timer)" && \
echo "    ATAK note  : No trust store import needed — LE cert is trusted automatically"
echo ""
echo -e "  ${CYAN}Certificates${NC}  (${CERT_DIR})"
echo "    Root CA    : ${SCRIPT_DIR}/root-ca.pem          <-- import into Firefox (Authorities)"
echo "    Server     : ${CERT_DIR}/${SERVER_NAME}.p12  (pass: ${CERT_PASS})"
echo "    Admin      : ${CERT_DIR}/${ADMIN_USER}.p12   (pass: ${CERT_PASS})"
echo "               : ${SCRIPT_DIR}/${ADMIN_USER}.p12  <-- import into Firefox (Your Certificates)"
echo ""
echo "    Clients:"
for name in "${CLIENT_NAMES[@]}"; do
    echo "      ${CERT_DIR}/${name}.p12  (pass: ${CERT_PASS})"
done
echo ""
echo -e "  ${CYAN}Next steps${NC}"
echo "    1. Import ${SCRIPT_DIR}/${ADMIN_USER}.p12 into Firefox/Chrome"
echo "       (password: ${CERT_PASS})"
echo "    2. Open: https://${HOST_IP}:${TAK_ADMIN_PORT}"
echo "    3. On each ATAK/WinTAK device:"
echo "       a. Trust Store : ${SCRIPT_DIR}/truststore-root.p12  (pass: ${CERT_PASS})"
echo "       b. Client Cert : ${SCRIPT_DIR}/client1.p12 .. client5.p12  (pass: ${CERT_PASS})"
echo "       c. Server      : ssl://${HOST_IP}:${TAK_COT_PORT}"
echo ""
echo -e "  ${CYAN}Mumble${NC}"
echo "    Port       : ${MUMBLE_PORT} (TCP+UDP)"
echo "    Superuser  : SuperUser / ${MUMBLE_SUPERUSER_PASS}"
[[ -n "$MUMBLE_PASS" ]] && \
echo "    Server pw  : ${MUMBLE_PASS}" || \
echo "    Server pw  : (none)"
echo ""
echo -e "  ${CYAN}WireGuard${NC}"
echo "    Server pub : ${WG_SERVER_PUB}"
echo "    Subnet     : ${WG_SUBNET}.0/24"
echo "    Configs    : (in ${SCRIPT_DIR})"
for client in "tak-admin" "${CLIENT_NAMES[@]}" "wintak"; do
    echo "      wg-${client}.conf  +  wg-${client}.png (QR)"
done
echo ""
echo -e "  ${CYAN}Node-RED${NC}"
echo "    URL        : http://${DISPLAY_HOST}:${NODERED_PORT}"
echo "    Username   : ${NODERED_USER}"
echo "    Password   : ${NODERED_PASS}"
echo ""
echo -e "  ${YELLOW}Logs:${NC} sudo tail -f /opt/tak/logs/takserver-messaging.log"
echo ""
echo "============================================================"
