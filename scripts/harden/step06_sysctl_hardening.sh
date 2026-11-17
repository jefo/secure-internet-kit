#!/bin/bash
# step06_sysctl_hardening.sh — Apply kernel-level security parameters
SCRIPT_DESC="Applies sysctl hardening: anti-spoofing, SYN flood protection, ICMP hardening, disable IPv6, log martians."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

SYSCTL_CONF="/etc/sysctl.d/99-hardening.conf"

# ─── Check ─────────────────────────────────────────────────────────
check() {
    local all_ok=true

    echo -e "${BOLD}Checking step 06: Sysctl hardening${NC}\n"

    # Config file exists
    if [[ -f "$SYSCTL_CONF" ]]; then
        print_check_ok "Hardening config file exists ($SYSCTL_CONF)"
    else
        print_check_fail "Hardening config file does NOT exist"
        all_ok=false
    fi

    # Check each parameter
    check_sysctl "net.ipv4.conf.all.rp_filter" "1" "Reverse path filtering (all)" || all_ok=false
    check_sysctl "net.ipv4.conf.default.rp_filter" "1" "Reverse path filtering (default)" || all_ok=false
    check_sysctl "net.ipv4.conf.all.accept_redirects" "0" "ICMP redirects disabled (all)" || all_ok=false
    check_sysctl "net.ipv6.conf.all.accept_redirects" "0" "IPv6 ICMP redirects disabled" || all_ok=false
    check_sysctl "net.ipv4.conf.all.send_redirects" "0" "ICMP redirects sending disabled" || all_ok=false
    check_sysctl "net.ipv4.icmp_echo_ignore_broadcasts" "1" "ICMP broadcast ping ignored" || all_ok=false
    check_sysctl "net.ipv4.tcp_syncookies" "1" "SYN cookies enabled" || all_ok=false
    check_sysctl "net.ipv4.conf.all.log_martians" "1" "Martian packet logging" || all_ok=false
    check_sysctl "net.ipv4.conf.default.log_martians" "1" "Martian packet logging (default)" || all_ok=false

    # IPv6 disabled check (only if we set it)
    if grep -q "net.ipv6.conf.all.disable_ipv6 = 1" "$SYSCTL_CONF" 2>/dev/null; then
        local ipv6_val
        ipv6_val=$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null || echo "0")
        if [[ "$ipv6_val" == "1" ]]; then
            print_check_ok "IPv6 disabled at kernel level"
        else
            print_check_fail "IPv6 is NOT disabled (config says it should be)"
            all_ok=false
        fi
    fi

    $all_ok
}

check_sysctl() {
    local key="$1"
    local expected="$2"
    local label="$3"
    local current
    current=$(sysctl -n "$key" 2>/dev/null || echo "UNSET")

    if [[ "$current" == "$expected" ]]; then
        print_check_ok "$label ($key = $expected)"
        return 0
    else
        print_check_fail "$label ($key = $current, expected $expected)"
        return 1
    fi
}

# ─── Run ───────────────────────────────────────────────────────────
run() {
    step "Applying sysctl hardening"

    info "Writing $SYSCTL_CONF..."
    cat > "$SYSCTL_CONF" <<'EOF'
# ─── Network hardening ───

# Anti-IP-spoofing (reverse path filtering)
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Ignore ICMP redirects (prevent MITM)
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0

# Don't respond to broadcast pings (Smurf attack protection)
net.ipv4.icmp_echo_ignore_broadcasts = 1

# SYN flood protection
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048

# Log suspicious packets
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Disable IPv6 (if not needed — prevents IPv6 leak)
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF
    ok "Config written"

    # Apply
    info "Applying sysctl settings..."
    sysctl --system
    ok "Sysctl settings applied"

    echo ""
    ok "Kernel hardening complete."
    info "Run step07 (install TrustTunnel) next."
}

dispatch check run "$1"
