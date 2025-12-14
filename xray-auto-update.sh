#!/bin/bash
# ==================================================
# Xray Auto-Update Script
# Checks GitHub for new releases and updates automatically
# Runs every 2 days via systemd timer
# ==================================================

LOG_FILE="/var/log/xray/auto-update.log"
VERSION_FILE="/var/lib/xray/last-check"
CHECK_INTERVAL=172800  # 2 days in seconds

# Create directories if not exist
mkdir -p /var/log/xray
mkdir -p /var/lib/xray

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check if running as root
if [[ "$EUID" -ne 0 ]]; then
   log "ERROR: This script must be run as root"
   exit 1
fi

log "Starting Xray auto-update check..."

# Check if enough time has passed since last check
if [[ -f "$VERSION_FILE" ]]; then
    LAST_CHECK=$(cat "$VERSION_FILE")
    CURRENT_TIME=$(date +%s)
    TIME_DIFF=$((CURRENT_TIME - LAST_CHECK))
    
    if [[ $TIME_DIFF -lt $CHECK_INTERVAL ]]; then
        HOURS_LEFT=$(( (CHECK_INTERVAL - TIME_DIFF) / 3600 ))
        log "INFO: Last check was $((TIME_DIFF / 3600)) hours ago. Next check in $HOURS_LEFT hours."
        exit 0
    fi
fi

# Get installed version
if ! command -v xray &> /dev/null; then
    log "ERROR: Xray not installed"
    exit 1
fi

INSTALLED_VERSION=$(xray version | head -n 1 | awk '{print $2}')
log "INFO: Installed version: $INSTALLED_VERSION"

# Get latest version from GitHub
LATEST_VERSION=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep '"tag_name"' | cut -d'"' -f4)

if [[ -z "$LATEST_VERSION" ]]; then
    log "ERROR: Failed to fetch latest version from GitHub"
    exit 1
fi

log "INFO: Latest version: $LATEST_VERSION"

# Compare versions
if [[ "$INSTALLED_VERSION" == "$LATEST_VERSION" ]]; then
    log "INFO: Xray is up to date"
    date +%s > "$VERSION_FILE"
    exit 0
fi

log "INFO: New version available: $LATEST_VERSION (current: $INSTALLED_VERSION)"
log "INFO: Starting update process..."

# Backup current config
CONFIG_BACKUP="/var/lib/xray/config.json.backup-$(date +%Y%m%d-%H%M%S)"
if [[ -f /usr/local/etc/xray/config.json ]]; then
    cp /usr/local/etc/xray/config.json "$CONFIG_BACKUP"
    log "INFO: Config backed up to $CONFIG_BACKUP"
fi

# Update Xray
log "INFO: Downloading and installing Xray $LATEST_VERSION..."
if bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install; then
    log "INFO: Xray updated successfully to $LATEST_VERSION"
    
    # Verify installation
    NEW_VERSION=$(xray version | head -n 1 | awk '{print $2}')
    log "INFO: Verified installed version: $NEW_VERSION"
    
    # Restart service
    log "INFO: Restarting Xray service..."
    if systemctl restart xray; then
        log "INFO: Xray service restarted successfully"
        
        # Wait and check service status
        sleep 3
        if systemctl is-active --quiet xray; then
            log "INFO: Xray service is running"
        else
            log "ERROR: Xray service failed to start after update"
            log "ERROR: Attempting to restore backup config..."
            
            if [[ -f "$CONFIG_BACKUP" ]]; then
                cp "$CONFIG_BACKUP" /usr/local/etc/xray/config.json
                systemctl restart xray
                log "INFO: Config restored and service restarted"
            fi
            
            exit 1
        fi
    else
        log "ERROR: Failed to restart Xray service"
        exit 1
    fi
else
    log "ERROR: Failed to update Xray"
    exit 1
fi

# Update last check timestamp
date +%s > "$VERSION_FILE"

log "INFO: Update completed successfully"
log "======================================"

exit 0