#!/bin/bash

# --- Settings ---
SSH_USER="injektor"
SSH_PASS="changeme123"
DEFAULT_PORT=2222
RELAY_BIN_URL="https://github.com/webhookrelay/relay/releases/latest/download/relay-linux-amd64"
CONFIG_FILE="/etc/relay/config.yaml"
RELAY_BIN="/usr/local/bin/relay"

echo
echo "=== Webhook Relay SSH Tunnel (Service) Auto-Installer ==="
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

sudo systemctl restart ssh

# 6. Install relay binary
echo "Installing relay binary..."
sudo rm -f $RELAY_BIN
curl -LO $RELAY_BIN_URL
chmod +x relay-linux-amd64
sudo mv relay-linux-amd64 $RELAY_BIN

# 7. Setup relay config
echo
echo "Please enter your Webhook Relay KEY:"
read -r RELAY_KEY
echo "Please enter your Webhook Relay SECRET:"
read -r RELAY_SECRET

sudo mkdir -p /etc/relay
sudo tee $CONFIG_FILE > /dev/null <<EOF
auth:
  key: $RELAY_KEY
  secret: $RELAY_SECRET
tunnels:
  - name: ssh-tunnel
    protocol: tcp
    destination: 127.0.0.1:$SSH_PORT
    port: $SSH_PORT
EOF

# 8. Install and start relay as a service
echo "Installing relay service..."
sudo $RELAY_BIN service install -c $CONFIG_FILE --user $(whoami)
sudo $RELAY_BIN service start

echo
echo "======================================================"
echo "SSH server is running!"
echo "Use these in HTTP Injector or Netmod:"
echo "    Host: (Webhook Relay public endpoint, see dashboard)"
echo "    Port: $SSH_PORT"
echo "    Username: $SSH_USER"
echo "    Password: $SSH_PASS"
echo "------------------------------------------------------"
echo "Check your Webhook Relay dashboard for your public endpoint."
echo "Relay service logs: journalctl -u relay.service"
echo "======================================================"
