# Xray VLESS Auto-Installer Collection 🚀

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Professional-grade Bash scripts for fully automated installation of VPN servers based on **Xray** using the **VLESS** protocol.

## 🎯 Available Installation Variants

This repository offers **4 production-ready configurations** optimized for different use cases:

### 🔵 Variant 1-3: VLESS + WS / XHTTP (No TLS)
**File:** `install-vless.sh`

**Modes:**
- **Mode 1:** VLESS + WebSocket (port 443)
- **Mode 2:** VLESS + XHTTP (port 2053)
- **Mode 3:** Both WS + XHTTP (dual-port setup)

**Best for:**
- Quick deployment without domain
- Moderate censorship environments
- Testing and development

**Security:** `none` (no TLS/certificates)

### 🟢 Variant 4: VLESS + REALITY + Vision (Recommended)
**File:** `install-vless-reality.sh`

**Transport:** TCP with REALITY encryption + XTLS Vision flow

**Best for:**
- **Maximum stealth** (indistinguishable from legitimate HTTPS)
- Heavy censorship (China, Iran, Russia)
- **Performance-critical applications** (~1.5x speed boost)
- Long-term stable connections

**Security:** REALITY (perfect TLS mimicry of real websites)

---

## 📊 Feature Comparison

| Feature | WS (no TLS) | XHTTP (no TLS) | REALITY + Vision |
|---------|-------------|----------------|------------------|
| **Port** | 443 | 2053 | 443 |
| **Speed** | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Stealth** | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **DPI Resistance** | Low | Medium | **Maximum** |
| **Client Support** | Universal | Xray-core only | Universal |
| **Latency** | Medium | Low | **Lowest** |
| **Setup Complexity** | Simple | Simple | Moderate |
| **Domain Required** | ❌ | ❌ | ❌ |
| **Certificate** | None | None | Mimics real site |
| **Perfect Forward Secrecy** | ❌ | ❌ | ✅ |
| **OCSP Stapling** | ❌ | ❌ | ✅ (inherited) |

---

## 🚀 Quick Start

### Option 1: VLESS + WS / XHTTP (Quick Setup)

```bash
# Download script
wget https://raw.githubusercontent.com/Nerve11/Xray-Vless-auto-Deploy/main/install-vless.sh

# Make executable
chmod +x install-vless.sh

# Run with sudo
sudo ./install-vless.sh
```

**Interactive menu:**
1. Select SNI (google.com / yandex.ru)
2. Choose mode (WS / XHTTP / Both)
3. Wait for completion

### Option 2: VLESS + REALITY + Vision (Maximum Security)

```bash
# Download script
wget https://raw.githubusercontent.com/Nerve11/Xray-Vless-auto-Deploy/main/install-vless-reality.sh

# Make executable
chmod +x install-vless-reality.sh

# Run with sudo
sudo ./install-vless-reality.sh
```

**Interactive menu:**
1. Select camouflage site (microsoft.com / google.com / cloudflare.com / apple.com)
2. Choose TLS fingerprint (chrome / firefox / safari / edge)
3. Automatic x25519 key generation
4. QR code and VLESS link output

---

## 📱 Client Compatibility

### VLESS + WebSocket (Port 443)
**Compatible clients:**
- ✅ v2rayN (Windows)
- ✅ v2rayNG (Android)
- ✅ Shadowrocket (iOS)
- ✅ Clash.Meta (All platforms)
- ✅ **Happ** (Android/iOS/Windows)
- ✅ Nekoray (Desktop)
- ✅ Sing-box clients

### VLESS + XHTTP (Port 2053)
**Compatible clients (Xray-core based only):**
- ✅ v2rayNG (Android) with xray-core
- ✅ v2rayN (Windows) with xray-core
- ✅ Nekoray (Desktop) with xray-core backend
- ❌ **Happ** (no XHTTP support)
- ❌ Clash/Sing-box (no XHTTP)

