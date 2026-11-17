#!/bin/bash
# lib.sh — Shared functions for all hardening scripts
# Source this file: source "$(dirname "$0")/lib.sh"

set -euo pipefail

# ─── Colours ───────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Colour

# ─── Logging helpers ───────────────────────────────────────────────
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()      { echo -e "${GREEN}[ OK ]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERR ]${NC}  $*" >&2; }
fatal()   { error "$*"; exit 1; }
step()    { echo -e "\n${BOLD}━━━ $* ━━━${NC}"; }

# ─── Check helpers ─────────────────────────────────────────────────
# Each check function returns 0 = already applied, 1 = not applied.
# Call these from the script's check() function.

is_root() {
    [[ $EUID -eq 0 ]] || fatal "This script must be run as root (use sudo)"
}

is_ubuntu() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        [[ "$ID" == "ubuntu" ]] && return 0
    fi
    return 1
}

pkg_installed() {
    dpkg -s "$1" &>/dev/null
}

service_active() {
    systemctl is-active --quiet "$1" 2>/dev/null
}

file_contains() {
    # file_contains <file> <pattern>
    [[ -f "$1" ]] && grep -qF "$2" "$1" 2>/dev/null
}

file_matches_regex() {
    # file_matches_regex <file> <regex>
    [[ -f "$1" ]] && grep -qE "$2" "$1" 2>/dev/null
}

config_value_set() {
    # config_value_set <file> <key> <value>
    # Checks that sshd_config-style file has "Key value" (uncommented)
    [[ -f "$1" ]] && grep -qE "^[[:space:]]*${2}[[:space:]]+${3}" "$1" 2>/dev/null
}

port_open_ufw() {
    # port_open_ufw <port/proto>
    ufw status 2>/dev/null | grep -qF "$1"
}

sysctl_set() {
    # sysctl_set <key> <value>
    local current
    current=$(sysctl -n "$1" 2>/dev/null || echo "UNSET")
    [[ "$current" == "$2" ]]
}

# ─── Print helpers ──────────────────────────────────────────────────
print_header() {
    local title="$1"
    local desc="$2"
    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}  $title${NC}"
    echo -e "${BOLD}═══════════════════════════════════════════════════${NC}"
    [[ -n "$desc" ]] && echo -e "  $desc\n"
    echo ""
}

print_check_ok() {
    ok "$1 — already applied"
}

print_check_fail() {
    warn "$1 — NOT applied, run with --run to fix"
}

# ─── Usage boilerplate ─────────────────────────────────────────────
usage() {
    local name="$1"
    local desc="$2"
    echo "Usage: $name {--check|--run|--help}"
    echo ""
    echo "$desc"
    echo ""
    echo "  --check   Verify if this step is already applied"
    echo "  --run     Apply this step (idempotent)"
    echo "  --help    Show this help"
    exit 0
}

# ─── Dispatch ──────────────────────────────────────────────────────
# Call this at the bottom of each script after defining check() and run()
dispatch() {
    local check_fn="$1"
    local run_fn="$2"
    local action="${3:-}"

    case "$action" in
        --check)
            is_root
            if "$check_fn"; then
                echo ""
                ok "All checks passed. Step is already applied."
                exit 0
            else
                echo ""
                warn "Checks failed. Run '$0 --run' to apply."
                exit 1
            fi
            ;;
        --run)
            is_root
            "$run_fn"
            echo ""
            # Re-run check to confirm
            if "$check_fn"; then
                ok "Step applied and verified successfully."
                exit 0
            else
                error "Step may have partially applied. Run '$0 --check' for details."
                exit 1
            fi
            ;;
        --help|-h|help)
            usage "$(basename "$0")" "${SCRIPT_DESC:-}"
            ;;
        *)
            error "Unknown argument: ${action:-(none)}"
            usage "$(basename "$0")" "${SCRIPT_DESC:-}"
            ;;
    esac
}
