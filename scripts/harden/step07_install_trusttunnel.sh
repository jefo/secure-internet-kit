#!/bin/bash
# step07_install_trusttunnel.sh — Download and install TrustTunnel endpoint
SCRIPT_DESC="Downloads and installs the TrustTunnel endpoint binary from the official GitHub repository."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# ─── Configuration ─────────────────────────────────────────────────
INSTALL_DIR="${INSTALL_DIR:-/opt/trusttunnel}"
TRUSTTUNNEL_VERSION="${TRUSTTUNNEL_VERSION:-}"  # Empty = latest
INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/TrustTunnel/TrustTunnel/refs/heads/master/scripts/install.sh"

# ─── Check ─────────────────────────────────────────────────────────
check() {
    local all_ok=true

    echo -e "${BOLD}Checking step 07: TrustTunnel installation${NC}\n"

    # Binary exists
    if [[ -x "$INSTALL_DIR/trusttunnel_endpoint" ]]; then
        print_check_ok "trusttunnel_endpoint binary exists and is executable"
    else
        print_check_fail "trusttunnel_endpoint binary NOT found at $INSTALL_DIR"
        all_ok=false
    fi

    # Setup wizard exists
    if [[ -x "$INSTALL_DIR/setup_wizard" ]]; then
        print_check_ok "setup_wizard binary exists"
    else
        print_check_fail "setup_wizard binary NOT found"
        all_ok=false
    fi

    # Systemd template exists
    if [[ -f "$INSTALL_DIR/trusttunnel.service.template" ]]; then
        print_check_ok "trusttunnel.service.template exists"
    else
        print_check_fail "trusttunnel.service.template NOT found"
        all_ok=false
    fi

    # Version info
    if [[ -x "$INSTALL_DIR/trusttunnel_endpoint" ]]; then
        local version
        version=$("$INSTALL_DIR/trusttunnel_endpoint" --version 2>/dev/null || echo "unknown")
        info "Installed version: $version"
    fi

    $all_ok
}

# ─── Run ───────────────────────────────────────────────────────────
run() {
    step "Installing TrustTunnel endpoint"

    # Stop if already running
    if service_active trusttunnel; then
        info "Stopping existing TrustTunnel service..."
        systemctl stop trusttunnel
        ok "Service stopped"
    fi

    # Build install command
    local install_cmd="curl -fsSL $INSTALL_SCRIPT_URL | sh -s - -o $INSTALL_DIR"
    if [[ -n "$TRUSTTUNNEL_VERSION" ]]; then
        install_cmd="$install_cmd -V $TRUSTTUNNEL_VERSION"
        info "Installing version: $TRUSTTUNNEL_VERSION"
    else
        info "Installing latest version"
    fi

    # Install
    info "Running installer..."
    eval "$install_cmd"
    ok "TrustTunnel installed to $INSTALL_DIR"

    # Verify
    if [[ -x "$INSTALL_DIR/trusttunnel_endpoint" ]]; then
        local version
        version=$("$INSTALL_DIR/trusttunnel_endpoint" --version 2>/dev/null || echo "unknown")
        ok "Verified: trusttunnel_endpoint $version"
    else
        fatal "Installation failed — binary not found at $INSTALL_DIR/trusttunnel_endpoint"
    fi

    echo ""
    info "TrustTunnel endpoint installed successfully."
    info "Run step08 (configure TrustTunnel) next."
}

dispatch check run "$1"
