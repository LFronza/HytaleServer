# Hytale Server Docker

This project provides a Dockerized Hytale Server with smart file detection, local world directory import, and automated local backups.

## Features
- **Smart File Detection**: Checks if server files exist locally before downloading, enabling faster builds.
- **Auto-Update/Install**: Downloads the latest Hytale server files during build if they are not already present.
- **Auto-Import**: If you place world files in the `./import` folder, they will be synced to the server directory on startup (overwriting existing files).
- **Auto-Backup**: Automatically zips the `world` folder every 15 minutes (configurable) to `./backups`.

## Prerequisites
- Docker & Docker Compose
- Java 25 (Managed inside the container).

## Usage

### 1. Build and Start the Server
```bash
docker-compose up --build -d
```
> [!NOTE]
> If it's the first time and you don't have the server files, the build process will start the Hytale Downloader, which may require you to follow a link for authentication.

### 2. Check Logs for Authentication
The Hytale server requires initial authentication. Check the logs:
```bash
docker-compose logs -f
```

### 3. Restoring/Importing a World
- Stop the server: `docker-compose down`
- Place your `world` folder inside the `./import` directory. structure should be `./import/world/...`.
- Start the server: `docker-compose up -d`
- The script will detect files in `/import` and sync them to the server.

### 4. Backups
- Backups are stored in `./backups` as zip files.
- To restore, unzip a backup into `./import` and restart.

## Configuration
Edit `docker-compose.yml` to change:
- `BACKUP_INTERVAL`: Seconds between backups (default 900 = 15 mins).
- `JAVA_OPTS`: JVM memory settings.
- `ports`: Port mapping.

## Directory Structure
- `data/`: Contains all runtime data to keep project root clean.
  - `hytale_data/`: The actual server files (persisted).
  - `import/`: Drop files here to import them.
  - `backups/`: Destination for backup zips.
=======
# HytaleServer
>>>>>>> be61337079f39d2553cf88b017a2ca978531ac15
