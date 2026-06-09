#!/usr/bin/env bash
# =============================================================================
# SmartRoad — Ubuntu Server Hardening & Setup Script
# =============================================================================
# Run this script on a fresh Ubuntu Server (24.04 LTS recommended) as root.
#
# Usage:
#   chmod +x scripts/server-setup.sh
#   sudo ./scripts/server-setup.sh
#
# What this does:
#   1. Updates system packages
#   2. Configures a non-root sudo user (smartroad)
#   3. Hardens SSH (key-only auth, disable root login)
#   4. Sets up UFW firewall
#   5. Installs and configures Fail2Ban
#   6. Installs Docker + Docker Compose
#   7. Sets up automatic security updates
# =============================================================================

set -euo pipefail

# --- Config ------------------------------------------------------------------
NEW_USER="smartroad"
SSH_PORT="2222"              # Non-standard port reduces automated attack noise
DOCKER_COMPOSE_VERSION="v2.27.0"
# -----------------------------------------------------------------------------

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; }

# --- Check root --------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  err "This script must be run as root (use sudo)."
  exit 1
fi

echo ""
echo "=============================================="
echo "  SmartRoad — Server Setup"
echo "=============================================="
echo ""

# --- 1. System update --------------------------------------------------------
log "Updating system packages..."
apt-get update -qq && apt-get upgrade -y -qq
apt-get install -y -qq \
  curl wget git ufw fail2ban \
  unattended-upgrades apt-listchanges \
  htop net-tools ca-certificates gnupg lsb-release
log "System packages updated."

# --- 2. Create non-root user -------------------------------------------------
if id "$NEW_USER" &>/dev/null; then
  log "User '$NEW_USER' already exists."
else
  useradd -m -s /bin/bash -G sudo "$NEW_USER"
  passwd "$NEW_USER"
  log "User '$NEW_USER' created with sudo access."
fi

# --- 3. SSH Hardening --------------------------------------------------------
log "Hardening SSH configuration..."

# Change SSH port
sed -i "s/^#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
sed -i "s/^Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config

# Disable root login
sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config

# Key-only authentication
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# Disable empty passwords
sed -i 's/^#PermitEmptyPasswords no/PermitEmptyPasswords no/' /etc/ssh/sshd_config

# Use only SSH Protocol 2
sed -i 's/^#Protocol 2/Protocol 2/' /etc/ssh/sshd_config

# Limit login attempts
sed -i 's/^#MaxAuthTries 6/MaxAuthTries 3/' /etc/ssh/sshd_config
sed -i 's/^MaxAuthTries 6/MaxAuthTries 3/' /etc/ssh/sshd_config

# Set client alive interval
sed -i 's/^#ClientAliveInterval 0/ClientAliveInterval 300/' /etc/ssh/sshd_config
sed -i 's/^#ClientAliveCountMax 3/ClientAliveCountMax 2/' /etc/ssh/sshd_config

systemctl restart sshd
log "SSH hardened (port $SSH_PORT, key-only auth, root login disabled)."

warn "IMPORTANT: Before disconnecting, ensure your SSH key is added for user '$NEW_USER':"
warn "  sudo mkdir -p /home/$NEW_USER/.ssh"
warn "  sudo tee -a /home/$NEW_USER/.ssh/authorized_keys < ~/.ssh/id_ed25519.pub"
warn "  sudo chown -R $NEW_USER:$NEW_USER /home/$NEW_USER/.ssh"
warn "  sudo chmod 700 /home/$NEW_USER/.ssh && sudo chmod 600 /home/$NEW_USER/.ssh/authorized_keys"

# --- 4. UFW Firewall ---------------------------------------------------------
log "Configuring UFW firewall..."

ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# SSH on custom port
ufw allow "$SSH_PORT/tcp" comment "SSH (custom port)"

# HTTP/HTTPS for web services
ufw allow 80/tcp comment "HTTP"
ufw allow 443/tcp comment "HTTPS"

# GraphHopper API (internal)
ufw allow from 172.16.0.0/12 to any port 8989 comment "GraphHopper (Docker internal)"

# Cloudflare Tunnel (outbound-only, no extra ports needed)
# Prometheus / Grafana (internal only - behind Cloudflare Tunnel or VPN)
ufw allow 9090/tcp comment "Prometheus (internal)"
ufw allow 3001/tcp comment "Grafana (internal)"

# Rate limiting on SSH
ufw limit "$SSH_PORT/tcp" comment "SSH rate limit"

ufw --force enable
log "UFW firewall configured and enabled."

# --- 5. Fail2Ban -------------------------------------------------------------
log "Configuring Fail2Ban..."

cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = $SSH_PORT
logpath = %(sshd_log)s
maxretry = 3
bantime = 86400
EOF

systemctl enable fail2ban
systemctl restart fail2ban
log "Fail2Ban configured (SSH: 3 retries → 24h ban)."

# --- 6. Automatic Security Updates -------------------------------------------
log "Configuring automatic security updates..."

cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
  "${distro_id}:${distro_codename}-security";
  "${distro_id}ESMApps:${distro_codename}-apps-security";
  "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::AutoFixIntervals "7";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

systemctl enable unattended-upgrades
systemctl restart unattended-upgrades
log "Automatic security updates configured."

# --- 7. Docker ---------------------------------------------------------------
log "Installing Docker..."

if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com | bash
  usermod -aG docker "$NEW_USER"
  systemctl enable docker
  systemctl start docker
  log "Docker installed."
else
  log "Docker already installed."
fi

# --- 8. Docker Compose -------------------------------------------------------
log "Installing Docker Compose..."

if ! command -v docker-compose &>/dev/null; then
  curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
  log "Docker Compose installed."
else
  log "Docker Compose already installed."
fi

# --- 9. Swap configuration (for memory-constrained servers) ------------------
if ! swapon --show | grep -q .; then
  log "Setting up swap (2GB)..."
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
  # Lower swappiness for server workloads
  echo 'vm.swappiness=10' >> /etc/sysctl.conf
  sysctl -p
  log "Swap configured (2GB)."
else
  log "Swap already configured."
fi

# --- 10. Summary --------------------------------------------------------------
echo ""
echo "=============================================="
echo "  SmartRoad — Server Setup Complete"
echo "=============================================="
echo ""
log "SSH port:          $SSH_PORT"
log "Admin user:        $NEW_USER"
log "Firewall:          UFW active"
log "Fail2Ban:          Active (SSH)"
log "Docker:            Installed"
log "Docker Compose:    Installed"
log "Auto-updates:      Enabled (security only)"
echo ""
echo "Next steps:"
echo "  1. Add your SSH public key (see warning above)"
echo "  2. Reboot: sudo reboot"
echo "  3. After reboot, verify SSH with: ssh $NEW_USER@<server-ip> -p $SSH_PORT"
echo "  4. Run: cd /opt/smartroad && git clone <repo-url> && docker-compose up -d"
echo ""
