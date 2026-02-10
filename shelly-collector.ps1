<#
.SYNOPSIS
    Shelly EM Data Collector - Collects power data from Shelly devices and sends to InfluxDB.

.DESCRIPTION
    This script continuously collects power consumption data from Shelly energy monitoring
    devices (EM, PM, 3EM) via local network or Shelly Cloud API, then sends the data to
    InfluxDB v2 in line protocol format.

.PARAMETER ConfigPath
    Path to the configuration JSON file. Defaults to ".\config.json"

.EXAMPLE
    pwsh .\shelly-collector.ps1
    Run with default config.json in current directory

.EXAMPLE
    pwsh .\shelly-collector.ps1 -ConfigPath "C:\config\shelly-config.json"
    Run with custom config file path

.NOTES
    Requires PowerShell 7.0 or later
    Requires network access to InfluxDB and Shelly devices/cloud
#>

param(
    [string]$ConfigPath = ".\config.json"
)

# Load and parse configuration file
$config = Get-Content $ConfigPath | ConvertFrom-Json

# Set log file path from config or use default
$logPath = $config.LogPath
if (-not $logPath) { $logPath = ".\collector.log" }

<#
.SYNOPSIS
    Writes a log message to file and console.

.PARAMETER msg
    The message to log
#>
function Log {
    param([string]$msg)
    $line = "$(Get-Date -Format s) $msg"
    $line | Out-File -FilePath $logPath -Append -Encoding utf8
    Write-Host $line
}

# ============================================================================
# InfluxDB Configuration
# ============================================================================

# Influx connection settings
$influxUrl    = $config.Influx.Url.TrimEnd("/")
$influxOrg    = $config.Influx.Org
$influxBucket = $config.Influx.Bucket
$influxToken  = $config.Influx.Token
$interval     = [int]$config.IntervalSeconds
$refreshMin   = [int]$config.DeviceRefreshMinutes

# Build InfluxDB write URL with query parameters
$writeUrl = "$influxUrl/api/v2/write?org=$influxOrg&bucket=$influxBucket&precision=s"
$influxHeaders = @{
    "Authorization" = "Token $influxToken"
    "Content-Type"  = "text/plain; charset=utf-8"
}

# ============================================================================
# Shelly Cloud Configuration
# ============================================================================

# Cloud API settings (if enabled)
$cloudEnabled = $config.ShellyCloud.Enabled
if ($cloudEnabled) {
    $cloudServer = $config.ShellyCloud.Server.TrimEnd("/")
    $cloudToken  = $config.ShellyCloud.Token
    $cloudHeaders = @{
        "Authorization" = "Bearer $cloudToken"
        "Content-Type"  = "application/json"
    }
}

<#
.SYNOPSIS
    Sends a line of data to InfluxDB.

.DESCRIPTION
    Writes a single line of InfluxDB line protocol data to the configured
    InfluxDB instance using the HTTP API.

.PARAMETER Line
    InfluxDB line protocol formatted string (e.g., "measurement,tag=value field=123")
#>
function Send-ToInflux {
    param([string]$Line)
    try {
        Invoke-RestMethod -Method Post -Uri $writeUrl -Headers $influxHeaders -Body $Line -TimeoutSec 5 | Out-Null
    } catch {
        Log "Influx write failed"
    }
}

<#
.SYNOPSIS
    Retrieves the list of configured local devices.

.DESCRIPTION
    Reads local device configuration from config.json and returns a normalized
    array of device objects with Id, Name, Type, and Url properties.

.OUTPUTS
    Array of device objects configured for local network access
#>
function Get-LocalDevices {
    $devices = @()
    foreach ($dev in $config.LocalDevices) {
        $devices += [pscustomobject]@{
            Id   = $dev.Url
            Name = $dev.Name
            Type = "local"
            Url  = $dev.Url
        }
    }
    return $devices
}

<#
.SYNOPSIS
    Discovers Shelly devices registered in Shelly Cloud.

.DESCRIPTION
    Queries the Shelly Cloud API to get a list of all registered devices.
    Filters for energy monitoring devices (EM, PM, 3EM types) and returns
    a normalized array of device objects.

.OUTPUTS
    Array of device objects discovered from Shelly Cloud, or empty array if cloud is disabled or query fails
#>
function Get-CloudDevices {
    if (-not $cloudEnabled) { return @() }
    $uri = "$cloudServer/v2/devices"
    try {
        $resp = Invoke-RestMethod -Uri $uri -Headers $cloudHeaders -TimeoutSec 15
        $devices = @()
        foreach ($dev in $resp.data) {
            if ($dev.type -match "EM|PM|3EM") {
                $devices += [pscustomobject]@{
                    Id   = $dev.id
                    Name = $dev.name
                    Type = "cloud"
                }
            }
        }
        return $devices
    } catch {
        Log "Cloud device discovery failed"
        return @()
    }
}

<#
.SYNOPSIS
    Retrieves status for multiple cloud devices in a single batch request.

.DESCRIPTION
    Queries Shelly Cloud API for device status using batch endpoint.
    More efficient than individual queries when monitoring multiple devices.
    Supports up to 10 devices per batch (API limitation).

.PARAMETER DeviceIds
    Array of Shelly Cloud device IDs to query

.OUTPUTS
    API response object containing status data for all requested devices, or null on failure
