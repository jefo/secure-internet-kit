#!/bin/bash
# bootstrap.sh — One-liner to download and run the hardening suite on a fresh VPS
# Usage: curl -fsSL <URL> | bash
# Or:    wget -qO- <URL> | bash

set -euo pipefail

REPO_URL="${REPO_URL:-https://raw.githubusercontent.com/jefo/secure-internet-kit/main}"
BRANCH="${BRANCH:-main}"
TARGET_DIR="/tmp/secure-internet-kit-harden"

echo "━━━ Secure Internet Kit VPS Bootstrap ━━━"
echo ""

# Cleanup previous
if [[ -d "$TARGET_DIR" ]]; then
    echo "[INFO] Cleaning up previous download..."
    rm -rf "$TARGET_DIR"
fi

mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"

echo "[INFO] Downloading hardening scripts..."

SCRIPTS=(
    "scripts/harden/lib.sh"
    "scripts/harden/run.sh"
    "scripts/harden/step01_create_user.sh"
    "scripts/harden/step02_harden_ssh.sh"
    "scripts/harden/step03_setup_firewall.sh"
    "scripts/harden/step04_setup_fail2ban.sh"
    "scripts/harden/step05_auto_updates.sh"
    "scripts/harden/step06_sysctl_hardening.sh"
    "scripts/harden/step07_install_trusttunnel.sh"
    "scripts/harden/step08_configure_trusttunnel.sh"
    "scripts/harden/step09_setup_tls.sh"
    "scripts/harden/step10_setup_service.sh"
)

FAILED=0
for script in "${SCRIPTS[@]}"; do
    local_path="$TARGET_DIR/$script"
    local_dir="$(dirname "$local_path")"
    mkdir -p "$local_dir"

    if curl -fsSL "${REPO_URL}/${script}" -o "$local_path" 2>/dev/null; then
        chmod +x "$local_path"
    else
        echo "[ERR]  Failed to download: $script"
        FAILED=1
    fi
done

if [[ $FAILED -ne 0 ]]; then
    echo ""
    echo "[ERR] Some scripts failed to download. Aborting."
    echo "      Check REPO_URL and network connectivity."
    exit 1
fi

echo "[OK]  All scripts downloaded."
echo ""
echo "━━━ Running hardening orchestrator ━━━"
echo ""
echo "Usage:"
echo "  sudo bash $TARGET_DIR/scripts/harden/run.sh status   # Check what's done"
echo "  sudo bash $TARGET_DIR/scripts/harden/run.sh check    # Full audit"
echo "  sudo bash $TARGET_DIR/scripts/harden/run.sh run      # Apply all pending"
echo ""
echo "Or set env vars and run directly:"
echo "  export SSH_PORT=2222"
echo "  export SSH_PUBKEY='ssh-ed25519 AAAA...'"
echo "  export TLS_DOMAIN=cdn.example.com"
echo "  export TLS_EMAIL=admin@example.com"
echo "  sudo bash $TARGET_DIR/scripts/harden/run.sh run"
echo ""

# If running non-interactively with env vars, auto-run
if [[ -n "${AUTO_RUN:-}" ]]; then
    echo "━━━ AUTO_RUN is set — executing all steps ━━━"
    sudo bash "$TARGET_DIR/scripts/harden/run.sh" run
else
    echo "Run one of the commands above. No AUTO_RUN detected."
fi
