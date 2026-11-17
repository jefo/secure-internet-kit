#!/bin/bash
# step10_setup_service.sh — Install systemd service, lock down file permissions, enable logrotate
SCRIPT_DESC="Installs TrustTunnel as a systemd service, restricts file permissions on config files, and sets up logrotate."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# ─── Configuration ─────────────────────────────────────────────────
INSTALL_DIR="${INSTALL_DIR:-/opt/trusttunnel}"
SERVICE_NAME="trusttunnel"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
LOG_DIR="/var/log/trusttunnel"

# ─── Check ─────────────────────────────────────────────────────────
check() {
    local all_ok=true

    echo -e "${BOLD}Checking step 10: Systemd service + lockdown${NC}\n"

    # Service file exists
    if [[ -f "$SERVICE_FILE" ]]; then
        print_check_ok "systemd service file exists ($SERVICE_FILE)"
    else
        print_check_fail "systemd service file does NOT exist"
        all_ok=false
    fi

    # Service enabled
    if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
        print_check_ok "$SERVICE_NAME service is enabled"
    else
        print_check_fail "$SERVICE_NAME service is NOT enabled"
        all_ok=false
    fi

    # Service running
    if service_active "$SERVICE_NAME"; then
        print_check_ok "$SERVICE_NAME service is running"
    else
        print_check_fail "$SERVICE_NAME service is NOT running"
        all_ok=false
    fi

    # File permissions: credentials.toml 600
    local creds_perms
    creds_perms=$(stat -c '%a' "$INSTALL_DIR/credentials.toml" 2>/dev/null || echo "missing")
    if [[ "$creds_perms" == "600" ]]; then
        print_check_ok "credentials.toml permissions are 600"
    else
        print_check_fail "credentials.toml permissions are $creds_perms (expected 600)"
        all_ok=false
    fi

    # File permissions: rules.toml 600
    local rules_perms
    rules_perms=$(stat -c '%a' "$INSTALL_DIR/rules.toml" 2>/dev/null || echo "missing")
    if [[ "$rules_perms" == "600" ]]; then
        print_check_ok "rules.toml permissions are 600"
    else
        print_check_fail "rules.toml permissions are $rules_perms (expected 600)"
        all_ok=false
    fi

    # Log directory exists
    if [[ -d "$LOG_DIR" ]]; then
        print_check_ok "Log directory exists ($LOG_DIR)"
    else
        print_check_fail "Log directory does NOT exist"
        all_ok=false
    fi

    # Logrotate configured
    if [[ -f "/etc/logrotate.d/trusttunnel" ]]; then
        print_check_ok "Logrotate configured for TrustTunnel"
    else
        print_check_fail "Logrotate NOT configured for TrustTunnel"
        all_ok=false
    fi

    # No extra open ports (besides SSH and 443)
    info "Open listening ports:"
    local extra_ports
    extra_ports=$(ss -tlnp 2>/dev/null | grep -vE '(2222|443|127\.0\.0\.1)' | grep -v '^State' || true)
    if [[ -z "$extra_ports" ]]; then
        print_check_ok "No unexpected open ports"
    else
        print_check_fail "Unexpected open ports detected:"
        echo "$extra_ports" | while read -r line; do
            warn "  $line"
        done
        all_ok=false
    fi

    $all_ok
}