#>
function Get-CloudStatusBatch {
    param([array]$DeviceIds)
    $uri = "$cloudServer/v2/devices/status"
    $body = @{ ids = $DeviceIds } | ConvertTo-Json -Depth 3
    try {
        return Invoke-RestMethod -Method Post -Uri $uri -Headers $cloudHeaders -Body $body -TimeoutSec 15
    } catch {
        Log "Cloud batch query failed"
        return $null
    }
}

<#
.SYNOPSIS
    Retrieves status from a local network Shelly device.

.DESCRIPTION
    Makes HTTP request to local device's /status endpoint to retrieve
    current power consumption and sensor data.

.PARAMETER device
    Device object containing Url property

.OUTPUTS
    Device status object (JSON parsed), or null on failure
#>
function Get-LocalStatus {
    param($device)
    try {
        return Invoke-RestMethod -Uri $device.Url -TimeoutSec 5
    } catch {
        Log "Local query failed: $($device.Name)"
        return $null
    }
}

<#
.SYNOPSIS
    Converts Shelly device status to InfluxDB line protocol format.

.DESCRIPTION
    Transforms device status JSON into InfluxDB line protocol string.
    Handles multiple device types:
    - EM/3EM devices: power per channel (emeters)
    - PM devices: power per channel (meters)
    - Switch devices: total power (switches)
    Also extracts temperature data if available.

.PARAMETER DeviceName
    Name/identifier for the device (used as tag in InfluxDB)

.PARAMETER Status
    Device status object (parsed JSON from device or cloud API)

.OUTPUTS
    InfluxDB line protocol string, or null if no valid data found
    Format: "shelly,device=<name> power=<watts>[,power_l1=<watts>,...][,temperature=<celsius>]"
#>
function Convert-ToInfluxLine {
    param([string]$DeviceName, $Status)
    $fields = @()
    $totalPower = 0

    # Handle Shelly EM and 3EM devices (emeters property)
    if ($Status.emeters) {
        $i = 1
        foreach ($m in $Status.emeters) {
            $p = [double]$m.power
            $fields += "power_l$i=$p"
            $totalPower += $p
            $i++
        }
    }
    # Handle Shelly PM devices (meters property)
    elseif ($Status.meters) {
        $i = 1
        foreach ($m in $Status.meters) {
            $p = [double]$m.power
            $fields += "power_l$i=$p"
            $totalPower += $p
            $i++
        }
    }
    # Handle switch-based devices (e.g., Shelly Plug)
    elseif ($Status.switches) {
        foreach ($sw in $Status.switches) {
            $totalPower += [double]$sw.apower
        }
    }

    # Add total power field if we have any power data
    if ($totalPower -ne 0) {
        $fields += "power=$totalPower"
    }

    # Extract temperature data if available
    if ($Status.temperature.tC) {
        $fields += "temperature=$($Status.temperature.tC)"
    } elseif ($Status.tmp.tC) {
        $fields += "temperature=$($Status.tmp.tC)"
    }

    # Return null if no valid fields were extracted
    if ($fields.Count -eq 0) { return $null }
    
    # Return InfluxDB line protocol formatted string
    return "shelly,device=$DeviceName " + ($fields -join ",")
}

<#
.SYNOPSIS
    Refreshes the list of all devices (local and cloud).

.DESCRIPTION
    Combines local device configuration with cloud device discovery
    to create a complete list of devices to monitor.

.OUTPUTS
    Array of all device objects (both local and cloud)
#>
function Refresh-Devices {
    Log "Refreshing device list"
    return (Get-LocalDevices) + (Get-CloudDevices)
}

# ============================================================================
# Main Collection Loop
# ============================================================================

Log "Shelly Collector starting"

# Initial device discovery
$devices = Refresh-Devices
$lastRefresh = Get-Date

while ($true) {

    # Periodically refresh device list (for cloud device changes)
    if ((Get-Date) -gt $lastRefresh.AddMinutes($refreshMin)) {
        $devices = Refresh-Devices
        $lastRefresh = Get-Date
    }

    # Separate devices by type for different collection methods
    $localDevices = $devices | Where-Object { $_.Type -eq "local" }
    $cloudDevices = $devices | Where-Object { $_.Type -eq "cloud" }

    # Collect data from local devices (sequential queries)
    foreach ($dev in $localDevices) {
        $status = Get-LocalStatus -device $dev
        if ($status) {
            $line = Convert-ToInfluxLine -DeviceName $dev.Name -Status $status
            if ($line) { Send-ToInflux $line }
        }
    }

    # Collect data from cloud devices (batch queries of up to 10 devices)
    if ($cloudDevices.Count -gt 0) {
        for ($i = 0; $i -lt $cloudDevices.Count; $i += 10) {
            # Get batch of up to 10 devices (Shelly Cloud API limit)
            $batch = $cloudDevices[$i..([math]::Min($i+9, $cloudDevices.Count-1))]
            $ids = $batch | ForEach-Object { $_.Id }
            
            # Query batch status from cloud
            $resp = Get-CloudStatusBatch -DeviceIds $ids
            if ($resp -and $resp.data) {
                # Process each device in the batch
                foreach ($dev in $batch) {
                    $status = $resp.data.$($dev.Id)
                    if ($status) {
                        $line = Convert-ToInfluxLine -DeviceName $dev.Name -Status $status
                        if ($line) { Send-ToInflux $line }
                    }
                }
            }
        }
    }

    # Write health check file for monitoring systems
    "OK $(Get-Date -Format s)" | Out-File ".\health.txt" -Encoding ascii

    # Wait for next collection interval
    Start-Sleep -Seconds $interval
}
