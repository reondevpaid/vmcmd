#!/bin/bash
set -Eeuo pipefail

# ============================================================
# REON DEV INSTALLER v3 - Complete Management Platform
# Made By ReonDev
# Version: 3.0.0
# ============================================================

# ============================================================
# Global Configuration
# ============================================================

REON_VERSION="3.0.0"
REON_NAME="REON DEV INSTALLER"
REON_AUTHOR="ReonDev"
REON_INSTALL_DIR="/opt/reon-dev-installer"
REON_CONFIG_DIR="$REON_INSTALL_DIR/config"
REON_LOGS_DIR="$REON_INSTALL_DIR/logs"
REON_BACKUPS_DIR="$REON_INSTALL_DIR/backups"
REON_VM_DIR="$REON_INSTALL_DIR/vms"

# Colors
readonly C_RESET='\033[0m'
readonly C_BLACK='\033[0;30m'
readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[0;33m'
readonly C_BLUE='\033[0;34m'
readonly C_MAGENTA='\033[0;35m'
readonly C_CYAN='\033[0;36m'
readonly C_WHITE='\033[0;37m'
readonly C_BOLD='\033[1m'
readonly C_DIM='\033[2m'

# Icons
readonly ICON_SUCCESS="✓"
readonly ICON_ERROR="✗"
readonly ICON_WARNING="⚠"
readonly ICON_INFO="ℹ"
readonly ICON_QUESTION="?"
readonly ICON_STAR="★"
readonly ICON_ARROW="→"

# Log levels
LOG_LEVEL="INFO"
declare -A LOG_LEVELS=(
    ["DEBUG"]=0
    ["INFO"]=1
    ["WARN"]=2
    ["ERROR"]=3
    ["FATAL"]=4
)

# ============================================================
# Core Functions
# ============================================================

print_color() {
    local color=$1
    local message=$2
    local bold=${3:-false}
    if [[ "$bold" == "true" ]]; then
        echo -e "${C_BOLD}${color}${message}${C_RESET}"
    else
        echo -e "${color}${message}${C_RESET}"
    fi
}

print_success() { echo -e "${C_GREEN}${ICON_SUCCESS}${C_RESET} $1"; }
print_error() { echo -e "${C_RED}${ICON_ERROR}${C_RESET} $1" >&2; }
print_warning() { echo -e "${C_YELLOW}${ICON_WARNING}${C_RESET} $1"; }
print_info() { echo -e "${C_CYAN}${ICON_INFO}${C_RESET} $1"; }
print_question() { echo -e "${C_MAGENTA}${ICON_QUESTION}${C_RESET} $1"; }
print_header() { echo -e "\n${C_BOLD}${C_CYAN}═══ $1 ═══${C_RESET}\n"; }
print_subheader() { echo -e "${C_BOLD}${C_BLUE}─── $1 ───${C_RESET}"; }

# ============================================================
# Logging Functions
# ============================================================

log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="[$timestamp] [$level] $message"

    mkdir -p "$REON_LOGS_DIR"
    echo "$log_entry" >> "$REON_LOGS_DIR/actions.log"

    if [[ "$level" == "ERROR" ]] || [[ "$level" == "FATAL" ]]; then
        echo "$log_entry" >> "$REON_LOGS_DIR/errors.log"
    fi
}

log_info() { log_message "INFO" "$1"; }
log_warn() { log_message "WARN" "$1"; }
log_error() { log_message "ERROR" "$1"; }
log_action() { log_message "ACTION" "$1 - $2"; }

# ============================================================
# System Information Functions (FIXED)
# ============================================================

get_os_info() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "${ID:-unknown}|${VERSION_ID:-unknown}|${VERSION_CODENAME:-unknown}"
    else
        echo "unknown|unknown|unknown"
    fi
}

get_cpu_info() {
    local model=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^[ \t]*//' || echo "unknown")
    local cores=$(grep -c "^processor" /proc/cpuinfo 2>/dev/null || echo "0")
    local arch=$(uname -m 2>/dev/null || echo "unknown")
    echo "$model|$cores|$arch"
}

