#!/bin/bash
# reset_vps.sh — Wipe all RagTAK-installed components from a VPS
# Leaves: Ubuntu base system, SSH, ubuntu user, sudo, apt
# Run as root or with sudo: sudo bash reset_vps.sh
set -uo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; NC='\033[0m'
info()    { echo -e "${YELLOW}[RESET]${NC} $*"; }
success() { echo -e "${GREEN}[DONE]${NC}  $*"; }

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Run as root: sudo bash reset_vps.sh${NC}" >&2
    exit 1
fi

echo -e "${RED}"
echo "======================================================"
echo "  This will WIPE all RagTAK components from this VPS."
echo "  TAK Server, PostgreSQL, certs, Node-RED, Mumble,"
echo "  MediaMTX, OpenVPN, and the RagTAK admin panel."
echo "======================================================"
echo -en "${NC}"
read -rp "Type YES to continue: " confirm
[[ "$confirm" == "YES" ]] || { echo "Aborted."; exit 0; }

# ─── 1. Stop and disable all services ────────────────────────────────────────
info "Stopping services..."
for svc in takserver takadmin node-red mediamtx mumble-server wg-quick@wg0 openvpn@server; do
    systemctl stop    "$svc" 2>/dev/null || true
    systemctl disable "$svc" 2>/dev/null || true
done
success "Services stopped."

# ─── 2. TAK Server ───────────────────────────────────────────────────────────
info "Removing TAK Server..."
# Kill all tak-user processes — dpkg post-removal calls userdel which fails if
# the tak Java processes are still alive after systemctl stop
if id tak &>/dev/null; then
    pkill -u tak 2>/dev/null || true
    sleep 3
    pkill -9 -u tak 2>/dev/null || true
    sleep 1
fi
# Force dpkg out of its broken state before attempting purge
dpkg --remove --force-remove-reinstreq takserver 2>/dev/null || true
if dpkg -l | grep -q takserver 2>/dev/null; then
    apt-get purge -y takserver 2>/dev/null || true
fi
rm -rf /opt/tak
userdel -r tak 2>/dev/null || true
success "TAK Server removed."

# ─── 3. PostgreSQL 15 ────────────────────────────────────────────────────────
info "Removing PostgreSQL 15..."
systemctl stop "postgresql@15-main" 2>/dev/null || true
apt-get purge -y "postgresql-15" "postgresql-15-postgis-3" \
    "postgresql-client-15" "postgresql-common" 2>/dev/null || true
rm -rf /etc/postgresql /var/lib/postgresql /var/log/postgresql
# Remove the postgres apt source we added
rm -f /etc/apt/sources.list.d/pgdg.list
apt-get autoremove -y 2>/dev/null || true
success "PostgreSQL removed."

# ─── 4. Let's Encrypt / certbot ──────────────────────────────────────────────
info "Removing Let's Encrypt..."
rm -f /etc/letsencrypt/renewal-hooks/deploy/takserver.sh
if command -v certbot &>/dev/null; then
    certbot delete --non-interactive --cert-name "$(hostname -f)" 2>/dev/null || true
    apt-get purge -y certbot python3-certbot-apache python3-certbot-nginx 2>/dev/null || true
fi
rm -rf /etc/letsencrypt /var/log/letsencrypt
success "Let's Encrypt removed."

# ─── 5. MediaMTX ─────────────────────────────────────────────────────────────
info "Removing MediaMTX..."
rm -f /etc/systemd/system/mediamtx.service
rm -f /usr/local/bin/mediamtx
rm -rf /etc/mediamtx
success "MediaMTX removed."

# ─── 6. Mumble ───────────────────────────────────────────────────────────────
info "Removing Mumble..."
apt-get purge -y mumble-server 2>/dev/null || true
rm -rf /etc/mumble-server.ini /var/lib/mumble-server /etc/mumble
success "Mumble removed."

# ─── 7. Node-RED ─────────────────────────────────────────────────────────────
info "Removing Node-RED..."
rm -f /etc/systemd/system/node-red.service
rm -rf /opt/nodered /home/nodered
userdel -r nodered 2>/dev/null || true
# Remove nodejs apt source
rm -f /etc/apt/sources.list.d/nodesource.list /etc/apt/keyrings/nodesource.gpg
apt-get purge -y nodejs 2>/dev/null || true
success "Node-RED removed."


# ─── 7b. dnsmasq ─────────────────────────────────────────────────────────────
info "Removing dnsmasq..."
systemctl stop dnsmasq 2>/dev/null || true
systemctl disable dnsmasq 2>/dev/null || true
apt-get purge -y dnsmasq dnsmasq-base 2>/dev/null || true
rm -f /etc/dnsmasq.d/ragtak.conf
success "dnsmasq removed."

# ─── 8. WireGuard (legacy — removed from installer, kept for old installs) ───
info "Removing WireGuard (if present)..."
ip link delete wg0 2>/dev/null || true
rm -rf /etc/wireguard
apt-get purge -y wireguard wireguard-tools qrencode 2>/dev/null || true
success "WireGuard removed."

# ─── 8b. OpenVPN ─────────────────────────────────────────────────────────────
info "Removing OpenVPN..."
systemctl stop "openvpn@server" 2>/dev/null || true
systemctl disable "openvpn@server" 2>/dev/null || true
apt-get purge -y openvpn easy-rsa 2>/dev/null || true
rm -rf /etc/openvpn /var/log/openvpn
success "OpenVPN removed."

# ─── 9. RagTAK Admin Panel ───────────────────────────────────────────────────
info "Removing RagTAK admin panel..."
rm -f /etc/systemd/system/takadmin.service
rm -rf /opt/takadmin
success "Admin panel removed."

# ─── 10. Systemd reload ──────────────────────────────────────────────────────
systemctl daemon-reload
systemctl reset-failed 2>/dev/null || true

# ─── 11. UFW — reset to defaults ─────────────────────────────────────────────
info "Resetting UFW..."
ufw --force reset
# Re-allow SSH so we don't lock ourselves out
SSH_PORT="$(grep -E '^Port ' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | head -1 || true)"
SSH_PORT="${SSH_PORT:-22}"
ufw allow "${SSH_PORT}/tcp" comment "SSH"
ufw --force enable
success "UFW reset (SSH port ${SSH_PORT} re-allowed)."

# ─── 12. Clean up generated certs dir in script location ─────────────────────
info "Removing generated certs directories..."
# Common locations where install_tak.sh might have been run from
for dir in /home/ubuntu /home/ubuntu/TAK/RagTAK /root /tmp; do
    if [[ -d "${dir}/certs" ]]; then
        read -rp "  Remove ${dir}/certs? [y/N] " yn
        [[ "$yn" =~ ^[Yy]$ ]] && rm -rf "${dir}/certs" && success "  Removed ${dir}/certs."
    fi
done

# ─── 13. Final apt cleanup ───────────────────────────────────────────────────
info "Running apt autoremove..."
apt-get autoremove -y 2>/dev/null || true
apt-get autoclean 2>/dev/null || true

echo ""
echo -e "${GREEN}======================================================"
echo "  Reset complete. VPS is ready for a clean install."
echo -e "======================================================${NC}"
echo ""
echo "Next: copy install_tak.sh and your takserver .deb to the VPS, then:"
echo "  sudo DOMAIN=<your-domain> bash install_tak.sh"