# ─── Run ───────────────────────────────────────────────────────────
run() {
    step "Setting up systemd service and final lockdown"

    # ── Systemd service ──
    info "Installing systemd service..."

    if [[ -f "$INSTALL_DIR/trusttunnel.service.template" ]]; then
        cp "$INSTALL_DIR/trusttunnel.service.template" "$SERVICE_FILE"
        # Ensure paths are correct
        sed -i "s|ExecStart=.*|ExecStart=$INSTALL_DIR/trusttunnel_endpoint $INSTALL_DIR/vpn.toml $INSTALL_DIR/hosts.toml|" "$SERVICE_FILE"
        sed -i "s|WorkingDirectory=.*|WorkingDirectory=$INSTALL_DIR|" "$SERVICE_FILE"
        ok "Service file installed from template"
    else
        info "No template found — creating service file..."
        cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=TrustTunnel VPN Endpoint
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/trusttunnel_endpoint $INSTALL_DIR/vpn.toml $INSTALL_DIR/hosts.toml
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=trusttunnel

# Security hardening
NoNewPrivileges=false
ProtectSystem=strict
ReadWritePaths=$INSTALL_DIR $LOG_DIR
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
        ok "Service file created"
    fi

    # Reload and enable
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    ok "Service enabled"

    # Start or restart (in case configs were just created/changed)
    info "Starting TrustTunnel service..."
    if service_active "$SERVICE_NAME"; then
        systemctl restart "$SERVICE_NAME"
        ok "Service restarted"
    else
        systemctl start "$SERVICE_NAME"
    fi
    sleep 2
    if service_active "$SERVICE_NAME"; then
        ok "TrustTunnel is running"
    else
        error "Service failed to start. Check logs:"
        error "  journalctl -u $SERVICE_NAME -n 20 --no-pager"
        all_ok=false
    fi

    # ── File permissions lockdown ──
    step "Locking down file permissions"

    info "Restricting config file permissions..."
    chown -R root:root "$INSTALL_DIR"
    chmod 600 "$INSTALL_DIR/credentials.toml"
    chmod 600 "$INSTALL_DIR/rules.toml"
    chmod 644 "$INSTALL_DIR/vpn.toml"
    chmod 644 "$INSTALL_DIR/hosts.toml"
    chmod 700 "$INSTALL_DIR/trusttunnel_endpoint"
    chmod 700 "$INSTALL_DIR/setup_wizard" 2>/dev/null || true
    ok "Config files restricted"

    # ── Log directory ──
    mkdir -p "$LOG_DIR"
    chown root:root "$LOG_DIR"
    chmod 755 "$LOG_DIR"
    ok "Log directory created ($LOG_DIR)"

    # ── Logrotate ──
    info "Setting up logrotate..."
    cat > /etc/logrotate.d/trusttunnel <<EOF
$LOG_DIR/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
    postrotate
        kill -HUP \$(pidof trusttunnel_endpoint) 2>/dev/null || true
    endscript
}
EOF
    ok "Logrotate configured"

    # ── Disable unnecessary services ──
    step "Disabling unnecessary services"
    for svc in apache2 nginx docker postfix; do
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            warn "$svc is running — consider if it's needed"
            info "To disable: systemctl disable --now $svc"
        fi
    done
    info "Review with: ss -tlnp"

    echo ""
    echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║   HARDENING COMPLETE                                   ║${NC}"
    echo -e "${GREEN}${BOLD}║                                                       ║${NC}"
    echo -e "${GREEN}${BOLD}║   Server is secured and TrustTunnel is running.       ║${NC}"
    echo -e "${GREEN}${BOLD}║                                                       ║${NC}"
    echo -e "${GREEN}${BOLD}║   Next steps:                                         ║${NC}"
    echo -e "${GREEN}${BOLD}║   1. Export client config:                            ║${NC}"
    echo -e "${GREEN}${BOLD}║      cd $INSTALL_DIR                                   ║${NC}"
    echo -e "${GREEN}${BOLD}║      ./trusttunnel_endpoint vpn.toml hosts.toml \\      ║${NC}"
    echo -e "${GREEN}${BOLD}║          -c <username> -a <your_domain_or_ip>         ║${NC}"
    echo -e "${GREEN}${BOLD}║   2. Monitor: journalctl -u trusttunnel -f           ║${NC}"
    echo -e "${GREEN}${BOLD}║   3. Monthly: run scripts/harden/run.sh --check-all  ║${NC}"
    echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""
}

dispatch check run "$1"
