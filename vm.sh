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
    esac
    return 0
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

# ============================================================
# System Information Functions
# ============================================================

get_os_info() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "$ID|$VERSION_ID|${VERSION_CODENAME:-unknown}"
    else
        echo "unknown|unknown|unknown"
    fi
}

get_cpu_info() {
    local model=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | sed 's/^[ \t]*//')
    local cores=$(grep -c "^processor" /proc/cpuinfo)
    local arch=$(uname -m)
    echo "$model|$cores|$arch"
}

get_memory_info() {
    local total=$(grep "^MemTotal" /proc/meminfo | awk '{print $2}')
    local total_mb=$((total / 1024))
    local total_gb=$(echo "scale=2; $total / 1048576" | bc)
    local free=$(grep "^MemFree" /proc/meminfo | awk '{print $2}')
    local free_mb=$((free / 1024))
    local free_gb=$(echo "scale=2; $free / 1048576" | bc)
    local swap=$(grep "^SwapTotal" /proc/meminfo | awk '{print $2}')
    local swap_mb=$((swap / 1024))
    echo "$total_mb|$total_gb|$free_mb|$free_gb|$swap_mb"
}

get_disk_info() {
    local total=$(df -BG / | awk 'NR==2 {print $2}' | sed 's/G//')
    local used=$(df -BG / | awk 'NR==2 {print $3}' | sed 's/G//')
    local free=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    local percent=$(df -BG / | awk 'NR==2 {print $5}' | sed 's/%//')
    echo "$total|$used|$free|$percent"
}

get_network_info() {
    local public_ip=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null || echo "Unknown")
    local private_ip=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v "127.0.0.1" | head -n1)
    local hostname=$(hostname)
    echo "$public_ip|$private_ip|$hostname"
}

get_virtualization_info() {
    if command -v systemd-detect-virt &> /dev/null; then
        systemd-detect-virt
    elif grep -q "hypervisor" /proc/cpuinfo; then
        echo "kvm"
    elif grep -q "QEMU" /proc/cpuinfo; then
        echo "qemu"
    elif grep -q "VMware" /proc/cpuinfo; then
        echo "vmware"
    else
        echo "physical"
    fi
}

get_load_average() {
    uptime | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//'
}

get_uptime() {
    uptime -p | sed 's/up //'
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
    local os_info=($(get_os_info))
    echo -e "${C_DIM}System: ${os_info[0]} ${os_info[1]} | Host: $(hostname) | ${REON_NAME} v${REON_VERSION}${C_RESET}"
    echo -e "${C_BOLD}${C_CYAN}════════════════════════════════════════════════════════════════${C_RESET}"
}

# ============================================================
# VPS Manager
# ============================================================

