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

# Download and Install Server during BUILD
RUN echo "Downloading Hytale Downloader..." && \
    curl -L -o hytale-downloader.zip "$HYTALE_DOWNLOADER_URL" && \
    unzip -qo hytale-downloader.zip && \
    if [ -f "hytale-downloader-linux-amd64" ]; then mv hytale-downloader-linux-amd64 hytale-downloader; fi && \
    chmod +x hytale-downloader && \
    echo "Running Hytale Downloader..." && \
    ./hytale-downloader && \
    # Find latest zip and unzip it
    LATEST_ZIP=$(ls *.zip | grep -v "hytale-downloader.zip" | sort -r | head -n 1) && \
    echo "Extracting $LATEST_ZIP..." && \
    unzip -qo "$LATEST_ZIP" && \
    rm "$LATEST_ZIP" hytale-downloader.zip

# Create directories for volumes
RUN mkdir -p /import /backups

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
