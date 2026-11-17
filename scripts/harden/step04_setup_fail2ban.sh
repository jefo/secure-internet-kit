#!/bin/bash
# step04_setup_fail2ban.sh — Install and configure Fail2ban for SSH
SCRIPT_DESC="Installs Fail2ban with UFW ban action, configured to ban IPs after 3 failed SSH attempts for 24 hours."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# ─── Configuration ─────────────────────────────────────────────────
SSH_PORT="${SSH_PORT:-22}"
JAIL_LOCAL="/etc/fail2ban/jail.local"

# ─── Check ─────────────────────────────────────────────────────────
check() {
    local all_ok=true

    echo -e "${BOLD}Checking step 04: Fail2ban${NC}\n"

    # Installed
    if pkg_installed fail2ban; then
        print_check_ok "Fail2ban is installed"
    else
        print_check_fail "Fail2ban is NOT installed"
        all_ok=false
    fi

    # Service active
    if service_active fail2ban; then
        print_check_ok "Fail2ban service is running"
    else
        print_check_fail "Fail2ban service is NOT running"
        all_ok=false
    fi

    # jail.local exists
    if [[ -f "$JAIL_LOCAL" ]]; then
        print_check_ok "jail.local exists"
    else
        print_check_fail "jail.local does NOT exist at $JAIL_LOCAL"
        all_ok=false
    fi

    # SSH jail enabled
    if grep -q '^\[sshd\]' "$JAIL_LOCAL" 2>/dev/null && \
       grep -A5 '^\[sshd\]' "$JAIL_LOCAL" 2>/dev/null | grep -q 'enabled = true'; then
        print_check_ok "SSH jail is enabled"
    else
        print_check_fail "SSH jail is NOT enabled"
        all_ok=false
    fi

    # SSH jail uses correct port
    if file_contains "$JAIL_LOCAL" "port = $SSH_PORT"; then
        print_check_ok "SSH jail monitors port $SSH_PORT"
    else
        print_check_fail "SSH jail does NOT monitor port $SSH_PORT"
        all_ok=false
    fi

    # UFW ban action
    if file_contains "$JAIL_LOCAL" "banaction = ufw"; then
        print_check_ok "Ban action set to UFW"
    else
        print_check_fail "Ban action is NOT set to UFW"
        all_ok=false
    fi

    $all_ok
}

# ─── Run ───────────────────────────────────────────────────────────
run() {
    step "Setting up Fail2ban"

    # Install
    if ! pkg_installed fail2ban; then
        info "Installing Fail2ban..."
        apt install -y fail2ban
        ok "Fail2ban installed"
    else
        info "Fail2ban already installed"
    fi

    # Create jail.local
    info "Writing jail.local configuration..."
    cat > "$JAIL_LOCAL" <<EOF
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 3
banaction = ufw

[sshd]
enabled = true
port = $SSH_PORT
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 24h
EOF
    ok "jail.local written"

    # Enable and start
    info "Enabling and starting Fail2ban..."
    systemctl enable --now fail2ban
    ok "Fail2ban started"

    # Wait a moment for it to initialize
    sleep 2

    # Status
    echo ""
    info "Fail2ban status:"
    fail2ban-client status 2>/dev/null || warn "Could not get status (may still be starting)"

    echo ""
    info "SSH jail status:"
    fail2ban-client status sshd 2>/dev/null || warn "Could not get SSH jail status"

    echo ""
    ok "Fail2ban configured and running."
    info "Run step05 (automatic updates) next."
}

dispatch check run "$1"
