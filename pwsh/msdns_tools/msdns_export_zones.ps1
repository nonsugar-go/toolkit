$ZoneName = @((Get-DnsServerZone |
        Where-Object { $_.ZoneType -eq "Primary" -and $_.ZoneName -ne "TrustAnchors" } |
        Select-Object ZoneName).ZoneName)

$dir = "$env:USERPROFILE\Desktop\dnsinfo_$(Get-Date -Format 'yyyyMMdd-HHmm')"
New-Item -Path $dir -ItemType Directory | Out-Null

foreach ($ZoneName in $ZoneName) {
    Write-Output "Exporting zone: $ZoneName"
    $ZoneFile = Join-Path -Path $dir -ChildPath "zonefile_$ZoneName.dns"
    $RRS = Get-DnsServerResourceRecord -ZoneName $ZoneName
    $RRS | ForEach-Object {
        $HostName = $_.HostName
        $TimeToLive = $_.TimeToLive.TotalSeconds
        $RecordClass = $_.RecordClass
        $RecordType = $_.RecordType
        $RecordData = $_.RecordData
        switch ($RecordType) {
            "A" {
                $RD = $RecordData.IPv4Address.IPAddressToString
            }
            "AAAA" {
                $RD = $RecordData.IPv6Address.IPAddressToString
            }
            "CNAME" {
                $RD = $RecordData.HostNameAlias
            }
            "NS" {
                $RD = $RecordData.NameServer
            }
            "MX" {
                $RD = "$($RecordData.Preference) $($RecordData.MailExchange)"
            }
            "PTR" {
                $RD = $RecordData.PtrDomainName
            }
            "SOA" {
                $PrimaryServer = $RecordData.PrimaryServer
                $ResponsiblePerson = $RecordData.ResponsiblePerson
                $SerialNumber = $RecordData.SerialNumber
                $RefreshInterval = $RecordData.RefreshInterval.TotalSeconds
                $RetryDelay = $RecordData.RetryDelay.TotalSeconds
                $ExpireLimit = $RecordData.ExpireLimit.TotalSeconds
                $MinimumTimeToLive = $RecordData.MinimumTimeToLive.TotalSeconds

                $RD = "$PrimaryServer $ResponsiblePerson ( $SerialNumber $RefreshInterval $RetryDelay $ExpireLimit $MinimumTimeToLive )"
            }
            "SRV" {
                $RD = "$($RecordData.Priority) $($RecordData.Weight) $($RecordData.Port) $($RecordData.DomainName)"
            }
            "TXT" {
                $RD = "`"$($RecordData.DescriptiveText)`""
            }
            default {
                Write-Warning "Unknown RecordType: $RecordType"
                $RD = $RecordData
            }
        }   

        $line = "$HostName`t$TimeToLive`t$RecordClass`t$RecordType`t$RD"
        Add-Content -Path $ZoneFile -Value $line -Encoding UTF8
    }
}

$csvFile = Join-Path -Path $dir -ChildPath "zones.csv"
Get-DnsServerZone |
Select-Object ZoneName, ZoneType, ZoneFile, Notify, IsAutoCreated, IsDsIntegrated, IsReverseLookupZone, IsSigned |
Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8

$csvFile = Join-Path -Path $dir -ChildPath "forwarder.csv"
Get-DnsServerForwarder |
Select-Object IPAddress, ReorderedIPAddress, EnableReordering, Timeout, UseRootHint |
Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8
