FROM eclipse-temurin:25-jdk

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    zip \
    rsync \
    pv \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Workdir
WORKDIR /hytale

# Environment variables
ENV HYTALE_DOWNLOADER_URL="https://downloader.hytale.com/hytale-downloader.zip"
ENV BACKUP_INTERVAL=900
ENV JAVA_OPTS="-Xms2G -Xmx6G"

# Copy project files first (to check if server files already exist)
COPY . /hytale/

# Download and Install Server during BUILD (only if not already present)
RUN if [ ! -f "Server/HytaleServer.jar" ] && [ ! -f "Server/HytaleServer" ]; then \
    echo "Server files not found in repository. Downloading..."; \
    echo "Downloading Hytale Downloader..." && \
    curl -L -o hytale-downloader.zip "$HYTALE_DOWNLOADER_URL" && \
    unzip -qo hytale-downloader.zip && \
    if [ -f "hytale-downloader-linux-amd64" ]; then mv hytale-downloader-linux-amd64 hytale-downloader; fi && \
    chmod +x hytale-downloader && \
    echo "Running Hytale Downloader..." && \
    ./hytale-downloader && \
    LATEST_ZIP=$(ls *.zip | grep -v "hytale-downloader.zip" | sort -r | head -n 1) && \
    echo "Extracting $LATEST_ZIP..." && \
    unzip -qo "$LATEST_ZIP" && \
    rm "$LATEST_ZIP" hytale-downloader.zip; \
    else \
    echo "Server files found in repository. Skipping download."; \
    fi

# Create directories for volumes
RUN mkdir -p /import /backups

# Make entrypoint executable (already copied above)
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
