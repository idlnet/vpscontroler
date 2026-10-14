#!/usr/bin/env bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Wajib dijalankan sebagai root!"
  exit 1
fi

echo "[*] Membersihkan repository bermasalah jika ada..."
rm -f /etc/apt/sources.list.d/*haproxy* 2>/dev/null || true

echo "[*] Update dependensi sistem..."
apt-get update -y || true
apt-get install -y curl python3 python3-pip ufw iptables > /dev/null 2>&1

INSTALL_DIR="/opt/vpn-agent"
mkdir -p "$INSTALL_DIR"

echo "[*] Mengunduh Agent..."
AGENT_URL="https://raw.githubusercontent.com/idlnet/vpscontroler/main/agent.py"
curl -sL -f -o "$INSTALL_DIR/agent.py" "$AGENT_URL" || {
  echo "[!] Gagal mengunduh agent.py dari GitHub! Pastikan file agent.py sudah di-push ke branch main."
  exit 1
}

# Verifikasi isi file bukan teks 404
if grep -q "404: Not Found" "$INSTALL_DIR/agent.py"; then
  echo "[!] Error: File yang terunduh berisi teks 404 Not Found!"
  exit 1
fi

echo "[*] Menginstal library Python..."
pip3 install --break-system-packages fastapi uvicorn > /dev/null 2>&1 || pip3 install fastapi uvicorn > /dev/null 2>&1

AGENT_TOKEN=$(openssl rand -hex 16)
AGENT_PORT=5050

cat <<EOF > "$INSTALL_DIR/.env"
AGENT_PORT=$AGENT_PORT
AGENT_SECRET=$AGENT_TOKEN
EOF

# Perbaikan konfigurasi service systemd dengan path absolut
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
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now vpn-agent.service > /dev/null 2>&1
systemctl restart vpn-agent.service > /dev/null 2>&1

# Buka port firewall sistem
ufw allow 5050/tcp > /dev/null 2>&1 || true
iptables -I INPUT -p tcp --dport 5050 -j ACCEPT > /dev/null 2>&1 || true

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
