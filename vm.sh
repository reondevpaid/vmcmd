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
REON_INSTALL_DIR="${REON_INSTALL_DIR:-/opt/reon-dev-installer}"
REON_CONFIG_DIR="$REON_INSTALL_DIR/config"
REON_LOGS_DIR="$REON_INSTALL_DIR/logs"
REON_BACKUPS_DIR="$REON_INSTALL_DIR/backups"
REON_VM_DIR="$REON_INSTALL_DIR/vms"
REON_TEMP_DIR="/tmp/reon-installer"

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
readonly C_UNDERLINE='\033[4m'
readonly C_BLINK='\033[5m'

# Icons
readonly ICON_SUCCESS="✓"
readonly ICON_ERROR="✗"
readonly ICON_WARNING="⚠"
readonly ICON_INFO="ℹ"
readonly ICON_QUESTION="?"
readonly ICON_STAR="★"
readonly ICON_ARROW="→"
readonly ICON_CHECK="✔"
readonly ICON_CROSS="✘"
readonly ICON_CLOCK="⌛"
readonly ICON_GEAR="⚙"
readonly ICON_DISK="💾"
readonly ICON_NETWORK="🌐"
readonly ICON_CPU="💻"
readonly ICON_MEMORY="🧠"
readonly ICON_DATABASE="🗄️"
readonly ICON_DOCKER="🐳"
readonly ICON_NODE="📦"
readonly ICON_SECURITY="🔒"
readonly ICON_BACKUP="📀"

# Log levels
LOG_LEVEL="${REON_LOG_LEVEL:-INFO}"
declare -A LOG_LEVELS=(
    ["DEBUG"]=0
    ["INFO"]=1
    ["WARN"]=2
    ["ERROR"]=3
    ["FATAL"]=4
)

# Terminal detection
if [[ -t 1 ]]; then
    TERMINAL_WIDTH=$(tput cols 2>/dev/null || echo 80)
    TERMINAL_HEIGHT=$(tput lines 2>/dev/null || echo 24)
else
    TERMINAL_WIDTH=80
    TERMINAL_HEIGHT=24
fi

# ============================================================
# Signal Handlers
# ============================================================

trap 'cleanup_temp; exit 130' INT TERM
trap 'cleanup_temp' EXIT

cleanup_temp() {
    [[ -d "$REON_TEMP_DIR" ]] && rm -rf "$REON_TEMP_DIR"
}

# ============================================================
# Core Functions
# ============================================================

print_color() {
    local color=$1
    local message=$2
    local bold=${3:-false}
    local underline=${4:-false}
    local output=""
    
    [[ "$bold" == "true" ]] && output+="${C_BOLD}"
    [[ "$underline" == "true" ]] && output+="${C_UNDERLINE}"
    output+="${color}${message}${C_RESET}"
    echo -e "$output"
}

print_success() { echo -e "${C_GREEN}${ICON_SUCCESS}${C_RESET} $1"; }
print_error() { echo -e "${C_RED}${ICON_ERROR}${C_RESET} $1" >&2; }
print_warning() { echo -e "${C_YELLOW}${ICON_WARNING}${C_RESET} $1"; }
print_info() { echo -e "${C_CYAN}${ICON_INFO}${C_RESET} $1"; }
print_question() { echo -e "${C_MAGENTA}${ICON_QUESTION}${C_RESET} $1"; }
print_header() { echo -e "\n${C_BOLD}${C_CYAN}═══ $1 ═══${C_RESET}\n"; }
print_subheader() { echo -e "${C_BOLD}${C_BLUE}─── $1 ───${C_RESET}"; }
print_divider() { echo -e "${C_DIM}$(printf '═%.0s' $(seq 1 ${TERMINAL_WIDTH}))${C_RESET}"; }
print_centered() { 
    local text="$1"
    local padding=$(( (TERMINAL_WIDTH - ${#text}) / 2 ))
    printf "%${padding}s%s\n" "" "$text"
}

# ============================================================
# Logging Functions
# ============================================================

log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="[$timestamp] [$level] $message"
    local log_file="${REON_LOGS_DIR}/actions.log"
    
    mkdir -p "$REON_LOGS_DIR"
    echo "$log_entry" >> "$log_file"
    
    if [[ "$level" == "ERROR" ]] || [[ "$level" == "FATAL" ]]; then
        echo "$log_entry" >> "${REON_LOGS_DIR}/errors.log"
    fi
    
    # Rotate logs if too large (10MB)
    if [[ -f "$log_file" ]] && [[ $(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo 0) -gt 10485760 ]]; then
        mv "$log_file" "${log_file}.old"
    fi
}

log_debug() { 
    [[ "${LOG_LEVELS[$LOG_LEVEL]}" -le 0 ]] && log_message "DEBUG" "$1"
}
log_info() { 
    [[ "${LOG_LEVELS[$LOG_LEVEL]}" -le 1 ]] && log_message "INFO" "$1"
}
log_warn() { 
    [[ "${LOG_LEVELS[$LOG_LEVEL]}" -le 2 ]] && log_message "WARN" "$1"
}
log_error() { 
    [[ "${LOG_LEVELS[$LOG_LEVEL]}" -le 3 ]] && log_message "ERROR" "$1"
}
log_fatal() { 
    [[ "${LOG_LEVELS[$LOG_LEVEL]}" -le 4 ]] && log_message "FATAL" "$1"
}
log_action() { log_message "ACTION" "$1 - $2"; }

# ============================================================
# System Information Functions (Robust)
# ============================================================

get_os_info() {
    local os_name="unknown"
    local os_version="unknown"
    local os_codename="unknown"
    
    if [[ -f /etc/os-release ]]; then
        # Source safely without polluting environment
        while IFS='=' read -r key value; do
            case "$key" in
                "ID") os_name="${value//\"/}" ;;
                "VERSION_ID") os_version="${value//\"/}" ;;
                "VERSION_CODENAME") os_codename="${value//\"/}" ;;
            esac
        done < /etc/os-release
    elif [[ -f /etc/debian_version ]]; then
        os_name="debian"
        os_version=$(cat /etc/debian_version 2>/dev/null || echo "unknown")
    elif [[ -f /etc/redhat-release ]]; then
        os_name="rhel"
        os_version=$(cat /etc/redhat-release 2>/dev/null | sed 's/.*release \([0-9.]*\).*/\1/' || echo "unknown")
    fi
    
    # Ensure we have values
    [[ -z "$os_name" ]] && os_name="unknown"
    [[ -z "$os_version" ]] && os_version="unknown"
    [[ -z "$os_codename" ]] && os_codename="unknown"
    
    echo "$os_name|$os_version|$os_codename"
}

get_cpu_info() {
    local model="unknown"
    local cores="0"
    local arch="unknown"
    
    if [[ -f /proc/cpuinfo ]]; then
        model=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^[ \t]*//' || echo "unknown")
        cores=$(grep -c "^processor" /proc/cpuinfo 2>/dev/null || echo "0")
    fi
    arch=$(uname -m 2>/dev/null || echo "unknown")
    
    echo "$model|$cores|$arch"
}

