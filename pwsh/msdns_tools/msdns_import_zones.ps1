param (
    [string]$ZoneName,
    [string]$ZoneFile
)

if ($ZoneName -eq "" -or $ZoneFile -eq "") {
    Write-Warning "Usage: dns_import_zones.ps1 -ZoneName <ZoneName> -ZoneFile <ZoneFile>"
    exit(1)
}

Write-Output "Importing zone $ZoneName from file $ZoneFile"

foreach ($line in Get-Content -Path $ZoneFile) {
    $fields = $line -split "`t"
    $HostName = $fields[0]
    $TimeToLive = [System.TimeSpan]::FromSeconds($fields[1])
    # $RecordClass = $fields[2]
    $RecordType = $fields[3]
    $RD = $fields[4]

    switch ($RecordType) {
        "A" {
            Add-DnsServerResourceRecordA -Name $HostName -IPv4Address $RD -ZoneName $ZoneName -TimeToLive $TimeToLive
        }
        "AAAA" {
            Add-DnsServerResourceRecordAAAA -Name $HostName -IPv6Address $RD -ZoneName $ZoneName -TimeToLive $TimeToLive
        }
        "CNAME" {
            Add-DnsServerResourceRecordCName -Name $HostName -HostNameAlias $RD -ZoneName $ZoneName -TimeToLive $TimeToLive
        }
        "NS" {
            Write-Output "NS: $RD"
            # Add-DnsServerResourceRecordNS -Name $HostName -NameServer $RD -ZoneName $ZoneName -TimeToLive $TimeToLive
        }
        "MX" {
            $fields = $RD -split " "
            $Preference = $fields[0]
            $MailExchange = $fields[1]
            Add-DnsServerResourceRecordMX -Name $HostName -Preference $Preference -MailExchange $MailExchange -ZoneName $ZoneName -TimeToLive $TimeToLive
        }
        "PTR" {
            Add-DnsServerResourceRecordPtr -Name $HostName -PtrDomainName $RD -ZoneName $ZoneName -TimeToLive $TimeToLive
        }
        "SOA" {
            Write-Output "SOA: $RD"
            # $fields = $RD -split " "
            # $PrimaryServer = $fields[0]
            # $ResponsiblePerson = $fields[1]
            # $SerialNumber = $fields[2]
            # $RefreshInterval = $fields[3]
            # $RetryDelay = $fields[4]
            # $ExpireLimit = $fields[5]
            # $MinimumTimeToLive = $fields[6]
            # $RecordData = Add-DnsServerResourceRecordSoa -ZoneName $ZoneName -PrimaryServer $PrimaryServer -ResponsiblePerson $ResponsiblePerson -SerialNumber $SerialNumber -RefreshInterval $RefreshInterval -RetryDelay $RetryDelay -ExpireLimit $ExpireLimit -MinimumTimeToLive $MinimumTimeToLive
        }
        "SRV" {
            $fields = $RD -split " "
            $Priority = $fields[0]
            $Weight = $fields[1]
            $Port = $fields[2]
            $DomainName = $fields[3]
            Add-DnsServerResourceRecord -Srv -Name $HostName -Priority $Priority -Weight $Weight -Port $Port -DomainName $DomainName -ZoneName $ZoneName -TimeToLive $TimeToLive
        }
        "TXT" {
            $RD = $RD -replace "^""", "" -replace """$", ""
            Add-DnsServerResourceRecord -Txt -Name $HostName -DescriptiveText $RD -ZoneName $ZoneName -TimeToLive $TimeToLive
        }
        default {
            Write-Warning "Unknown RecordType: $RecordType"
        }
    }
}
