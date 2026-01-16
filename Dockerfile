FROM eclipse-temurin:25-jdk

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    zip \
    rsync \
    pv \
    && rm -rf /var/lib/apt/lists/*

# Workdir
WORKDIR /hytale

# Environment variables
ENV HYTALE_DOWNLOADER_URL="https://downloader.hytale.com/hytale-downloader.zip"
ENV BACKUP_INTERVAL=900
ENV JAVA_OPTS="-Xms1G -Xmx4G"

# Create directories
RUN mkdir -p /import /backups /hytale

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
