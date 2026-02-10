
param(
    [string]$ConfigPath = ".\config.json"
)

$config = Get-Content $ConfigPath | ConvertFrom-Json

$logPath = $config.LogPath
if (-not $logPath) { $logPath = ".\collector.log" }

function Log {
    param([string]$msg)
    $line = "$(Get-Date -Format s) $msg"
    $line | Out-File -FilePath $logPath -Append -Encoding utf8
    Write-Host $line
}

# Influx settings
$influxUrl    = $config.Influx.Url.TrimEnd("/")
$influxOrg    = $config.Influx.Org
$influxBucket = $config.Influx.Bucket
$influxToken  = $config.Influx.Token
$interval     = [int]$config.IntervalSeconds
$refreshMin   = [int]$config.DeviceRefreshMinutes

$writeUrl = "$influxUrl/api/v2/write?org=$influxOrg&bucket=$influxBucket&precision=s"
$influxHeaders = @{
    "Authorization" = "Token $influxToken"
    "Content-Type"  = "text/plain; charset=utf-8"
}

# Cloud settings
$cloudEnabled = $config.ShellyCloud.Enabled
if ($cloudEnabled) {
    $cloudServer = $config.ShellyCloud.Server.TrimEnd("/")
    $cloudToken  = $config.ShellyCloud.Token
    $cloudHeaders = @{
        "Authorization" = "Bearer $cloudToken"
        "Content-Type"  = "application/json"
    }
}

function Send-ToInflux {
    param([string]$Line)
    try {
        Invoke-RestMethod -Method Post -Uri $writeUrl -Headers $influxHeaders -Body $Line -TimeoutSec 5 | Out-Null
    } catch {
        Log "Influx write failed"
    }
}

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

function Get-LocalStatus {
    param($device)
    try {
        return Invoke-RestMethod -Uri $device.Url -TimeoutSec 5
    } catch {
        Log "Local query failed: $($device.Name)"
        return $null
    }
}

function Convert-ToInfluxLine {
    param([string]$DeviceName, $Status)
    $fields = @()
    $totalPower = 0

    if ($Status.emeters) {
        $i = 1
        foreach ($m in $Status.emeters) {
            $p = [double]$m.power
            $fields += "power_l$i=$p"
            $totalPower += $p
            $i++
        }
    } elseif ($Status.meters) {
        $i = 1
        foreach ($m in $Status.meters) {
            $p = [double]$m.power
            $fields += "power_l$i=$p"
            $totalPower += $p
            $i++
        }
    } elseif ($Status.switches) {
        foreach ($sw in $Status.switches) {
            $totalPower += [double]$sw.apower
        }
    }

    if ($totalPower -ne 0) {
        $fields += "power=$totalPower"
    }

    if ($Status.temperature.tC) {
        $fields += "temperature=$($Status.temperature.tC)"
    } elseif ($Status.tmp.tC) {
        $fields += "temperature=$($Status.tmp.tC)"
    }

    if ($fields.Count -eq 0) { return $null }
    return "shelly,device=$DeviceName " + ($fields -join ",")
}

function Refresh-Devices {
    Log "Refreshing device list"
    return (Get-LocalDevices) + (Get-CloudDevices)
}

Log "Shelly Collector starting"
$devices = Refresh-Devices
$lastRefresh = Get-Date

while ($true) {

    if ((Get-Date) -gt $lastRefresh.AddMinutes($refreshMin)) {
        $devices = Refresh-Devices
        $lastRefresh = Get-Date
    }

    $localDevices = $devices | Where-Object { $_.Type -eq "local" }
    $cloudDevices = $devices | Where-Object { $_.Type -eq "cloud" }

    foreach ($dev in $localDevices) {
        $status = Get-LocalStatus -device $dev
        if ($status) {
            $line = Convert-ToInfluxLine -DeviceName $dev.Name -Status $status
            if ($line) { Send-ToInflux $line }
        }
    }

    if ($cloudDevices.Count -gt 0) {
        for ($i = 0; $i -lt $cloudDevices.Count; $i += 10) {
            $batch = $cloudDevices[$i..([math]::Min($i+9, $cloudDevices.Count-1))]
            $ids = $batch | ForEach-Object { $_.Id }
            $resp = Get-CloudStatusBatch -DeviceIds $ids
            if ($resp -and $resp.data) {
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

    "OK $(Get-Date -Format s)" | Out-File ".\health.txt" -Encoding ascii

    Start-Sleep -Seconds $interval
}
