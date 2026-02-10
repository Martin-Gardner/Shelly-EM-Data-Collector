<#
.SYNOPSIS
    Installs the Shelly Collector as a Windows service.

.DESCRIPTION
    Creates and starts a Windows service that runs the Shelly collector script
    continuously in the background. The service will start automatically on system boot.

.PARAMETER ServiceName
    Name of the Windows service to create. Default: "ShellyCollector"

.PARAMETER ScriptPath
    Full path to the shelly-collector.ps1 script. Must be an absolute path.
    Default: "C:\shelly\shelly-collector.ps1"

.EXAMPLE
    .\install-service.ps1
    Install with default settings

.EXAMPLE
    .\install-service.ps1 -ServiceName "MyShellyService" -ScriptPath "D:\scripts\shelly-collector.ps1"
    Install with custom service name and script path

.NOTES
    Requires Administrator privileges
    Requires PowerShell 7 (pwsh) to be installed
    The script and config.json must be in the target directory before running
#>

# install-service.ps1
param(
    [string]$ServiceName = "ShellyCollector",
    [string]$ScriptPath = "C:\shelly\shelly-collector.ps1"
)

# Get PowerShell 7 executable path
$pwsh = (Get-Command pwsh).Source

# Create the Windows service
New-Service -Name $ServiceName `
    -BinaryPathName "`"$pwsh`" -File `"$ScriptPath`"" `
    -DisplayName "Shelly Power Collector" `
    -StartupType Automatic

# Start the service immediately
Start-Service $ServiceName
