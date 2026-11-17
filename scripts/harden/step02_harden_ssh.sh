#!/bin/bash
# step02_harden_ssh.sh — Harden sshd_config (port, no root, no password)
SCRIPT_DESC="Changes SSH port, disables root login, disables password authentication, enables key-based auth only."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# ─── Configuration ─────────────────────────────────────────────────
SSH_PORT="${SSH_PORT:-2222}"
SSHD_CONFIG="/etc/ssh/sshd_config"

# ─── Check ─────────────────────────────────────────────────────────
check() {
    local all_ok=true

    echo -e "${BOLD}Checking step 02: SSH hardening${NC}\n"

    # Port
    local current_port
    current_port=$(grep -E '^[[:space:]]*Port ' "$SSHD_CONFIG" 2>/dev/null | awk '{print $2}' || true)
    [[ -z "$current_port" ]] && current_port="22"

    if [[ "$SSH_PORT" == "$current_port" ]]; then
        print_check_ok "SSH port is $SSH_PORT"
    elif [[ "$current_port" == "22" ]] || [[ -z "$current_port" ]]; then
        # Port line is commented out or set to 22 (default)
        if [[ "$SSH_PORT" == "22" ]]; then
            print_check_ok "SSH port is default (22)"
        else
            print_check_fail "SSH port is NOT set to $SSH_PORT (currently $current_port or default 22)"
            all_ok=false
        fi
    else
        print_check_fail "SSH port is NOT set to $SSH_PORT (currently $current_port)"
        all_ok=false
    fi

    # PermitRootLogin prohibit-password
    if config_value_set "$SSHD_CONFIG" "PermitRootLogin" "prohibit-password"; then
        print_check_ok "PermitRootLogin set to prohibit-password (keys only)"
    else
        print_check_fail "PermitRootLogin is NOT set to prohibit-password"
        all_ok=false
    fi

    # PasswordAuthentication no
    if config_value_set "$SSHD_CONFIG" "PasswordAuthentication" "no"; then
        print_check_ok "PasswordAuthentication disabled"
    else
        print_check_fail "PasswordAuthentication is NOT disabled"
        all_ok=false
    fi

    # PubkeyAuthentication yes
    if config_value_set "$SSHD_CONFIG" "PubkeyAuthentication" "yes"; then
        print_check_ok "PubkeyAuthentication enabled"
    else
        print_check_fail "PubkeyAuthentication is NOT enabled"
        all_ok=false
    fi

    # MaxAuthTries
    if config_value_set "$SSHD_CONFIG" "MaxAuthTries" "3"; then
        print_check_ok "MaxAuthTries set to 3"
    else
        print_check_fail "MaxAuthTries NOT set to 3"
        all_ok=false
    fi

    # LoginGraceTime
    if config_value_set "$SSHD_CONFIG" "LoginGraceTime" "20"; then
        print_check_ok "LoginGraceTime set to 20"
    else
        print_check_fail "LoginGraceTime NOT set to 20"
        all_ok=false
    fi

    # X11Forwarding
    if config_value_set "$SSHD_CONFIG" "X11Forwarding" "no"; then
        print_check_ok "X11Forwarding disabled"
    else
        print_check_fail "X11Forwarding is NOT disabled"
        all_ok=false
    fi

    $all_ok
}

# ─── Run ───────────────────────────────────────────────────────────
run() {
    step "Hardening SSH configuration"

    # Verify we're not about to lock ourselves out
    local current_port
    current_port=$(grep -E '^[[:space:]]*Port ' "$SSHD_CONFIG" 2>/dev/null | awk '{print $2}' || echo "22")
    # If port is already changed, use it; otherwise 22
    [[ -z "$current_port" ]] && current_port=22

    if [[ "$SSH_PORT" != "$current_port" ]] && [[ "$current_port" != "22" ]]; then
        warn "SSH is currently on port $current_port but you're changing to $SSH_PORT"
        warn "Make sure your firewall allows $SSH_PORT BEFORE restarting sshd!"
    fi

    # Apply each setting
    if [[ "$SSH_PORT" != "22" ]]; then
        apply_sshd_setting "Port" "$SSH_PORT"
    else
        info "SSH port: keeping default (22)"
    fi
    apply_sshd_setting "PermitRootLogin" "prohibit-password"
    apply_sshd_setting "PasswordAuthentication" "no"
    apply_sshd_setting "PubkeyAuthentication" "yes"
    apply_sshd_setting "ChallengeResponseAuthentication" "no"
    apply_sshd_setting "UsePAM" "yes"
    apply_sshd_setting "X11Forwarding" "no"
    apply_sshd_setting "MaxAuthTries" "3"
    apply_sshd_setting "LoginGraceTime" "20"

    # Validate config before restarting
    info "Validating sshd configuration..."
    if sshd -t 2>/dev/null; then
        ok "sshd config syntax is valid"
    else
        error "sshd config has syntax errors! NOT restarting."
        error "Fix $SSHD_CONFIG manually before continuing."
        return 1
    fi

    # Detect service name (Ubuntu uses 'ssh', others use 'sshd')
    local ssh_service="sshd"
    if systemctl list-unit-files ssh.service &>/dev/null; then
        ssh_service="ssh"
    fi

    # Restart SSH
    info "Restarting $ssh_service..."
    systemctl restart "$ssh_service"
    ok "$ssh_service restarted on port $SSH_PORT"

    echo ""
    warn "════════════════════════════════════════════════════════════"
    warn "IMPORTANT: Do NOT close your current session!"
    warn "Test connection in a NEW terminal:"
    warn "  ssh -p $SSH_PORT ${ADMIN_USER:-vpnadmin}@<server_ip>"
    warn "════════════════════════════════════════════════════════════"
    echo ""
    info "After confirming access, run step03 (firewall setup)"
}

# Helper to apply a single sshd setting idempotently
apply_sshd_setting() {
    local key="$1"
    local value="$2"

    if config_value_set "$SSHD_CONFIG" "$key" "$value"; then
        info "$key = $value (already set)"
    else
        # Check if the key exists (commented or different value)
        if grep -qE "^[#[:space:]]*${key}[[:space:]]" "$SSHD_CONFIG" 2>/dev/null; then
            # Replace existing line (commented or uncommented)
            sed -i "s/^[#[:space:]]*${key}[[:space:]].*/${key} ${value}/" "$SSHD_CONFIG"
        else
            # Append
            echo "${key} ${value}" >> "$SSHD_CONFIG"
        fi
        ok "$key = $value"
    fi
}

dispatch check run "$1"
