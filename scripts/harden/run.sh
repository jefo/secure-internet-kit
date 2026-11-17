#!/bin/bash
# run.sh — Master orchestrator for VPS hardening + TrustTunnel deployment
# Each step has --check (verify) and --run (apply).
# Steps must pass in order: step N cannot succeed until step N-1 is applied.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# ─── Step definitions ──────────────────────────────────────────────
STEPS=(
    "01:Create admin user + SSH key"
    "02:Harden SSH (port, no root, no password)"
    "03:Firewall (UFW) — default deny, open SSH + 443"
    "04:Fail2ban — auto-ban brute-force SSH attempts"
    "05:Automatic security updates"
    "06:Sysctl kernel hardening"
    "07:Install TrustTunnel endpoint"
    "08:Configure TrustTunnel (vpn.toml, hosts, credentials)"
    "09:TLS certificate (Let's Encrypt)"
    "10:Systemd service + file permissions lockdown"
)

# ─── Colours ───────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Helpers ───────────────────────────────────────────────────────
get_step_script() {
    local num="$1"
    echo "$SCRIPT_DIR/step${num}_*.sh"
}

check_step() {
    local num="$1"
    local script
    script=$(get_step_script "$num")

    if [[ -z "$script" ]] || [[ ! -f "$script" ]]; then
        echo "NOT_FOUND"
        return 1
    fi

    if bash "$script" --check &>/dev/null; then
        echo "OK"
        return 0
    else
        echo "PENDING"
        return 1
    fi
}

run_step() {
    local num="$1"
    local script
    script=$(get_step_script "$num")

    if [[ -z "$script" ]] || [[ ! -f "$script" ]]; then
        error "Script for step $num not found"
        return 1
    fi

    bash "$script" --run
}

