#!/bin/bash

SSH_USER="injektor"
SSH_PASS="changeme123"
DEFAULT_PORT=2222

# Find a free port if 22 is in use
is_port_free() {
  ! ss -tulpn | grep -q ":$1 "
}

SSH_PORT=$DEFAULT_PORT
until is_port_free $SSH_PORT; do
  SSH_PORT=$((SSH_PORT+1))
  if [ $SSH_PORT -ge 65000 ]; then
    echo "No free port found!"
    exit 1
  fi
done

sudo apt update
sudo apt install -y openssh-server

if ! id "$SSH_USER" >/dev/null 2>&1; then
  sudo useradd -m -s /bin/bash "$SSH_USER"
  echo "$SSH_USER:$SSH_PASS" | sudo chpasswd
  sudo usermod -aG sudo "$SSH_USER"
fi

# Set SSH to new port
sudo sed -i "s/^#Port .*/Port $SSH_PORT/;s/^Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config

# Enable password authentication
sudo sed -i "s/^#PasswordAuthentication yes/PasswordAuthentication yes/;s/^PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config

# Restart SSH
sudo systemctl restart ssh

echo "===================="
echo "SSH server is running!"
echo "Use these in HTTP Injector or Netmod:"
echo "Host: <YOUR WEBHOOK RELAY PUBLIC ENDPOINT>"
echo "Port: $SSH_PORT"
echo "Username: $SSH_USER"
echo "Password: $SSH_PASS"
echo "===================="
