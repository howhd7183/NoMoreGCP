#!/bin/bash

# --- CONFIGURABLE SECTION ---
SSH_USER="injektor"
SSH_PASS="changeme123"
DEFAULT_PORT=2222

echo
echo "=== Webhook Relay SSH Tunnel Auto-Installer ==="
echo

# 1. Find a free SSH port
is_port_free() {
  ! ss -tulpn 2>/dev/null | grep -q ":$1 "
}
SSH_PORT=$DEFAULT_PORT
until is_port_free $SSH_PORT; do
  SSH_PORT=$((SSH_PORT+1))
  if [ $SSH_PORT -ge 65000 ]; then
    echo "No free port found!"
    exit 1
  fi
done

# 2. Install SSH server
sudo apt update
sudo apt install -y openssh-server curl

# 3. Create SSH user if not exists
if ! id "$SSH_USER" >/dev/null 2>&1; then
  sudo useradd -m -s /bin/bash "$SSH_USER"
  echo "$SSH_USER:$SSH_PASS" | sudo chpasswd
  sudo usermod -aG sudo "$SSH_USER"
fi

# 4. Set SSH to chosen port
sudo sed -i "s/^#Port .*/Port $SSH_PORT/;s/^Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config

# 5. Enable password authentication
sudo sed -i "s/^#PasswordAuthentication yes/PasswordAuthentication yes/;s/^PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config

# 6. Restart SSH service
sudo systemctl restart ssh

# 7. Install Webhook Relay CLI
echo
echo "Installing Webhook Relay CLI..."
sudo rm -f /usr/local/bin/webhook-relay
curl -LO https://github.com/webhookrelay/cli/releases/latest/download/webhook-relay-linux-amd64
chmod +x webhook-relay-linux-amd64
sudo mv webhook-relay-linux-amd64 /usr/local/bin/webhook-relay

# 8. Authenticate Webhook Relay
echo
echo "Please enter your Webhook Relay KEY:"
read -r RELAY_KEY
echo "Please enter your Webhook Relay SECRET:"
read -r RELAY_SECRET

webhook-relay login -k "$RELAY_KEY" -t "$RELAY_SECRET"

# 9. Start webhook-relay TCP tunnel in background
echo
echo "Starting Webhook Relay TCP tunnel for SSH..."
nohup webhook-relay tunnel --proto tcp --port $SSH_PORT > webhook-relay-tunnel.log 2>&1 &

# 10. Print connection info
echo
echo "======================================================"
echo "SSH server is running!"
echo "Use these in HTTP Injector or Netmod:"
echo "    Host: (Webhook Relay public endpoint, see dashboard or below)"
echo "    Port: $SSH_PORT"
echo "    Username: $SSH_USER"
echo "    Password: $SSH_PASS"
echo "------------------------------------------------------"
echo "Check your Webhook Relay dashboard for your public endpoint."
echo "Or check 'webhook-relay-tunnel.log' for tunnel info:"
echo "    tail -f webhook-relay-tunnel.log"
echo "======================================================"