get_memory_info() {
    local total=0 total_mb=0 total_gb=0
    local free=0 free_mb=0 free_gb=0
    local swap=0 swap_mb=0
    
    if [[ -f /proc/meminfo ]]; then
        total=$(grep "^MemTotal" /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")
        free=$(grep "^MemFree" /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")
        swap=$(grep "^SwapTotal" /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")
    fi
    
    total_mb=$((total / 1024))
    total_gb=$(echo "scale=2; $total / 1048576" | bc 2>/dev/null || echo "0")
    free_mb=$((free / 1024))
    free_gb=$(echo "scale=2; $free / 1048576" | bc 2>/dev/null || echo "0")
    swap_mb=$((swap / 1024))
    
    echo "$total_mb|$total_gb|$free_mb|$free_gb|$swap_mb"
}

get_disk_info() {
    local total=0 used=0 free=0 percent=0
    
    if command -v df &> /dev/null; then
        total=$(df -BG / 2>/dev/null | awk 'NR==2 {print $2}' | sed 's/G//' || echo "0")
        used=$(df -BG / 2>/dev/null | awk 'NR==2 {print $3}' | sed 's/G//' || echo "0")
        free=$(df -BG / 2>/dev/null | awk 'NR==2 {print $4}' | sed 's/G//' || echo "0")
        percent=$(df -BG / 2>/dev/null | awk 'NR==2 {print $5}' | sed 's/%//' || echo "0")
    fi
    
    echo "$total|$used|$free|$percent"
}

get_network_info() {
    local public_ip="Unknown"
    local private_ip="Unknown"
    local hostname="unknown"
    local interfaces=0
    
    # Get public IP with fallbacks
    for url in "https://api.ipify.org" "https://icanhazip.com" "https://ifconfig.me/ip"; do
        public_ip=$(curl -s --max-time 3 "$url" 2>/dev/null | head -n1 || echo "")
        [[ -n "$public_ip" ]] && [[ "$public_ip" != "Unknown" ]] && break
    done
    [[ -z "$public_ip" ]] && public_ip="Unknown"
    
    # Get private IP
    if command -v ip &> /dev/null; then
        private_ip=$(ip -4 addr show 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v "127.0.0.1" | head -n1 || echo "Unknown")
        interfaces=$(ip -br link show 2>/dev/null | grep -v "lo" | wc -l || echo "0")
    fi
    [[ -z "$private_ip" ]] && private_ip="Unknown"
    
    hostname=$(hostname 2>/dev/null || echo "unknown")
    
    echo "$public_ip|$private_ip|$hostname|$interfaces"
}

get_virtualization_info() {
    local virt="physical"
    
    if command -v systemd-detect-virt &> /dev/null; then
        virt=$(systemd-detect-virt 2>/dev/null || echo "physical")
    elif [[ -f /proc/cpuinfo ]]; then
        if grep -q "hypervisor" /proc/cpuinfo 2>/dev/null; then
            if grep -q "QEMU" /proc/cpuinfo 2>/dev/null; then
                virt="qemu"
            elif grep -q "VMware" /proc/cpuinfo 2>/dev/null; then
                virt="vmware"
            elif grep -q "VirtualBox" /proc/cpuinfo 2>/dev/null; then
                virt="virtualbox"
            else
                virt="kvm"
            fi
        fi
    fi
    
    echo "$virt"
}

get_load_average() {
    local load="0.00 0.00 0.00"
    if [[ -f /proc/loadavg ]]; then
        load=$(cat /proc/loadavg 2>/dev/null | awk '{print $1" "$2" "$3}' || echo "0.00 0.00 0.00")
    fi
    echo "$load"
}

get_uptime() {
    local uptime="unknown"
    if command -v uptime &> /dev/null; then
        uptime=$(uptime -p 2>/dev/null | sed 's/up //' || echo "unknown")
    fi
    echo "$uptime"
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
    
    if [[ $total -eq 0 ]]; then
        printf "\r${C_CYAN}${message}${C_RESET} ${ICON_CLOCK}"
        return
    fi
    
    local percent=$((current * 100 / total))
    local filled=$((percent * width / 100))
    local empty=$((width - filled))
    
    printf "\r${C_CYAN}${message}${C_RESET} ["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] %3d%%" "$percent"
}

show_spinner() {
    local pid=$1
    local message=${2:-"Loading..."}
    local spin=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${C_CYAN}${spin[$i]}${C_RESET} ${message}"
        i=$(((i + 1) % 10))
        sleep 0.1
    done
    printf "\r${C_GREEN}${ICON_SUCCESS}${C_RESET} ${message}\n"
}

display_banner() {
    clear_screen
    cat << "EOF"
${C_CYAN}${C_BOLD}
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║   ██████╗ ███████╗ ██████╗ ███╗   ██╗                           ║
║   ██╔══██╗██╔════╝██╔═══██╗████╗  ██║                           ║
║   ██████╔╝█████╗  ██║   ██║██╔██╗ ██║                           ║
║   ██╔══██╗██╔══╝  ██║   ██║██║╚██╗██║                           ║
║   ██║  ██║███████╗╚██████╔╝██║ ╚████║                           ║
║   ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═╝  ╚═══╝                           ║
║                                                                   ║
║   ██████╗ ███████╗██╗   ██╗                                     ║
║   ██╔══██╗██╔════╝██║   ██║                                     ║
║   ██║  ██║█████╗  ██║   ██║                                     ║
║   ██║  ██║██╔══╝  ╚██╗ ██╔╝                                     ║
║   ██████╔╝███████╗ ╚████╔╝                                      ║
║   ╚═════╝ ╚══════╝  ╚═══╝                                       ║
║                                                                   ║
║         ${C_WHITE}INSTALLER v3.0 - Made By ReonDev${C_CYAN}             ║
╚═══════════════════════════════════════════════════════════════════╝
${C_RESET}
EOF
}

show_header() {
    display_banner
    echo
    print_divider
    echo -e "${C_BOLD}${C_CYAN}$(printf ' %-*s' $((TERMINAL_WIDTH - 2)) "${REON_NAME} v${REON_VERSION}")${C_RESET}"
    print_divider
}

show_main_menu() {
    show_header
    
    echo -e "\n${C_BOLD}${C_WHITE}${ICON_STAR} MAIN MENU ${C_RESET}\n"
    
    # Two-column layout
    local menu_items=(
        "1:VPS Manager:VPS Manager - System Information"
        "2:Pterodactyl Panel:Pterodactyl Panel Management"
        "3:Wings Manager:Wings Manager"
        "4:Docker Manager:Docker Manager"
        "5:Node.js Manager:Node.js Manager"
        "6:VM Manager:VM Manager"
        "7:LXC Manager:LXC Manager"
        "8:QEMU Manager:QEMU Manager"
        "9:Database Manager:Database Manager"
        "10:Web Server:Web Server Manager"
        "11:Monitoring:Monitoring"
        "12:Network Tools:Network Tools"
        "13:Security:Security Manager"
        "14:Backups:Backup Manager"
        "15:User Manager:User Manager"
        "16:Service Manager:Service Manager"
        "17:File Manager:File Manager"
        "18:Git Manager:Git Manager"
        "19:Developer Tools:Developer Tools"
        "20:Settings:Settings"
        "21:Update Installer:Update Installer"
        "22:About:About"
        "0:Exit:Exit"
    )
    
    local col1=()
    local col2=()
    local half=$(( (${#menu_items[@]} + 1) / 2 ))
    
    for i in "${!menu_items[@]}"; do
        if [[ $i -lt $half ]]; then
            col1+=("${menu_items[$i]}")
        else
            col2+=("${menu_items[$i]}")
        fi
    done
    
    # Print two columns
    local max_len=0
    for item in "${col1[@]}"; do
        local label=$(echo "$item" | cut -d: -f1-2 | tr ':' ' ')
        local len=${#label}
        [[ $len -gt $max_len ]] && max_len=$len
    done
    
    for ((i=0; i<${#col1[@]}; i++)); do
        local item1="${col1[$i]}"
        local item2="${col2[$i]:-}"
        
        local num1=$(echo "$item1" | cut -d: -f1)
        local name1=$(echo "$item1" | cut -d: -f2)
        local desc1=$(echo "$item1" | cut -d: -f3)
        
        local output=" ${C_GREEN}${num1}.${C_RESET} ${name1}"
        if [[ -n "$item2" ]]; then
            local num2=$(echo "$item2" | cut -d: -f1)
            local name2=$(echo "$item2" | cut -d: -f2)
            local desc2=$(echo "$item2" | cut -d: -f3)
            printf "%-35s %s\n" "$output" " ${C_GREEN}${num2}.${C_RESET} ${name2}"
        else
            echo "$output"
        fi
    done
    
    echo
    print_divider
    
    # System info bar
    local os_info=$(get_os_info)
    IFS='|' read -r os_name os_version os_codename <<< "$os_info"
    local hostname=$(hostname 2>/dev/null || echo "unknown")
    local load_avg=$(get_load_average)
    
    echo -e "${C_DIM}System: ${os_name} ${os_version} | Host: ${hostname} | Load: ${load_avg} | ${REON_NAME} v${REON_VERSION}${C_RESET}"
    print_divider
}

# ============================================================
# Input Functions
# ============================================================

get_input() {
    local prompt=$1
    local default=${2:-""}
    local required=${3:-false}
    local input
    
    while true; do
        if [[ -n "$default" ]]; then
            read -p "$(print_question "$prompt [$default]: ")" input
            input="${input:-$default}"
        else
            read -p "$(print_question "$prompt: ")" input
        fi
        
        if [[ -n "$input" ]] || [[ "$required" != "true" ]]; then
            echo "$input"
            return 0
        else
            print_error "Input is required"
        fi
    done
}

get_password() {
    local prompt=$1
    local default=${2:-""}
    local input
    
    while true; do
        if [[ -n "$default" ]]; then
            read -s -p "$(print_question "$prompt [hidden]: ")" input
            input="${input:-$default}"
        else
            read -s -p "$(print_question "$prompt: ")" input
        fi
        echo
        if [[ -n "$input" ]]; then
            echo "$input"
            return 0
        else
            print_error "Password cannot be empty"
        fi
    done
}

confirm_action() {
    local message=${1:-"Are you sure?"}
    local default=${2:-"n"}
    local input
    
    if [[ "$default" == "y" ]]; then
        read -p "$(print_question "$message (Y/n): ")" input
        input="${input:-y}"
    else
        read -p "$(print_question "$message (y/N): ")" input
        input="${input:-n}"
    fi
    
    [[ "$input" =~ ^[Yy]$ ]]
}

select_option() {
    local prompt=$1
    shift
    local options=("$@")
    local choice
    
    for i in "${!options[@]}"; do
        echo "  $((i+1))) ${options[$i]}"
    done
    
    while true; do
        read -p "$(print_question "$prompt [1-${#options[@]}]: ")" choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#options[@]} ]; then
            echo "$((choice-1))"
            return 0
        else
            print_error "Invalid selection"
        fi
    done
}

# ============================================================
# Validation Functions
# ============================================================

validate_input() {
    local type=$1
    local value=$2
    
    case $type in
        "number")
            if ! [[ "$value" =~ ^[0-9]+$ ]]; then
                print_error "Must be a number"
                return 1
            fi
            ;;
        "size")
            if ! [[ "$value" =~ ^[0-9]+[GgMm]$ ]]; then
                print_error "Must be a size with unit (e.g., 100G, 512M)"
                return 1
            fi
            ;;
        "port")
            if ! [[ "$value" =~ ^[0-9]+$ ]] || [ "$value" -lt 23 ] || [ "$value" -gt 65535 ]; then
                print_error "Must be a valid port number (23-65535)"
                return 1
            fi
            ;;
        "name")
            if ! [[ "$value" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                print_error "Name can only contain letters, numbers, hyphens, and underscores"
                return 1
            fi
            ;;
        "email")
            if ! [[ "$value" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
                print_error "Invalid email address"
                return 1
            fi
            ;;
        "domain")
            if ! [[ "$value" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*$ ]]; then
                print_error "Invalid domain name"
                return 1
            fi
            ;;
        "ip")
            if ! [[ "$value" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                print_error "Invalid IP address"
                return 1
            fi
            ;;
        "username")
            if ! [[ "$value" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
                print_error "Username must start with a letter or underscore"
                return 1
            fi
            ;;
    esac
    return 0
}

# ============================================================
# VPS Manager
# ============================================================

vps_manager() {
    clear_screen
    print_header "${ICON_CPU} VPS Manager - System Information"
    
    print_divider
    echo -e "${C_BOLD}${C_CYAN}System Information${C_RESET}"
    print_divider
    
    # OS Info
    local os_info=$(get_os_info)
    IFS='|' read -r os_name os_version os_codename <<< "$os_info"
    echo -e "${C_BOLD}${ICON_INFO} OS:${C_RESET} ${os_name} ${os_version} (${os_codename})"
    
    # CPU Info
    local cpu_info=($(get_cpu_info))
    echo -e "${C_BOLD}${ICON_CPU} CPU:${C_RESET} ${cpu_info[0]}"
    echo -e "${C_BOLD}   Cores:${C_RESET} ${cpu_info[1]}"
    echo -e "${C_BOLD}   Arch:${C_RESET} ${cpu_info[2]}"
    
    # Memory Info
    local mem_info=($(get_memory_info))
    echo -e "${C_BOLD}${ICON_MEMORY} Memory:${C_RESET} ${mem_info[1]}GB total (${mem_info[3]}GB free)"
    echo -e "${C_BOLD}   Swap:${C_RESET} ${mem_info[4]}MB"
    
    # Disk Info
    local disk_info=($(get_disk_info))
    echo -e "${C_BOLD}${ICON_DISK} Disk:${C_RESET} ${disk_info[0]}GB total (${disk_info[2]}GB free, ${disk_info[3]}% used)"
    
    # Network Info
    local net_info=($(get_network_info))
    echo -e "${C_BOLD}${ICON_NETWORK} Network:${C_RESET}"
    echo -e "${C_BOLD}   Public IP:${C_RESET} ${net_info[0]}"
    echo -e "${C_BOLD}   Private IP:${C_RESET} ${net_info[1]}"
    echo -e "${C_BOLD}   Hostname:${C_RESET} ${net_info[2]}"
    echo -e "${C_BOLD}   Interfaces:${C_RESET} ${net_info[3]}"
    
    # Virtualization
    echo -e "${C_BOLD}${ICON_GEAR} Virtualization:${C_RESET} $(get_virtualization_info)"
    
    # Load and Uptime
    echo -e "${C_BOLD}${ICON_CLOCK} Load Average:${C_RESET} $(get_load_average)"
    echo -e "${C_BOLD}${ICON_CLOCK} Uptime:${C_RESET} $(get_uptime)"
    
    print_divider
    
    # Health Status
    echo -e "\n${C_BOLD}${C_GREEN}${ICON_CHECK} System Health${C_RESET}"
    echo -e "${C_DIM}─────────────────────────────────────────────────────────────${C_RESET}"
    
    # Check CPU load
    local load_info=($(get_load_average))
    local load_1min=${load_info[0]:-0}
    local cpu_cores=$(grep -c "^processor" /proc/cpuinfo 2>/dev/null || echo "1")
    local load_percent=$(echo "scale=2; ($load_1min / $cpu_cores) * 100" | bc 2>/dev/null || echo "0")
    
    if (( $(echo "$load_percent > 80" | bc -l 2>/dev/null || echo "0") )); then
        echo -e "  ${C_YELLOW}${ICON_WARNING}${C_RESET} CPU: High load (${load_percent}%)"
    else
        echo -e "  ${C_GREEN}${ICON_SUCCESS}${C_RESET} CPU: Normal (${load_percent}%)"
    fi
    
    # Check memory
    local total_ram=${mem_info[0]:-0}
    local free_ram=${mem_info[2]:-0}
    if [[ $total_ram -gt 0 ]]; then
        local used_percent=$(( (total_ram - free_ram) * 100 / total_ram ))
        if (( used_percent > 90 )); then
            echo -e "  ${C_YELLOW}${ICON_WARNING}${C_RESET} Memory: High usage (${used_percent}%)"
        elif (( used_percent > 75 )); then
            echo -e "  ${C_YELLOW}${ICON_WARNING}${C_RESET} Memory: Elevated usage (${used_percent}%)"
        else
            echo -e "  ${C_GREEN}${ICON_SUCCESS}${C_RESET} Memory: Normal (${used_percent}%)"
        fi
    else
        echo -e "  ${C_YELLOW}${ICON_WARNING}${C_RESET} Memory: Unable to determine"
    fi
    
    # Check disk
    local disk_percent=${disk_info[3]:-0}
    if (( disk_percent > 90 )); then
        echo -e "  ${C_RED}${ICON_ERROR}${C_RESET} Disk: Critical usage (${disk_percent}%)"
    elif (( disk_percent > 80 )); then
        echo -e "  ${C_YELLOW}${ICON_WARNING}${C_RESET} Disk: High usage (${disk_percent}%)"
    else
        echo -e "  ${C_GREEN}${ICON_SUCCESS}${C_RESET} Disk: Normal (${disk_percent}%)"
    fi
    
    # Internet
    if ping -c 1 -W 2 8.8.8.8 &> /dev/null; then
        echo -e "  ${C_GREEN}${ICON_SUCCESS}${C_RESET} Internet: Connected"
    else
        echo -e "  ${C_YELLOW}${ICON_WARNING}${C_RESET} Internet: No connectivity"
    fi
    
    # Running processes
    local processes=$(ps aux 2>/dev/null | wc -l || echo "0")
    echo -e "  ${C_GREEN}${ICON_SUCCESS}${C_RESET} Processes: ${processes} running"
    
    echo
    read -p "$(print_question "Press Enter to continue...")"
}

# ============================================================
# VM Manager
# ============================================================

get_vm_list() {
    find "$REON_VM_DIR" -name "*.conf" -exec basename {} .conf \; 2>/dev/null | sort
}

load_vm_config() {
    local vm_name=$1
    local config_file="$REON_VM_DIR/$vm_name.conf"
    
    if [[ -f "$config_file" ]]; then
        # Source safely
        while IFS='=' read -r key value; do
            [[ -z "$key" ]] && continue
            key=$(echo "$key" | tr -d ' ')
            value=$(echo "$value" | sed 's/^"//;s/"$//')
            case "$key" in
                VM_NAME) VM_NAME="$value" ;;
                OS_TYPE) OS_TYPE="$value" ;;
                CODENAME) CODENAME="$value" ;;
                IMG_URL) IMG_URL="$value" ;;
                HOSTNAME) HOSTNAME="$value" ;;
                USERNAME) USERNAME="$value" ;;
                PASSWORD) PASSWORD="$value" ;;
                DISK_SIZE) DISK_SIZE="$value" ;;
                MEMORY) MEMORY="$value" ;;
                CPUS) CPUS="$value" ;;
                SSH_PORT) SSH_PORT="$value" ;;
                GUI_MODE) GUI_MODE="$value" ;;
                PORT_FORWARDS) PORT_FORWARDS="$value" ;;
                IMG_FILE) IMG_FILE="$value" ;;
                SEED_FILE) SEED_FILE="$value" ;;
                CREATED) CREATED="$value" ;;
            esac
        done < "$config_file"
        return 0
    else
        print_error "Configuration for VM '$vm_name' not found"
        return 1
    fi
}

