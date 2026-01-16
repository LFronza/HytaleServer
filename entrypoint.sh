#!/bin/bash
set -e

echo "--- Hytale Server Docker Container ---"

# --- Update Phase ---
# Helper function for unzip with progress
unzip_with_progress() {
    local zipfile="$1"
    if command -v pv >/dev/null 2>&1; then
        echo "Extracting $zipfile..."
        # Count lines in zip listing (approx files)
        local total
        total=$(unzip -l "$zipfile" | wc -l)
        # Unzip piping to pv. -o to overwrite.
        unzip -o "$zipfile" | pv -l -s "$total" > /dev/null
    else
        echo "Extracting $zipfile (no progress bar available)..."
        unzip -qo "$zipfile"
    fi
}

# --- Update Phase ---
# Check if hytale-downloader exists
if [ ! -f "hytale-downloader.jar" ] && [ ! -f "hytale-downloader" ]; then
    echo "[Update] Downloading Hytale Downloader from $HYTALE_DOWNLOADER_URL..."
    curl -L -o hytale-downloader.zip "$HYTALE_DOWNLOADER_URL"
    unzip_with_progress "hytale-downloader.zip"
    # Rename the linux binary to standard name if it exists
    if [ -f "hytale-downloader-linux-amd64" ]; then
        mv hytale-downloader-linux-amd64 hytale-downloader
    fi
    chmod +x hytale-downloader
fi

# Run Downloader only if forced or if no server binary exists
# This prevents running the downloader on every restart, which might cause loops or redundant checks.
SERVER_EXISTS=false
if [ -f "Server/HytaleServer.jar" ] || [ -f "Server/HytaleServer" ]; then
    SERVER_EXISTS=true
fi

if [ "$SERVER_EXISTS" = false ] || [ "$FORCE_UPDATE" = "true" ]; then
    echo "[Update] Running Hytale Downloader..."
    if [ -f "./hytale-downloader" ]; then
        ./hytale-downloader
    elif [ -f "hytale-downloader.jar" ]; then
        java -jar hytale-downloader.jar
    fi
else
    echo "[Update] Server exists. Skipping downloader check (set FORCE_UPDATE=true to force)."
fi

# --- Unzip Phase ---
# Find the specific version zip (ignoring hytale-downloader.zip)
LATEST_ZIP=$(ls *.zip 2>/dev/null | grep -v "hytale-downloader.zip" | sort -r | head -n 1)

if [ -n "$LATEST_ZIP" ]; then
    # Helper: Check if we already unzipped this zip
    if [ ! -f "unzipped_${LATEST_ZIP}.marker" ]; then
        echo "[Update] Found new server package: $LATEST_ZIP"
        unzip_with_progress "$LATEST_ZIP"
        touch "unzipped_${LATEST_ZIP}.marker"
    else
         echo "[Update] $LATEST_ZIP already extracted."
    fi
else
    if [ "$SERVER_EXISTS" = false ]; then
        echo "[Update] No server package zip found and no server binary."
    fi
fi

# --- Import Phase ---
# Check if we should prompt for import (Interactive mode)
if [ -t 0 ]; then
    echo "----------------------------------------------------------------"
    echo " Import Wizard"
    echo "----------------------------------------------------------------"
    echo "This feature allows you to copy files to 'data/import' on your host"
    echo "before the server processes them. Useful for restoring backups or valid worlds."
    echo ""
    read -t 10 -p "Do you want to pause to import files? (y/N) [10s skip]: " DO_IMPORT_PAUSE
    
    if [[ "$DO_IMPORT_PAUSE" =~ ^[Yy]$ ]]; then
        echo ""
        echo ">> PAUSED. Please copy your files to the 'data/import' folder now."
        echo ">> Structure example: data/import/world/"
        echo ">> Press ENTER when you are ready to proceed..."
        read -r _
        echo "Resuming..."
    else
        echo "Skipping import pause."
    fi
fi

echo "[Import] Checking /import directory..."
if [ -d "/import" ] && [ "$(ls -A /import)" ]; then
    echo "[Import] Files found in /import. Syncing to /hytale..."
    rsync -av /import/ /hytale/
    echo "[Import] Sync complete."
else
    echo "[Import] /import is empty. Skipping import."
fi

# --- Configuration Phase ---
# Check for config.json (usually in root or Server/)
CONFIG_FILE=""
if [ -f "config.json" ]; then CONFIG_FILE="config.json"; fi
if [ -f "Server/config.json" ]; then CONFIG_FILE="Server/config.json"; fi

