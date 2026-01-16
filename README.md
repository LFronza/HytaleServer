# Hytale Server Docker

This project provides a Dockerized Hytale Server with automatic updates, local world directory import, and automated local backups.

## Features
- **Auto-Update**: Downloads the latest Hytale server files on startup using the official Hytale Downloader.
- **Auto-Import**: If you place world files in the `./import` folder, they will be synced to the server directory on startup (overwriting existing files).
- **Auto-Backup**: Automatically zips the `world` folder every 15 minutes (configurable) to `./backups`.

## Prerequisites
- Docker & Docker Compose
- Java 25 (Managed inside the container, but ensure your host supports running the container).

## CI/CD (GitHub Actions)
This project includes a GitHub Action to automatically build the Docker image with the server assets **baked in**.
This means the heavy download and extraction happens on GitHub's servers, not your machine.

1. Push this code to a GitHub repository.
2. Go to the "Actions" tab to see the build running.
3. Once finished, you can pull the image directly from GitHub Container Registry (GHCR) and start it instantly without waiting for downloads.

## Usage
### Local Build (Traditional)
```bash
docker-compose up --build
```
This will download and build the image locally.

### Using Pre-Built Image (from Git)
Change `image: hytale-server:latest` in `docker-compose.yml` to your GHCR image URL (e.g., `ghcr.io/seu-usuario/seu-repo:main`) and run:
```bash
docker-compose up -d
```

3. **Restoring/Importing a World**
   - Stop the server: `docker-compose down`
   - Place your `world` folder inside the `./import` directory. structure should be `./import/world/...`.
   - Start the server: `docker-compose up -d`
   - The script will detect files in `/import` and sync them to the server.

4. **Backups**
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
