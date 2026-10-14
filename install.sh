#!/usr/bin/env bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Wajib dijalankan sebagai root!"
  exit 1
fi

echo "[*] Update dependensi sistem..."
apt-get update -y > /dev/null
apt-get install -y curl python3 python3-pip ufw > /dev/null

INSTALL_DIR="/opt/vpn-agent"
mkdir -p "$INSTALL_DIR"

echo "[*] Mengunduh Agent..."
# GANTI USERNAME DAN REPO DENGAN MILIK ANDA
curl -sL -o "$INSTALL_DIR/agent.py" https://raw.githubusercontent.com/username/vps-agent-tunnel/main/agent.py

apt-get install -y python3-fastapi python3-uvicorn

AGENT_TOKEN=$(openssl rand -hex 16)
AGENT_PORT=5050

cat <<EOF > "$INSTALL_DIR/.env"
AGENT_PORT=$AGENT_PORT
AGENT_SECRET=$AGENT_TOKEN
EOF

cat <<EOF > /etc/systemd/system/vpn-agent.service
[Unit]
Description=VPN Agent Tunnel Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
EnvironmentFile=$INSTALL_DIR/.env
ExecStart=/usr/bin/python3 -m uvicorn agent:app --host 0.0.0.0 --port 5050
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now vpn-agent.service > /dev/null 2>&1
ufw allow 5050/tcp > /dev/null 2>&1 || true

SERVER_IP=$(curl -s https://api.ipify.org || hostname -I | awk '{print $1}')

clear
echo "=================================================="
echo "           VPN AGENT BERHASIL AKTIF               "
echo "=================================================="
echo "Salin kredensial ini ke aplikasi Android Anda:"
echo "HOST / IP  : $SERVER_IP"
echo "PORT       : 5050"
echo "TOKEN      : $AGENT_TOKEN"
echo "=================================================="