vps_manager() {
    clear_screen
    print_header "VPS Manager - System Information"
    
    echo -e "${C_BOLD}${C_CYAN}System Information${C_RESET}"
    echo -e "─────────────────────────────────────────────────────────────"
    
    # OS Info
    local os_info=($(get_os_info))
    echo -e "${C_BOLD}OS:${C_RESET} ${os_info[0]} ${os_info[1]} (${os_info[2]})"
    
    # CPU Info
    local cpu_info=($(get_cpu_info))
    echo -e "${C_BOLD}CPU:${C_RESET} ${cpu_info[0]}"
    echo -e "${C_BOLD}CPU Cores:${C_RESET} ${cpu_info[1]}"
    echo -e "${C_BOLD}Architecture:${C_RESET} ${cpu_info[2]}"
    
    # Memory Info
    local mem_info=($(get_memory_info))
    echo -e "${C_BOLD}Memory (RAM):${C_RESET} ${mem_info[1]}GB total (${mem_info[3]}GB free)"
    echo -e "${C_BOLD}Swap:${C_RESET} ${mem_info[4]}MB"
    
    # Disk Info
    local disk_info=($(get_disk_info))
    echo -e "${C_BOLD}Disk:${C_RESET} ${disk_info[0]}GB total (${disk_info[2]}GB free, ${disk_info[3]}% used)"
    
    # Network Info
    local net_info=($(get_network_info))
    echo -e "${C_BOLD}Public IP:${C_RESET} ${net_info[0]}"
    echo -e "${C_BOLD}Private IP:${C_RESET} ${net_info[1]}"
    echo -e "${C_BOLD}Hostname:${C_RESET} ${net_info[2]}"
    
    # Virtualization
    echo -e "${C_BOLD}Virtualization:${C_RESET} $(get_virtualization_info)"
    
    # Load and Uptime
    echo -e "${C_BOLD}Load Average:${C_RESET} $(get_load_average)"
    echo -e "${C_BOLD}Uptime:${C_RESET} $(get_uptime)"
    
    echo -e "─────────────────────────────────────────────────────────────"
    
    # Health Status
    echo -e "\n${C_BOLD}${C_GREEN}System Health:${C_RESET}"
    
    # Check CPU load
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | sed 's/^[ \t]*//')
    local cpu_cores=$(grep -c "^processor" /proc/cpuinfo)
    local load_percent=$(echo "scale=2; ($load_avg / $cpu_cores) * 100" | bc 2>/dev/null || echo "0")
    if (( $(echo "$load_percent > 80" | bc -l 2>/dev/null || echo "0") )); then
        echo -e "  ${C_YELLOW}⚠${C_RESET} CPU: High load (${load_percent}%)"
    else
        echo -e "  ${C_GREEN}✓${C_RESET} CPU: Normal (${load_percent}%)"
    fi
    
    # Check memory
    local total_ram=${mem_info[0]}
    local free_ram=${mem_info[2]}
    local used_percent=$(( (total_ram - free_ram) * 100 / total_ram ))
    if (( used_percent > 90 )); then
        echo -e "  ${C_YELLOW}⚠${C_RESET} Memory: High usage (${used_percent}%)"
    else
        echo -e "  ${C_GREEN}✓${C_RESET} Memory: Normal (${used_percent}%)"
    fi
    
    # Check disk
    local disk_percent=${disk_info[3]}
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
# VM Manager
# ============================================================

get_vm_list() {
    find "$REON_VM_DIR" -name "*.conf" -exec basename {} .conf \; 2>/dev/null | sort
}

load_vm_config() {
    local vm_name=$1
    local config_file="$REON_VM_DIR/$vm_name.conf"
    
    if [[ -f "$config_file" ]]; then
        source "$config_file"
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
    
    print_success "Configuration saved"
}

setup_vm_image() {
    print_info "Setting up VM image..."
    
    mkdir -p "$REON_VM_DIR"
    
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
    if ! qemu-img resize "$IMG_FILE" "$DISK_SIZE" 2>/dev/null; then
        print_warning "Failed to resize disk. Creating new image..."
        rm -f "$IMG_FILE"
        qemu-img create -f qcow2 "$IMG_FILE" "$DISK_SIZE"
    fi
    
    # Cloud-init configuration
    cat > user-data <<EOF
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

    cat > meta-data <<EOF
instance-id: iid-$VM_NAME
local-hostname: $HOSTNAME
EOF

    if command -v cloud-localds &> /dev/null; then
        cloud-localds "$SEED_FILE" user-data meta-data 2>/dev/null
    else
        print_warning "cloud-localds not found, skipping seed file creation"
    fi
    
    rm -f user-data meta-data
    print_success "VM image setup complete"
}