if [ -n "$CONFIG_FILE" ]; then
    echo "[Config] Found configuration file: $CONFIG_FILE"
    
    # Check if we are running interactively
    if [ -t 0 ]; then
        echo "----------------------------------------------------------------"
        echo " Interactive Configuration Wizard"
        echo "----------------------------------------------------------------"
        read -t 5 -p "Do you want to run the setup wizard? (y/N) [5s timeout]: " DO_SETUP
        if [[ "$DO_SETUP" =~ ^[Yy]$ ]]; then
            # Read current values
            CUR_NAME=$(jq -r '.ServerName' "$CONFIG_FILE")
            CUR_MAX=$(jq -r '.MaxPlayers' "$CONFIG_FILE")
            CUR_MOTD=$(jq -r '.MOTD' "$CONFIG_FILE")
            
            echo "Current ServerName: $CUR_NAME"
            read -p "New ServerName (leave empty to keep): " NEW_NAME
            if [ -n "$NEW_NAME" ]; then
                # User jq to update file
                jq --arg v "$NEW_NAME" '.ServerName = $v' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
                echo "Updated ServerName."
            fi

            echo "Current MaxPlayers: $CUR_MAX"
            read -p "New MaxPlayers (leave empty to keep): " NEW_MAX
            if [ -n "$NEW_MAX" ]; then
                jq --argjson v "$NEW_MAX" '.MaxPlayers = $v' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
                echo "Updated MaxPlayers."
            fi
            
            echo "Current MOTD: $CUR_MOTD"
            read -p "New MOTD (leave empty to keep): " NEW_MOTD
            if [ -n "$NEW_MOTD" ]; then
                jq --arg v "$NEW_MOTD" '.MOTD = $v' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
                echo "Updated MOTD."
            fi

            # Mod Installation Question
            read -t 10 -p "Do you want to install 'Hytale Server Essentials' mod? (y/N) [10s skip]: " DO_INSTALL_MOD
            if [[ "$DO_INSTALL_MOD" =~ ^[Yy]$ ]]; then
                INSTALL_MOD_ESSENTIALS="true"
            fi
            
            echo "[Config] Setup complete. Proceeding to startup..."
        else
            echo "[Config] Skipping setup wizard."
        fi
    else
        echo "[Config] Non-interactive mode detected. Skipping wizard."
    fi
else
    echo "[Config] config.json not found."
fi

# --- Mod Installation Phase ---
if [ "$INSTALL_MOD_ESSENTIALS" = "true" ]; then
    echo "[Mods] Checking Hytale Server Essentials..."
    mkdir -p mods
    # Check if already installed (simple check)
    if [ ! -f "mods/hytale-server-essentials.jar" ]; then
         echo "[Mods] Downloading Hytale Server Essentials..."
         MOD_URL="https://www.curseforge.com/api/v1/mods/1429782/files/7461212/download"
         curl -L -o "mods/hytale-server-essentials.jar" "$MOD_URL"
         echo "[Mods] Download complete."
    else
         echo "[Mods] Hytale Server Essentials already exists."
    fi
fi

# --- Backup Loop ---
backup_loop() {
    while true; do
        sleep "$BACKUP_INTERVAL"
        echo "[Backup] Starting backup..."
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        BACKUP_FILE="/backups/hytale_backup_$TIMESTAMP.zip"
        
        # Backup world and config if they exist. 
        # Adjust paths based on where 'world' actually is.
        # Based on typical servers, it might be in root or inside Server/.
        # We will try to zip 'world' in root, or 'Server/world'.
        
        if [ -d "world" ]; then
            zip -r "$BACKUP_FILE" world
            echo "[Backup] Created $BACKUP_FILE"
        elif [ -d "Server/world" ]; then
             zip -r "$BACKUP_FILE" Server/world
             echo "[Backup] Created $BACKUP_FILE"
        else
            echo "[Backup] 'world' directory not found. Skipping backup."
        fi
        
        find /backups -name "hytale_backup_*.zip" -mtime +7 -delete
    done
}

# Start backup loop in background
backup_loop &

# --- Run Phase ---
echo "[Run] Starting Hytale Server..."

# List files for debugging purposes
ls -F

if [ -f "Server/HytaleServer.jar" ]; then
    echo "[Run] Found Server/HytaleServer.jar. Launching..."
    # Some servers need to be run from their dir, others from root with paths.
    # Trying root first.
    java $JAVA_OPTS -jar Server/HytaleServer.jar
elif [ -f "Server/HytaleServer" ]; then
    echo "[Run] Found binary Server/HytaleServer. Launching..."
    chmod +x Server/HytaleServer
    ./Server/HytaleServer
# Check for bat/sh scripts in Server/
elif [ -f "Server/start.sh" ]; then
    bash Server/start.sh
else
    echo "[Run] Could not determine how to start the server. Searching for candidates:"
    find . -maxdepth 3 -name "*.jar" -o -name "start.sh" -o -name "HytaleServer*"
    
    echo "[Run] Keeping container alive for inspection..."
    tail -f /dev/null
fi
