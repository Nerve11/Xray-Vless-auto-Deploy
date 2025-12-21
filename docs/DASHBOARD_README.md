# Xray Dashboard Documentation

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Client Browser                        │
│              (Tailwind CSS + Vanilla JS)                 │
└─────────────────────┬───────────────────────────────────┘
                      │ HTTP/HTTPS
                      ▼
┌─────────────────────────────────────────────────────────┐
│                 Nginx Reverse Proxy                      │
│              (SSL Termination, Caching)                  │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│              FastAPI Backend (Uvicorn)                   │
│  • REST API (Pydantic validation)                        │
│  • Config Manager (Atomic file operations)               │
│  • Profile CRUD                                          │
│  • QR Code generation                                    │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│                 Xray Core Process                        │
│  • VLESS + REALITY + Vision                              │
│  • config.json (managed by dashboard)                    │
│  • Systemd service (auto-restart)                        │
└─────────────────────────────────────────────────────────┘
```

## API Reference

### Base URL
```
http://YOUR_SERVER:8080/api
```

### Endpoints

#### Health Check
```http
GET /api/health
Response: {"status": "healthy", "version": "1.0.0"}
```

#### List Profiles
```http
GET /api/profiles
Response: [
  {
    "id": "uuid",
    "email": "user@example.com",
    "protocol": "vless_reality",
    "transport": "tcp",
    "security": "reality",
    "connection_link": "vless://...",
    "port": 443,
    "server_address": "1.2.3.4",
    "flow": "xtls-rprx-vision",
    "sni": "www.microsoft.com",
    "public_key": "...",
    "short_id": "..."
  }
]
```

#### Create Profile
```http
POST /api/profiles?email=newuser@example.com
Response: { ...profile object... }
Status: 201 Created
```

#### Get Profile
```http
GET /api/profiles/{profile_id}
Response: { ...profile object... }
```

#### Delete Profile
```http
DELETE /api/profiles/{profile_id}
Status: 204 No Content
```

#### Get QR Code
```http
GET /api/profiles/{profile_id}/qr
Response: PNG image (binary)
Content-Type: image/png
```

#### Statistics
```http
GET /api/stats
Response: {
  "active_connections": 3,
  "total_profiles": 5,
  "uptime_seconds": 86400,
  "total_traffic_bytes": 1073741824,
  "cpu_usage_percent": 15.2,
  "memory_usage_percent": 45.8
}
```

#### System Info
```http
GET /api/system
Response: {
  "xray_version": "1.8.7",
  "os_name": "Ubuntu",
  "os_version": "22.04",
  "kernel_version": "5.15.0",
  "python_version": "3.11.7",
  "dashboard_version": "1.0.0",
  "active_protocol": "vless_reality",
  "bbr_enabled": true
}
```

#### Create Backup
```http
GET /api/backup
Response: {
  "backup_file": "/path/to/backup.tar.gz",
  "created_at": "2024-12-21T12:00:00Z",
  "size_bytes": 4096,
  "config_hash": "sha256..."
}
```

#### Restore Backup
```http
POST /api/restore?backup_file=/path/to/backup.tar.gz
Response: {"status": "restored", "backup_file": "..."}
```

## Frontend Structure

```
frontend/
├── index.html           # Main page
└── assets/
    └── js/
        ├── api.js       # API client class
        ├── utils.js     # Helper functions
        └── app.js       # Dashboard logic
```

### Key Features

- **Responsive Design:** Works on mobile, tablet, desktop
- **Dark Theme:** Modern UI with Tailwind CSS
- **Real-time Updates:** Auto-refresh stats every 10s
- **Toast Notifications:** User feedback for all actions
- **QR Code Modal:** Inline QR generation
- **Copy to Clipboard:** One-click connection link copy

## Backend Structure

```
backend/
├── main.py                 # FastAPI app
├── models.py               # Pydantic models
├── config_manager.py       # Xray config operations
├── utils.py                # Helper functions
└── protocol_templates/     # Protocol configs
```

### Design Principles

1. **Atomic Operations:** Config writes are validated before commit
2. **Type Safety:** Full Pydantic validation on all inputs
3. **Error Handling:** Graceful degradation with informative errors
4. **Async I/O:** Non-blocking file and network operations
5. **Security:** No shell injection, sanitized inputs

## Development

### Local Setup

```bash
# Clone repository
git clone https://github.com/Nerve11/Xray-Vless-auto-Deploy.git
cd Xray-Vless-auto-Deploy
git checkout feature/dashboard-mvp

# Create venv
python3.11 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r backend/requirements.txt
pip install -r backend/requirements-dev.txt  # For testing

# Run development server
cd backend
uvicorn main:app --reload --host 0.0.0.0 --port 8080
```

### Testing

```bash
# Unit tests
pytest tests/ -v

# Coverage
pytest --cov=backend --cov-report=html

# Linting
black backend/
ruff check backend/
mypy backend/
```

### API Documentation

After starting the server:
- Swagger UI: `http://localhost:8080/api/docs`
- ReDoc: `http://localhost:8080/api/redoc`

## Configuration

### Environment Variables

```bash
# Create .env file
XRAY_CONFIG_PATH=/usr/local/etc/xray/config.json
LOG_LEVEL=info
DASHBOARD_PORT=8080
```

### Xray Config Location

Default: `/usr/local/etc/xray/config.json`

### Dashboard Files

Default: `/opt/xray-dashboard/`

## Security Considerations

### Authentication (Future)

- JWT tokens
- Role-based access control (admin, user)
- API key authentication

### Current Security

- Dashboard runs as root (required for Xray config management)
- No built-in authentication (use Nginx Basic Auth)
- HTTPS strongly recommended for production
- Firewall rules to restrict access

## Performance

### Benchmarks

- **API Response Time:** < 50ms (local)
- **Profile Creation:** < 200ms (includes Xray restart)
- **QR Generation:** < 100ms
- **Memory Usage:** ~80MB (Python + Uvicorn)
- **CPU Usage:** < 5% idle, ~15% under load

### Optimization Tips

1. Use Nginx caching for static assets
2. Increase Uvicorn workers for high traffic
3. Enable HTTP/2 in Nginx
4. Use CDN for frontend assets (optional)

## Troubleshooting

### Dashboard Not Starting

```bash
# Check Python version
python3.11 --version

# Check dependencies
source /opt/xray-dashboard/venv/bin/activate
pip list

# Check systemd service
sudo systemctl status xray-dashboard
sudo journalctl -u xray-dashboard -n 100
```

### API Errors

```bash
# Enable debug logging
# Edit /opt/xray-dashboard/systemd/xray-dashboard.service
# Change --log-level info to --log-level debug
sudo systemctl daemon-reload
sudo systemctl restart xray-dashboard
```

### Frontend Issues

```bash
# Check browser console (F12)
# Verify API endpoint
curl http://localhost:8080/api/health

# Check Nginx logs
sudo tail -f /var/log/nginx/xray-dashboard-error.log
```

## Roadmap

### v1.1 (Planned)

- [ ] WebSocket for real-time stats
- [ ] Multi-protocol support (Trojan, Shadowsocks)
- [ ] User authentication (JWT)
- [ ] Profile traffic statistics
- [ ] Backup scheduler

### v1.2 (Future)

- [ ] PostgreSQL database backend
- [ ] Multi-server management
- [ ] Prometheus metrics exporter
- [ ] Email notifications
- [ ] API rate limiting

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md)

## License

MIT License - see [LICENSE](../LICENSE)