### VLESS + REALITY + Vision (Port 443)
**Compatible clients:**
- ✅ v2rayN 6.17+ (Windows)
- ✅ v2rayNG 1.8.0+ (Android)
- ✅ **Happ** (All platforms)
- ✅ Nekoray (Desktop)
- ✅ FoXray (iOS)
- ✅ Streisand (iOS)
- ❌ Clash (no REALITY support)

---

## ⚙️ System Requirements

- **VPS:** 1 GB RAM minimum (2 GB recommended)
- **OS:** Ubuntu 20.04+ / Debian 10+ / CentOS 7+ / AlmaLinux / Rocky Linux
- **Kernel:** 4.9+ (for TCP BBR support)
- **Network:** Public IPv4 address
- **Access:** Root or sudo privileges

---

## 🎯 Use Case Recommendations

### For China 🇨🇳
**Primary:** VLESS + REALITY + Vision (`install-vless-reality.sh`)
- Mimics microsoft.com or cloudflare.com
- XTLS Vision flow for GFW bypass
- Chrome fingerprint recommended

**Backup:** VLESS + XHTTP (if primary blocked)
- Port 2053 with google.com SNI
- Padding enabled for traffic obfuscation

### For Iran 🇮🇷
**Primary:** VLESS + REALITY + Vision
- Use apple.com or microsoft.com SNI
- Safari fingerprint for iOS devices

**Backup:** VLESS + WebSocket
- Universal client support
- Works with restrictive firewalls

### For Russia 🇷🇺
**Primary:** VLESS + REALITY + Vision
- google.com or cloudflare.com SNI
- Edge fingerprint for Windows users

### For General Use
**Recommended:** VLESS + WebSocket
- Maximum client compatibility
- Easy setup and management
- Sufficient for moderate blocking

---

## 📊 Performance Benchmarks

Based on community testing (1 Gbps VPS, 100ms RTT):

| Configuration | Download | Upload | Latency | Packet Loss |
|---------------|----------|--------|---------|-------------|
| **REALITY + Vision** | 950 Mbps | 920 Mbps | +2ms | 0% |
| **XHTTP** | 820 Mbps | 780 Mbps | +5ms | 0% |
| **WebSocket** | 720 Mbps | 680 Mbps | +8ms | 0.1% |
| **Direct (no VPN)** | 980 Mbps | 960 Mbps | 0ms | 0% |

*Results vary by network conditions, server location, and ISP routing.*

---

## 🔧 Post-Installation Management

### Service Control
```bash
# Check status
sudo systemctl status xray

# Restart service
sudo systemctl restart xray

# View real-time logs
sudo journalctl -u xray -f

# Check access logs
sudo tail -f /var/log/xray/access.log
```

### Configuration Files
- **Server config:** `/usr/local/etc/xray/config.json`
- **Service file:** `/etc/systemd/system/xray.service`
- **Logs:** `/var/log/xray/`

### Firewall Management
```bash
# UFW (Ubuntu/Debian)
sudo ufw status
sudo ufw allow 443/tcp
sudo ufw allow 2053/tcp

# Firewalld (CentOS/RHEL)
sudo firewall-cmd --list-all
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --reload
```

---

## 🔍 Troubleshooting

### XHTTP: No Connection
**Problem:** Traffic shows in logs but browser doesn't load pages

**Solution:**
1. Verify client supports XHTTP (v2rayNG/v2rayN with xray-core)
2. Check port 2053 is open: `sudo ss -tlnp | grep 2053`
3. Ensure `mode=packet-up` in client config
4. Test with WebSocket mode first to rule out network issues

### REALITY: "Connection Failed"
**Problem:** Client shows "connection timeout" or "handshake failed"

**Solutions:**
1. Verify public key matches server's public key
2. Check shortId is correct (case-sensitive)
3. Ensure SNI matches server configuration exactly
4. Test camouflage website accessibility: `curl -I https://www.microsoft.com`
5. Verify firewall allows port 443: `sudo ufw status`

### Low Speed (All Variants)
**Diagnostics:**
```bash
# Check BBR is enabled
sysctl net.ipv4.tcp_congestion_control
# Should output: bbr

# Test server speed
curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 -

# Check CPU load
htop
```

