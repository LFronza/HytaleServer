FROM deinfreu/hytale-server:experimental

# Install extra runtime dependencies for our entrypoint script
USER root
RUN apt-get update && apt-get install -y \
    rsync \
    zip \
    && rm -rf /var/lib/apt/lists/*

# Switch back to the app user if needed (the community image might use one)
# For now, we'll stay root to handle chmod and volume syncs in entrypoint
WORKDIR /data

# Copy our custom entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint-wrapper.sh

# Fix CRLF and make executable
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint-wrapper.sh && \
    chmod +x /usr/local/bin/entrypoint-wrapper.sh

# We overwrite their entrypoint with our wrapper
ENTRYPOINT ["/usr/local/bin/entrypoint-wrapper.sh"]
