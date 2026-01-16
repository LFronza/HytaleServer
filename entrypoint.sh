#!/bin/bash
set -e

echo "--- Hytale Server Docker Container (Baked Image) ---"

# --- Config Initialization ---
# Since config.json is mounted as a file, docker creates an empty directory if it doesn't exist on host!
# To avoid this issue, users should ideally create empty files, but we can't easily fix a directory-mounted-as-file issue from inside.
# BEST PRACTICE: Mount directories containing config, or use environment checks.
# But for now, let's assume the volume mount is correct.

# Actually, mounting a single file that doesn't exist on host creates a DIR on host. This breaks things.
# Better strategy: Mount /hytale/config (folder) if possible, or accept that config.json comes from host.
# For simplicity, if config.json is missing or is a directory (bad mount), we will warn.

if [ -d "config.json" ]; then
    echo "[Warning] 'config.json' appears to be a directory. This usually happens when Docker mounts a non-existent file."
    echo "[Warning] Using default configuration internally, but changes won't persist properly unless you fix the mount."
fi

# If config.json doesn't exist (not mounted?), we might be running ephemeral.
if [ ! -e "config.json" ]; then
    echo "[Config] No config.json found. Creating default..."
    echo '{"ServerName": "Hytale Server", "MaxPlayers": 100}' > config.json
fi

# --- Wizard ---
if [ -t 0 ]; then
    echo "----------------------------------------------------------------"
    echo " Interactive Configuration Wizard"
    echo "----------------------------------------------------------------"
    read -t 5 -p "Run setup wizard? (y/N) [5s skip]: " DO_SETUP
    if [[ "$DO_SETUP" =~ ^[Yy]$ ]]; then
        # Check if jq installed (it is in our new Dockerfile)
        if command -v jq >/dev/null; then
             # Create config if empty (or directory issue workaround)
             if [ -d "config.json" ] || [ ! -s "config.json" ]; then
                 echo '{"ServerName": "Hytale Server", "MaxPlayers": 100, "MOTD": ""}' > config.json
             fi

            CUR_NAME=$(jq -r '.ServerName // "My Server"' config.json)
            read -p "ServerName [$CUR_NAME]: " NEW_NAME
            if [ -n "$NEW_NAME" ]; then
                jq --arg v "$NEW_NAME" '.ServerName = $v' config.json > config.json.tmp && mv config.json.tmp config.json
            fi
            
            # Mod Install
            read -t 10 -p "Install 'Hytale Server Essentials' mod? (y/N): " DO_INSTALL_MOD
            if [[ "$DO_INSTALL_MOD" =~ ^[Yy]$ ]]; then
                mkdir -p mods
                MOD_URL="https://www.curseforge.com/api/v1/mods/1429782/files/7461212/download"
                echo "[Mods] Downloading..."
                curl -L -o "mods/hytale-server-essentials.jar" "$MOD_URL"
            fi
        else
            echo "[Error] jq not found, skipping wizard."
        fi
    fi
    
    # Import Wizard
    echo ""
    read -t 10 -p "Pause to copy files to 'data/import'? (y/N) [10s skip]: " DO_IMPORT_PAUSE
    if [[ "$DO_IMPORT_PAUSE" =~ ^[Yy]$ ]]; then
        echo ">> PAUSED. Copy files to ./data/import on host. Press ENTER when ready."
        read -r _
    fi
fi

# --- Import Phase ---
echo "[Import] Checking /import directory..."
if [ -d "/import" ] && [ "$(ls -A /import)" ]; then
    echo "[Import] Syncing files..."
    rsync -av /import/ /hytale/
else
    echo "[Import] Empty, skipping."
fi

# --- Backup Loop ---
backup_loop() {
    while true; do
        sleep "$BACKUP_INTERVAL"
        echo "[Backup] Creating backup..."
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        mkdir -p /backups
        # Backup only 'world' and 'config.json' and 'mods'
        zip -qr "/backups/backup_$TIMESTAMP.zip" world config.json mods
        find /backups -name "backup_*.zip" -mtime +7 -delete
    done
}
backup_loop &

# --- Run Phase ---
echo "[Run] Starting Hytale Server..."
# Since files are baked in, we expect them to be here.
# Check for Server/HytaleServer.jar or similar
ls -F

if [ -f "Server/HytaleServer.jar" ]; then
    java $JAVA_OPTS -jar Server/HytaleServer.jar
elif [ -f "Server/HytaleServer" ]; then
    chmod +x Server/HytaleServer
    ./Server/HytaleServer
else
    # Fallback search
    LAUNCHER=$(find . -maxdepth 3 -name "HytaleServer.jar" -o -name "HytaleServer" | head -n 1)
    if [ -n "$LAUNCHER" ]; then
         echo "[Run] Found launcher: $LAUNCHER"
         if [[ "$LAUNCHER" == *.jar ]]; then
             java $JAVA_OPTS -jar "$LAUNCHER"
         else
             chmod +x "$LAUNCHER"
             "$LAUNCHER"
         fi
    else
        echo "[Run] Server executable not found in image!"
        tail -f /dev/null
    fi
fi
