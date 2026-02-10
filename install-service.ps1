
# install-service.ps1
param(
    [string]$ServiceName = "ShellyCollector",
    [string]$ScriptPath = "C:\shelly\shelly-collector.ps1"
)

$pwsh = (Get-Command pwsh).Source
New-Service -Name $ServiceName `
    -BinaryPathName "`"$pwsh`" -File `"$ScriptPath`"" `
    -DisplayName "Shelly Power Collector" `
    -StartupType Automatic
Start-Service $ServiceName