**Optimization:**
- Enable BBR if not active: `sudo sysctl -p /etc/sysctl.d/99-bbr.conf`
- Increase connection limits in `/usr/local/etc/xray/config.json`
- Use geographically closer server
- Switch to REALITY + Vision for best performance

### Service Won't Start
```bash
# Validate configuration
sudo /usr/local/bin/xray -test -config /usr/local/etc/xray/config.json

# Check port conflicts
sudo ss -tlnp | grep -E ':(443|2053)'

# Review error logs
sudo journalctl -u xray -n 100 --no-pager
```

---

## 🔒 Security Best Practices

### For Production Deployments:

1. **Enable UFW/Firewalld**
   ```bash
   sudo ufw enable
   sudo ufw default deny incoming
   sudo ufw allow 22/tcp  # SSH
   sudo ufw allow 443/tcp # Xray
   ```

2. **Disable Root SSH Login**
   ```bash
   sudo nano /etc/ssh/sshd_config
   # Set: PermitRootLogin no
   sudo systemctl restart sshd
   ```

3. **Set Up Fail2Ban**
   ```bash
   sudo apt install fail2ban
   sudo systemctl enable fail2ban
   ```

4. **Regular Updates**
   ```bash
   # Update Xray to latest version
   sudo bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
   sudo systemctl restart xray
   ```

5. **Monitor Logs**
   ```bash
   # Set up log rotation
   sudo nano /etc/logrotate.d/xray
   ```

---

## 🌐 Client Configuration Examples

### VLESS + REALITY (v2rayNG)
1. Tap **+** → **Import config from clipboard**
2. Paste VLESS link from server output
3. Verify settings:
   - **Transport:** tcp
   - **Security:** reality
   - **SNI:** www.microsoft.com (or chosen site)
   - **Flow:** xtls-rprx-vision
   - **Public Key:** (auto-filled from link)
   - **Short ID:** (auto-filled from link)
4. Save and connect

### VLESS + XHTTP (v2rayN)
1. Servers → Add VLESS server
2. Fill manually:
   - **Address:** Server IP
   - **Port:** 2053
   - **UUID:** From server output
   - **Network:** xhttp
   - **Host:** google.com
   - **Path:** (empty)
   - **Mode:** packet-up
3. Save and connect

---

## 📈 Advanced Optimizations

### Custom SNI for REALITY
Edit `/usr/local/etc/xray/config.json`:
```json
"realitySettings": {
  "dest": "your-custom-site.com:443",
  "serverNames": ["your-custom-site.com"]
}
```

### Multiple Users (REALITY)
```json
"clients": [
  {"id": "uuid-1", "flow": "xtls-rprx-vision", "email": "user1"},
  {"id": "uuid-2", "flow": "xtls-rprx-vision", "email": "user2"}
]
```

### Traffic Statistics
Enable detailed logging:
```json
"log": {
  "loglevel": "info",
  "access": "/var/log/xray/access.log"
}
```

Analyze with:
```bash
grep "accepted" /var/log/xray/access.log | wc -l  # Connection count
```

---

## 🆘 Support & Resources

- **Xray Documentation:** [xtls.github.io](https://xtls.github.io)
- **Issue Tracker:** [GitHub Issues](https://github.com/Nerve11/Xray-Vless-auto-Deploy/issues)
- **Telegram Community:** [@projectXray](https://t.me/projectXray)
- **REALITY Guide:** [cscot.pages.dev](https://cscot.pages.dev/2023/03/02/Xray-REALITY-tutorial/)

---

## 📜 License

MIT License. See `LICENSE` file for details.

---

## 🙏 Credits

- **Xray-core:** [@XTLS](https://github.com/XTLS/Xray-core)
- **REALITY Protocol:** [@rprx](https://github.com/rprx)
- **Community Contributors:** [@chika0801](https://github.com/chika0801), [@2dust](https://github.com/2dust)

---

## ⚠️ Disclaimer

These scripts are provided for educational and privacy purposes. Users are responsible for compliance with local laws and VPS provider terms of service. The authors assume no liability for misuse or service disruptions.