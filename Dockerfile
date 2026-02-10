
FROM mcr.microsoft.com/powershell:7.4-alpine
WORKDIR /app
COPY shelly-collector.ps1 /app/
COPY config.json /app/
CMD ["pwsh", "/app/shelly-collector.ps1"]
