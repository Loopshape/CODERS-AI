#!/bin/bash
set -e

USER_NAME=${SUDO_USER:-$USER}

echo "=== Step 1: Backup & clean APT sources ==="
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
sudo rm -f /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources

echo "=== Step 2: Set main Debian sources ==="
sudo tee /etc/apt/sources.list > /dev/null <<'EOF'
deb [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] http://ftp.de.debian.org/debian bookworm main contrib non-free-firmware
deb [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] http://security.debian.org/debian-security bookworm-security main contrib non-free-firmware
deb [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] http://deb.debian.org/debian bookworm-updates main contrib non-free-firmware
EOF

echo "=== Step 3: Install Debian keyring ==="
sudo apt update
sudo apt install -y debian-archive-keyring curl git aria2

echo "=== Step 4: Add Docker repository ==="
sudo mkdir -p /usr/share/keyrings /etc/apt/sources.list.d
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null <<'EOF'
deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian bookworm stable
EOF

echo "=== Step 5: Update APT and install apt-fast & docker ==="
sudo apt update
sudo apt install -y docker.io

echo "=== Step 6: Apply WSL1 performance tweaks ==="
sudo tee /etc/apt/apt.conf.d/99parallel > /dev/null <<'EOF'
Acquire::http { Pipeline-Depth "200"; };
APT::Acquire::Retries "3";
Acquire::Retries "3";
EOF

sudo tee /etc/apt/apt.conf.d/99translations > /dev/null <<'EOF'
Acquire::Languages "none";
EOF

echo "=== Step 7: Add user to docker group ==="
sudo usermod -aG docker $USER_NAME

echo "=== Step 8: Create Docker data folder for WSL1 stability ==="
DOCKER_DATA="/home/$USER_NAME/docker-data"
mkdir -p $DOCKER_DATA
sudo chown -R $USER_NAME:$USER_NAME $DOCKER_DATA

echo "=== Step 9: Setup dockerd auto-start in .bashrc ==="
BASHRC_FILE="/home/$USER_NAME/.bashrc"
if ! grep -q "dockerd" "$BASHRC_FILE"; then
    cat >> "$BASHRC_FILE" <<EOF

# Auto-start Docker daemon in WSL1
if ! pgrep -x dockerd >/dev/null; then
    sudo dockerd --data-root $DOCKER_DATA > /tmp/dockerd.log 2>&1 &
fi
EOF
fi

echo "=== Step 10: Initial Docker test ==="
sudo dockerd --data-root $DOCKER_DATA --storage-driver=vfs &
sleep 5
docker run hello-world

echo "=== Setup complete! Log out and back in to apply docker group changes ==="

