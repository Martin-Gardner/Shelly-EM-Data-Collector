# Shelly EM Data Collector - Docker Image
# 
# This Dockerfile creates a lightweight container to run the Shelly collector
# using PowerShell 7 on Alpine Linux.
#
# Build: docker build -t shelly-collector .
# Run:   docker run -d --name shelly-collector -v $(pwd)/config.json:/app/config.json:ro shelly-collector

# Use official PowerShell 7 image based on Alpine Linux (minimal size)
FROM mcr.microsoft.com/powershell:7.4-alpine-3.20

# Set working directory
WORKDIR /app

# Copy collector script and default configuration
COPY shelly-collector.ps1 /app/
COPY config.json /app/

# Run the collector script when container starts
CMD ["pwsh", "/app/shelly-collector.ps1"]
