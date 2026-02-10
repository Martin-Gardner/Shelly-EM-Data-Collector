# Shelly EM Data Collector

A PowerShell-based data collector for Shelly energy monitoring devices that sends power consumption data to InfluxDB. Supports both local network devices and Shelly Cloud-connected devices.

## Features

- **Multi-Device Support**: Collect data from Shelly EM, PM, and 3EM energy monitoring devices
- **Dual Collection Methods**: 
  - Local network devices (direct HTTP access)
  - Shelly Cloud devices (via Shelly Cloud API)
- **InfluxDB Integration**: Automatic time-series data storage in InfluxDB v2
- **Flexible Deployment**: Run as a Windows service, Docker container, or with Telegraf
- **Automatic Device Discovery**: Periodic refresh of cloud devices
- **Batch Processing**: Efficient cloud API batch queries (up to 10 devices per request)
- **Health Monitoring**: Generates health check file for monitoring systems
- **Error Handling**: Robust error handling with detailed logging
- **Environment Variables**: Support for secure credential management via environment variables
- **Graceful Shutdown**: Proper signal handling for clean stops
- **Statistics Tracking**: Built-in monitoring of collection success rates
- **Configuration Validation**: Automatic validation with helpful error messages

## Supported Shelly Devices

- **Shelly EM**: Single-phase energy meter with 2 channels
- **Shelly PM**: Plug-in power meter
- **Shelly 3EM**: Three-phase energy meter with 3 channels

## Requirements

- PowerShell 7.0 or later (cross-platform)
- InfluxDB v2.x instance
- Network access to:
  - Local Shelly devices (if using local mode)
  - Shelly Cloud API (if using cloud mode)
  - InfluxDB server

## Quick Start

### 1. Configure the Collector

Edit `config.json` with your settings (or use environment variables):

```json
{
  "Influx": {
    "Url": "http://your-influxdb:8086",
    "Org": "your-org",
    "Bucket": "power",
    "Token": "YOUR_INFLUX_TOKEN"
  },
  "IntervalSeconds": 10,
  "DeviceRefreshMinutes": 10,
  "LogPath": "./collector.log",
  "LocalDevices": [
    {
      "Name": "Kitchen",
      "Url": "http://192.168.1.100/status"
    }
  ],
  "ShellyCloud": {
    "Enabled": true,
    "Server": "https://shelly-001-eu.shelly.cloud",
    "Token": "YOUR_V2_BEARER_TOKEN"
  }
}
```

**Security Note**: You can use environment variables instead of storing sensitive values in config.json:
- `INFLUX_URL`, `INFLUX_ORG`, `INFLUX_BUCKET`, `INFLUX_TOKEN`
- `SHELLY_CLOUD_SERVER`, `SHELLY_CLOUD_TOKEN`

### 2. Run the Collector

```powershell
pwsh ./shelly-collector.ps1
```

Or with a custom config path:

```powershell
pwsh ./shelly-collector.ps1 -ConfigPath "/path/to/config.json"
```

## Configuration Reference

### InfluxDB Settings

| Parameter | Description | Example |
|-----------|-------------|---------|
| `Url` | InfluxDB server URL | `http://localhost:8086` |
| `Org` | InfluxDB organization | `home` |
| `Bucket` | InfluxDB bucket name | `power` |
| `Token` | InfluxDB API token | `your-token-here` |

### Collection Settings

| Parameter | Description | Default | Range |
|-----------|-------------|---------|-------|
| `IntervalSeconds` | Data collection interval | 10 | 1-3600 |
| `DeviceRefreshMinutes` | Cloud device list refresh interval | 10 | 1-1440 |
| `LogPath` | Path to log file | `./collector.log` | Any valid path |

### Local Devices

Add local network devices to the `LocalDevices` array:

```json
"LocalDevices": [
  {
    "Name": "Kitchen_EM",
    "Url": "http://192.168.1.100/status"
  },
  {
    "Name": "Garage_3EM", 
    "Url": "http://192.168.1.101/status"
  }
]
```

**Finding your device IP**: Check your router's DHCP leases or use the Shelly app to find device IP addresses.

### Shelly Cloud Settings

| Parameter | Description | Notes |
|-----------|-------------|-------|
| `Enabled` | Enable cloud device collection | `true` or `false` |
| `Server` | Shelly Cloud API server | Depends on your region |
| `Token` | Shelly Cloud API token | V2 Bearer token required |

**Cloud Server URLs**:
- Europe: `https://shelly-001-eu.shelly.cloud`
- US: `https://shelly-001-us.shelly.cloud`
- Asia: `https://shelly-001-as.shelly.cloud`

**Getting your Cloud Token**:
1. Log in to your Shelly Cloud account at https://control.shelly.cloud
2. Go to User Settings → Authorization Cloud Key
3. Generate a new API key (v2)

## Installation Methods

### Option 1: Windows Service

Run the collector as a Windows background service:

```powershell
# Edit install-service.ps1 to set your installation path
.\install-service.ps1 -ServiceName "ShellyCollector" -ScriptPath "C:\shelly\shelly-collector.ps1"
```

