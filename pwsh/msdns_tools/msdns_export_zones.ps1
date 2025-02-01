$ZoneNames = @((Get-DnsServerZone |
        Where-Object {
            $_.IsAutoCreated -eq $false -and @("Primary", "Secondary") -contains $_.ZoneType -and $_.ZoneName -ne "TrustAnchors"
        } | Select-Object ZoneName).ZoneName)

$datetime = Get-Date -Format 'yyyyMMdd-HHmm'
$dir = Join-Path -Path (Join-Path -Path $env:SystemRoot -ChildPath "System32\dns") `
    -ChildPath $datetime
New-Item -Path $dir -ItemType Directory | Out-Null
$dnsinfodir = Join-Path -Path $env:USERPROFILE -ChildPath "Desktop\dnsinfo"
if (-not (Test-Path -Path $dnsinfodir)) {
    New-Item -Path $dnsinfodir -ItemType Directory | Out-Null
}
$destdir = Join-Path -Path $dnsinfodir -ChildPath $datetime

foreach ($ZoneName in $ZoneNames) {
    $ZoneFile = Join-Path -Path $datetime -ChildPath "$($ZoneName).dns"
    Write-Output "Exporting $ZoneName to $ZoneFile"
    Export-DnsServerZone -Name $ZoneName -FileName $ZoneFile
}

Write-Output "Exported zone files to $dnsinfodir\$datetime"
Move-Item -Path $dir -Destination $dnsinfodir

$csvFile = Join-Path -Path $destdir -ChildPath "zones.csv"
Write-Output "Output the list of zones to $csvFile"
Get-DnsServerZone |
Select-Object ZoneName, ZoneType, ZoneFile, Notify, IsAutoCreated, IsDsIntegrated, IsReverseLookupZone, IsSigned |
Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8

$csvFile = Join-Path -Path $destdir -ChildPath "forwarders.csv"
Write-Output "Output the list of forwarders to $csvFile"
Get-DnsServerForwarder |
Select-Object IPAddress, ReorderedIPAddress, EnableReordering, Timeout, UseRootHint |
Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8
