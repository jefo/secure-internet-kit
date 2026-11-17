#!/bin/bash
# Secure Internet Kit — client generator
# Creates a TrustTunnel user, reloads the endpoint, and prints a deep link + TOML config.
#
# Usage:
#   sudo VPN_DOMAIN=vpn.example.com VPN_IP_PREMIUM=203.0.113.10 \
#     ./scripts/generate_client.sh <client_name> <lite|pro|pc>
#
# Tier:
#   lite — limited bandwidth (uses VPN_LITE_DOMAIN / VPN_IP_LITE)
#   pro  — full speed (uses VPN_DOMAIN / VPN_IP_PREMIUM)
#   pc   — export a TOML config for an existing user without creating a new one

set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-/opt/trusttunnel}"
VPN_DOMAIN="${VPN_DOMAIN:-vpn.example.com}"
VPN_LITE_DOMAIN="${VPN_LITE_DOMAIN:-lite.vpn.example.com}"
VPN_IP_PREMIUM="${VPN_IP_PREMIUM:-198.51.100.10}"
VPN_IP_LITE="${VPN_IP_LITE:-198.51.100.11}"

VPN_CONFIG="vpn.toml"
HOSTS_CONFIG="hosts.toml"
CREDS_FILE="credentials.toml"

if [ -z "${1:-}" ] || [ -z "${2:-}" ]; then
    echo "Usage: $0 <client_name> <lite|pro|pc>"
    echo ""
    echo "Environment:"
    echo "  VPN_DOMAIN       Premium hostname (default: vpn.example.com)"
    echo "  VPN_LITE_DOMAIN  Lite hostname (default: lite.vpn.example.com)"
    echo "  VPN_IP_PREMIUM   Premium IP, informational (default: 198.51.100.10)"
    echo "  VPN_IP_LITE      Lite IP, informational (default: 198.51.100.11)"
    echo "  INSTALL_DIR      TrustTunnel install dir (default: /opt/trusttunnel)"
    exit 1
fi

cd "$INSTALL_DIR"

CLIENT_NAME=$1
TIER=$2

case "$TIER" in
    lite)
        TARGET_HOST="$VPN_LITE_DOMAIN"
        TARGET_IP="$VPN_IP_LITE"
        TIER_NAME="LITE (limited bandwidth)"
        ;;
    pro)
        TARGET_HOST="$VPN_DOMAIN"
        TARGET_IP="$VPN_IP_PREMIUM"
        TIER_NAME="PREMIUM (full speed)"
        ;;
    pc)
        echo "━━━ TOML config for existing user: pc ━━━"
        "$INSTALL_DIR/trusttunnel_endpoint" "$INSTALL_DIR/$VPN_CONFIG" "$INSTALL_DIR/$HOSTS_CONFIG" \
            -c "pc" \
            -a "$TARGET_HOST:443" \
            --format toml
        exit 0
        ;;
    *)
        echo "Error: tier must be lite, pro, or pc" >&2
        exit 1
        ;;
esac

# Prevent duplicate usernames. Commenting out a block is the supported way to
# suspend a client; creating a second block with the same name is not.
if grep -qE "^[[:space:]]*username[[:space:]]*=[[:space:]]*\"${CLIENT_NAME}\"" "$CREDS_FILE" 2>/dev/null; then
    echo "Error: user '$CLIENT_NAME' already exists in $CREDS_FILE" >&2
    echo "Suspend/reactivate the existing block instead of creating a duplicate." >&2
    exit 1
fi

PASSWORD=$(openssl rand -base64 12)

cat >> "$CREDS_FILE" <<EOF

[[client]]
username = "$CLIENT_NAME"
password = "$PASSWORD"
EOF

PID=$(pidof trusttunnel_endpoint || true)
if [ -n "$PID" ]; then
    kill -HUP "$PID"
    echo "✅ credentials reloaded without dropping active sessions (SIGHUP)"
else
    systemctl start trusttunnel
    echo "✅ service started"
fi

echo ""
echo "━━━ Client created ━━━"
echo "  Name:     $CLIENT_NAME"
echo "  Tier:     $TIER_NAME"
echo "  Password: $PASSWORD"
echo "  Address:  $TARGET_HOST:443 ($TARGET_IP)"
echo ""

echo "━━━ Android — open the link or scan the QR ━━━"
DEEPLINK=$("$INSTALL_DIR/trusttunnel_endpoint" "$INSTALL_DIR/$VPN_CONFIG" "$INSTALL_DIR/$HOSTS_CONFIG" \
    -c "$CLIENT_NAME" \
    -a "$TARGET_HOST:443" \
    --generate-client-random-prefix \
    --format deeplink 2>/dev/null)
echo "$DEEPLINK"
echo ""
echo "QR: https://trusttunnel.org/qr.html#tt=$(echo "$DEEPLINK" | cut -d'?' -f2-)"
echo ""

echo "━━━ Windows / Linux — TOML config ━━━"
"$INSTALL_DIR/trusttunnel_endpoint" "$INSTALL_DIR/$VPN_CONFIG" "$INSTALL_DIR/$HOSTS_CONFIG" \
    -c "$CLIENT_NAME" \
    -a "$TARGET_HOST:443" \
    --format toml
echo ""
echo "━━━ Done. Record the client in your own CRM/spreadsheet. ━━━"