**Requirements**:
- Administrator privileges
- PowerShell 7 installed
- Script and config.json copied to target directory

**Service Management**:
```powershell
# Start service
Start-Service ShellyCollector

# Stop service
Stop-Service ShellyCollector

# Check status
Get-Service ShellyCollector

# Remove service
Remove-Service ShellyCollector
```

### Option 2: Docker Container

Run the collector in a Docker container:

```bash
# Build the image
docker build -t shelly-collector .

# Run the container with config file
docker run -d \
  --name shelly-collector \
  --restart unless-stopped \
  -v $(pwd)/config.json:/app/config.json:ro \
  -v $(pwd)/logs:/app/logs \
  shelly-collector

# Or use environment variables for sensitive data
docker run -d \
  --name shelly-collector \
  --restart unless-stopped \
  -v $(pwd)/config.json:/app/config.json:ro \
  -e INFLUX_TOKEN=your-secret-token \
  -e SHELLY_CLOUD_TOKEN=your-cloud-token \
  shelly-collector
```

**Docker Compose with Full Stack**:

See `docker-compose.yml` for a complete setup including InfluxDB and Grafana:

```bash
# Copy and edit config
cp config.example.json config.json

# Start the full stack
docker-compose up -d

# View logs
docker-compose logs -f shelly-collector
```

### Option 3: Telegraf Integration

Use Telegraf to run the collector and manage the output:

1. Copy the script to `/opt/shelly/`
2. Update `telegraf.conf` with the correct path
3. Add the configuration to your Telegraf config:

```toml
[[inputs.exec]]
  commands = ["pwsh /opt/shelly/shelly-collector.ps1"]
  timeout = "30s"
  data_format = "influx"
```

### Option 4: Manual Execution

For testing or development:

```powershell
# Run in foreground
pwsh ./shelly-collector.ps1

# Run in background (Linux/macOS)
nohup pwsh ./shelly-collector.ps1 &

# Run in background (Windows PowerShell)
Start-Process pwsh -ArgumentList "-File ./shelly-collector.ps1" -WindowStyle Hidden
```

## Data Format

The collector sends data to InfluxDB in line protocol format:

```
shelly,device=<device_name> power=<total_watts>[,power_l1=<watts>,power_l2=<watts>,power_l3=<watts>][,temperature=<celsius>]
```

**Fields**:
- `power`: Total power consumption in watts (always present)
- `power_l1`, `power_l2`, `power_l3`: Per-phase power for multi-channel devices
- `temperature`: Device temperature in Celsius (if available)

**Example**:
```
shelly,device=Kitchen_EM power=1250.5,power_l1=650.2,power_l2=600.3,temperature=45.2
```

## Monitoring and Health Checks

The collector creates a `health.txt` file every collection cycle:

```
OK 2026-02-10T17:00:00
```

The collector also logs statistics periodically (every 100 collections):
```
2026-02-10T17:00:00 Stats: 100 collections, 98.0% success rate
```

Use the health file for external monitoring systems (e.g., Nagios, Zabbix, Prometheus).

**Example health check script**:
```powershell
$health = Get-Content health.txt
$time = [DateTime]::Parse($health.Split(" ")[1])
if ((Get-Date) - $time -gt [TimeSpan]::FromMinutes(5)) {
    Write-Error "Collector is stale"
    exit 1
}
```

## Logging

Logs are written to the file specified in `LogPath` (default: `./collector.log`).

**Log Format**:
```
2026-02-10T17:00:00 Shelly Collector starting
2026-02-10T17:00:00 InfluxDB: http://localhost:8086, Org: home, Bucket: power
2026-02-10T17:00:00 Collection interval: 10 seconds, Device refresh: 10 minutes
2026-02-10T17:00:00 Starting with 5 devices
2026-02-10T17:00:00 Refreshing device list
2026-02-10T17:00:00 Discovered 3 cloud devices
2026-02-10T17:00:10 Influx write failed: Connection timeout
2026-02-10T17:00:10 Stats: 100 collections, 98.0% success rate
2026-02-10T17:00:10 Shelly Collector shutting down gracefully
```

Improved error messages now include exception details for easier troubleshooting.

**Log Rotation**: The collector appends to the log file indefinitely. Implement external log rotation:

**Linux (logrotate)**:
```
/opt/shelly/collector.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
}
```

**Windows**: Use Task Scheduler to run a cleanup script periodically.

## Troubleshooting

### No Data Appearing in InfluxDB

1. **Check InfluxDB connection**:
   ```powershell
   Invoke-RestMethod -Uri "http://your-influx:8086/health"
   ```

2. **Verify token permissions**: Ensure the token has write access to the bucket

3. **Check logs**: Look for "Influx write failed" messages

4. **Test data manually**:
   ```powershell
   curl -X POST "http://your-influx:8086/api/v2/write?org=home&bucket=power" \
     -H "Authorization: Token YOUR_TOKEN" \
     --data-raw "shelly,device=test power=100"
   ```

### Local Devices Not Working

1. **Verify device accessibility**:
   ```powershell
   Invoke-RestMethod -Uri "http://192.168.1.100/status"
   ```