save_vm_config() {
    local config_file="$REON_VM_DIR/$VM_NAME.conf"
    mkdir -p "$REON_VM_DIR"
    
    cat > "$config_file" <<EOF
VM_NAME="$VM_NAME"
OS_TYPE="$OS_TYPE"
CODENAME="$CODENAME"
IMG_URL="$IMG_URL"
HOSTNAME="$HOSTNAME"
USERNAME="$USERNAME"
PASSWORD="$PASSWORD"
DISK_SIZE="$DISK_SIZE"
MEMORY="$MEMORY"
CPUS="$CPUS"
SSH_PORT="$SSH_PORT"
GUI_MODE="$GUI_MODE"
PORT_FORWARDS="$PORT_FORWARDS"
IMG_FILE="$IMG_FILE"
SEED_FILE="$SEED_FILE"
CREATED="$CREATED"
EOF
    
    print_success "Configuration saved to $config_file"
}

setup_vm_image() {
    print_info "Setting up VM image..."
    
    mkdir -p "$REON_VM_DIR"
    mkdir -p "$REON_TEMP_DIR"
    
    if [[ -f "$IMG_FILE" ]]; then
        print_info "Image file already exists. Skipping download."
    else
        print_info "Downloading image from $IMG_URL..."
        if ! wget --progress=bar:force "$IMG_URL" -O "$IMG_FILE.tmp" 2>/dev/null; then
            print_error "Failed to download image"
            return 1
        fi
        mv "$IMG_FILE.tmp" "$IMG_FILE"
    fi
    
    # Resize disk
    if command -v qemu-img &> /dev/null; then
        if ! qemu-img resize "$IMG_FILE" "$DISK_SIZE" 2>/dev/null; then
            print_warning "Failed to resize disk. Creating new image..."
            rm -f "$IMG_FILE"
            qemu-img create -f qcow2 "$IMG_FILE" "$DISK_SIZE"
        fi
    else
        print_warning "qemu-img not found, skipping resize"
    fi
    
    # Cloud-init configuration
    cat > "$REON_TEMP_DIR/user-data" <<EOF
#cloud-config
hostname: $HOSTNAME
ssh_pwauth: true
disable_root: false
users:
  - name: $USERNAME
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    password: $(openssl passwd -6 "$PASSWORD" 2>/dev/null | tr -d '\n' || echo "$PASSWORD")
chpasswd:
  list: |
    root:$PASSWORD
    $USERNAME:$PASSWORD
  expire: false
EOF

    cat > "$REON_TEMP_DIR/meta-data" <<EOF
instance-id: iid-$VM_NAME
local-hostname: $HOSTNAME
EOF

    if command -v cloud-localds &> /dev/null; then
        cloud-localds "$SEED_FILE" "$REON_TEMP_DIR/user-data" "$REON_TEMP_DIR/meta-data" 2>/dev/null
    else
        print_warning "cloud-localds not found, skipping seed file creation"
    fi
    
    rm -rf "$REON_TEMP_DIR"
    print_success "VM image setup complete"
}

