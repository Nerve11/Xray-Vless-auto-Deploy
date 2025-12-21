# Production Deployment Guide

## Overview

This guide covers deploying Xray Dashboard in production with security hardening, SSL/TLS, and monitoring.

## Prerequisites

- VPS with 1GB+ RAM, 10GB disk
- Ubuntu 20.04+ / Debian 10+ / CentOS 7+
- Root or sudo access
- Domain name (optional, for HTTPS)

## Quick Start

### 1. One-Command Installation

```bash
wget -O install.sh https://raw.githubusercontent.com/Nerve11/Xray-Vless-auto-Deploy/feature/dashboard-mvp/install-with-dashboard.sh
chmod +x install.sh
sudo ./install.sh
```

**What it does:**
- Installs Xray core with REALITY protocol
- Sets up Python 3.11 virtual environment
- Deploys FastAPI dashboard
- Configures systemd services
- Enables TCP BBR
- Opens firewall ports

### 2. Access Dashboard

After installation:
```
http://YOUR_SERVER_IP:8080
```

## Production Hardening

### A. Setup Nginx Reverse Proxy with SSL

#### Install Nginx

```bash
# Ubuntu/Debian
sudo apt install nginx certbot python3-certbot-nginx

# CentOS/RHEL
sudo yum install nginx certbot python3-certbot-nginx
```

#### Obtain SSL Certificate

```bash
# Replace with your domain
sudo certbot certonly --nginx -d dashboard.example.com
```

#### Configure Nginx

```bash
# Copy template
sudo wget -O /etc/nginx/sites-available/xray-dashboard \
  https://raw.githubusercontent.com/Nerve11/Xray-Vless-auto-Deploy/feature/dashboard-mvp/nginx/xray-dashboard.conf

# Edit configuration
sudo nano /etc/nginx/sites-available/xray-dashboard
# Change 'your-domain.com' to your actual domain

# Enable site (Debian/Ubuntu)
sudo ln -s /etc/nginx/sites-available/xray-dashboard /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx
```

#### Auto-Renewal Setup

```bash
# Test renewal
sudo certbot renew --dry-run

# Certbot automatically sets up cron job
# Verify:
sudo systemctl status certbot.timer
```

### B. Firewall Configuration

#### UFW (Ubuntu/Debian)

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp     # SSH
sudo ufw allow 443/tcp    # Xray + HTTPS
sudo ufw allow 80/tcp     # HTTP (for Let's Encrypt)
sudo ufw enable
```

#### Firewalld (CentOS/RHEL)

```bash
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

### C. Security Hardening

#### 1. Disable Password SSH (Use Keys)

```bash
sudo nano /etc/ssh/sshd_config
# Set:
# PasswordAuthentication no
# PermitRootLogin prohibit-password

sudo systemctl restart sshd
```

#### 2. Install Fail2Ban

```bash
# Ubuntu/Debian
sudo apt install fail2ban

# CentOS
sudo yum install fail2ban

sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

#### 3. Limit Dashboard Access by IP

Edit Nginx config:
```nginx
location / {
    allow 1.2.3.4;      # Your IP
    allow 192.168.1.0/24; # Your office network
    deny all;
    proxy_pass http://xray_dashboard;
}
```

#### 4. Enable HTTP Basic Auth (Optional)

```bash
# Create password file
sudo apt install apache2-utils
sudo htpasswd -c /etc/nginx/.htpasswd admin

# Add to Nginx config:
# auth_basic "Restricted";
# auth_basic_user_file /etc/nginx/.htpasswd;
```

## Monitoring

### A. Service Status

```bash
# Check services
sudo systemctl status xray
sudo systemctl status xray-dashboard

# View logs
sudo journalctl -u xray -f
sudo journalctl -u xray-dashboard -f
```

### B. Resource Monitoring

```bash
# Install htop
sudo apt install htop
htop

# Disk usage
df -h

# Network connections
sudo ss -tulnp | grep xray
```

### C. Prometheus + Grafana (Advanced)

```bash
# Install Prometheus exporter (future feature)
# Dashboard will expose /metrics endpoint
```

## Backup & Restore

### Backup Configuration

```bash
# Manual backup
sudo tar -czf xray-backup-$(date +%F).tar.gz \
  /usr/local/etc/xray \
  /opt/xray-dashboard \
  /etc/systemd/system/xray*.service

# Via Dashboard API
curl -X GET http://localhost:8080/api/backup
```

### Restore

```bash
# Extract backup
sudo tar -xzf xray-backup-2024-12-21.tar.gz -C /

# Restart services
sudo systemctl restart xray xray-dashboard
```

## Performance Tuning

### A. Increase File Descriptors

```bash
sudo nano /etc/security/limits.conf
# Add:
* soft nofile 65536
* hard nofile 65536
```

### B. Optimize Xray Workers

Edit `/opt/xray-dashboard/systemd/xray-dashboard.service`:
```ini
ExecStart=/opt/xray-dashboard/venv/bin/uvicorn backend.main:app \
    --workers 4  # Increase for high load
```

### C. Enable HTTP/2

Nginx config already includes `http2` directive.

## Troubleshooting

### Dashboard Not Accessible

```bash
# Check service status
sudo systemctl status xray-dashboard

# Check port binding
sudo ss -tlnp | grep 8080

# Check logs
sudo journalctl -u xray-dashboard -n 100

# Test locally
curl http://localhost:8080/api/health
```

### Xray Not Connecting

```bash
# Validate config
sudo xray -test -config /usr/local/etc/xray/config.json

# Check firewall
sudo ufw status
sudo ss -tlnp | grep 443

# Test REALITY handshake
curl -I https://www.microsoft.com  # Should work from server
```

### High CPU Usage

```bash
# Check process
top -p $(pgrep xray)

# Analyze connections
sudo ss -tn | wc -l

# Review logs for errors
sudo tail -f /var/log/xray/error.log
```

## Scaling

### Multiple Servers

1. Use HAProxy/Nginx as load balancer
2. Deploy dashboard on management server
3. Configure API to manage multiple Xray instances

### Database Backend (Future)

- SQLite (default, single server)
- PostgreSQL (multi-server, high availability)

## Updates

### Update Xray

```bash
sudo bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
sudo systemctl restart xray
```

### Update Dashboard

```bash
cd /opt/xray-dashboard
sudo -u root bash << 'EOF'
source venv/bin/activate
pip install --upgrade fastapi uvicorn
deactivate
EOF
sudo systemctl restart xray-dashboard
```

## Security Checklist

- [ ] SSL/TLS enabled with valid certificate
- [ ] Firewall configured (only 22, 80, 443)
- [ ] SSH key-only authentication
- [ ] Fail2Ban installed
- [ ] Regular system updates (`apt update && apt upgrade`)
- [ ] Dashboard access restricted by IP (optional)
- [ ] HTTP Basic Auth enabled (optional)
- [ ] Automated backups configured
- [ ] Monitoring setup (logs, metrics)
- [ ] Strong passwords for profiles

## Support

- **GitHub Issues:** [Report bugs](https://github.com/Nerve11/Xray-Vless-auto-Deploy/issues)
- **Documentation:** [Wiki](https://github.com/Nerve11/Xray-Vless-auto-Deploy/wiki)
- **Telegram:** [@projectXray](https://t.me/projectXray)