2. **Check firewall**: Ensure no firewall is blocking access

3. **Verify URL format**: Must include `/status` endpoint

4. **Check device firmware**: Update to latest firmware if needed

### Cloud Devices Not Discovered

1. **Verify cloud token**: Test with:
   ```powershell
   $headers = @{ "Authorization" = "Bearer YOUR_TOKEN" }
   Invoke-RestMethod -Uri "https://shelly-001-eu.shelly.cloud/v2/devices" -Headers $headers
   ```

2. **Check server URL**: Ensure you're using the correct region

3. **Verify device types**: Only EM, PM, and 3EM devices are collected

4. **Check token expiry**: Cloud tokens may expire and need renewal

### High CPU or Memory Usage

1. **Increase collection interval**: Set `IntervalSeconds` to a higher value (e.g., 30)

2. **Reduce device refresh frequency**: Increase `DeviceRefreshMinutes` (e.g., 30)

3. **Limit cloud devices**: Cloud API queries are batched but still resource-intensive

## Architecture

### Collection Flow

```
┌─────────────────┐
│  Config.json    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Shelly Collector│
└────────┬────────┘
         │
         ├──────────────┐
         │              │
         ▼              ▼
┌──────────────┐ ┌─────────────┐
│Local Devices │ │Shelly Cloud │
│  (Direct)    │ │   (API)     │
└──────┬───────┘ └──────┬──────┘
       │                │
       └────────┬───────┘
                │
                ▼
        ┌───────────────┐
        │   InfluxDB    │
        └───────────────┘
```

### Key Components

1. **Configuration Loader**: Reads and validates `config.json`
2. **Device Manager**: Discovers and tracks devices
3. **Data Collectors**: 
   - Local collector: Direct HTTP requests to devices
   - Cloud collector: Batch API requests to Shelly Cloud
4. **Data Transformer**: Converts device status to InfluxDB line protocol
5. **InfluxDB Writer**: Sends data to InfluxDB via HTTP API

## Performance Considerations

- **Batch Processing**: Cloud devices are queried in batches of 10 to minimize API calls
- **Parallel Local Queries**: Local devices are queried sequentially to avoid overwhelming the network
- **Efficient Refresh**: Device list is cached and refreshed only periodically
- **Minimal Parsing**: Uses PowerShell native JSON parsing for speed
- **Error Isolation**: Failures in one device don't affect others
- **Graceful Shutdown**: Properly handles termination signals for clean shutdown

## Data Visualization with Grafana

The collector stores data in InfluxDB, which integrates seamlessly with Grafana for visualization.

See the [grafana/README.md](grafana/README.md) for:
- Step-by-step Grafana setup instructions
- Example Flux queries for common use cases
- Dashboard panel ideas and configurations
- Alert rule examples
- Tips and best practices

**Quick Start with Docker Compose**:
```bash
docker-compose up -d
# Access Grafana at http://localhost:3000 (admin/admin)
```

The included `docker-compose.yml` sets up the complete stack: Shelly Collector, InfluxDB, and Grafana.

## Security Best Practices

1. **Protect Tokens**: 
   - Never commit `config.json` with real tokens to version control
   - Use environment variables for sensitive values in production:
     ```bash
     export INFLUX_TOKEN="your-secret-token"
     export SHELLY_CLOUD_TOKEN="your-cloud-token"
     pwsh ./shelly-collector.ps1
     ```
   - Use secrets management systems (e.g., Docker secrets, Kubernetes secrets)
   - Restrict file permissions: `chmod 600 config.json`

2. **Network Security**:
   - Use HTTPS for InfluxDB if possible
   - Place Shelly devices on an isolated IoT network
   - Use VPN for remote access

3. **InfluxDB Token Permissions**:
   - Create a token with write-only access to the specific bucket
   - Never use an all-access token

4. **Service Account**: Run the Windows service under a dedicated service account with minimal privileges

## Development

### Project Structure

```
.
├── shelly-collector.ps1    # Main collector script
├── config.json             # Configuration file
├── install-service.ps1     # Windows service installer
├── Dockerfile             # Docker container definition
├── telegraf.conf          # Telegraf integration example
└── README.md              # This file
```

### Adding New Device Types

To support additional Shelly device types, update the `Convert-ToInfluxLine` function:

```powershell
# Add new status field parsing
if ($Status.your_new_field) {
    $fields += "new_metric=$($Status.your_new_field)"
}
```

### Testing

Manual testing with a mock InfluxDB endpoint:

```powershell
# Create a simple HTTP listener for testing
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:8086/")
$listener.Start()
```

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

Key areas for contribution:
- Unit tests using Pester
- Additional device type support
- Performance optimizations
- Documentation improvements

Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes with clear commit messages
4. Test thoroughly with your Shelly devices
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For issues, questions, or feature requests, please open an issue on the GitHub repository.

## Acknowledgments

- Built for [Shelly](https://shelly.cloud) energy monitoring devices
- Integrates with [InfluxDB](https://www.influxdata.com/) time-series database
- Written in [PowerShell](https://github.com/PowerShell/PowerShell) for cross-platform support
