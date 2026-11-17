#!/bin/bash
# step09_setup_tls.sh — Obtain and configure Let's Encrypt TLS certificate
SCRIPT_DESC="Installs Certbot, obtains a Let's Encrypt certificate for your domain, and configures hosts.toml for TrustTunnel."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# ─── Configuration ─────────────────────────────────────────────────
INSTALL_DIR="${INSTALL_DIR:-/opt/trusttunnel}"
TLS_DOMAIN="${TLS_DOMAIN:-}"          # Required: your domain name
TLS_EMAIL="${TLS_EMAIL:-}"            # Required: email for Let's Encrypt
HTTP_CHALLENGE_PORT="${HTTP_CHALLENGE_PORT:-80}"
CERT_DIR="/etc/letsencrypt/live/${TLS_DOMAIN}"

# ─── Check ─────────────────────────────────────────────────────────
check() {
    local all_ok=true

    echo -e "${BOLD}Checking step 09: TLS certificate${NC}\n"

    # Certbot installed
    if pkg_installed certbot; then
        print_check_ok "Certbot is installed"
    else
        print_check_fail "Certbot is NOT installed"
        all_ok=false
    fi

    # Certificate exists
    if [[ -n "$TLS_DOMAIN" ]] && [[ -f "$CERT_DIR/fullchain.pem" ]]; then
        print_check_ok "Certificate exists for $TLS_DOMAIN"

        # Check expiry (30 days)
        if openssl x509 -checkend 2592000 -noout -in "$CERT_DIR/fullchain.pem" 2>/dev/null; then
            local expiry
            expiry=$(openssl x509 -enddate -noout -in "$CERT_DIR/fullchain.pem" 2>/dev/null | cut -d= -f2)
            print_check_ok "Certificate valid until $expiry"
        else
            warn "Certificate expires within 30 days — renewal needed"
            all_ok=false
        fi
    else
        print_check_fail "Certificate NOT found for $TLS_DOMAIN"
        all_ok=false
    fi

    # Certificate readable by root
    if [[ -f "$CERT_DIR/fullchain.pem" ]] && [[ -r "$CERT_DIR/fullchain.pem" ]]; then
        print_check_ok "Certificate is readable"
    else
        print_check_fail "Certificate file permissions issue"
        all_ok=false
    fi

    # hosts.toml configured with cert paths
    if file_contains "$INSTALL_DIR/hosts.toml" "cert_chain_path"; then
        # Check it's not commented out
        if grep -qE "^[^#].*cert_chain_path" "$INSTALL_DIR/hosts.toml" 2>/dev/null; then
            print_check_ok "hosts.toml has cert_chain_path configured"
        else
            print_check_fail "hosts.toml cert_chain_path is commented out"
            all_ok=false
        fi
    else
        print_check_fail "hosts.toml does NOT have cert_chain_path"
        all_ok=false
    fi

    # hosts.toml has matching hostname
    if [[ -n "$TLS_DOMAIN" ]] && grep -q "hostname = \"$TLS_DOMAIN\"" "$INSTALL_DIR/hosts.toml" 2>/dev/null; then
        print_check_ok "hosts.toml hostname matches $TLS_DOMAIN"
    else
        print_check_fail "hosts.toml hostname does NOT match $TLS_DOMAIN"
        all_ok=false
    fi

    $all_ok
}

