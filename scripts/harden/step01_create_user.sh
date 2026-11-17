#!/bin/bash
# step01_create_user.sh — Create admin user, add to sudo, set up SSH keys
SCRIPT_DESC="Creates a non-root admin user, adds to sudo group, and sets up SSH key authentication."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# ─── Configuration (edit these) ────────────────────────────────────
ADMIN_USER="${ADMIN_USER:-vpnadmin}"
SSH_PUBKEY="${SSH_PUBKEY:-}"  # Set env var or edit here

# ─── Check ─────────────────────────────────────────────────────────
check() {
    local all_ok=true

    echo -e "${BOLD}Checking step 01: Admin user + SSH key${NC}\n"

    # Check user exists
    if id "$ADMIN_USER" &>/dev/null; then
        print_check_ok "User '$ADMIN_USER' exists"
    else
        print_check_fail "User '$ADMIN_USER' does not exist"
        all_ok=false
    fi

    # Check sudo membership
    if id -nG "$ADMIN_USER" 2>/dev/null | grep -qw sudo; then
        print_check_ok "User '$ADMIN_USER' is in sudo group"
    else
        print_check_fail "User '$ADMIN_USER' is NOT in sudo group"
        all_ok=false
    fi

    # Check SSH key configured
    local auth_keys="/home/$ADMIN_USER/.ssh/authorized_keys"
    if [[ -f "$auth_keys" ]] && [[ -s "$auth_keys" ]]; then
        local key_count
        key_count=$(wc -l < "$auth_keys")
        print_check_ok "SSH authorized_keys exists ($key_count key(s))"
    else
        print_check_fail "SSH authorized_keys missing for '$ADMIN_USER'"
        all_ok=false
    fi

    $all_ok
}

# ─── Run ───────────────────────────────────────────────────────────
run() {
    step "Creating admin user"

    # 1. Create user if not exists
    if ! id "$ADMIN_USER" &>/dev/null; then
        info "Creating user '$ADMIN_USER'..."
        adduser --disabled-password --gecos "" "$ADMIN_USER"
        ok "User '$ADMIN_USER' created"
    else
        info "User '$ADMIN_USER' already exists, skipping"
    fi

    # 2. Add to sudo
    if ! id -nG "$ADMIN_USER" 2>/dev/null | grep -qw sudo; then
        info "Adding '$ADMIN_USER' to sudo group..."
        usermod -aG sudo "$ADMIN_USER"
        ok "Added to sudo group"
    else
        info "Already in sudo group"
    fi

    # 3. Set up SSH
    local ssh_dir="/home/$ADMIN_USER/.ssh"
    local auth_keys="$ssh_dir/authorized_keys"

    info "Setting up SSH key authentication..."

    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"

    if [[ -n "$SSH_PUBKEY" ]]; then
        if ! grep -qF "$SSH_PUBKEY" "$auth_keys" 2>/dev/null; then
            echo "$SSH_PUBKEY" >> "$auth_keys"
            ok "SSH key added from SSH_PUBKEY env variable"
        else
            info "SSH key already present"
        fi
    else
        warn "No SSH_PUBKEY provided. The key must be added manually:"
        warn "  ssh-copy-id $ADMIN_USER@<server_ip>"
        warn "  OR: echo 'ssh-ed25519 AAAA...' >> $auth_keys"
        info "Creating empty authorized_keys file for manual setup..."
        touch "$auth_keys"
    fi

    chmod 600 "$auth_keys"
    chown -R "$ADMIN_USER:$ADMIN_USER" "$ssh_dir"

    echo ""
    info "Next steps:"
    info "  1. Set a password: passwd $ADMIN_USER"
    info "  2. Test login: ssh $ADMIN_USER@<server_ip>"
    info "  3. Run step02 to harden SSH once you confirm access"
}

dispatch check run "$1"
