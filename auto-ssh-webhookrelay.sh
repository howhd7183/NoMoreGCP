#!/bin/bash

set -e

# === CONFIGURATION ===
SSH_USER="injektor"
SSH_PASS="changeme123"
DEFAULT_SSH_PORT=2222

# --- 1. Install OpenSSH Server ---
sudo apt update
sudo apt install -y openssh-server curl

# --- 2. Find a free SSH port ---
is_port_free() {
  ! ss -tulpn | grep -q ":$1 "
}
SSH_PORT=$DEFAULT_SSH_PORT
until is_port_free $SSH_PORT; do
  SSH_PORT=$((SSH_PORT+1))
  if [ $SSH_PORT -ge 65000 ]; then
    echo "No free port found!"
    exit 1
  fi
done

# --- 3. Create SSH user if needed ---
if ! id "$SSH_USER" >/dev/null 2>&1; then
  sudo useradd -m -s /bin/bash "$SSH_USER"
  echo "$SSH_USER:$SSH_PASS" | sudo chpasswd
  sudo usermod -aG sudo "$SSH_USER"
fi

# --- 4. Configure SSH ---
sudo sed -i "s/^#Port .*/Port $SSH_PORT/;s/^Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
sudo sed -i "s/^#PasswordAuthentication yes/PasswordAuthentication yes/;s/^PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config
sudo systemctl restart ssh

# --- 5. Download and install webhook-relay CLI ---
if ! command -v webhook-relay &>/dev/null; then
  curl -LO https://github.com/webhookrelay/cli/releases/latest/download/webhook-relay-linux-amd64
  chmod +x webhook-relay-linux-amd64
  sudo mv webhook-relay-linux-amd64 /usr/local/bin/webhook-relay
fi

# --- 6. Prompt for webhookrelay credentials ---
echo -n "Enter your Webhook Relay KEY: "
read -r RELAY_KEY
echo -n "Enter your Webhook Relay SECRET: "
read -r RELAY_SECRET

# --- 7. Login to webhook-relay ---
webhook-relay login -k "$RELAY_KEY" -t "$RELAY_SECRET"

# --- 8. Start the tunnel (in background) ---
TUNNEL_LOG=/tmp/whrelay-tunnel.log
nohup webhook-relay tunnel --proto tcp --port "$SSH_PORT" > "$TUNNEL_LOG" 2>&1 &

sleep 3

# --- 9. Extract public endpoint from log ---
PUBADDR=$(grep -Eo "tcp://[a-zA-Z0-9\.\-]+:[0-9]+" "$TUNNEL_LOG" | head -n1 | sed 's/tcp:\/\///')

echo "=============================================="
echo " SSH + Webhook Relay tunnel is running!"
echo ""
echo " Use these credentials in HTTP Injector or Netmod:"
echo "  Host    : $PUBADDR"
echo "  Port    : $SSH_PORT"
echo "  Username: $SSH_USER"
echo "  Password: $SSH_PASS"
echo ""
echo " If no Host is shown above, check '$TUNNEL_LOG' for details."
echo "=============================================="