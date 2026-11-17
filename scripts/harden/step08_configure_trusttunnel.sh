#!/bin/bash
# step08_configure_trusttunnel.sh — Generate all config files for TrustTunnel endpoint
# Fully non-interactive. Works with or without TLS certificate.
SCRIPT_DESC="Creates vpn.toml, hosts.toml (self-signed cert), credentials.toml, rules.toml."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# ─── Configuration ─────────────────────────────────────────────────
INSTALL_DIR="${INSTALL_DIR:-/opt/trusttunnel}"
LISTEN_PORT="${LISTEN_PORT:-443}"
TT_USERNAME="${TT_USERNAME:-pc}"
TT_PASSWORD="${TT_PASSWORD:-}"

# ─── Check ─────────────────────────────────────────────────────────
check() {
    local all_ok=true

    echo -e "${BOLD}Checking step 08: TrustTunnel configuration${NC}\n"

    for cfg in vpn.toml hosts.toml credentials.toml rules.toml; do
        if [[ -f "$INSTALL_DIR/$cfg" ]]; then
            print_check_ok "$cfg exists"
        else
            print_check_fail "$cfg does NOT exist"
            all_ok=false
        fi
    done

    if grep -q 'username' "$INSTALL_DIR/credentials.toml" 2>/dev/null; then
        print_check_ok "credentials.toml has at least one user"
    else
        print_check_fail "credentials.toml has NO users configured"
        all_ok=false
    fi

    if grep -qE '^\[\[main_hosts\]\]' "$INSTALL_DIR/hosts.toml" 2>/dev/null; then
        print_check_ok "hosts.toml has [[main_hosts]] configured"
    else
        print_check_fail "hosts.toml has NO [[main_hosts]] (endpoint won't start)"
        all_ok=false
    fi

    $all_ok
}

# ─── Run ───────────────────────────────────────────────────────────
run() {
    step "Configuring TrustTunnel endpoint"
    cd "$INSTALL_DIR"

    # ── vpn.toml ──
    info "Creating vpn.toml..."
    cat > vpn.toml <<EOF
listen_address = "0.0.0.0:$LISTEN_PORT"
ipv6_available = false
allow_private_network_connections = false
tls_handshake_timeout_secs = 10
client_listener_timeout_secs = 600
connection_establishment_timeout_secs = 30
tcp_connections_timeout_secs = 604800
udp_connections_timeout_secs = 300
credentials_file = "credentials.toml"
rules_file = "rules.toml"

[listen_protocols.http2]
initial_connection_window_size = 8388608
initial_stream_window_size = 131072
max_concurrent_streams = 1000
max_frame_size = 16384
header_table_size = 65536

[listen_protocols.quic]
recv_udp_payload_size = 1350
send_udp_payload_size = 1350
initial_max_data = 104857600
initial_max_stream_data_bidi_local = 1048576
initial_max_stream_data_bidi_remote = 1048576
initial_max_stream_data_uni = 1048576
initial_max_streams_bidi = 4096
initial_max_streams_uni = 4096
max_connection_window = 25165824
max_stream_window = 16777216
disable_active_migration = true
enable_early_data = true
message_queue_capacity = 4096
EOF
    ok "vpn.toml created"

    # ── Self-signed certificate (works without domain) ──
    info "Generating self-signed TLS certificate..."
    mkdir -p certs
    openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
        -keyout certs/key.pem \
        -out certs/cert.pem \
        -days 3650 -nodes -subj "/CN=localhost" 2>/dev/null \
        || openssl req -x509 -newkey rsa:2048 \
            -keyout certs/key.pem -out certs/cert.pem \
            -days 3650 -nodes -subj "/CN=localhost" 2>/dev/null

    # ── hosts.toml (points to self-signed cert) ──
    info "Creating hosts.toml with self-signed cert..."
    cat > hosts.toml <<EOF
[[main_hosts]]
hostname = "localhost"
cert_chain_path = "$INSTALL_DIR/certs/cert.pem"
private_key_path = "$INSTALL_DIR/certs/key.pem"
EOF
    chmod 644 hosts.toml
    chmod 600 certs/key.pem
    ok "hosts.toml configured with self-signed certificate"

    # ── credentials.toml ──
    info "Creating credentials.toml..."
    local pw
    pw="${TT_PASSWORD:-$(head -c 12 /dev/urandom | base64 | tr -d '\n')}"
    cat > credentials.toml <<EOF
[[client]]
username = "$TT_USERNAME"
password = "$pw"
EOF
    chmod 600 credentials.toml
    ok "credentials.toml created (user: $TT_USERNAME)"

    # ── rules.toml ──
    info "Creating rules.toml (allow all)..."
    cat > rules.toml <<'EOF'
# Connection filtering rules (allow all by default)
EOF
    chmod 600 rules.toml
    ok "rules.toml created"

    echo ""
    ok "All TrustTunnel configuration files created."
    info "Username: $TT_USERNAME"
    info "Password: $pw"
    info "Next: run step10 (systemd service + lockdown)"
}

dispatch check run "$1"