# ─── Commands ──────────────────────────────────────────────────────
cmd_status() {
    echo -e "\n${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  Secure Internet Kit VPS — Deployment Status${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    local step_num=0
    local all_done=true
    local last_applied=""

    for entry in "${STEPS[@]}"; do
        step_num="${entry%%:*}"
        step_desc="${entry#*:}"
        step_num_padded=$(printf "%02d" "$step_num")

        local status
        status=$(check_step "$step_num" 2>/dev/null || true)

        case "$status" in
            OK)
                echo -e "  ${GREEN}✓${NC} Step $step_num: $step_desc"
                last_applied="$step_num"
                ;;
            PENDING)
                echo -e "  ${YELLOW}○${NC} Step $step_num: $step_desc"
                all_done=false
                ;;
            NOT_FOUND)
                echo -e "  ${RED}?${NC} Step $step_num: $step_desc ${YELLOW}(script missing)${NC}"
                all_done=false
                ;;
        esac
    done

    echo ""
    if $all_done; then
        echo -e "  ${GREEN}${BOLD}All steps applied. Server is hardened and running.${NC}"
    elif [[ -n "$last_applied" ]]; then
        local next=$((10#$last_applied + 1))
        echo -e "  ${CYAN}Last applied: Step $last_applied${NC}"
        echo -e "  ${YELLOW}Next: Step $next — run '$0 run' or '$0 run $next'${NC}"
    else
        echo -e "  ${YELLOW}No steps applied yet. Run '$0 run' to start.${NC}"
    fi
    echo ""
}

cmd_run() {
    local target_step="${1:-}"

    if [[ -n "$target_step" ]]; then
        # Run a specific step
        printf -v target_num "%02d" "$target_step"
        echo -e "\n${BOLD}Running Step $target_num${NC}\n"

        # Check all prerequisites
        for i in $(seq 1 $((10#$target_num - 1))); do
            printf -v prev_num "%02d" "$i"
            local status
            status=$(check_step "$i" 2>/dev/null || true)
            if [[ "$status" != "OK" ]]; then
                error "Prerequisite failed: Step $prev_num must be applied before Step $target_num"
                error "Run '$0 run' to apply all pending steps in order."
                exit 1
            fi
        done

        run_step "$target_num"
    else
        # Run all pending steps
        echo -e "\n${BOLD}Applying all pending steps...${NC}\n"

        for entry in "${STEPS[@]}"; do
            step_num="${entry%%:*}"
            step_desc="${entry#*:}"
            step_num_padded=$(printf "%02d" "$step_num")

            local status
            status=$(check_step "$step_num" 2>/dev/null || true)

            if [[ "$status" == "OK" ]]; then
                echo -e "  ${GREEN}✓${NC} Step $step_num_padded: $step_desc ${CYAN}(already applied, skipping)${NC}"
                continue
            fi

            # Check that all previous steps are OK
            local prereqs_ok=true
            for prev in $(seq 1 $((10#$step_num - 1))); do
                local prev_status
                prev_status=$(check_step "$prev" 2>/dev/null || true)
                if [[ "$prev_status" != "OK" ]]; then
                    printf -v prev_padded "%02d" "$prev"
                    error "Cannot run Step $step_num_padded: prerequisite Step $prev_padded is not applied"
                    prereqs_ok=false
                    break
                fi
            done

            if ! $prereqs_ok; then
                echo ""
                error "Halting. Apply prerequisites first."
                exit 1
            fi

            echo ""
            echo -e "${BOLD}▶ Step $step_num_padded: $step_desc${NC}"
            echo -e "${BOLD}───────────────────────────────────────────────────${NC}"

            if ! run_step "$step_num"; then
                echo ""
                error "Step $step_num_padded FAILED. Fix the issue and re-run."
                exit 1
            fi
        done

        echo ""
        echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}${BOLD}  All steps completed successfully!${NC}"
        echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════${NC}"
    fi
}

cmd_check_all() {
    echo -e "\n${BOLD}Running full security audit...${NC}\n"

    local total=${#STEPS[@]}
    local passed=0
    local failed=0

    for entry in "${STEPS[@]}"; do
        step_num="${entry%%:*}"
        step_desc="${entry#*:}"
        step_num_padded=$(printf "%02d" "$step_num")

        printf "  Step %-2s %-40s" "$step_num_padded" "$step_desc"

        local status
        status=$(check_step "$step_num" 2>/dev/null || true)

        if [[ "$status" == "OK" ]]; then
            echo -e "${GREEN}✓ PASS${NC}"
            ((passed++))
        else
            echo -e "${RED}✗ FAIL${NC}"
            ((failed++))
        fi
    done

    echo ""
    echo -e "  ${BOLD}Results:${NC} $passed passed, $failed failed out of $total"

    if [[ $failed -eq 0 ]]; then
        echo -e "  ${GREEN}${BOLD}All checks passed. Server is hardened.${NC}"
        exit 0
    else
        echo -e "  ${YELLOW}Run '$0 run' to apply missing steps.${NC}"
        exit 1
    fi
}

cmd_check() {
    local step_num="${1:-}"
    if [[ -z "$step_num" ]]; then
        cmd_check_all
        return
    fi

    local script
    script=$(get_step_script "$step_num")
    if [[ -f "$script" ]]; then
        bash "$script" --check
    else
        error "Script for step $step_num not found"
        exit 1
    fi
}

cmd_run_single() {
    local step_num="${1:-}"
    if [[ -z "$step_num" ]]; then
        error "Step number required. Usage: $0 run-single <step_number>"
        exit 1
    fi

    local script
    script=$(get_step_script "$step_num")
    if [[ -f "$script" ]]; then
        bash "$script" --run
    else
        error "Script for step $step_num not found"
        exit 1
    fi
}

# ─── Usage ─────────────────────────────────────────────────────────
usage() {
    cat <<EOF
Usage: $(basename "$0") <command> [args]

Commands:
  status          Show which steps are applied vs pending
  check           Run --check on all steps (full audit)
  check <N>       Run --check on a specific step
  run             Apply all pending steps in order (with prerequisite checks)
  run <N>         Apply a single step (checks prerequisites first)
  help            Show this help

Environment variables (optional, override defaults):
  SSH_PORT        SSH port (default: 2222)
  ADMIN_USER      Admin username (default: vpnadmin)
  SSH_PUBKEY      SSH public key for step 01
  INSTALL_DIR     TrustTunnel install dir (default: /opt/trusttunnel)
  TLS_DOMAIN      Domain for Let's Encrypt cert (required for step 09)
  TLS_EMAIL       Email for Let's Encrypt (required for step 09)
  TT_USERNAME    Default TrustTunnel username (default: admin)
  TT_PASSWORD    Default TrustTunnel password (auto-generated if not set)

Examples:
  $(basename "$0") status                              # What's done?
  $(basename "$0") check                               # Full audit
  $(basename "$0") run                                 # Apply all pending
  $(basename "$0") run 03                              # Just the firewall
  SSH_PORT=3333 $(basename "$0") run 02               # Custom SSH port
  TLS_DOMAIN=cdn.example.com TLS_EMAIL=a@b.com $(basename "$0") run 09
EOF
}

# ─── Main dispatch ─────────────────────────────────────────────────
case "${1:-status}" in
    status)       cmd_status ;;
    check)        shift; cmd_check "${1:-}" ;;
    run)          shift; cmd_run "${1:-}" ;;
    help|-h|--help) usage ;;
    *)            error "Unknown command: $1"; usage; exit 1 ;;
esac