create_vm() {
    clear_screen
    print_header "${ICON_GEAR} Create New VM"
    
    # OS Selection
    print_info "Select OS:"
    declare -A OS_OPTIONS=(
        ["Ubuntu 22.04 LTS"]="ubuntu|jammy|https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img|ubuntu22|ubuntu|ubuntu"
        ["Ubuntu 24.04 LTS"]="ubuntu|noble|https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img|ubuntu24|ubuntu|ubuntu"
        ["Debian 12"]="debian|bookworm|https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2|debian12|debian|debian"
        ["Rocky Linux 9"]="rockylinux|9|https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2|rocky9|rocky|rocky"
        ["AlmaLinux 9"]="almalinux|9|https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2|alma9|alma|alma"
        ["Fedora 40"]="fedora|40|https://download.fedoraproject.org/pub/fedora/linux/releases/40/Cloud/x86_64/images/Fedora-Cloud-Base-40-1.14.x86_64.qcow2|fedora40|fedora|fedora"
    )
    
    local os_options=()
    local i=1
    for os in "${!OS_OPTIONS[@]}"; do
        echo "  $i) $os"
        os_options[$i]="$os"
        ((i++))
    done
    
    while true; do
        read -p "$(print_question "Select OS (1-${#OS_OPTIONS[@]}): ")" choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#OS_OPTIONS[@]} ]; then
            local os="${os_options[$choice]}"
            IFS='|' read -r OS_TYPE CODENAME IMG_URL DEFAULT_HOSTNAME DEFAULT_USERNAME DEFAULT_PASSWORD <<< "${OS_OPTIONS[$os]}"
            break
        else
            print_error "Invalid selection"
        fi
    done
    
    echo
    print_divider
    echo -e "${C_CYAN}${ICON_INFO} Selected: ${C_WHITE}${os}${C_RESET}"
    print_divider
    
    # VM Name
    while true; do
        read -p "$(print_question "Enter VM name (default: $DEFAULT_HOSTNAME): ")" VM_NAME
        VM_NAME="${VM_NAME:-$DEFAULT_HOSTNAME}"
        if validate_input "name" "$VM_NAME"; then
            if [[ -f "$REON_VM_DIR/$VM_NAME.conf" ]]; then
                print_error "VM '$VM_NAME' already exists"
            else
                break
            fi
        fi
    done
    
    # Hostname
    read -p "$(print_question "Enter hostname (default: $VM_NAME): ")" HOSTNAME
    HOSTNAME="${HOSTNAME:-$VM_NAME}"
    
    # Username
    read -p "$(print_question "Enter username (default: $DEFAULT_USERNAME): ")" USERNAME
    USERNAME="${USERNAME:-$DEFAULT_USERNAME}"
    
    # Password
    PASSWORD=$(get_password "Enter password (default: $DEFAULT_PASSWORD)" "$DEFAULT_PASSWORD")
    
    # Resources
    echo
    print_subheader "Resources"
    read -p "$(print_question "Disk size (default: 20G): ")" DISK_SIZE
    DISK_SIZE="${DISK_SIZE:-20G}"
    
    read -p "$(print_question "Memory in MB (default: 2048): ")" MEMORY
    MEMORY="${MEMORY:-2048}"
    
    read -p "$(print_question "Number of CPUs (default: 2): ")" CPUS
    CPUS="${CPUS:-2}"
    
    # Network
    echo
    print_subheader "Network"
    read -p "$(print_question "SSH Port (default: 2222): ")" SSH_PORT
    SSH_PORT="${SSH_PORT:-2222}"
    
    read -p "$(print_question "Enable GUI mode? (y/n, default: n): ")" gui_input
    GUI_MODE=false
    [[ "$gui_input" =~ ^[Yy]$ ]] && GUI_MODE=true
    
    read -p "$(print_question "Additional port forwards (e.g., 8080:80): ")" PORT_FORWARDS
    
    IMG_FILE="$REON_VM_DIR/$VM_NAME.img"
    SEED_FILE="$REON_VM_DIR/$VM_NAME-seed.iso"
    CREATED="$(date)"
    
    echo
    print_divider
    echo -e "${C_CYAN}${ICON_INFO} Summary:${C_RESET}"
    echo -e "  Name: ${C_WHITE}$VM_NAME${C_RESET}"
    echo -e "  OS: ${C_WHITE}$OS_TYPE${C_RESET}"
    echo -e "  Memory: ${C_WHITE}${MEMORY}MB${C_RESET}"
    echo -e "  CPUs: ${C_WHITE}${CPUS}${C_RESET}"
    echo -e "  Disk: ${C_WHITE}${DISK_SIZE}${C_RESET}"
    echo -e "  SSH Port: ${C_WHITE}${SSH_PORT}${C_RESET}"
    print_divider
    
    if confirm_action "Create VM with these settings?"; then
        # Setup VM
        if setup_vm_image; then
            save_vm_config
            print_success "VM '$VM_NAME' created successfully"
            echo
            echo -e "${C_GREEN}${ICON_SUCCESS} SSH: ssh -p $SSH_PORT $USERNAME@localhost${C_RESET}"
            echo -e "${C_YELLOW}${ICON_WARNING} Password: $PASSWORD${C_RESET}"
        fi
    else
        print_info "Creation cancelled"
    fi
    
    read -p "$(print_question "Press Enter to continue...")"
}

delete_vm() {
    local vms=($(get_vm_list))
    if [[ ${#vms[@]} -eq 0 ]]; then
        print_warning "No VMs found"
        read -p "$(print_question "Press Enter to continue...")"
        return
    fi
    
    clear_screen
    print_header "${ICON_ERROR} Delete VM"
    
    echo "Available VMs:"
    for i in "${!vms[@]}"; do
        echo "  $((i+1))) ${vms[$i]}"
    done
    echo
    
    read -p "$(print_question "Select VM to delete: ")" choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#vms[@]} ]; then
        local vm_name="${vms[$((choice-1))]}"
        if confirm_action "Delete VM '$vm_name'?"; then
            if load_vm_config "$vm_name"; then
                rm -f "$IMG_FILE" "$SEED_FILE" "$REON_VM_DIR/$vm_name.conf"
                print_success "VM '$vm_name' deleted"
            fi
        fi
    else
        print_error "Invalid selection"
    fi
    
    read -p "$(print_question "Press Enter to continue...")"
}

start_vm() {
    local vms=($(get_vm_list))
    if [[ ${#vms[@]} -eq 0 ]]; then
        print_warning "No VMs found"
        read -p "$(print_question "Press Enter to continue...")"
        return
    fi
    
    clear_screen
    print_header "${ICON_GEAR} Start VM"
    
    echo "Available VMs:"
    for i in "${!vms[@]}"; do
        echo "  $((i+1))) ${vms[$i]}"
    done
    echo
    
    read -p "$(print_question "Select VM to start: ")" choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#vms[@]} ]; then
        local vm_name="${vms[$((choice-1))]}"
        if load_vm_config "$vm_name"; then
            print_info "Starting VM: $vm_name"
            print_info "SSH: ssh -p $SSH_PORT $USERNAME@localhost"
            
            # Check if image exists
            if [[ ! -f "$IMG_FILE" ]]; then
                print_error "VM image not found: $IMG_FILE"
                read -p "$(print_question "Press Enter to continue...")"
                return
            fi
            
            local qemu_cmd=(
                qemu-system-x86_64
                -enable-kvm
                -m "$MEMORY"
                -smp "$CPUS"
                -cpu host
                -drive "file=$IMG_FILE,format=qcow2,if=virtio"
                -drive "file=$SEED_FILE,format=raw,if=virtio"
                -boot order=c
                -device virtio-net-pci,netdev=n0
                -netdev "user,id=n0,hostfwd=tcp::$SSH_PORT-:22"
            )
            
            # Add port forwards
            if [[ -n "$PORT_FORWARDS" ]]; then
                IFS=',' read -ra forwards <<< "$PORT_FORWARDS"
                local nid=1
                for forward in "${forwards[@]}"; do
                    IFS=':' read -r host_port guest_port <<< "$forward"
                    qemu_cmd+=(-device "virtio-net-pci,netdev=n${nid}")
                    qemu_cmd+=(-netdev "user,id=n${nid},hostfwd=tcp::$host_port-:$guest_port")
                    ((nid++))
                done
            fi
            
            # GUI or console
            if [[ "$GUI_MODE" == true ]]; then
                qemu_cmd+=(-vga virtio -display gtk,gl=on)
            else
                qemu_cmd+=(-nographic -serial mon:stdio)
            fi
            
            # Performance enhancements
            qemu_cmd+=(
                -device virtio-balloon-pci
                -object rng-random,filename=/dev/urandom,id=rng0
                -device virtio-rng-pci,rng=rng0
            )
            
            print_info "Starting QEMU..."
            echo -e "${C_DIM}${ICON_INFO} Press Ctrl+A then X to exit${C_RESET}"
            echo
            "${qemu_cmd[@]}" || true
        fi
    else
        print_error "Invalid selection"
    fi
}

vm_manager() {
    while true; do
        clear_screen
        print_header "${ICON_GEAR} Virtual Machine Manager"
        
        local vms=($(get_vm_list))
        echo -e "${C_BOLD}${C_CYAN}${ICON_INFO} Available VMs:${C_RESET}"
        if [[ ${#vms[@]} -gt 0 ]]; then
            for vm in "${vms[@]}"; do
                echo "  ${C_GREEN}•${C_RESET} $vm"
            done
        else
            echo "  ${C_DIM}No VMs configured${C_RESET}"
        fi
        echo
        
        echo -e " ${C_GREEN}1.${C_RESET} Create VM"
        echo -e " ${C_GREEN}2.${C_RESET} Start VM"
        echo -e " ${C_GREEN}3.${C_RESET} Delete VM"
        echo -e " ${C_GREEN}4.${C_RESET} List VMs"
        echo -e " ${C_GREEN}5.${C_RESET} VM Info"
        echo -e " ${C_RED}0.${C_RESET} Back to Main Menu"
        echo
        
        read -p "$(print_question "Select option: ")" choice
        
        case "$choice" in
            1) create_vm ;;
            2) start_vm ;;
            3) delete_vm ;;
            4) 
                clear_screen
                print_header "VM List"
                if [[ ${#vms[@]} -gt 0 ]]; then
                    for vm in "${vms[@]}"; do
                        echo "  ${C_GREEN}•${C_RESET} $vm"
                        if load_vm_config "$vm" 2>/dev/null; then
                            echo "    ${C_DIM}OS: $OS_TYPE | Memory: ${MEMORY}MB | CPUs: ${CPUS}${C_RESET}"
                        fi
                    done
                else
                    echo "  No VMs configured"
                fi
                echo
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            5)
                if [[ ${#vms[@]} -gt 0 ]]; then
                    echo
                    for i in "${!vms[@]}"; do
                        echo "  $((i+1))) ${vms[$i]}"
                    done
                    echo
                    read -p "$(print_question "Select VM: ")" choice
                    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#vms[@]} ]; then
                        local vm_name="${vms[$((choice-1))]}"
                        if load_vm_config "$vm_name"; then
                            clear_screen
                            print_header "VM Information: $vm_name"
                            echo -e "${C_BOLD}OS:${C_RESET} $OS_TYPE"
                            echo -e "${C_BOLD}Hostname:${C_RESET} $HOSTNAME"
                            echo -e "${C_BOLD}Username:${C_RESET} $USERNAME"
                            echo -e "${C_BOLD}SSH Port:${C_RESET} $SSH_PORT"
                            echo -e "${C_BOLD}Memory:${C_RESET} ${MEMORY}MB"
                            echo -e "${C_BOLD}CPUs:${C_RESET} $CPUS"
                            echo -e "${C_BOLD}Disk:${C_RESET} $DISK_SIZE"
                            echo -e "${C_BOLD}GUI Mode:${C_RESET} $GUI_MODE"
                            echo -e "${C_BOLD}Created:${C_RESET} $CREATED"
                            echo
                        fi
                    fi
                fi
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            0) return ;;
            *) print_error "Invalid option"; sleep 1 ;;
        esac
    done
}

# ============================================================
# Docker Manager
# ============================================================

docker_manager() {
    while true; do
        clear_screen
        print_header "${ICON_DOCKER} Docker Manager"
        
        # Check if Docker is installed
        if command -v docker &> /dev/null; then
            echo -e "${C_GREEN}${ICON_SUCCESS}${C_RESET} Docker is installed"
            echo -e "${C_CYAN}${ICON_INFO} Version:${C_RESET} $(docker --version 2>/dev/null | cut -d' ' -f3 | sed 's/,//')"
            echo -e "${C_CYAN}${ICON_INFO} Containers:${C_RESET} $(docker ps -q 2>/dev/null | wc -l) running, $(docker ps -a -q 2>/dev/null | wc -l) total"
            echo -e "${C_CYAN}${ICON_INFO} Images:${C_RESET} $(docker images -q 2>/dev/null | wc -l)"
            echo -e "${C_CYAN}${ICON_INFO} Volumes:${C_RESET} $(docker volume ls -q 2>/dev/null | wc -l)"
        else
            echo -e "${C_YELLOW}${ICON_WARNING}${C_RESET} Docker is not installed"
        fi
        echo
        
        echo -e " ${C_GREEN}1.${C_RESET} Install Docker"
        echo -e " ${C_GREEN}2.${C_RESET} Install Docker Compose"
        echo -e " ${C_GREEN}3.${C_RESET} Start Docker"
        echo -e " ${C_GREEN}4.${C_RESET} Stop Docker"
        echo -e " ${C_GREEN}5.${C_RESET} Restart Docker"
        echo -e " ${C_GREEN}6.${C_RESET} Container Manager"
        echo -e " ${C_GREEN}7.${C_RESET} Image Manager"
        echo -e " ${C_GREEN}8.${C_RESET} Volume Manager"
        echo -e " ${C_GREEN}9.${C_RESET} Cleanup Docker"
        echo -e " ${C_GREEN}10.${C_RESET} Uninstall Docker"
        echo -e " ${C_RED}0.${C_RESET} Back to Main Menu"
        echo
        
        read -p "$(print_question "Select option: ")" choice
        
        case "$choice" in
            1)
                print_info "Installing Docker..."
                if command -v docker &> /dev/null; then
                    print_warning "Docker is already installed"
                else
                    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
                    sudo sh /tmp/get-docker.sh
                    sudo usermod -aG docker "$USER" 2>/dev/null || true
                    rm -f /tmp/get-docker.sh
                    print_success "Docker installed successfully"
                fi
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            2)
                print_info "Installing Docker Compose..."
                if command -v docker-compose &> /dev/null; then
                    print_warning "Docker Compose is already installed"
                else
                    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
                    sudo chmod +x /usr/local/bin/docker-compose
                    print_success "Docker Compose installed"
                fi
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            3)
                sudo systemctl start docker
                print_success "Docker started"
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            4)
                sudo systemctl stop docker
                print_success "Docker stopped"
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            5)
                sudo systemctl restart docker
                print_success "Docker restarted"
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            6)
                if command -v docker &> /dev/null; then
                    clear_screen
                    print_header "Container Manager"
                    echo -e "${C_BOLD}${C_CYAN}Running Containers:${C_RESET}"
                    docker ps
                    echo
                    echo -e "${C_BOLD}${C_CYAN}All Containers:${C_RESET}"
                    docker ps -a
                    echo
                    echo -e " ${C_GREEN}1.${C_RESET} Start container"
                    echo -e " ${C_GREEN}2.${C_RESET} Stop container"
                    echo -e " ${C_GREEN}3.${C_RESET} Restart container"
                    echo -e " ${C_GREEN}4.${C_RESET} Remove container"
                    echo -e " ${C_GREEN}5.${C_RESET} View logs"
                    echo -e " ${C_GREEN}6.${C_RESET} Exec into container"
                    echo -e " ${C_RED}0.${C_RESET} Back"
                    read -p "$(print_question "Select: ")" sub_choice
                    case "$sub_choice" in
                        1)
                            read -p "$(print_question "Container ID/Name: ")" cid
                            docker start "$cid"
                            ;;
                        2)
                            read -p "$(print_question "Container ID/Name: ")" cid
                            docker stop "$cid"
                            ;;
                        3)
                            read -p "$(print_question "Container ID/Name: ")" cid
                            docker restart "$cid"
                            ;;
                        4)
                            read -p "$(print_question "Container ID/Name: ")" cid
                            docker rm -f "$cid"
                            ;;
                        5)
                            read -p "$(print_question "Container ID/Name: ")" cid
                            docker logs -f "$cid"
                            ;;
                        6)
                            read -p "$(print_question "Container ID/Name: ")" cid
                            read -p "$(print_question "Command (default: /bin/bash): ")" cmd
                            cmd="${cmd:-/bin/bash}"
                            docker exec -it "$cid" "$cmd"
                            ;;
                    esac
                else
                    print_warning "Docker is not installed"
                fi
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            7)
                if command -v docker &> /dev/null; then
                    clear_screen
                    print_header "Image Manager"
                    docker images
                    echo
                    echo -e " ${C_GREEN}1.${C_RESET} Pull image"
                    echo -e " ${C_GREEN}2.${C_RESET} Remove image"
                    echo -e " ${C_GREEN}3.${C_RESET} Prune images"
                    echo -e " ${C_GREEN}4.${C_RESET} Build image"
                    echo -e " ${C_RED}0.${C_RESET} Back"
                    read -p "$(print_question "Select: ")" sub_choice
                    case "$sub_choice" in
                        1)
                            read -p "$(print_question "Image name: ")" img
                            docker pull "$img"
                            ;;
                        2)
                            read -p "$(print_question "Image ID/Name: ")" img
                            docker rmi -f "$img"
                            ;;
                        3)
                            docker image prune -f
                            ;;
                        4)
                            read -p "$(print_question "Path to Dockerfile: ")" path
                            read -p "$(print_question "Image name/tag: ")" tag
                            docker build -t "$tag" "$path"
                            ;;
                    esac
                else
                    print_warning "Docker is not installed"
                fi
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            8)
                if command -v docker &> /dev/null; then
                    clear_screen
                    print_header "Volume Manager"
                    docker volume ls
                    echo
                    echo -e " ${C_GREEN}1.${C_RESET} Create volume"
                    echo -e " ${C_GREEN}2.${C_RESET} Remove volume"
                    echo -e " ${C_GREEN}3.${C_RESET} Prune volumes"
                    echo -e " ${C_RED}0.${C_RESET} Back"
                    read -p "$(print_question "Select: ")" sub_choice
                    case "$sub_choice" in
                        1)
                            read -p "$(print_question "Volume name: ")" vol
                            docker volume create "$vol"
                            ;;
                        2)
                            read -p "$(print_question "Volume name: ")" vol
                            docker volume rm "$vol"
                            ;;
                        3)
                            docker volume prune -f
                            ;;
                    esac
                else
                    print_warning "Docker is not installed"
                fi
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            9)
                if confirm_action "Clean up unused Docker objects?"; then
                    docker system prune -f
                    docker volume prune -f
                    docker image prune -f
                    docker network prune -f
                    print_success "Cleanup completed"
                fi
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            10)
                if confirm_action "Uninstall Docker completely?"; then
                    sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
                    sudo rm -rf /var/lib/docker
                    sudo rm -rf /var/lib/containerd
                    sudo rm -f /usr/local/bin/docker-compose
                    print_success "Docker uninstalled"
                fi
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            0) return ;;
            *) print_error "Invalid option"; sleep 1 ;;
        esac
    done
}

