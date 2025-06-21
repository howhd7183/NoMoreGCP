#!/bin/bash

# === Configuration ===
SSH_USER="injektor"
SSH_PASS="changeme123"
SSH_PORT="22"           # Change if you want a non-default port (e.g., 2222)

# === 1. Update and install OpenSSH Server ===
sudo apt update
sudo apt install -y openssh-server

# === 2. Create SSH user (if not exists) ===
if ! id "$SSH_USER" >/dev/null 2>&1; then
  sudo useradd -m -s /bin/bash "$SSH_USER"
  echo "$SSH_USER:$SSH_PASS" | sudo chpasswd
  sudo usermod -aG sudo "$SSH_USER"
  echo "User $SSH_USER created."
fi

# === 3. Set SSH to desired port ===
if ! grep -q "^Port $SSH_PORT" /etc/ssh/sshd_config; then
  sudo sed -i "s/^#Port 22/Port $SSH_PORT/g; s/^Port .*/Port $SSH_PORT/g" /etc/ssh/sshd_config
fi

# === 4. Allow password authentication ===
sudo sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/g; s/^PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config

# === 5. Restart SSH ===
sudo systemctl restart ssh
sudo systemctl enable ssh

# === 6. Output connection info ===
echo "============================================="
echo " SSH server is installed and running!"
echo " Connect using:"
echo "   Host: <YOUR WEBHOOK RELAY PUBLIC ENDPOINT>"
echo "   Port: $SSH_PORT"
echo "   Username: $SSH_USER"
echo "   Password: $SSH_PASS"
echo ""
echo " Use these in HTTP Injector or Netmod."
echo "============================================="

# === 7. Show SSH status ===
sudo systemctl status ssh --no-pager