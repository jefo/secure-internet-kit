#!/bin/bash
# step05_auto_updates.sh — Enable unattended security updates
SCRIPT_DESC="Enables automatic security updates via unattended-upgrades to keep the system patched without manual intervention."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# ─── Check ─────────────────────────────────────────────────────────
check() {
    local all_ok=true

    echo -e "${BOLD}Checking step 05: Automatic updates${NC}\n"

    # Package installed
    if pkg_installed unattended-upgrades; then
        print_check_ok "unattended-upgrades is installed"
    else
        print_check_fail "unattended-upgrades is NOT installed"
        all_ok=false
    fi

    # Service enabled
    if systemctl is-enabled --quiet unattended-upgrades 2>/dev/null; then
        print_check_ok "unattended-upgrades service is enabled"
    else
        print_check_fail "unattended-upgrades service is NOT enabled"
        all_ok=false
    fi

    # Auto-upgrades configured
    local conf="/etc/apt/apt.conf.d/20auto-upgrades"
    if [[ -f "$conf" ]] && grep -q 'APT::Periodic::Unattended-Upgrade "1"' "$conf" 2>/dev/null; then
        print_check_ok "Unattended-upgrades is enabled in APT config"
    else
        print_check_fail "Unattended-upgrades NOT enabled in APT config"
        all_ok=false
    fi

    # Security updates only
    local ua_conf="/etc/apt/apt.conf.d/50unattended-upgrades"
    if [[ -f "$ua_conf" ]] && grep -q 'Unattended-Upgrade::Allowed-Origins' "$ua_conf" 2>/dev/null; then
        print_check_ok "Allowed origins configured (security updates)"
    else
        print_check_fail "Allowed origins NOT configured"
        all_ok=false
    fi

    $all_ok
}

# ─── Run ───────────────────────────────────────────────────────────
run() {
    step "Enabling automatic security updates"

    # Install
    if ! pkg_installed unattended-upgrades; then
        info "Installing unattended-upgrades..."
        apt update && apt install -y unattended-upgrades
        ok "unattended-upgrades installed"
    else
        info "unattended-upgrades already installed"
    fi

    # Configure auto-updates
    info "Configuring automatic updates..."
    cat > /etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
    ok "APT periodic config written"

    # Ensure security-only updates
    local ua_conf="/etc/apt/apt.conf.d/50unattended-upgrades"
    if [[ -f "$ua_conf" ]]; then
        # Remove any non-security origins if present
        info "Verifying 50unattended-upgrades allows security updates..."
        if ! grep -q '${distro_id}:${distro_codename}-security' "$ua_conf" 2>/dev/null; then
            warn "50unattended-upgrades doesn't include security origin — may need manual review"
        else
            ok "Security updates origin is present"
        fi
    else
        warn "50unattended-upgrades not found — using defaults"
    fi

    # Enable service
    info "Enabling unattended-upgrades service..."
    systemctl enable unattended-upgrades
    systemctl start unattended-upgrades 2>/dev/null || true
    ok "Service enabled"

    echo ""
    ok "Automatic security updates are enabled."
    info "Updates are applied automatically. Reboots still require manual action."
    info "Run step06 (sysctl hardening) next."
}

dispatch check run "$1"
