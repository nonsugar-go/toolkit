$ZoneNames = @(
    "hoge.com",
    "1.168.192.in-addr.arpa"
)
$ResponsiblePerson = "root.contoso.com."
$NameServers = @("ns1.contoso.com", "ns2.contoso.com")
foreach ($ZoneName in $ZoneNames) {
    Write-Output "Creating zone: $ZoneName"
    $ZoneFile = "$ZoneName.dns"
    Add-DnsServerPrimaryZone -Name $ZoneName -ZoneFile $ZoneFile

    Add-DnsServerResourceRecord -ZoneName $ZoneName -Name "@" -NS -NameServer $NameServers[0] -TimeToLive "01:00:00"
    Add-DnsServerResourceRecord -ZoneName $ZoneName -Name "@" -NS -NameServer $NameServers[1] -TimeToLive "01:00:00"

    $OldSOA = Get-DnsServerResourceRecord -ZoneName $ZoneName -Name "@" -RRType "SOA"
    $NewSOA = [ciminstance]::new($OldSOA)
    $NewSOA.TimeToLive = [System.TimeSpan]::FromDays(1)
    $NewSOA.RecordData.ResponsiblePerson = $ResponsiblePerson
    $NewSOA.RecordData.SerialNumber = "$(Get-Date -Format 'yyyyMMdd')01"
    $NewSOA.RecordData.RefreshInterval = [System.TimeSpan]::FromHours(1)
    $NewSOA.RecordData.RetryDelay = [System.TimeSpan]::FromMinutes(20)
    $NewSOA.RecordData.ExpireLimit = [System.TimeSpan]::FromDays(14)
    $NewSOA.RecordData.MinimumTimeToLive = [System.TimeSpan]::FromDays(1)
    Set-DnsServerResourceRecord -NewInputObject $NewSOA -OldInputObject $OldSOA -ZoneName $ZoneName
}