#!/bin/bash
# ===========================================================
# LOVExREON Terminal Control Panel
# Mode By - Reon
# ===========================================================

# --- COLORS ---
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
WHITE='\033[1;37m'
NC='\033[0m'

# ===================== AUTO COLORS =====================
COLORS=(
'\033[1;31m' '\033[1;32m' '\033[1;33m' '\033[1;34m'
'\033[1;35m' '\033[1;36m'
'\033[38;5;208m' '\033[38;5;205m' '\033[38;5;51m'
)
NC='\033[0m'
BOLD='\033[1m'
GRAY='\033[38;5;245m'

rand_color(){ echo -e "${COLORS[$RANDOM % ${#COLORS[@]}]}"; }
pause(){ echo -e "${GRAY}"; read -p "Press Enter to continue..." x; echo -e "${NC}"; }

# ===================== BANNER =====================
banner(){
clear
C1=$(rand_color); C2=$(rand_color); C3=$(rand_color)
echo -e "${C1}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
echo -e "${C2} ██████╗ ███████╗ ██████╗ ███╗   ██╗${NC}"
echo -e "${C2} ██╔══██╗██╔════╝██╔═══██╗████╗  ██║${NC}"
echo -e "${C2} ██████╔╝█████╗  ██║   ██║██╔██╗ ██║${NC}"
echo -e "${C2} ██╔══██╗██╔══╝  ██║   ██║██║╚██╗██║${NC}"
echo -e "${C2} ██║  ██║███████╗╚██████╔╝██║ ╚████║${NC}"
echo -e "${C2} ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═╝  ╚═══╝ ${NC}"
echo
echo -e "${C3}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "                 ${BOLD}Made By - Reon${NC}" ${C2}2026
echo -e "${C1}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
}
# ===================== PANEL MENU =====================
panel_menu(){
while true; do banner
echo -e "${C3}────────────── PANEL MENU ──────────────${NC}"
echo -e "${YELLOW} 1)${WHITE} FeatherPanel"
echo -e "${YELLOW} 2)${WHITE} Pterodactyl"
echo -e "${YELLOW} 3)${WHITE} Jexactyl v3"
echo -e "${YELLOW} 4)${WHITE} Jexpanel v4"
echo -e "${YELLOW} 5)${WHITE} Dashboard v3"
echo -e "${YELLOW} 6)${WHITE} Dashboard v4"
echo -e "${YELLOW} 7)${WHITE} Payment Gateway"
echo -e "${YELLOW} 8)${WHITE} CtrlPanel"
echo -e "${YELLOW} 9)${WHITE} CPanel"
echo -e "${YELLOW}10)${WHITE} Tools Panel (External)"
echo -e "${YELLOW}11)${WHITE} Back"
echo -e "${C3}─────────────────────────────────────────${NC}"
read -p "Select → " p

case $p in
 1) curl -sSL https://get.featherpanel.com/beta.sh | bash ;;
 2) bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/Uninstall/unPterodactyl.sh) ;;
 3) bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/panel/Jexactyl.sh) ;;
 4) bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/Uninstall/unJexactyl.sh) ;;
 5) bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/Uninstall/undash-3.sh) ;;
 6) bash <(curl -s https://github.com/nobita329/The-Coding-Hub/raw/refs/heads/main/srv/Uninstall/dash-v4.sh) ;;
 7) bash <(curl -s https://github.com/nobita329/The-Coding-Hub/raw/refs/heads/main/srv/Uninstall/unPaymenter.sh) ;;
 8) bash <(curl -s https://raw.githubusercontent.com/nobita54/-150/refs/heads/main/Uninstall/unCtrlPanel.sh) ;;
 9) bash <(curl -s https://raw.githubusercontent.com/yourlink/cpanel.sh) ;;
 10) bash <(curl -s https://raw.githubusercontent.com/yourlink/t-panel.sh) ;;
 11) break;;
 *) echo -e "${RED}Invalid Option${NC}"; pause;;
esac
done
}

# ===================== TOOLS MENU =====================
tools_menu(){
while true; do banner
echo -e "${BLUE}────────────── TOOLS MENU ──────────────${NC}"
echo -e "${YELLOW} 1)${WHITE} Root Access"
echo -e "${YELLOW} 2)${WHITE} Tailscale"
echo -e "${YELLOW} 3)${WHITE} Cloudflare DNS"
echo -e "${YELLOW} 4)${WHITE} System Info"
echo -e "${YELLOW} 5)${WHITE} Vps Run"
echo -e "${YELLOW} 6)${WHITE} Port Forward"
echo -e "${YELLOW} 7)${WHITE} RDP Installer"
echo -e "${YELLOW} 8)${WHITE} Back"
echo -e "${BLUE}────────────────────────────────────────${NC}"
read -p "Select → " t

case $t in
 1) bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/tools/root.sh) ;;
 2) bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/tools/Tailscale.sh) ;;
 3) bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/tools/cloudflare.sh) ;;
 4) bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/tools/SYSTEM.sh) ;;
 5) bash <(curl -s https://raw.githubusercontent.com/nobita54/-150/refs/heads/main/tools/vps.sh) ;;
 6) bash <(curl -s https://raw.githubusercontent.com/yourlink/portforward.sh) ;;
 7) bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/tools/rdp.sh) ;;
 8) break;;
 *) echo -e "${RED}Invalid${NC}"; pause;;
esac
done
}

# ===================== THEME MENU =====================
theme_menu(){
while true; do banner
echo -e "${PURPLE}────────────── THEME MENU ──────────────${NC}"
echo -e "${YELLOW} 1)${WHITE} Blueprint Theme"
echo -e "${YELLOW} 2)${WHITE} Change Theme"
echo -e "${YELLOW} 3)${WHITE} Uninstall Theme"
echo -e "${YELLOW} 4)${WHITE} Back"
echo -e "${PURPLE}────────────────────────────────────────${NC}"
read -p "Select → " th

case $th in
 1) bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/thame/ch.sh) ;;
 2) bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/thame/chang.sh) ;;
 3) bash <(curl -s https://raw.githubusercontent.com/yourlink/theme_uninstall.sh) ;;
 4) break;;
 *) echo -e "${RED}Invalid${NC}"; pause;;
esac
done
}

# ===================== MAIN MENU =====================
main_menu(){
while true; do banner
echo -e "${CYAN}────────────── MAIN MENU ──────────────${NC}"
echo -e "${YELLOW} 1)${WHITE} Vps Run"
echo -e "${YELLOW} 2)${WHITE} Panel"
echo -e "${YELLOW} 3)${WHITE} Wings"
echo -e "${YELLOW} 4)${WHITE} Tools"
echo -e "${YELLOW} 5)${WHITE} Theme"
echo -e "${YELLOW} 6)${WHITE} System"
echo -e "${YELLOW} 7)${WHITE} External"
echo -e "${YELLOW} 8)${WHITE} Exit"
echo -e "${CYAN}──────────────────────────────────────${NC}"
read -p "Select → " c

case $c in
 1) bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/vm/vps.sh) ;;
 2) panel_menu ;;
 3) bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/wings/www.sh) ;;
 4) tools_menu ;;
 5) theme_menu ;;
 6) bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/menu/System1.sh) ;;
 7) bash <(curl -s https://raw.githubusercontent.com/nobita329/The-Coding-Hub/refs/heads/main/srv/External/INFRA.sh) ;;
 8) echo -e "${GREEN}Exiting — CODING HUB by REON${NC}"; exit ;;
 *) echo -e "${RED}Invalid${NC}"; pause ;;
esac
done
}

main_menu