# ============================================================
# Node.js Manager
# ============================================================

nodejs_manager() {
    while true; do
        clear_screen
        print_header "${ICON_NODE} Node.js Manager"
        
        # Check if Node.js is installed
        if command -v node &> /dev/null; then
            echo -e "${C_GREEN}${ICON_SUCCESS}${C_RESET} Node.js is installed"
            echo -e "${C_CYAN}${ICON_INFO} Node Version:${C_RESET} $(node --version 2>/dev/null)"
            echo -e "${C_CYAN}${ICON_INFO} NPM Version:${C_RESET} $(npm --version 2>/dev/null)"
            if command -v nvm &> /dev/null; then
                echo -e "${C_CYAN}${ICON_INFO} NVM:${C_RESET} Installed"
            fi
        else
            echo -e "${C_YELLOW}${ICON_WARNING}${C_RESET} Node.js is not installed"
        fi
        echo
        
        echo -e " ${C_GREEN}1.${C_RESET} Install Node.js (Latest LTS)"
        echo -e " ${C_GREEN}2.${C_RESET} Install Node.js (Latest Stable)"
        echo -e " ${C_GREEN}3.${C_RESET} Install NVM (Node Version Manager)"
        echo -e " ${C_GREEN}4.${C_RESET} Install npm"
        echo -e " ${C_GREEN}5.${C_RESET} Install pnpm"
        echo -e " ${C_GREEN}6.${C_RESET} Install yarn"
        echo -e " ${C_GREEN}7.${C_RESET} Install Bun"
        echo -e " ${C_GREEN}8.${C_RESET} Install Deno"
        echo -e " ${C_GREEN}9.${C_RESET} PM2 Manager"
        echo -e " ${C_GREEN}10.${C_RESET} Uninstall Node.js"
        echo -e " ${C_RED}0.${C_RESET} Back to Main Menu"
        echo
        
        read -p "$(print_question "Select option: ")" choice
        
        case "$choice" in
            1)
                print_info "Installing Node.js LTS..."
                curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
                sudo apt-get install -y nodejs
                print_success "Node.js installed: $(node --version 2>/dev/null)"
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            2)
                print_info "Installing Node.js Latest..."
                curl -fsSL https://deb.nodesource.com/setup_current.x | sudo -E bash -
                sudo apt-get install -y nodejs
                print_success "Node.js installed: $(node --version 2>/dev/null)"
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            3)
                print_info "Installing NVM..."
                curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
                export NVM_DIR="$HOME/.nvm"
                [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
                print_success "NVM installed"
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            4)
                print_info "Installing npm..."
                sudo apt-get install -y npm
                print_success "npm installed: $(npm --version 2>/dev/null)"
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            5)
                print_info "Installing pnpm..."
                curl -fsSL https://get.pnpm.io/install.sh | sh -
                print_success "pnpm installed"
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            6)
                print_info "Installing yarn..."
                curl -fsSL https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
                echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
                sudo apt-get update && sudo apt-get install -y yarn
                print_success "yarn installed: $(yarn --version 2>/dev/null)"
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            7)
                print_info "Installing Bun..."
                curl -fsSL https://bun.sh/install | bash
                print_success "Bun installed"
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            8)
                print_info "Installing Deno..."
                curl -fsSL https://deno.land/x/install/install.sh | sh
                print_success "Deno installed"
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            9)
                if command -v pm2 &> /dev/null; then
                    clear_screen
                    print_header "PM2 Manager"
                    pm2 list
                    echo
                    echo -e " ${C_GREEN}1.${C_RESET} Start app"
                    echo -e " ${C_GREEN}2.${C_RESET} Stop app"
                    echo -e " ${C_GREEN}3.${C_RESET} Restart app"
                    echo -e " ${C_GREEN}4.${C_RESET} Remove app"
                    echo -e " ${C_GREEN}5.${C_RESET} Logs"
                    echo -e " ${C_GREEN}6.${C_RESET} Save processes"
                    echo -e " ${C_GREEN}7.${C_RESET} Startup script"
                    echo -e " ${C_RED}0.${C_RESET} Back"
                    read -p "$(print_question "Select: ")" sub_choice
                    case "$sub_choice" in
                        1)
                            read -p "$(print_question "App name or script: ")" app
                            pm2 start "$app"
                            ;;
                        2)
                            read -p "$(print_question "App name/ID: ")" app
                            pm2 stop "$app"
                            ;;
                        3)
                            read -p "$(print_question "App name/ID: ")" app
                            pm2 restart "$app"
                            ;;
                        4)
                            read -p "$(print_question "App name/ID: ")" app
                            pm2 delete "$app"
                            ;;
                        5) pm2 logs ;;
                        6) pm2 save ;;
                        7) pm2 startup ;;
                    esac
                else
                    print_info "Installing PM2..."
                    npm install -g pm2 2>/dev/null || sudo npm install -g pm2
                    print_success "PM2 installed"
                fi
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            10)
                if confirm_action "Uninstall Node.js?"; then
                    sudo apt-get remove -y nodejs npm
                    sudo rm -rf /usr/local/lib/node_modules
                    sudo rm -rf ~/.nvm
                    print_success "Node.js uninstalled"
                fi
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            0) return ;;
            *) print_error "Invalid option"; sleep 1 ;;
        esac
    done
}

