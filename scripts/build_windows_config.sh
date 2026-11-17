#!/bin/bash
# build_windows_config.sh — собирает полный config.toml для Windows-клиента
# Использование:
#   ./build_windows_config.sh <имя_пользователя> [пароль]
#   ./build_windows_config.sh pc <password>
#   ./build_windows_config.sh ivanov              (пароль сгенерируется)
#
# Вывод в stdout и в файл build/<имя_пользователя>_config.toml

set -euo pipefail

DOMAIN="${VPN_DOMAIN:-vpn.example.com}"
IP="${VPN_IP:-198.51.100.10}"
PORT="${VPN_PORT:-443}"

CLIENT_NAME="${1:-}"
CLIENT_PASS="${2:-}"

if [ -z "$CLIENT_NAME" ]; then
    echo "Использование: $0 <имя_пользователя> [пароль]"
    echo "  $0 ivanov               — сгенерирует пароль"
    echo "  $0 pc <password>      — с готовым паролем"
    exit 1
fi

# Генерируем пароль если не передан
if [ -z "$CLIENT_PASS" ]; then
    CLIENT_PASS=$(openssl rand -base64 12 2>/dev/null || cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 16)
fi

# Временный файл
TMPFILE=$(mktemp)

cat > "$TMPFILE" << ENDOFTEMPLATE
# Secure Internet Kit — Windows Client Config
# Сервер: ${DOMAIN}:${PORT}
# Пользователь: ${CLIENT_NAME}

loglevel = "info"
vpn_mode = "general"
killswitch_enabled = true
killswitch_allow_ports = []
post_quantum_group_enabled = true

exclusions = [
    "sberbank.ru", "*.sberbank.ru",
    "gosuslugi.ru", "*.gosuslugi.ru",
    "tinkoff.ru", "*.tinkoff.ru",
    "alfabank.ru", "*.alfabank.ru",
    "vtb.ru", "*.vtb.ru",
    "avito.ru", "*.avito.ru",
    "yandex.ru", "*.yandex.ru",
    "mail.ru", "*.mail.ru",
    "ok.ru", "*.ok.ru",
    "vk.com", "*.vk.com",
    "wildberries.ru", "*.wildberries.ru",
    "ozon.ru", "*.ozon.ru",
    "nalog.ru", "*.nalog.ru",
    "pfr.gov.ru", "*.pfr.gov.ru",
    "roskazna.ru", "*.roskazna.ru"
]

dns_upstreams = [
    "https://dns.adguard-dns.com/dns-query",
    "https://cloudflare-dns.com/dns-query",
    "https://dns.google/dns-query"
]

[endpoint]
hostname = "${DOMAIN}"
addresses = ["${IP}:${PORT}"]
has_ipv6 = false
username = "${CLIENT_NAME}"
password = "${CLIENT_PASS}"
client_random = ""
skip_verification = false
certificate = ""
upstream_protocol = "http2"
anti_dpi = false

[listener.tun]
included_routes = ["0.0.0.0/0"]
excluded_routes = ["0.0.0.0/8", "10.0.0.0/8", "169.254.0.0/16", "172.16.0.0/12", "192.168.0.0/16", "224.0.0.0/3"]
mtu_size = 1280
change_system_dns = true
ENDOFTEMPLATE

# Вывод в stdout
cat "$TMPFILE"

# Сохраняем в build/
OUTDIR="$(dirname "$0")/../client/builds"
mkdir -p "$OUTDIR"
cp "$TMPFILE" "$OUTDIR/${CLIENT_NAME}_config.toml"

echo ""
echo "# ─── Сохранено в: client/builds/${CLIENT_NAME}_config.toml"
echo "# ─── Логин: ${CLIENT_NAME}"
echo "# ─── Пароль: ${CLIENT_PASS}"

rm "$TMPFILE"
