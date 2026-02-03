#!/bin/bash

# Paqet Installer & Manager Script
# Created for Easy Installation

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check Root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}" 
   exit 1
fi

function get_net_info() {
    # Find Interface
    INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
    
    # Find Server IP
    SERVER_IP=$(ip -4 addr show $INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
    
    # Find Gateway IP & MAC
    GATEWAY_IP=$(ip route | grep default | awk '{print $3}' | head -n1)
    ping -c 1 $GATEWAY_IP > /dev/null 2>&1
    ROUTER_MAC=$(ip neigh show | grep $GATEWAY_IP | awk '{print $5}' | head -n1)
}

function install_paqet() {
    echo -e "${GREEN}Installing Paqet...${NC}"
    
    # 1. Install Dependencies
    apt-get update -q
    apt-get install -y libpcap-dev net-tools wget curl

    # 2. Get Port
    read -p "Enter Port to use (Default 8443): " PORT
    PORT=${PORT:-8443}

    # 3. Detect Info
    get_net_info
    if [ -z "$ROUTER_MAC" ]; then
        echo -e "${RED}Error: Could not detect Router MAC. Aborting.${NC}"
        return
    fi

    # 4. Download
    wget -q https://github.com/hanselime/paqet/releases/download/v0.1.0/paqet_linux_amd64_v1.tar.gz
    tar -xzf paqet_linux_amd64_v1.tar.gz
    chmod +x paqet
    mv paqet /usr/local/bin/
    rm paqet_linux_amd64_v1.tar.gz

    # 5. Config
    mkdir -p /etc/paqet
    cat > /etc/paqet/config.yaml <<EOF
role: "server"
log_level: "info"
ipv4:
  addr: "$SERVER_IP:$PORT"
  router_mac: "$ROUTER_MAC"
  interface: "$INTERFACE"
cipher:
  key: "mysecretkey"
  salt: "somesalt"
EOF

    # 6. Firewall
    iptables -A INPUT -p tcp --dport $PORT -j DROP
    apt-get install -y iptables-persistent 2>/dev/null

    # 7. Service
    cat > /etc/systemd/system/paqet.service <<EOF
[Unit]
Description=Paqet Server
After=network.target

[Service]
ExecStart=/usr/local/bin/paqet --config /etc/paqet/config.yaml
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable paqet
    systemctl start paqet

    echo -e "${GREEN}Installation Complete!${NC}"
    echo -e "${YELLOW}--------------------------------${NC}"
    echo -e "Server IP: ${SERVER_IP}"
    echo -e "Port: ${PORT}"
    echo -e "Secret Key: mysecretkey"
    echo -e "${YELLOW}--------------------------------${NC}"
    read -p "Press Enter to continue..."
}

function uninstall_paqet() {
    echo -e "${RED}Uninstalling Paqet...${NC}"
    systemctl stop paqet
    systemctl disable paqet
    rm /etc/systemd/system/paqet.service
    rm /usr/local/bin/paqet
    rm -rf /etc/paqet
    systemctl daemon-reload
    echo -e "${GREEN}Paqet removed successfully.${NC}"
    read -p "Press Enter to continue..."
}

function update_paqet() {
    echo -e "${GREEN}Updating Binary...${NC}"
    systemctl stop paqet
    wget -q https://github.com/hanselime/paqet/releases/download/v0.1.0/paqet_linux_amd64_v1.tar.gz
    tar -xzf paqet_linux_amd64_v1.tar.gz
    chmod +x paqet
    mv paqet /usr/local/bin/
    rm paqet_linux_amd64_v1.tar.gz
    systemctl start paqet
    echo -e "${GREEN}Update Complete.${NC}"
    read -p "Press Enter to continue..."
}

# Menu Loop
while true; do
    clear
    echo -e "${YELLOW}================================${NC}"
    echo -e "    Paqet Manager v1.0"
    echo -e "${YELLOW}================================${NC}"
    echo "1. Install Paqet"
    echo "2. Uninstall Paqet"
    echo "3. Update Paqet"
    echo "4. Re-install Paqet"
    echo "5. Exit"
    echo -e "${YELLOW}================================${NC}"
    read -p "Please enter a number [1-5]: " choice

    case $choice in
        1) install_paqet ;;
        2) uninstall_paqet ;;
        3) update_paqet ;;
        4) uninstall_paqet; install_paqet ;;
        5) exit 0 ;;
        *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
done