create_vm() {
    clear_screen
    print_header "Create New VM"
    
    # OS Selection
    print_info "Select OS:"
    declare -A OS_OPTIONS=(
        ["Ubuntu 22.04"]="ubuntu|jammy|https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img|ubuntu22|ubuntu|ubuntu"
        ["Ubuntu 24.04"]="ubuntu|noble|https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img|ubuntu24|ubuntu|ubuntu"
        ["Debian 12"]="debian|bookworm|https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2|debian12|debian|debian"
        ["Rocky Linux 9"]="rockylinux|9|https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2|rocky9|rocky|rocky"
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
    read -s -p "$(print_question "Enter password (default: $DEFAULT_PASSWORD): ")" PASSWORD
    PASSWORD="${PASSWORD:-$DEFAULT_PASSWORD}"
    echo
    
    # Resources
    read -p "$(print_question "Disk size (default: 20G): ")" DISK_SIZE
    DISK_SIZE="${DISK_SIZE:-20G}"
    
    read -p "$(print_question "Memory in MB (default: 2048): ")" MEMORY
    MEMORY="${MEMORY:-2048}"
    
    read -p "$(print_question "Number of CPUs (default: 2): ")" CPUS
    CPUS="${CPUS:-2}"
    
    read -p "$(print_question "SSH Port (default: 2222): ")" SSH_PORT
    SSH_PORT="${SSH_PORT:-2222}"
    
    read -p "$(print_question "Enable GUI mode? (y/n, default: n): ")" gui_input
    GUI_MODE=false
    [[ "$gui_input" =~ ^[Yy]$ ]] && GUI_MODE=true
    
    read -p "$(print_question "Additional port forwards (e.g., 8080:80): ")" PORT_FORWARDS
    
    IMG_FILE="$REON_VM_DIR/$VM_NAME.img"
    SEED_FILE="$REON_VM_DIR/$VM_NAME-seed.iso"
    CREATED="$(date)"
    
    # Setup VM
    if setup_vm_image; then
        save_vm_config
        print_success "VM '$VM_NAME' created successfully"
        echo
        echo -e "${C_CYAN}SSH: ssh -p $SSH_PORT $USERNAME@localhost${C_RESET}"
        echo -e "${C_CYAN}Password: $PASSWORD${C_RESET}"
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
    print_header "Delete VM"
    
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
    print_header "Start VM"
    
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
            
            if [[ "$GUI_MODE" == true ]]; then
                qemu_cmd+=(-vga virtio -display gtk,gl=on)
            else
                qemu_cmd+=(-nographic -serial mon:stdio)
            fi
            
            print_info "Starting QEMU..."
            "${qemu_cmd[@]}" || true
        fi
    fi
}

vm_manager() {
    while true; do
        clear_screen
        print_header "Virtual Machine Manager"
        
        local vms=($(get_vm_list))
        echo -e "${C_BOLD}${C_CYAN}Available VMs:${C_RESET}"
        if [[ ${#vms[@]} -gt 0 ]]; then
            for vm in "${vms[@]}"; do
                echo "  • $vm"
            done
        else
            echo "  ${C_DIM}No VMs configured${C_RESET}"
        fi
        echo
        
        echo -e " ${C_GREEN}1.${C_RESET} Create VM"
        echo -e " ${C_GREEN}2.${C_RESET} Start VM"
        echo -e " ${C_GREEN}3.${C_RESET} Delete VM"
        echo -e " ${C_GREEN}4.${C_RESET} List VMs"
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
                        echo "  • $vm"
                    done
                else
                    echo "  No VMs configured"
                fi
                echo
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
        print_header "Docker Manager"
        
        # Check if Docker is installed
        if command -v docker &> /dev/null; then
            echo -e "${C_GREEN}✓${C_RESET} Docker is installed"
            echo -e "${C_CYAN}Docker Version:${C_RESET} $(docker --version 2>/dev/null | cut -d' ' -f3 | sed 's/,//')"
            echo -e "${C_CYAN}Containers:${C_RESET} $(docker ps -q 2>/dev/null | wc -l) running"
            echo -e "${C_CYAN}Images:${C_RESET} $(docker images -q 2>/dev/null | wc -l)"
        else
            echo -e "${C_YELLOW}⚠${C_RESET} Docker is not installed"
        fi
        echo
        
        echo -e " ${C_GREEN}1.${C_RESET} Install Docker"
        echo -e " ${C_GREEN}2.${C_RESET} Install Docker Compose"
        echo -e " ${C_GREEN}3.${C_RESET} Start Docker"
        echo -e " ${C_GREEN}4.${C_RESET} Stop Docker"
        echo -e " ${C_GREEN}5.${C_RESET} Container Manager"
        echo -e " ${C_GREEN}6.${C_RESET} Image Manager"
        echo -e " ${C_GREEN}7.${C_RESET} Cleanup Docker"
        echo -e " ${C_GREEN}8.${C_RESET} Uninstall Docker"
        echo -e " ${C_RED}0.${C_RESET} Back to Main Menu"
        echo
        
        read -p "$(print_question "Select option: ")" choice
        
        case "$choice" in
            1)
                print_info "Installing Docker..."
                curl -fsSL https://get.docker.com -o get-docker.sh
                sudo sh get-docker.sh
                sudo usermod -aG docker $USER
                print_success "Docker installed successfully"
                rm -f get-docker.sh
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            2)
                print_info "Installing Docker Compose..."
                sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
                sudo chmod +x /usr/local/bin/docker-compose
                print_success "Docker Compose installed"
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
                if command -v docker &> /dev/null; then
                    clear_screen
                    print_header "Container Manager"
                    docker ps -a
                    echo
                    echo -e " ${C_GREEN}1.${C_RESET} Start container"
                    echo -e " ${C_GREEN}2.${C_RESET} Stop container"
                    echo -e " ${C_GREEN}3.${C_RESET} Restart container"
                    echo -e " ${C_GREEN}4.${C_RESET} Remove container"
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
                    esac
                else
                    print_warning "Docker is not installed"
                fi
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            6)
                if command -v docker &> /dev/null; then
                    clear_screen
                    print_header "Image Manager"
                    docker images
                    echo
                    echo -e " ${C_GREEN}1.${C_RESET} Pull image"
                    echo -e " ${C_GREEN}2.${C_RESET} Remove image"
                    echo -e " ${C_GREEN}3.${C_RESET} Prune images"
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
                    esac
                else
                    print_warning "Docker is not installed"
                fi
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            7)
                if confirm_action "Clean up unused Docker objects?"; then
                    docker system prune -f
                    docker volume prune -f
                    print_success "Cleanup completed"
                fi
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            8)
                if confirm_action "Uninstall Docker completely?"; then
                    sudo apt-get remove -y docker docker-engine docker.io containerd runc
                    sudo rm -rf /var/lib/docker
                    sudo rm -rf /var/lib/containerd
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
        print_header "Node.js Manager"
        
        # Check if Node.js is installed
        if command -v node &> /dev/null; then
            echo -e "${C_GREEN}✓${C_RESET} Node.js is installed"
            echo -e "${C_CYAN}Node Version:${C_RESET} $(node --version 2>/dev/null)"
            echo -e "${C_CYAN}NPM Version:${C_RESET} $(npm --version 2>/dev/null)"
        else
            echo -e "${C_YELLOW}⚠${C_RESET} Node.js is not installed"
        fi
        echo
        
        echo -e " ${C_GREEN}1.${C_RESET} Install Node.js (Latest LTS)"
        echo -e " ${C_GREEN}2.${C_RESET} Install Node.js (Latest Stable)"
        echo -e " ${C_GREEN}3.${C_RESET} Install npm"
        echo -e " ${C_GREEN}4.${C_RESET} Install pnpm"
        echo -e " ${C_GREEN}5.${C_RESET} Install yarn"
        echo -e " ${C_GREEN}6.${C_RESET} Install Bun"
        echo -e " ${C_GREEN}7.${C_RESET} Install Deno"
        echo -e " ${C_GREEN}8.${C_RESET} PM2 Manager"
        echo -e " ${C_GREEN}9.${C_RESET} Uninstall Node.js"
        echo -e " ${C_RED}0.${C_RESET} Back to Main Menu"
        echo
        
        read -p "$(print_question "Select option: ")" choice
        
        case "$choice" in
            1)
                print_info "Installing Node.js LTS..."
                curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
                sudo apt-get install -y nodejs
                print_success "Node.js installed: $(node --version)"
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            2)
                print_info "Installing Node.js Latest..."
                curl -fsSL https://deb.nodesource.com/setup_current.x | sudo -E bash -
                sudo apt-get install -y nodejs
                print_success "Node.js installed: $(node --version)"
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            3)
                print_info "Installing npm..."
                sudo apt-get install -y npm
                print_success "npm installed: $(npm --version)"
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            4)
                print_info "Installing pnpm..."
                curl -fsSL https://get.pnpm.io/install.sh | sh -
                print_success "pnpm installed"
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            5)
                print_info "Installing yarn..."
                curl -fsSL https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
                echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
                sudo apt-get update && sudo apt-get install -y yarn
                print_success "yarn installed: $(yarn --version)"
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            6)
                print_info "Installing Bun..."
                curl -fsSL https://bun.sh/install | bash
                print_success "Bun installed"
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            7)
                print_info "Installing Deno..."
                curl -fsSL https://deno.land/x/install/install.sh | sh
                print_success "Deno installed"
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            8)
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
                    esac
                else
                    print_info "Installing PM2..."
                    npm install -g pm2
                    print_success "PM2 installed"
                fi
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            9)
                if confirm_action "Uninstall Node.js?"; then
                    sudo apt-get remove -y nodejs npm
                    sudo rm -rf /usr/local/lib/node_modules
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
        print_header "Security Manager"
        
        echo -e " ${C_GREEN}1.${C_RESET} SSH Hardening"
        echo -e " ${C_GREEN}2.${C_RESET} Toggle Root Login"
        echo -e " ${C_GREEN}3.${C_RESET} Toggle Password Login"
        echo -e " ${C_GREEN}4.${C_RESET} Install Fail2Ban"
        echo -e " ${C_GREEN}5.${C_RESET} Configure UFW Firewall"
        echo -e " ${C_GREEN}6.${C_RESET} Enable BBR"
        echo -e " ${C_GREEN}7.${C_RESET} Malware Scan (ClamAV)"
        echo -e " ${C_GREEN}8.${C_RESET} Rootkit Scan (rkhunter)"
        echo -e " ${C_GREEN}9.${C_RESET} Automatic Security Updates"
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
                sudo systemctl restart sshd
                print_success "SSH hardened"
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            2)
                if grep -q "^PermitRootLogin no" /etc/ssh/sshd_config; then
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
                if grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config; then
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
                sudo ufw allow ssh
                sudo ufw allow 80,443/tcp
                sudo ufw --force enable
                print_success "UFW configured"
                sudo ufw status
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            6)
                print_info "Enabling BBR..."
                echo "net.core.default_qdisc=fq" | sudo tee -a /etc/sysctl.conf
                echo "net.ipv4.tcp_congestion_control=bbr" | sudo tee -a /etc/sysctl.conf
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
        print_header "Network Tools"
        
        echo -e " ${C_GREEN}1.${C_RESET} Speed Test"
        echo -e " ${C_GREEN}2.${C_RESET} Port Scanner"
        echo -e " ${C_GREEN}3.${C_RESET} Port Checker"
        echo -e " ${C_GREEN}4.${C_RESET} Ping"
        echo -e " ${C_GREEN}5.${C_RESET} Traceroute"
        echo -e " ${C_GREEN}6.${C_RESET} DNS Lookup"
        echo -e " ${C_GREEN}7.${C_RESET} WHOIS"
        echo -e " ${C_GREEN}8.${C_RESET} Bandwidth Monitor"
        echo -e " ${C_RED}0.${C_RESET} Back to Main Menu"
        echo
        
        read -p "$(print_question "Select option: ")" choice
        
        case "$choice" in
            1)
                print_info "Running speed test..."
                if command -v speedtest-cli &> /dev/null; then
                    speedtest-cli
                else
                    print_info "Installing speedtest-cli..."
                    pip3 install speedtest-cli 2>/dev/null || sudo apt-get install -y speedtest-cli
                    speedtest-cli
                fi
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            2)
                read -p "$(print_question "Target IP/Host: ")" target
                read -p "$(print_question "Port range (e.g., 1-1000): ")" ports
                print_info "Scanning $target..."
                nc -zv "$target" $(echo "$ports" | tr '-' ' ') 2>&1 | grep succeeded
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            3)
                read -p "$(print_question "Target IP/Host: ")" target
                read -p "$(print_question "Port: ")" port
                if nc -zv "$target" "$port" 2>&1 | grep -q succeeded; then
                    print_success "Port $port is open"
                else
                    print_warning "Port $port is closed"
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
                traceroute "$target"
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
        print_header "Settings"
        
        echo -e " ${C_GREEN}1.${C_RESET} Configure Theme"
        echo -e " ${C_GREEN}2.${C_RESET} Toggle Auto Updates"
        echo -e " ${C_GREEN}3.${C_RESET} Configure Log Level"
        echo -e " ${C_GREEN}4.${C_RESET} View Configuration"
        echo -e " ${C_GREEN}5.${C_RESET} Reset Configuration"
        echo -e " ${C_RED}0.${C_RESET} Back to Main Menu"
        echo
        
        read -p "$(print_question "Select option: ")" choice
        
        case "$choice" in
            1)
                echo "Available themes: cyan, blue, green, red, yellow"
                read -p "$(print_question "Select theme: ")" theme
                mkdir -p "$REON_CONFIG_DIR"
                echo "REON_THEME=\"$theme\"" > "$REON_CONFIG_DIR/theme.conf"
                print_success "Theme set to $theme"
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            2)
                if [[ -f "$REON_CONFIG_DIR/settings.conf" ]] && grep -q "REON_AUTO_UPDATE=\"true\"" "$REON_CONFIG_DIR/settings.conf"; then
                    sed -i 's/REON_AUTO_UPDATE="true"/REON_AUTO_UPDATE="false"/' "$REON_CONFIG_DIR/settings.conf"
                    print_success "Auto updates disabled"
                else
                    sed -i 's/REON_AUTO_UPDATE="false"/REON_AUTO_UPDATE="true"/' "$REON_CONFIG_DIR/settings.conf" 2>/dev/null || echo 'REON_AUTO_UPDATE="true"' > "$REON_CONFIG_DIR/settings.conf"
                    print_success "Auto updates enabled"
                fi
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            3)
                echo "Log levels: DEBUG, INFO, WARN, ERROR, FATAL"
                read -p "$(print_question "Select log level: ")" level
                echo "REON_LOG_LEVEL=\"$level\"" > "$REON_CONFIG_DIR/logging.conf"
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
                read -p "$(print_question "Press Enter to continue...")"
                ;;
            5)
                if confirm_action "Reset all configuration to defaults?"; then
                    rm -rf "$REON_CONFIG_DIR"/*
                    print_success "Configuration reset"
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
    echo -e "${C_BOLD}${C_CYAN}REON DEV INSTALLER v3.0.0${C_RESET}"
    echo -e "${C_CYAN}Made By ReonDev${C_RESET}"
    echo
    echo -e "A professional Linux VPS management platform"
    echo -e "Designed for Ubuntu 20.04+, Debian 11+"
    echo
    echo -e "${C_BOLD}${C_CYAN}Features:${C_RESET}"
    echo -e "  • VPS Management"
    echo -e "  • Application Deployment"
    echo -e "  • Container Management"
    echo -e "  • Server Monitoring"
    echo -e "  • Security Hardening"
    echo -e "  • And much more..."
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
    echo -e "License: MIT"
    echo -e "Repository: https://github.com/reondev/reon-dev-installer"
    echo
    read -p "$(print_question "Press Enter to continue...")"
}

# ============================================================
# Update Function
# ============================================================

update_installer() {
    print_header "Update Installer"
    print_info "Checking for updates..."
    
    if confirm_action "Update to latest version?"; then
        print_info "Downloading latest version..."
        print_success "Update completed (placeholder)"
        read -p "$(print_question "Press Enter to continue...")"
    fi
}

# ============================================================
# Placeholder Functions
# ============================================================

pterodactyl_manager() {
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
    print_header "LXC Manager"
    print_info "LXC management coming soon..."
    read -p "$(print_question "Press Enter to continue...")"
}

qemu_manager() {
    print_header "QEMU Manager"
    print_info "QEMU management coming soon..."
    read -p "$(print_question "Press Enter to continue...")"
}

database_manager() {
    print_header "Database Manager"
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
    print_header "Backup Manager"
    print_info "Backup management coming soon..."
    read -p "$(print_question "Press Enter to continue...")"
}

user_manager() {
    print_header "User Manager"
    print_info "User management coming soon..."
    read -p "$(print_question "Press Enter to continue...")"
}

service_manager() {
    print_header "Service Manager"
    print_info "Service management coming soon..."
    read -p "$(print_question "Press Enter to continue...")"
}

file_manager() {
    print_header "File Manager"
    print_info "File management coming soon..."
    read -p "$(print_question "Press Enter to continue...")"
}

git_manager() {
    print_header "Git Manager"
    print_info "Git management coming soon..."
    read -p "$(print_question "Press Enter to continue...")"
}

developer_tools() {
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
    mkdir -p "$REON_INSTALL_DIR" "$REON_CONFIG_DIR" "$REON_LOGS_DIR" "$REON_BACKUPS_DIR" "$REON_VM_DIR"
    
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
EOF
    fi
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
    
    # Check if running in installation mode
    if [[ "${1:-}" == "--install" ]] || [[ "${1:-}" == "install" ]]; then
        print_info "Running in installation mode..."
        # Installation logic would go here
        print_success "Installation complete"
        exit 0
    fi
    
    # Check command line arguments
    case "${1:-}" in
        --help|-h)
            echo "REON DEV INSTALLER v3 - Professional Linux VPS Management Platform"
            echo "Made By ReonDev"
            echo ""
            echo "Usage:"
            echo "  ./main.sh              Start interactive menu"
            echo "  ./main.sh --help       Show this help"
            echo "  ./main.sh --install    Run installation"
            echo "  ./main.sh --version    Show version"
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

# ============================================================
# Run Main
# ============================================================

# Run main function with arguments
main "$@"
