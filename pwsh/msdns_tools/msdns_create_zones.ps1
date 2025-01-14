$ZoneNames = @(
    "hoge.com",
    "example.com",
    "1.168.192.in-addr.arpa"
)
$ResponsiblePerson = "root.contoso.com."
$NameServers = @("w22-1.blue.test", "ns1.contoso.com", "ns2.contoso.com")

$confirmation = Read-Host "Do you want to proceed with the changes? [yes/no]"
if ($confirmation -eq "yes") {
    Write-Output "Proceeding with the changes..."
}
else {
    Write-Output "Operation cancelled."
    exit(0)
}

foreach ($ZoneName in $ZoneNames) {
    $existingZone = $null
    $existingZone = Get-DnsServerZone -ZoneName $ZoneName -ErrorAction SilentlyContinue
    if ($existingZone) {
        Write-Output "Zone $ZoneName already exists. Skipping..."
        continue
    }

    Write-Output "Creating zone: $ZoneName"
    $ZoneFile = "$ZoneName.dns"
    Add-DnsServerPrimaryZone -Name $ZoneName -ZoneFile $ZoneFile
    foreach ($NameServer in $NameServers) {
        $recordExists = $null
        $recordExists = Get-DnsServerResourceRecord -ZoneName $ZoneName -Name "@" -RRType "NS" -ErrorAction SilentlyContinue |
        Where-Object { $_.RecordData.NameServer -eq "${NameServer}." }
        if ($recordExists) {
            Write-Output "`tNS record for $NameServer already exists."
            continue
        }
        Add-DnsServerResourceRecord -ZoneName $ZoneName -Name "@" -NS -NameServer $NameServer -TimeToLive "01:00:00"
    }

    $OldSOA = Get-DnsServerResourceRecord -ZoneName $ZoneName -Name "@" -RRType "SOA"
    $NewSOA = [ciminstance]::new($OldSOA)
    $NewSOA.TimeToLive = [System.TimeSpan]::FromDays(1)
    $NewSOA.RecordData.PrimaryServer = $NameServers[0]
    $NewSOA.RecordData.ResponsiblePerson = $ResponsiblePerson
    $NewSOA.RecordData.SerialNumber = "$(Get-Date -Format 'yyyyMMdd')01"
    $NewSOA.RecordData.RefreshInterval = [System.TimeSpan]::FromHours(1)
    $NewSOA.RecordData.RetryDelay = [System.TimeSpan]::FromMinutes(20)
    $NewSOA.RecordData.ExpireLimit = [System.TimeSpan]::FromDays(14)
    $NewSOA.RecordData.MinimumTimeToLive = [System.TimeSpan]::FromDays(1)
    Set-DnsServerResourceRecord -NewInputObject $NewSOA -OldInputObject $OldSOA -ZoneName $ZoneName
}