get_memory_info() {
    local total=$(grep "^MemTotal" /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")
    local total_mb=$((total / 1024))
    local total_gb=$(echo "scale=2; $total / 1048576" | bc 2>/dev/null || echo "0")
    local free=$(grep "^MemFree" /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")
    local free_mb=$((free / 1024))
    local free_gb=$(echo "scale=2; $free / 1048576" | bc 2>/dev/null || echo "0")
    local swap=$(grep "^SwapTotal" /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")
    local swap_mb=$((swap / 1024))
    echo "$total_mb|$total_gb|$free_mb|$free_gb|$swap_mb"
}

get_disk_info() {
    local total=$(df -BG / 2>/dev/null | awk 'NR==2 {print $2}' | sed 's/G//' || echo "0")
    local used=$(df -BG / 2>/dev/null | awk 'NR==2 {print $3}' | sed 's/G//' || echo "0")
    local free=$(df -BG / 2>/dev/null | awk 'NR==2 {print $4}' | sed 's/G//' || echo "0")
    local percent=$(df -BG / 2>/dev/null | awk 'NR==2 {print $5}' | sed 's/%//' || echo "0")
    echo "$total|$used|$free|$percent"
}

get_network_info() {
    local public_ip=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null || echo "Unknown")
    local private_ip=$(ip -4 addr show 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v "127.0.0.1" | head -n1 || echo "Unknown")
    local hostname=$(hostname 2>/dev/null || echo "unknown")
    echo "$public_ip|$private_ip|$hostname"
}

get_virtualization_info() {
    if command -v systemd-detect-virt &> /dev/null; then
        systemd-detect-virt 2>/dev/null || echo "unknown"
    elif grep -q "hypervisor" /proc/cpuinfo 2>/dev/null; then
        echo "kvm"
    elif grep -q "QEMU" /proc/cpuinfo 2>/dev/null; then
        echo "qemu"
    elif grep -q "VMware" /proc/cpuinfo 2>/dev/null; then
        echo "vmware"
    else
        echo "physical"
    fi
}

get_load_average() {
    uptime 2>/dev/null | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//' || echo "unknown"
}

get_uptime() {
    uptime -p 2>/dev/null | sed 's/up //' || echo "unknown"
}

# ============================================================
# UI Functions
# ============================================================

clear_screen() {
    printf "\033[2J\033[H"
}

show_progress() {
    local current=$1
    local total=$2
    local message=${3:-"Processing..."}
    local width=50

    local percent=$((current * 100 / total))
    local filled=$((percent * width / 100))
    local empty=$((width - filled))

    printf "\r${C_CYAN}${message}${C_RESET} ["
    printf "%${filled}s" | tr ' ' '='
    printf "%${empty}s" | tr ' ' ' '
    printf "] %3d%%" "$percent"
}

display_banner() {
    clear_screen
    cat << "EOF"
${C_CYAN}${C_BOLD}
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   ██████╗ ███████╗ ██████╗ ███╗   ██╗                       ║
║   ██╔══██╗██╔════╝██╔═══██╗████╗  ██║                       ║
║   ██████╔╝█████╗  ██║   ██║██╔██╗ ██║                       ║
║   ██╔══██╗██╔══╝  ██║   ██║██║╚██╗██║                       ║
║   ██║  ██║███████╗╚██████╔╝██║ ╚████║                       ║
║   ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═╝  ╚═══╝                       ║
║                                                               ║
║   ██████╗ ███████╗██╗   ██╗                                 ║
║   ██╔══██╗██╔════╝██║   ██║                                 ║
║   ██║  ██║█████╗  ██║   ██║                                 ║
║   ██║  ██║██╔══╝  ╚██╗ ██╔╝                                 ║
║   ██████╔╝███████╗ ╚████╔╝                                  ║
║   ╚═════╝ ╚══════╝  ╚═══╝                                   ║
║                                                               ║
║         ${C_WHITE}INSTALLER v3.0 - Made By ReonDev${C_CYAN}         ║
╚═══════════════════════════════════════════════════════════════╝
${C_RESET}
EOF
}

show_main_menu() {
    display_banner

    echo -e "${C_BOLD}${C_CYAN}════════════════════════════════════════════════════════════════${C_RESET}"
    echo -e "${C_BOLD}                         MAIN MENU${C_RESET}"
    echo -e "${C_BOLD}${C_CYAN}════════════════════════════════════════════════════════════════${C_RESET}\n"

    echo -e " ${C_GREEN}1.${C_RESET} VPS Manager         ${C_BLUE}11.${C_RESET} Monitoring"
    echo -e " ${C_GREEN}2.${C_RESET} Pterodactyl Panel  ${C_BLUE}12.${C_RESET} Network Tools"
    echo -e " ${C_GREEN}3.${C_RESET} Wings Manager      ${C_BLUE}13.${C_RESET} Security"
    echo -e " ${C_GREEN}4.${C_RESET} Docker Manager     ${C_BLUE}14.${C_RESET} Backups"
    echo -e " ${C_GREEN}5.${C_RESET} Node.js Manager    ${C_BLUE}15.${C_RESET} User Manager"
    echo -e " ${C_GREEN}6.${C_RESET} VM Manager         ${C_BLUE}16.${C_RESET} Service Manager"
    echo -e " ${C_GREEN}7.${C_RESET} LXC Manager        ${C_BLUE}17.${C_RESET} File Manager"
    echo -e " ${C_GREEN}8.${C_RESET} QEMU Manager       ${C_BLUE}18.${C_RESET} Git Manager"
    echo -e " ${C_GREEN}9.${C_RESET} Database Manager   ${C_BLUE}19.${C_RESET} Developer Tools"
    echo -e " ${C_GREEN}10.${C_RESET} Web Server        ${C_BLUE}20.${C_RESET} Settings\n"

    echo -e " ${C_YELLOW}21.${C_RESET} Update Installer   ${C_YELLOW}22.${C_RESET} About"
    echo -e " ${C_RED}0.${C_RESET} Exit\n"

    echo -e "${C_BOLD}${C_CYAN}════════════════════════════════════════════════════════════════${C_RESET}"
    
    # Safely get OS info with defaults
    local os_info_line=$(get_os_info)
    IFS='|' read -r os_name os_version os_codename <<< "$os_info_line"
    local hostname=$(hostname 2>/dev/null || echo "unknown")
    
    echo -e "${C_DIM}System: ${os_name:-unknown} ${os_version:-unknown} | Host: $hostname | ${REON_NAME} v${REON_VERSION}${C_RESET}"
    echo -e "${C_BOLD}${C_CYAN}════════════════════════════════════════════════════════════════${C_RESET}"
}

# ============================================================
# VPS Manager (FIXED)
# ============================================================

vps_manager() {
    clear_screen
    print_header "VPS Manager - System Information"

    echo -e "${C_BOLD}${C_CYAN}System Information${C_RESET}"
    echo -e "─────────────────────────────────────────────────────────────"

    # OS Info with safe handling
    local os_info_line=$(get_os_info)
    IFS='|' read -r os_name os_version os_codename <<< "$os_info_line"
    echo -e "${C_BOLD}OS:${C_RESET} ${os_name:-unknown} ${os_version:-unknown} (${os_codename:-unknown})"

    # CPU Info
    local cpu_info=($(get_cpu_info))
    echo -e "${C_BOLD}CPU:${C_RESET} ${cpu_info[0]:-unknown}"
    echo -e "${C_BOLD}CPU Cores:${C_RESET} ${cpu_info[1]:-0}"
    echo -e "${C_BOLD}Architecture:${C_RESET} ${cpu_info[2]:-unknown}"

    # Memory Info
    local mem_info=($(get_memory_info))
    echo -e "${C_BOLD}Memory (RAM):${C_RESET} ${mem_info[1]:-0}GB total (${mem_info[3]:-0}GB free)"
    echo -e "${C_BOLD}Swap:${C_RESET} ${mem_info[4]:-0}MB"

    # Disk Info
    local disk_info=($(get_disk_info))
    echo -e "${C_BOLD}Disk:${C_RESET} ${disk_info[0]:-0}GB total (${disk_info[2]:-0}GB free, ${disk_info[3]:-0}% used)"

    # Network Info
    local net_info=($(get_network_info))
    echo -e "${C_BOLD}Public IP:${C_RESET} ${net_info[0]:-Unknown}"
    echo -e "${C_BOLD}Private IP:${C_RESET} ${net_info[1]:-Unknown}"
    echo -e "${C_BOLD}Hostname:${C_RESET} ${net_info[2]:-unknown}"

    # Virtualization
    echo -e "${C_BOLD}Virtualization:${C_RESET} $(get_virtualization_info 2>/dev/null || echo "unknown")"

    # Load and Uptime
    echo -e "${C_BOLD}Load Average:${C_RESET} $(get_load_average 2>/dev/null || echo "unknown")"
    echo -e "${C_BOLD}Uptime:${C_RESET} $(get_uptime 2>/dev/null || echo "unknown")"

    echo -e "─────────────────────────────────────────────────────────────"

    # Health Status
    echo -e "\n${C_BOLD}${C_GREEN}System Health:${C_RESET}"

    # Check CPU load (with safe handling)
    local load_avg=$(uptime 2>/dev/null | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | sed 's/^[ \t]*//' || echo "0")
    local cpu_cores=$(grep -c "^processor" /proc/cpuinfo 2>/dev/null || echo "1")
    local load_percent=$(echo "scale=2; ($load_avg / $cpu_cores) * 100" | bc 2>/dev/null || echo "0")
    if [[ -n "$load_percent" ]] && (( $(echo "$load_percent > 80" | bc -l 2>/dev/null || echo "0") )); then
        echo -e "  ${C_YELLOW}⚠${C_RESET} CPU: High load (${load_percent}%)"
    else
        echo -e "  ${C_GREEN}✓${C_RESET} CPU: Normal (${load_percent}%)"
    fi

    # Check memory (with safe handling)
    local total_ram=${mem_info[0]:-0}
    local free_ram=${mem_info[2]:-0}
    if [[ $total_ram -gt 0 ]]; then
        local used_percent=$(( (total_ram - free_ram) * 100 / total_ram ))
        if (( used_percent > 90 )); then
            echo -e "  ${C_YELLOW}⚠${C_RESET} Memory: High usage (${used_percent}%)"
        else
            echo -e "  ${C_GREEN}✓${C_RESET} Memory: Normal (${used_percent}%)"
        fi
    else
        echo -e "  ${C_YELLOW}⚠${C_RESET} Memory: Unable to determine"
    fi

    # Check disk
    local disk_percent=${disk_info[3]:-0}
    if (( disk_percent > 90 )); then
        echo -e "  ${C_YELLOW}⚠${C_RESET} Disk: High usage (${disk_percent}%)"
    else
        echo -e "  ${C_GREEN}✓${C_RESET} Disk: Normal (${disk_percent}%)"
    fi

    # Internet
    if ping -c 1 -W 2 8.8.8.8 &> /dev/null; then
        echo -e "  ${C_GREEN}✓${C_RESET} Internet: Connected"
    else
        echo -e "  ${C_YELLOW}⚠${C_RESET} Internet: No connectivity"
    fi

    echo
    read -p "$(print_question "Press Enter to continue...")"
}

# ============================================================
# Rest of the script (VM Manager, Docker, Node.js, etc.)
# ============================================================

# ... (keep all other functions from the original script, 
#      but add safe handling with || echo "0" or || echo "unknown" 
#      where needed)

# ============================================================
# Main Entry Point
# ============================================================

main() {
    # Create directories
    mkdir -p "$REON_INSTALL_DIR" "$REON_CONFIG_DIR" "$REON_LOGS_DIR" "$REON_BACKUPS_DIR" "$REON_VM_DIR"

    # Log start
    log_action "Start" "REON DEV INSTALLER v3 started"

    # Check for root/sudo
    if [[ $EUID -ne 0 ]]; then
        print_warning "Some features may require root privileges"
    fi

    # Check command line arguments
    case "${1:-}" in
        --help|-h)
            echo "REON DEV INSTALLER v3 - Professional Linux VPS Management Platform"
            echo "Made By ReonDev"
            echo ""
            echo "Usage:"
            echo "  ./vm.sh              Start interactive menu"
            echo "  ./vm.sh --help       Show this help"
            echo "  ./vm.sh --version    Show version"
            exit 0
            ;;
        --version|-v)
            echo "REON DEV INSTALLER v3.0.0"
            echo "Made By ReonDev"
            exit 0
            ;;
    esac

    # Start main menu
    main_menu
}

# Run main
main "$@"