# ============================================================
# Security Manager
# ============================================================

security_manager() {
    while true; do
        clear_screen
        print_header "${ICON_SECURITY} Security Manager"
        
        # Check current security status
        echo -e "${C_BOLD}${C_CYAN}${ICON_INFO} Security Status:${C_RESET}"
        echo -e "  SSH Root Login: $(grep -q "^PermitRootLogin no" /etc/ssh/sshd_config 2>/dev/null && echo "${C_GREEN}Disabled${C_RESET}" || echo "${C_RED}Enabled${C_RESET}")"
        echo -e "  Password Auth: $(grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config 2>/dev/null && echo "${C_GREEN}Disabled${C_RESET}" || echo "${C_RED}Enabled${C_RESET}")"
        echo -e "  Fail2Ban: $(command -v fail2ban-client &> /dev/null && echo "${C_GREEN}Installed${C_RESET}" || echo "${C_RED}Not installed${C_RESET}")"
        echo -e "  UFW: $(command -v ufw &> /dev/null && ufw status 2>/dev/null | grep -q "Status: active" && echo "${C_GREEN}Active${C_RESET}" || echo "${C_RED}Inactive${C_RESET}")"
        echo
        
        echo -e " ${C_GREEN}1.${C_RESET} SSH Hardening"
        echo -e " ${C_GREEN}2.${C_RESET} Toggle Root Login"
        echo -e " ${C_GREEN}3.${C_RESET} Toggle Password Login"
        echo -e " ${C_GREEN}4.${C_RESET} Install Fail2Ban"
        echo -e " ${C_GREEN}5.${C_RESET} Configure UFW Firewall"
        echo -e " ${C_GREEN}6.${C_RESET} Enable BBR Congestion Control"
        echo -e " ${C_GREEN}7.${C_RESET} Malware Scan (ClamAV)"
        echo -e " ${C_GREEN}8.${C_RESET} Rootkit Scan (rkhunter)"
        echo -e " ${C_GREEN}9.${C_RESET} Automatic Security Updates"
        echo -e " ${C_GREEN}10.${C_RESET} Security Audit"
        echo -e " ${C_RED}0.${C_RESET} Back to Main Menu"
        echo
        
        read -p "$(print_question "Select option: ")" choice
        
        case "$choice" in
            1)
                print_info "Hardening SSH configuration..."
                sudo sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
                sudo sed -i 's/#MaxAuthTries.*/MaxAuthTries 3/' /etc/ssh/sshd_config
                sudo sed -i 's/#ClientAliveInterval.*/ClientAliveInterval 300/' /etc/ssh/sshd_config
                sudo sed -i 's/#ClientAliveCountMax.*/ClientAliveCountMax 2/' /etc/ssh/sshd_config
                sudo sed -i 's/#Protocol.*/Protocol 2/' /etc/ssh/sshd_config
                sudo sed -i 's/#X11Forwarding.*/X11Forwarding no/' /etc/ssh/sshd_config
                sudo systemctl restart sshd
                print_success "SSH hardened"
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            2)
                if grep -q "^PermitRootLogin no" /etc/ssh/sshd_config 2>/dev/null; then
                    sudo sed -i 's/PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config
                    print_success "Root login enabled"
                else
                    sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
                    print_success "Root login disabled"
                fi
                sudo systemctl restart sshd
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            3)
                if grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config 2>/dev/null; then
                    sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
                    print_success "Password login enabled"
                else
                    sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
                    print_success "Password login disabled"
                fi
                sudo systemctl restart sshd
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            4)
                print_info "Installing Fail2Ban..."
                sudo apt-get install -y fail2ban
                sudo systemctl enable fail2ban
                sudo systemctl start fail2ban
                print_success "Fail2Ban installed and running"
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            5)
                print_info "Configuring UFW..."
                sudo apt-get install -y ufw
                sudo ufw default deny incoming
                sudo ufw default allow outgoing
                sudo ufw allow 22/tcp
                sudo ufw allow 80/tcp
                sudo ufw allow 443/tcp
                sudo ufw --force enable
                print_success "UFW configured"
                sudo ufw status
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            6)
                print_info "Enabling BBR..."
                if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf 2>/dev/null; then
                    echo "net.core.default_qdisc=fq" | sudo tee -a /etc/sysctl.conf
                fi
                if ! grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf 2>/dev/null; then
                    echo "net.ipv4.tcp_congestion_control=bbr" | sudo tee -a /etc/sysctl.conf
                fi
                sudo sysctl -p
                print_success "BBR enabled"
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            7)
                print_info "Installing ClamAV..."
                sudo apt-get install -y clamav clamav-daemon
                sudo freshclam
                print_info "Running scan..."
                sudo clamscan -r --bell /home
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            8)
                print_info "Installing rkhunter..."
                sudo apt-get install -y rkhunter
                sudo rkhunter --check --skip-keypress
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            9)
                print_info "Configuring automatic security updates..."
                sudo apt-get install -y unattended-upgrades
                sudo dpkg-reconfigure --priority=low unattended-upgrades
                print_success "Automatic security updates configured"
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            10)
                clear_screen
                print_header "Security Audit"
                echo -e "${C_BOLD}${C_CYAN}${ICON_INFO} Running security audit...${C_RESET}\n"
                
                # Check SSH config
                echo -e "${C_BOLD}SSH Configuration:${C_RESET}"
                echo -e "  PermitRootLogin: $(grep "^PermitRootLogin" /etc/ssh/sshd_config 2>/dev/null || echo "Default")"
                echo -e "  PasswordAuthentication: $(grep "^PasswordAuthentication" /etc/ssh/sshd_config 2>/dev/null || echo "Default")"
                echo -e "  Port: $(grep "^Port" /etc/ssh/sshd_config 2>/dev/null || echo "22 (default)")"
                echo -e "  MaxAuthTries: $(grep "^MaxAuthTries" /etc/ssh/sshd_config 2>/dev/null || echo "Default")"
                echo
                
                # Check firewall
                echo -e "${C_BOLD}Firewall Status:${C_RESET}"
                if command -v ufw &> /dev/null; then
                    ufw status
                else
                    echo "  UFW not installed"
                fi
                echo
                
                # Check failed login attempts
                echo -e "${C_BOLD}Failed Login Attempts (last 24h):${C_RESET}"
                sudo grep "Failed password" /var/log/auth.log 2>/dev/null | tail -5 || echo "  No recent failures"
                echo
                
                # Check for security updates
                echo -e "${C_BOLD}Pending Security Updates:${C_RESET}"
                sudo apt-get -s upgrade | grep "^Inst" | head -5 || echo "  No updates"
                
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            0) return ;;
            *) print_error "Invalid option"; sleep 1 ;;
        esac
    done
}

