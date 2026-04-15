#!/usr/bin/env bash
# deploy_takadmin.sh — update takadmin.py on a live VPS without re-running the full installer
# Run as root from the RagTAK git checkout directory on the VPS:
#   sudo bash deploy_takadmin.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TAKADMIN_PY=/opt/takadmin/takadmin.py

echo "==> Pulling latest changes..."
git -C "$SCRIPT_DIR" pull

echo "==> Installing qrcode library..."
pip3 install "qrcode[pure]" --break-system-packages -q 2>/dev/null || \
    pip3 install qrcode --break-system-packages -q 2>/dev/null || \
    echo "    WARNING: qrcode install failed — QR buttons will show URL only (no image)"

echo "==> Extracting takadmin.py from install_tak.sh..."
awk "/^cat > \"\\\${TAKADMIN_DIR}\/takadmin\.py\" << 'PYEOF'/{found=1; next} found && /^PYEOF\$/{exit} found{print}" \
    "$SCRIPT_DIR/install_tak.sh" > /tmp/takadmin_new.py

if [[ ! -s /tmp/takadmin_new.py ]]; then
    echo "ERROR: extraction produced an empty file — aborting"
    exit 1
fi

echo "==> Backing up existing takadmin.py..."
cp "$TAKADMIN_PY" "${TAKADMIN_PY}.bak"

echo "==> Installing updated takadmin.py..."
cp /tmp/takadmin_new.py "$TAKADMIN_PY"

echo "==> Restarting takadmin service..."
systemctl restart takadmin

sleep 1
STATUS=$(systemctl is-active takadmin)
if [[ "$STATUS" == "active" ]]; then
    echo "==> Done. takadmin is running."
    echo "    Open the Downloads page and look for the QR buttons."
else
    echo "ERROR: takadmin failed to start (status: $STATUS)"
    echo "    Rolling back..."
    cp "${TAKADMIN_PY}.bak" "$TAKADMIN_PY"
    systemctl restart takadmin
    echo "    Rollback complete. Check: journalctl -u takadmin -n 50"
    exit 1
fi
