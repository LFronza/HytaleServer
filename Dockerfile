# --- Build Stage ---
FROM eclipse-temurin:25-jdk AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Support for Hytale Credentials
ARG HYTALE_EMAIL
ARG HYTALE_PASSWORD
ENV HYTALE_DOWNLOADER_URL="https://downloader.hytale.com/hytale-downloader.zip"

# Reorder: Download only if needed. 
# We copy ONLY the Server directory (if it exists) or credentials to check against them
COPY .hytale-downloader-credentials.json* Server* /build/

RUN if [ ! -f "Server/HytaleServer.jar" ] && [ ! -f "Server/HytaleServer" ]; then \
    echo "Server files not found. Starting Hytale Downloader..."; \
    curl -L -o hytale-downloader.zip "$HYTALE_DOWNLOADER_URL" && \
    unzip -qo hytale-downloader.zip && \
    if [ -f "hytale-downloader-linux-amd64" ]; then mv hytale-downloader-linux-amd64 hytale-downloader; fi && \
    chmod +x hytale-downloader && \
    echo "Running Hytale Downloader..." && \
    if [ -n "$HYTALE_EMAIL" ] && [ -n "$HYTALE_PASSWORD" ]; then \
    ./hytale-downloader --email "$HYTALE_EMAIL" --password "$HYTALE_PASSWORD" --non-interactive; \
    else \
    ./hytale-downloader --non-interactive || echo "Downloader failed. Credentials might be required."; \
    fi && \
    LATEST_ZIP=$(ls *.zip | grep -v "hytale-downloader.zip" | sort -r | head -n 1) && \
    if [ -n "$LATEST_ZIP" ]; then \
    echo "Extracting $LATEST_ZIP..." && \
    unzip -qo "$LATEST_ZIP" && \
    rm "$LATEST_ZIP" hytale-downloader.zip; \
    fi; \
    else \
    echo "Server files found in repository. Skipping download."; \
    fi

# Copy the rest of the project (scripts, etc.)
COPY . /build/

# --- Final Stage ---
FROM eclipse-temurin:25-jdk

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    zip \
    rsync \
    pv \
    jq \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /hytale

# Environment variables
ENV BACKUP_INTERVAL=900
ENV JAVA_OPTS="-Xms2G -Xmx6G"

# Copy server files from builder
COPY --from=builder /build/ /hytale/

# Create directories for volumes
RUN mkdir -p /import /backups

# Ensure entrypoint is executable
RUN chmod +x /hytale/entrypoint.sh

ENTRYPOINT ["/hytale/entrypoint.sh"]
