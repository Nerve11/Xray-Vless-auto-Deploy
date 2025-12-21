# Xray VLESS Auto-Installer Collection + Web Dashboard 🚀

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python 3.11+](https://img.shields.io/badge/python-3.11+-blue.svg)](https://www.python.org/downloads/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.109+-green.svg)](https://fastapi.tiangolo.com/)

Professional-grade **automated VPN deployment** system with **web-based management dashboard**.

## 🎯 What's New: Web Dashboard (MVP)

This branch adds a **production-ready web dashboard** for managing Xray VPN profiles:

### Features

- **✨ Modern UI:** Tailwind CSS dark theme, responsive design
- **🔧 Profile Management:** Create/delete VLESS profiles via web interface
- **📊 Real-time Stats:** Active connections, traffic, uptime monitoring
- **📱 QR Code Generation:** Instant QR codes for mobile clients
- **🔐 Security:** HTTPS support, Nginx reverse proxy integration
- **🚀 One-Click Deploy:** Complete installation in < 5 minutes
- **📡 REST API:** Full FastAPI backend with auto-generated docs
- **🔄 Auto-Restart:** Systemd integration with health checks

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  Web Dashboard (Port 8080)              │
│         Tailwind CSS + Vanilla JS + FastAPI            │
├─────────────────────────────────────────────────────────┤
│  • Profile CRUD   • QR Codes   • Statistics            │
│  • Backup/Restore • System Info • API Docs             │
└─────────────────────┬───────────────────────────────────┘
                      │ HTTP/JSON
                      ↓
┌─────────────────────────────────────────────────────────┐
│              Xray Core (Port 443)                       │
│          VLESS + REALITY + XTLS Vision                 │
├─────────────────────────────────────────────────────────┤
│  config.json (managed by dashboard)                     │
│  • Multi-user support                                   │
│  • Automatic service restart                            │
│  • Atomic configuration updates                         │
└─────────────────────────────────────────────────────────┘
```

---

## 🚀 Quick Start (Dashboard + Xray)

### One-Command Installation

```bash
wget -O install.sh https://raw.githubusercontent.com/Nerve11/Xray-Vless-auto-Deploy/feature/dashboard-mvp/install-with-dashboard.sh
chmod +x install.sh
sudo ./install.sh
```

**What it installs:**
- Xray core (latest stable)
- VLESS + REALITY protocol (maximum stealth)
- Python 3.11 + FastAPI dashboard
- Systemd services (auto-start on boot)
- TCP BBR optimization
- Firewall configuration

**After installation:**
```
Dashboard: http://YOUR_SERVER_IP:8080
API Docs:  http://YOUR_SERVER_IP:8080/api/docs
```

### Manual Installation (Xray Only)

If you prefer CLI-only deployment:

```bash
# VLESS + REALITY + Vision (recommended)
wget https://raw.githubusercontent.com/Nerve11/Xray-Vless-auto-Deploy/main/install-vless-reality.sh
chmod +x install-vless-reality.sh
sudo ./install-vless-reality.sh

# VLESS + WS/XHTTP (no TLS)
wget https://raw.githubusercontent.com/Nerve11/Xray-Vless-auto-Deploy/main/install-vless.sh
chmod +x install-vless.sh
sudo ./install-vless.sh
```

---

## 📊 Dashboard Features

### Profile Management

- **Create profiles** with one click (auto-generates UUID)
- **View all active profiles** with protocol details
- **Copy VLESS links** to clipboard
- **Generate QR codes** for mobile scanning
- **Delete profiles** with confirmation

### Statistics Dashboard

- Active connections count
- Total configured profiles
- Server uptime
- Traffic statistics
- CPU/Memory usage (coming soon)

### System Information

- Xray version
- Operating system details
- Kernel version
- BBR status
- Active protocol configuration

### API Endpoints

- `GET /api/profiles` - List all profiles
- `POST /api/profiles` - Create new profile
- `DELETE /api/profiles/{id}` - Remove profile
- `GET /api/profiles/{id}/qr` - Generate QR code
- `GET /api/stats` - Server statistics
- `GET /api/system` - System information
- `GET /api/backup` - Create configuration backup

Full API documentation: `http://YOUR_SERVER:8080/api/docs`

---

## 📖 Documentation

### Comprehensive Guides

- **[Dashboard README](docs/DASHBOARD_README.md)** - Architecture, API reference, development
- **[Deployment Guide](docs/DEPLOYMENT.md)** - Production setup, SSL, monitoring
- **[Nginx Configuration](nginx/xray-dashboard.conf)** - Reverse proxy with HTTPS

### Quick References

#### Service Management

```bash
# Xray service
sudo systemctl status xray
sudo systemctl restart xray
sudo journalctl -u xray -f

# Dashboard service
sudo systemctl status xray-dashboard
sudo systemctl restart xray-dashboard
sudo journalctl -u xray-dashboard -f
```

#### Configuration Files

```bash
# Xray config (managed by dashboard)
/usr/local/etc/xray/config.json

# Dashboard files
/opt/xray-dashboard/
├── backend/       # FastAPI application
├── frontend/      # Web UI
└── venv/          # Python virtual environment

# Logs
/var/log/xray/
├── access.log
└── error.log
```

#### Firewall Ports

```bash
# Xray
443/tcp   # VLESS + REALITY

# Dashboard
8080/tcp  # Web interface (change in production)

# Optional
80/tcp    # HTTP (for Let's Encrypt)
443/tcp   # HTTPS (if using Nginx reverse proxy)
```

---

## 🔒 Production Security Checklist

### Essential

- [ ] Setup Nginx reverse proxy with SSL
- [ ] Obtain Let's Encrypt certificate
- [ ] Configure firewall (UFW/firewalld)
- [ ] Disable password SSH authentication
- [ ] Install Fail2Ban
- [ ] Restrict dashboard access by IP (optional)
- [ ] Enable HTTP Basic Auth on Nginx (optional)

### Commands

```bash
# Install Nginx + Certbot
sudo apt install nginx certbot python3-certbot-nginx

# Obtain SSL certificate
sudo certbot --nginx -d dashboard.example.com

# Copy Nginx config
sudo wget -O /etc/nginx/sites-available/xray-dashboard \
  https://raw.githubusercontent.com/Nerve11/Xray-Vless-auto-Deploy/feature/dashboard-mvp/nginx/xray-dashboard.conf

# Edit domain name
sudo nano /etc/nginx/sites-available/xray-dashboard

# Enable site
sudo ln -s /etc/nginx/sites-available/xray-dashboard /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

See [DEPLOYMENT.md](docs/DEPLOYMENT.md) for complete production setup.

---

## 🎯 Available Installation Variants

### 🔵 Variant 1-3: VLESS + WS / XHTTP (No TLS)
**File:** `install-vless.sh`

**Modes:**
- **Mode 1:** VLESS + WebSocket (port 443)
- **Mode 2:** VLESS + XHTTP (port 2053)
- **Mode 3:** Both WS + XHTTP (dual-port setup)

**Best for:** Quick deployment, testing

### 🟢 Variant 4: VLESS + REALITY + Vision (Recommended)
**File:** `install-vless-reality.sh`

**Transport:** TCP with REALITY encryption + XTLS Vision flow

**Best for:** Maximum stealth, heavy censorship (China, Iran, Russia)

### 🆕 Variant 5: Dashboard + REALITY (This Branch)
**File:** `install-with-dashboard.sh`

**Includes:**
- All features of Variant 4
- Web-based profile management
- REST API
- Real-time monitoring
- QR code generation

**Best for:** Multi-user deployments, VPN resellers

---

## 📊 Feature Comparison

| Feature | WS (no TLS) | XHTTP (no TLS) | REALITY + Vision | **Dashboard + REALITY** |
|---------|-------------|----------------|------------------|-------------------------|
| **Port** | 443 | 2053 | 443 | 443 + 8080 |
| **Speed** | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Stealth** | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Client Support** | Universal | Xray-only | Universal | Universal |
| **Setup Complexity** | Simple | Simple | Moderate | **Easy (Web UI)** |
| **Multi-user** | Manual | Manual | Manual | **Automated** |
| **QR Codes** | CLI tool | CLI tool | CLI tool | **Web UI** |
| **Monitoring** | Logs only | Logs only | Logs only | **Real-time Dashboard** |
| **API** | ❌ | ❌ | ❌ | **✅ REST API** |

---

## ⚙️ System Requirements

### Minimum

- **VPS:** 1 GB RAM, 10 GB disk
- **OS:** Ubuntu 20.04+ / Debian 10+ / CentOS 7+
- **Kernel:** 4.9+ (for TCP BBR)
- **Network:** Public IPv4 address
- **Access:** Root or sudo

### Recommended (Dashboard)

- **VPS:** 2 GB RAM, 20 GB disk
- **Python:** 3.11+ (auto-installed)
- **Domain:** For HTTPS (optional)

---

## 📱 Client Compatibility

### VLESS + REALITY + Vision

**Compatible clients:**
- ✅ v2rayN 6.17+ (Windows)
- ✅ v2rayNG 1.8.0+ (Android)
- ✅ Happ (Android/iOS/Windows)
- ✅ Nekoray (Desktop)
- ✅ FoXray (iOS)
- ✅ Streisand (iOS)
- ❌ Clash (no REALITY support)

**Setup:**
1. Scan QR code from dashboard
2. Or paste VLESS link manually
3. Verify settings: TCP + REALITY + xtls-rprx-vision

---
## 🛠️ Development

### Local Development

```bash
git clone https://github.com/Nerve11/Xray-Vless-auto-Deploy.git
cd Xray-Vless-auto-Deploy
git checkout feature/dashboard-mvp

# Backend
cd backend
python3.11 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8080

# Frontend (open in browser)
open http://localhost:8080
```

### Testing

```bash
pip install -r requirements-dev.txt
pytest tests/ -v
pytest --cov=backend --cov-report=html
```

### API Documentation

- Swagger UI: `http://localhost:8080/api/docs`
- ReDoc: `http://localhost:8080/api/redoc`

---

## 🤝 Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

### Development Guidelines

- **Python:** Black formatting, Ruff linting, MyPy type checking
- **Bash:** ShellCheck validation
- **Frontend:** ES6+, no frameworks
- **Commits:** Conventional Commits format

---

## 📜 License

MIT License. See [LICENSE](LICENSE) file.

---

## 🙏 Credits

- **Xray-core:** [@XTLS](https://github.com/XTLS/Xray-core)
- **REALITY Protocol:** [@rprx](https://github.com/rprx)
- **Dashboard:** Nerve11 (this fork)
- **Community:** [@chika0801](https://github.com/chika0801), [@2dust](https://github.com/2dust)

---

## 🆘 Support & Resources

### Dashboard Specific

- **Issues:** [GitHub Issues](https://github.com/Nerve11/Xray-Vless-auto-Deploy/issues)
- **Discussions:** [GitHub Discussions](https://github.com/Nerve11/Xray-Vless-auto-Deploy/discussions)
- **Documentation:** [Wiki](https://github.com/Nerve11/Xray-Vless-auto-Deploy/wiki)

### Xray General

- **Xray Docs:** [xtls.github.io](https://xtls.github.io)
- **Telegram:** [@projectXray](https://t.me/projectXray)
- **REALITY Guide:** [cscot.pages.dev](https://cscot.pages.dev/2023/03/02/Xray-REALITY-tutorial/)

---

## ⚠️ Disclaimer

These scripts are provided for **educational and privacy purposes**. Users are responsible for:

- Compliance with local laws and regulations
- VPS provider terms of service
- Proper security configuration
- Backup of critical data

The authors assume **no liability** for misuse, service disruptions, or legal issues.

---

## 🗺️ Roadmap

### v1.1 (Current Branch)

- [x] Web dashboard MVP
- [x] Profile CRUD operations
- [x] QR code generation
- [x] REST API
- [x] Systemd integration
- [x] Nginx reverse proxy support
- [ ] WebSocket for real-time stats
- [ ] JWT authentication
- [ ] Profile traffic statistics

### v1.2 (Planned)

- [ ] Multi-protocol support (Trojan, Shadowsocks)
- [ ] PostgreSQL database backend
- [ ] Multi-server management
- [ ] Prometheus metrics exporter
- [ ] Email notifications
- [ ] Automated backups

### v2.0 (Future)

- [ ] User authentication system
- [ ] Role-based access control
- [ ] Payment integration (Stripe/Crypto)
- [ ] Mobile app (React Native)
- [ ] Containerization (Docker/K8s)

---

**Made with ❤️ by the Xray community**