# ─── Run ───────────────────────────────────────────────────────────
run() {
    step "Setting up TLS certificate (Let's Encrypt)"

    # Validate inputs
    if [[ -z "$TLS_DOMAIN" ]]; then
        fatal "TLS_DOMAIN env variable is required. Example: TLS_DOMAIN=cdn.example.com $0 --run"
    fi

    if [[ -z "$TLS_EMAIL" ]]; then
        fatal "TLS_EMAIL env variable is required. Example: TLS_EMAIL=admin@example.com $0 --run"
    fi

    # Check domain resolves
    info "Checking if $TLS_DOMAIN resolves..."
    if ! host "$TLS_DOMAIN" &>/dev/null && ! dig +short "$TLS_DOMAIN" &>/dev/null; then
        warn "Domain $TLS_DOMAIN does not appear to resolve via host/dig."
        warn "Make sure DNS is configured before running this step."
        if [[ -t 0 ]]; then
            read -rp "Continue anyway? [y/N]: " confirm
            [[ "$confirm" != "y" ]] && fatal "Aborted."
        else
            info "Non-interactive mode — continuing..."
        fi
    else
        ok "Domain resolves"
    fi

    # Check port 80 is accessible. HTTP-01 only needs port 80; the endpoint
    # stays on 443, so there is no need to stop it.
    info "Port $HTTP_CHALLENGE_PORT must be open for the HTTP-01 challenge..."
    PORT80_WAS_OPEN=false
    if ufw status 2>/dev/null | grep -q "${HTTP_CHALLENGE_PORT}/tcp"; then
        PORT80_WAS_OPEN=true
    else
        info "Opening port $HTTP_CHALLENGE_PORT temporarily..."
        ufw allow "$HTTP_CHALLENGE_PORT/tcp"
    fi

    cleanup_port80() {
        if ! $PORT80_WAS_OPEN; then
            ufw delete allow "$HTTP_CHALLENGE_PORT/tcp" >/dev/null 2>&1 || true
        fi
    }
    trap cleanup_port80 EXIT

    # Install certbot
    if ! pkg_installed certbot; then
        info "Installing Certbot..."
        apt install -y certbot
        ok "Certbot installed"
    else
        info "Certbot already installed"
    fi

    # Obtain certificate
    info "Requesting Let's Encrypt certificate via standalone (HTTP-01)..."
    certbot certonly \
        --standalone \
        --preferred-challenges http \
        --http-01-port "$HTTP_CHALLENGE_PORT" \
        --email "$TLS_EMAIL" \
        --agree-tos \
        --non-interactive \
        --domain "$TLS_DOMAIN" \
        --key-type ecdsa \
        --elliptic-curve secp256r1

    if [[ -f "$CERT_DIR/fullchain.pem" ]]; then
        ok "Certificate obtained successfully"
    else
        fatal "Certificate request failed. Check /var/log/letsencrypt/ for details."
    fi

    # Configure hosts.toml
    info "Configuring hosts.toml with certificate paths..."
    cat > "$INSTALL_DIR/hosts.toml" <<EOF
[[main_hosts]]
hostname = "$TLS_DOMAIN"
cert_chain_path = "$CERT_DIR/fullchain.pem"
private_key_path = "$CERT_DIR/privkey.pem"
EOF
    ok "hosts.toml configured"

    # If the endpoint is already running, reload the new certificate without
    # dropping active sessions. On a fresh install step 10 starts it later.
    if service_active trusttunnel; then
        local pid
        pid=$(pidof trusttunnel_endpoint || true)
        if [ -n "$pid" ]; then
            kill -HUP "$pid"
            ok "TrustTunnel reloaded with the new certificate"
        fi
    fi

    # Setup auto-renewal hook
    setup_renewal_hook

    echo ""
    ok "TLS certificate setup complete for $TLS_DOMAIN"
    info "Run step10 (systemd service + final lockdown) next."
}

# ─── Renewal hook ──────────────────────────────────────────────────
setup_renewal_hook() {
    local hook_dir="/etc/letsencrypt/renewal-hooks/post"
    mkdir -p "$hook_dir"

    info "Setting up automatic SIGHUP on cert renewal..."
    cat > "$hook_dir/trusttunnel_reload.sh" <<'EOF'
#!/bin/bash
PID=$(pidof trusttunnel_endpoint)
if [ -n "$PID" ]; then
    kill -HUP $PID
    logger "TrustTunnel (PID $PID) reloaded certificates via SIGHUP"
else
    logger "TrustTunnel not running — will pick up new certs on next start"
fi
EOF
    chmod +x "$hook_dir/trusttunnel_reload.sh"
    ok "Renewal hook installed"
}

dispatch check run "$1"
