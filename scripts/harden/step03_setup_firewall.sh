#!/bin/bash
# step03_setup_firewall.sh — Install and configure UFW
SCRIPT_DESC="Installs UFW, sets default-deny incoming, allows SSH (custom port), 443/tcp and 443/udp for TrustTunnel."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# ─── Configuration ─────────────────────────────────────────────────
SSH_PORT="${SSH_PORT:-22}"

# ─── Check ─────────────────────────────────────────────────────────
check() {
    local all_ok=true

    echo -e "${BOLD}Checking step 03: Firewall (UFW)${NC}\n"

    # UFW installed
    if pkg_installed ufw; then
        print_check_ok "UFW is installed"
    else
        print_check_fail "UFW is NOT installed"
        all_ok=false
    fi

    # UFW active
    if ufw status 2>/dev/null | grep -q "Status: active"; then
        print_check_ok "UFW is active"
    else
        print_check_fail "UFW is NOT active"
        all_ok=false
    fi

    # Default deny incoming
    if ufw status verbose 2>/dev/null | grep -q "Default: deny (incoming)"; then
        print_check_ok "Default policy: deny incoming"
    else
        print_check_fail "Default policy is NOT deny incoming"
        all_ok=false
    fi

    # SSH port allowed
    if port_open_ufw "${SSH_PORT}/tcp"; then
        print_check_ok "SSH port $SSH_PORT/tcp allowed"
    else
        print_check_fail "SSH port $SSH_PORT/tcp NOT allowed"
        all_ok=false
    fi

    # 443/tcp allowed
    if port_open_ufw "443/tcp"; then
        print_check_ok "443/tcp allowed"
    else
        print_check_fail "443/tcp NOT allowed"
        all_ok=false
    fi

    # 443/udp allowed
    if port_open_ufw "443/udp"; then
        print_check_ok "443/udp allowed"
    else
        print_check_fail "443/udp NOT allowed"
        all_ok=false
    fi

    $all_ok
}

# ─── Run ───────────────────────────────────────────────────────────
run() {
    step "Setting up firewall (UFW)"

    # Install
    if ! pkg_installed ufw; then
        info "Installing UFW..."
        apt update && apt install -y ufw
        ok "UFW installed"
    else
        info "UFW already installed"
    fi

    # Reset to clean state (safe if already inactive)
    info "Resetting UFW to clean state..."
    ufw --force reset >/dev/null 2>&1 || true

    # Default policies
    info "Setting default policies..."
    ufw default deny incoming
    ufw default allow outgoing
    ok "Default policies set"

    # Allow rules
    info "Adding firewall rules..."
    ufw allow "${SSH_PORT}/tcp" comment "SSH"
    ufw allow 443/tcp comment "TrustTunnel TCP"
    ufw allow 443/udp comment "TrustTunnel QUIC"
    ok "Rules added (SSH:$SSH_PORT, 443/tcp, 443/udp)"

    # Enable
    info "Enabling UFW..."
    ufw --force enable
    ok "UFW enabled"

    # Show status
    echo ""
    info "Current firewall rules:"
    ufw status numbered

    echo ""
    ok "Firewall configured successfully."
    info "Only SSH ($SSH_PORT), 443/tcp, and 443/udp are open."
    info "Run step04 (fail2ban) next."
}

dispatch check run "$1"
