#!/bin/bash
set -e

echo "--- Hytale Server Wrapper (deinfreu base) ---"

# --- Import Phase ---
echo "[Import] Checking /import directory..."
if [ -d "/import" ] && [ "$(ls -A /import)" ]; then
    echo "[Import] Syncing files to /data..."
    rsync -av /import/ /data/
else
    echo "[Import] Empty or missing, skipping."
fi

# --- Backup Loop ---
backup_loop() {
    while true; do
        sleep "${BACKUP_INTERVAL:-900}"
        echo "[Backup] Creating backup..."
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        mkdir -p /backups
        # In this image, everything is in /data
        # We backup 'world', 'config', 'mods' if they exist
        zip -qr "/backups/backup_$TIMESTAMP.zip" /data/Games /data/Storage /data/Config 2>/dev/null || true
        # Keep only last 7 days
        find /backups -name "backup_*.zip" -mtime +7 -delete 2>/dev/null || true
    done
}
backup_loop &

# --- Handoff ---
echo "[Run] Handing off to community entrypoint..."
exec /entrypoint.sh "$@"