# ============================================================
# Network Tools
# ============================================================

network_tools() {
    while true; do
        clear_screen
        print_header "${ICON_NETWORK} Network Tools"
        
        echo -e " ${C_GREEN}1.${C_RESET} Speed Test"
        echo -e " ${C_GREEN}2.${C_RESET} Port Scanner"
        echo -e " ${C_GREEN}3.${C_RESET} Port Checker"
        echo -e " ${C_GREEN}4.${C_RESET} Ping"
        echo -e " ${C_GREEN}5.${C_RESET} Traceroute"
        echo -e " ${C_GREEN}6.${C_RESET} DNS Lookup"
        echo -e " ${C_GREEN}7.${C_RESET} WHOIS Lookup"
        echo -e " ${C_GREEN}8.${C_RESET} Bandwidth Monitor"
        echo -e " ${C_GREEN}9.${C_RESET} Network Interfaces"
        echo -e " ${C_RED}0.${C_RESET} Back to Main Menu"
        echo
        
        read -p "$(print_question "Select option: ")" choice
        
        case "$choice" in
            1)
                print_info "Running speed test..."
                if command -v speedtest-cli &> /dev/null; then
                    speedtest-cli --simple
                else
                    print_info "Installing speedtest-cli..."
                    pip3 install speedtest-cli 2>/dev/null || sudo apt-get install -y speedtest-cli
                    speedtest-cli --simple
                fi
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            2)
                read -p "$(print_question "Target IP/Host: ")" target
                read -p "$(print_question "Port range (e.g., 1-1000): ")" ports
                print_info "Scanning $target..."
                if [[ "$ports" == *-* ]]; then
                    start_port=$(echo "$ports" | cut -d- -f1)
                    end_port=$(echo "$ports" | cut -d- -f2)
                    for port in $(seq "$start_port" "$end_port"); do
                        nc -zv "$target" "$port" 2>&1 | grep succeeded && echo "  Port $port: open"
                    done
                else
                    nc -zv "$target" "$ports" 2>&1 | grep succeeded && echo "  Port $ports: open"
                fi
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            3)
                read -p "$(print_question "Target IP/Host: ")" target
                read -p "$(print_question "Port: ")" port
                if nc -zv "$target" "$port" 2>&1 | grep -q succeeded; then
                    print_success "Port $port is open"
                else
                    print_warning "Port $port is closed or filtered"
                fi
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            4)
                read -p "$(print_question "Target IP/Host: ")" target
                ping -c 4 "$target"
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            5)
                read -p "$(print_question "Target IP/Host: ")" target
                if command -v traceroute &> /dev/null; then
                    traceroute "$target"
                else
                    print_info "Installing traceroute..."
                    sudo apt-get install -y traceroute
                    traceroute "$target"
                fi
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            6)
                read -p "$(print_question "Domain: ")" domain
                nslookup "$domain"
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            7)
                read -p "$(print_question "Domain/IP: ")" target
                whois "$target"
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            8)
                print_info "Installing bandwidth monitor..."
                sudo apt-get install -y nethogs
                sudo nethogs
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            9)
                clear_screen
                print_header "Network Interfaces"
                ip addr show
                echo
                print_info "Routing Table:"
                ip route show
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            0) return ;;
            *) print_error "Invalid option"; sleep 1 ;;
        esac
    done
}

# ============================================================
# Settings Manager
# ============================================================

