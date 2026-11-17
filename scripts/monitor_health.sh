#!/bin/bash
# Secure Internet Kit — simple health monitor
#
# Checks the TrustTunnel service and disk usage, and optionally sends a
# Telegram alert. Run from cron every 5 minutes:
#   */5 * * * * TELEGRAM_BOT_TOKEN=... TELEGRAM_CHAT_ID=... /opt/trusttunnel/scripts/monitor_health.sh

set -euo pipefail

TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT_ID="${TELEGRAM_CHAT_ID:-}"
HOSTNAME=$(hostname)

send_alert() {
    local message="$1"
    logger -t secure-internet-kit "$message"
    if [ -n "$TOKEN" ] && [ -n "$CHAT_ID" ]; then
        curl -fsS -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
            -d "chat_id=${CHAT_ID}" \
            -d "text=🚨 ${HOSTNAME}: ${message}" >/dev/null || true
    fi
}

# 1. TrustTunnel service
if ! systemctl is-active --quiet trusttunnel; then
    send_alert "TrustTunnel is DOWN. Restarting..."
    systemctl restart trusttunnel || true
    sleep 2
    if ! systemctl is-active --quiet trusttunnel; then
        send_alert "CRITICAL: TrustTunnel restart failed."
    else
        send_alert "TrustTunnel restarted successfully."
    fi
fi

# 2. Disk usage (threshold 90%)
DISK_USAGE=$(df / | awk 'NR==2 {gsub("%","",$5); print $5}')
if [ "${DISK_USAGE:-0}" -gt 90 ]; then
    send_alert "Low disk space: ${DISK_USAGE}% used."
fi

# 3. Certificate expiry (optional; requires openssl and a known domain)
# CERT="/etc/letsencrypt/live/${VPN_DOMAIN:-vpn.example.com}/fullchain.pem"
# if [ -f "$CERT" ] && ! openssl x509 -checkend 604800 -noout -in "$CERT" 2>/dev/null; then
#     send_alert "TLS certificate expires within 7 days."
# fi
