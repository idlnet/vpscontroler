#!/usr/bin/env bash
set -e

INSTALL_DIR="/opt/vpn-agent"
mkdir -p "$INSTALL_DIR"

echo "[*] Memuat turun agent..."
curl -sL -o "$INSTALL_DIR/agent.py" https://raw.githubusercontent.com/idlnet/vpscontroler/main/agent.py

# Jana token keselamatan secara rawak
AGENT_TOKEN=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)
AGENT_PORT=5050

cat <<EOF > "$INSTALL_DIR/.env"
AGENT_PORT=$AGENT_PORT
AGENT_SECRET=$AGENT_TOKEN
EOF

# Pasang service systemd menggunakan binary Python standard
cat <<EOF > /etc/systemd/system/vpn-agent.service
[Unit]
Description=VPN Agent Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
EnvironmentFile=$INSTALL_DIR/.env
ExecStart=/usr/bin/python3 $INSTALL_DIR/agent.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now vpn-agent.service > /dev/null 2>&1
systemctl restart vpn-agent.service

# Buka akses port firewall
ufw allow 5050/tcp > /dev/null 2>&1 || true
iptables -I INPUT -p tcp --dport 5050 -j ACCEPT > /dev/null 2>&1 || true

SERVER_IP=$(curl -s https://api.ipify.org || hostname -I | awk '{print $1}')

clear
echo "=================================================="
echo "           VPN AGENT BERJAYA DIPASANG             "
echo "=================================================="
echo "HOST / IP  : $SERVER_IP"
echo "PORT       : 5050"
echo "TOKEN      : $AGENT_TOKEN"
echo "=================================================="