settings_manager() {
    while true; do
        clear_screen
        print_header "${ICON_GEAR} Settings"
        
        # Show current settings
        echo -e "${C_BOLD}${C_CYAN}${ICON_INFO} Current Settings:${C_RESET}"
        echo -e "  Theme: $([[ -f "$REON_CONFIG_DIR/theme.conf" ]] && grep "REON_THEME" "$REON_CONFIG_DIR/theme.conf" | cut -d'"' -f2 || echo "cyan")"
        echo -e "  Auto Updates: $([[ -f "$REON_CONFIG_DIR/settings.conf" ]] && grep "REON_AUTO_UPDATE" "$REON_CONFIG_DIR/settings.conf" | cut -d'"' -f2 || echo "true")"
        echo -e "  Log Level: $([[ -f "$REON_CONFIG_DIR/logging.conf" ]] && grep "REON_LOG_LEVEL" "$REON_CONFIG_DIR/logging.conf" | cut -d'"' -f2 || echo "INFO")"
        echo -e "  Install Directory: $REON_INSTALL_DIR"
        echo
        
        echo -e " ${C_GREEN}1.${C_RESET} Configure Theme"
        echo -e " ${C_GREEN}2.${C_RESET} Toggle Auto Updates"
        echo -e " ${C_GREEN}3.${C_RESET} Configure Log Level"
        echo -e " ${C_GREEN}4.${C_RESET} View Configuration"
        echo -e " ${C_GREEN}5.${C_RESET} Reset Configuration"
        echo -e " ${C_GREEN}6.${C_RESET} Show Logs"
        echo -e " ${C_RED}0.${C_RESET} Back to Main Menu"
        echo
        
        read -p "$(print_question "Select option: ")" choice
        
        case "$choice" in
            1)
                echo "Available themes: cyan, blue, green, red, yellow, magenta, white"
                read -p "$(print_question "Select theme: ")" theme
                mkdir -p "$REON_CONFIG_DIR"
                echo "REON_THEME=\"$theme\"" > "$REON_CONFIG_DIR/theme.conf"
                print_success "Theme set to $theme"
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            2)
                mkdir -p "$REON_CONFIG_DIR"
                if [[ -f "$REON_CONFIG_DIR/settings.conf" ]] && grep -q "REON_AUTO_UPDATE=\"true\"" "$REON_CONFIG_DIR/settings.conf"; then
                    sed -i 's/REON_AUTO_UPDATE="true"/REON_AUTO_UPDATE="false"/' "$REON_CONFIG_DIR/settings.conf"
                    print_success "Auto updates disabled"
                else
                    echo 'REON_AUTO_UPDATE="true"' > "$REON_CONFIG_DIR/settings.conf"
                    print_success "Auto updates enabled"
                fi
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            3)
                echo "Log levels: DEBUG, INFO, WARN, ERROR, FATAL"
                read -p "$(print_question "Select log level: ")" level
                mkdir -p "$REON_CONFIG_DIR"
                echo "REON_LOG_LEVEL=\"$level\"" > "$REON_CONFIG_DIR/logging.conf"
                LOG_LEVEL="$level"
                print_success "Log level set to $level"
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            4)
                clear_screen
                print_header "Configuration"
                echo -e "${C_BOLD}${C_CYAN}Settings:${C_RESET}"
                if [[ -f "$REON_CONFIG_DIR/settings.conf" ]]; then
                    cat "$REON_CONFIG_DIR/settings.conf"
                else
                    echo "  No custom settings found"
                fi
                echo
                echo -e "${C_BOLD}${C_CYAN}Theme:${C_RESET}"
                if [[ -f "$REON_CONFIG_DIR/theme.conf" ]]; then
                    cat "$REON_CONFIG_DIR/theme.conf"
                else
                    echo "  Default (cyan)"
                fi
                echo
                echo -e "${C_BOLD}${C_CYAN}Logging:${C_RESET}"
                if [[ -f "$REON_CONFIG_DIR/logging.conf" ]]; then
                    cat "$REON_CONFIG_DIR/logging.conf"
                else
                    echo "  Default (INFO)"
                fi
                echo
                echo -e "${C_BOLD}${C_CYAN}Paths:${C_RESET}"
                echo "  Install: $REON_INSTALL_DIR"
                echo "  Config: $REON_CONFIG_DIR"
                echo "  Logs: $REON_LOGS_DIR"
                echo "  Backups: $REON_BACKUPS_DIR"
                echo "  VMs: $REON_VM_DIR"
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            5)
                if confirm_action "Reset all configuration to defaults?"; then
                    rm -rf "$REON_CONFIG_DIR"/*
                    print_success "Configuration reset"
                fi
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            6)
                clear_screen
                print_header "Log Files"
                echo -e "${C_BOLD}${C_CYAN}Actions Log:${C_RESET}"
                if [[ -f "$REON_LOGS_DIR/actions.log" ]]; then
                    tail -20 "$REON_LOGS_DIR/actions.log"
                else
                    echo "  No logs found"
                fi
                echo
                if [[ -f "$REON_LOGS_DIR/errors.log" ]]; then
                    echo -e "${C_BOLD}${C_RED}Errors Log:${C_RESET}"
                    tail -10 "$REON_LOGS_DIR/errors.log"
                fi
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            0) return ;;
            *) print_error "Invalid option"; sleep 1 ;;
        esac
    done
}

# ============================================================
# About
# ============================================================

show_about() {
    clear_screen
    display_banner
    echo
    echo -e "${C_BOLD}${C_CYAN}${ICON_STAR} REON DEV INSTALLER v3.0.0${C_RESET}"
    echo -e "${C_CYAN}Made By ReonDev${C_RESET}"
    echo
    echo -e "A professional Linux VPS management platform"
    echo -e "Designed for Ubuntu 20.04+, Debian 11+"
    echo
    echo -e "${C_BOLD}${C_CYAN}Features:${C_RESET}"
    echo -e "  ${ICON_CPU} VPS Management"
    echo -e "  ${ICON_GEAR} Application Deployment"
    echo -e "  ${ICON_DOCKER} Container Management"
    echo -e "  ${ICON_INFO} Server Monitoring"
    echo -e "  ${ICON_SECURITY} Security Hardening"
    echo -e "  ${ICON_BACKUP} Backup Management"
    echo -e "  ${ICON_STAR} And much more..."
    echo
    echo -e "${C_BOLD}${C_CYAN}Modules:${C_RESET}"
    echo -e "  • Pterodactyl Panel"
    echo -e "  • Docker Manager"
    echo -e "  • Node.js Manager"
    echo -e "  • VM/QEMU/LXC Manager"
    echo -e "  • Database Manager"
    echo -e "  • Web Server"
    echo -e "  • Network Tools"
    echo -e "  • File Manager"
    echo -e "  • Developer Tools"
    echo
    echo -e "${C_BOLD}${C_CYAN}System Information:${C_RESET}"
    local os_info=$(get_os_info)
    IFS='|' read -r os_name os_version os_codename <<< "$os_info"
    echo -e "  OS: $os_name $os_version ($os_codename)"
    local cpu_info=($(get_cpu_info))
    echo -e "  CPU: ${cpu_info[1]} cores"
    local mem_info=($(get_memory_info))
    echo -e "  Memory: ${mem_info[1]}GB total"
    local disk_info=($(get_disk_info))
    echo -e "  Disk: ${disk_info[0]}GB total"
    echo
    echo -e "License: MIT"
    echo -e "Repository: https://github.com/reondevpaid/vmcmd"
    echo
    read -p "$(print_question "Press Enter to continue...")"
}

# ============================================================
# Update Function
# ============================================================

update_installer() {
    clear_screen
    print_header "${ICON_GEAR} Update Installer"
    
    print_info "Checking for updates..."
    
    # Check GitHub for latest version
    local latest_version=$(curl -s --max-time 5 https://api.github.com/repos/reondevpaid/vmcmd/releases/latest 2>/dev/null | grep '"tag_name"' | head -1 | cut -d'"' -f4 || echo "")
    
    if [[ -n "$latest_version" ]]; then
        echo -e "${C_CYAN}${ICON_INFO} Latest version: $latest_version${C_RESET}"
        echo -e "${C_CYAN}${ICON_INFO} Current version: v${REON_VERSION}${C_RESET}"
        
        if [[ "$latest_version" != "v${REON_VERSION}" ]]; then
            if confirm_action "Update to $latest_version?"; then
                print_info "Downloading latest version..."
                curl -s https://raw.githubusercontent.com/reondevpaid/vmcmd/main/vm.sh -o /tmp/vm-update.sh
                if [[ -f /tmp/vm-update.sh ]]; then
                    # Update the script
                    cp /tmp/vm-update.sh "$0"
                    chmod +x "$0"
                    rm -f /tmp/vm-update.sh
                    print_success "Update completed! Please restart the installer."
                    exit 0
                else
                    print_error "Failed to download update"
                fi
            fi
        else
            print_success "You have the latest version"
        fi
    else
        print_warning "Could not check for updates"
        print_info "Current version: ${REON_VERSION}"
    fi
    
    read -p "$(print_question "Press Enter to continue...")"
}

# ============================================================
# Placeholder Functions
# ============================================================

pterodactyl_manager() {
    clear_screen
    print_header "Pterodactyl Panel Manager"
    print_info "Pterodactyl management coming soon..."
    echo
    echo -e "Available features will include:"
    echo "  • Install Panel"
    echo "  • Repair Panel"
    echo "  • Update Panel"
    echo "  • SSL Setup"
    echo "  • Database Setup"
    echo "  • Queue Worker"
    echo "  • Redis Setup"
    echo "  • Cron Setup"
    read -p "$(print_question "Press Enter to continue...")"
}

wings_manager() {
    clear_screen
    print_header "Wings Manager"
    print_info "Wings management coming soon..."
    echo
    echo -e "Available features will include:"
    echo "  • Install Wings"
    echo "  • Configure Wings"
    echo "  • Restart Wings"
    echo "  • Auto Node Configuration"
    read -p "$(print_question "Press Enter to continue...")"
}

lxc_manager() {
    clear_screen
    print_header "LXC Manager"
    print_info "LXC management coming soon..."
    read -p "$(print_question "Press Enter to continue...")"
}

qemu_manager() {
    clear_screen
    print_header "QEMU Manager"
    print_info "QEMU management coming soon..."
    read -p "$(print_question "Press Enter to continue...")"
}

database_manager() {
    clear_screen
    print_header "${ICON_DATABASE} Database Manager"
    print_info "Database management coming soon..."
    echo
    echo -e "Available features will include:"
    echo "  • MariaDB/MySQL"
    echo "  • PostgreSQL"
    echo "  • Redis"
    echo "  • MongoDB"
    read -p "$(print_question "Press Enter to continue...")"
}

webserver_manager() {
    clear_screen
    print_header "Web Server Manager"
    print_info "Web server management coming soon..."
    echo
    echo -e "Available features will include:"
    echo "  • Nginx"
    echo "  • Apache"
    echo "  • OpenLiteSpeed"
    echo "  • SSL/Let's Encrypt"
    echo "  • Reverse Proxy"
    read -p "$(print_question "Press Enter to continue...")"
}

monitoring() {
    clear_screen
    print_header "Monitoring"
    print_info "Monitoring coming soon..."
    echo
    echo -e "Available features will include:"
    echo "  • Live CPU Usage"
    echo "  • RAM Usage"
    echo "  • Disk Usage"
    echo "  • Network Usage"
    echo "  • Running Processes"
    echo "  • Real-time Dashboard"
    read -p "$(print_question "Press Enter to continue...")"
}

backups() {
    clear_screen
    print_header "${ICON_BACKUP} Backup Manager"
    print_info "Backup management coming soon..."
    read -p "$(print_question "Press Enter to continue...")"
}

user_manager() {
    clear_screen
    print_header "User Manager"
    print_info "User management coming soon..."
    read -p "$(print_question "Press Enter to continue...")"
}

service_manager() {
    clear_screen
    print_header "Service Manager"
    print_info "Service management coming soon..."
    read -p "$(print_question "Press Enter to continue...")"
}

file_manager() {
    clear_screen
    print_header "File Manager"
    print_info "File management coming soon..."
    read -p "$(print_question "Press Enter to continue...")"
}

git_manager() {
    clear_screen
    print_header "Git Manager"
    print_info "Git management coming soon..."
    read -p "$(print_question "Press Enter to continue...")"
}

developer_tools() {
    clear_screen
    print_header "Developer Tools"
    print_info "Developer tools coming soon..."
    echo
    echo -e "Available features will include:"
    echo "  • Git & GitHub CLI"
    echo "  • Python"
    echo "  • Go"
    echo "  • Rust"
    echo "  • Java"
    echo "  • PHP & Composer"
    echo "  • VS Code Server"
    read -p "$(print_question "Press Enter to continue...")"
}

# ============================================================
# Main Menu
# ============================================================

main_menu() {
    while true; do
        show_main_menu
        
        echo
        read -p "$(print_question "Select an option: ")" choice
        
        case "$choice" in
            1) vps_manager ;;
            2) pterodactyl_manager ;;
            3) wings_manager ;;
            4) docker_manager ;;
            5) nodejs_manager ;;
            6) vm_manager ;;
            7) lxc_manager ;;
            8) qemu_manager ;;
            9) database_manager ;;
            10) webserver_manager ;;
            11) monitoring ;;
            12) network_tools ;;
            13) security_manager ;;
            14) backups ;;
            15) user_manager ;;
            16) service_manager ;;
            17) file_manager ;;
            18) git_manager ;;
            19) developer_tools ;;
            20) settings_manager ;;
            21) update_installer ;;
            22) show_about ;;
            0)
                print_info "Goodbye!"
                log_action "Exit" "User exited"
                exit 0
                ;;
            *)
                print_error "Invalid option"
                sleep 1
                ;;
        esac
    done
}

# ============================================================
# Installation Check
# ============================================================

check_installation() {
    mkdir -p "$REON_INSTALL_DIR" "$REON_CONFIG_DIR" "$REON_LOGS_DIR" "$REON_BACKUPS_DIR" "$REON_VM_DIR" "$REON_TEMP_DIR"
    
    # Create default config if not exists
    if [[ ! -f "$REON_CONFIG_DIR/settings.conf" ]]; then
        cat > "$REON_CONFIG_DIR/settings.conf" <<EOF
REON_THEME="cyan"
REON_AUTO_UPDATE="true"
REON_CHECK_UPDATES="true"
REON_BACKUP_BEFORE_UPDATE="true"
REON_LOG_LEVEL="INFO"
REON_AUTO_SECURITY_UPDATES="true"
REON_FAIL2BAN_ENABLED="true"
REON_SSH_HARDENING="true"
REON_PARALLEL_OPERATIONS="true"
REON_USE_CACHE="true"
REON_INSTALL_DIR="$REON_INSTALL_DIR"
EOF
    fi
    
    # Ensure log files exist
    touch "$REON_LOGS_DIR/actions.log" 2>/dev/null || true
    touch "$REON_LOGS_DIR/errors.log" 2>/dev/null || true
}

# ============================================================
# Main Entry Point
# ============================================================

main() {
    # Create directories
    check_installation
    
    # Log start
    log_action "Start" "REON DEV INSTALLER v3 started"
    
    # Check for root/sudo
    if [[ $EUID -ne 0 ]]; then
        print_warning "Some features may require root privileges"
    fi
    
    # Check command line arguments
    case "${1:-}" in
        --help|-h)
            cat << "EOF"
REON DEV INSTALLER v3 - Professional Linux VPS Management Platform
Made By ReonDev

Usage:
  ./vm.sh              Start interactive menu
  ./vm.sh --help       Show this help
  ./vm.sh --version    Show version
  ./vm.sh --install    Run installation
  ./vm.sh --update     Update to latest version

Examples:
  ./vm.sh              Start the main menu
  ./vm.sh --version    Show version information
  ./vm.sh --install    Install dependencies and setup

For more information:
  https://github.com/reondevpaid/vmcmd
EOF
            exit 0
            ;;
        --version|-v)
            echo "REON DEV INSTALLER v3.0.0"
            echo "Made By ReonDev"
            exit 0
            ;;
        --install)
            print_info "Running in installation mode..."
            print_info "Installing dependencies..."
            sudo apt-get update
            sudo apt-get install -y curl wget git qemu-system cloud-image-utils
            print_success "Installation complete"
            exit 0
            ;;
        --update)
            update_installer
            exit 0
            ;;
    esac
    
    # Start main menu
    main_menu
}

# ============================================================
# Run Main
# ============================================================

# Run main function with arguments
main "$@"
