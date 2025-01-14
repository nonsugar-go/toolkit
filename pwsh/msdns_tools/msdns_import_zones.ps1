param (
    [string]$ZoneName,
    [string]$ZoneFile
)

if ($ZoneName -eq "" -or $ZoneFile -eq "") {
    Write-Warning "Usage: dns_import_zones.ps1 -ZoneName <ZoneName> -ZoneFile <ZoneFile>"
    exit(1)
}

$confirmation = Read-Host "Do you want to proceed with the changes? [yes/no]"
if ($confirmation -eq "yes") {
    Write-Output "Proceeding with the changes..."
}
else {
    Write-Output "Operation cancelled."
    exit(0)
}

Write-Output "Importing zone $ZoneName from file $ZoneFile"

$recordCounts = @{
    "A"       = @{ "Added" = 0; "Skipped" = 0 }
    "AAAA"    = @{ "Added" = 0; "Skipped" = 0 }
    "CNAME"   = @{ "Added" = 0; "Skipped" = 0 }
    "NS"      = @{ "Added" = 0; "Skipped" = 0 }
    "MX"      = @{ "Added" = 0; "Skipped" = 0 }
    "PTR"     = @{ "Added" = 0; "Skipped" = 0 }
    "SOA"     = @{ "Added" = 0; "Skipped" = 0 }
    "SRV"     = @{ "Added" = 0; "Skipped" = 0 }
    "TXT"     = @{ "Added" = 0; "Skipped" = 0 }
    "Unknown" = @{ "Added" = 0; "Skipped" = 0 }
}
$previousHostName = $null
$Origin = "."
$TTL = 0
foreach ($line in Get-Content -Path $ZoneFile) {
    if ($line.Trim() -eq '') {
        continue
    }
    if ($line -match "^\s*;") {
        continue
    }
    if ($line -match "^\`$TTL\s+(\S+)") {
        $TTL = $matches[1]
        continue
    }
    if ($line -match "^\`$ORIGIN\s+(\S+)") {
        $Origin = $matches[1]
        continue
    }
    if ($line -match "^\s") {
        if ($null -eq $previousHostName) {
            throw "Invalid line: $line"
        }
        $line = $previousHostName + $line
    }
    $line = $line -replace '\s*;[^"]*$', ''
    $line = $line.TrimEnd()
    $max_fields = 5
    $fields = $line -split '[ \t]+', $max_fields
    $posOfFields = 0
    $HostName = $fields[$posOfFields++]
    $previousHostName = $HostName
    $TmpTimeToLive = $fields[$posOfFields]
    if ($TmpTimeToLive -match "^\d+$") {
        $TimeToLive = [System.TimeSpan]::FromSeconds($TmpTimeToLive)
        $posOfFields++
    }
    else {
        $TimeToLive = [System.TimeSpan]::FromSeconds($TTL)
        $max_fields--
        $fields = $line -split '[ \t]+', $max_fields
    }
    $RecordClass = $fields[$posOfFields]
    if ($RecordClass -eq "IN") {
        $posOfFields++
    }
    else {
        $RecordClass = "IN"
        $max_fields--
        $fields = $line -split '[ \t]+', $max_fields
    }
    $RecordType = $fields[$posOfFields++]
    $RD = $fields[$posOfFields]

    $recordExists = $null
    switch ($RecordType) {
        "A" {
            $recordExists = Get-DnsServerResourceRecord -ZoneName $ZoneName -Name $HostName -RRType $RecordType -ErrorAction SilentlyContinue |
            Where-Object { $_.RecordData.IPv4Address.IPAddressToString -eq $RD }
            if ($recordExists) {
                Write-Output "`t$RecordType record for $HostName already exists."
                $recordCounts[$recordType]["Skipped"]++
                continue
            }
            Add-DnsServerResourceRecordA -Name $HostName -IPv4Address $RD -ZoneName $ZoneName -TimeToLive $TimeToLive
            $recordCounts[$recordType]["Added"]++
        }
        "AAAA" {
            $recordExists = Get-DnsServerResourceRecord -ZoneName $ZoneName -Name $HostName -RRType $RecordType -ErrorAction SilentlyContinue |
            Where-Object { $_.RecordData.IPv6Address.IPAddressToString -eq $RD }
            if ($recordExists) {
                Write-Output "`t$RecordType record for $HostName already exists."
                $recordCounts[$recordType]["Skipped"]++
                continue
            }
            Add-DnsServerResourceRecordAAAA -Name $HostName -IPv6Address $RD -ZoneName $ZoneName -TimeToLive $TimeToLive
            $recordCounts[$recordType]["Added"]++
        }
        "CNAME" {
            if (-not $RD.EndsWith(".")) {
                $RD += ".$Origin"
            }
            $recordExists = Get-DnsServerResourceRecord -ZoneName $ZoneName -Name $HostName -RRType $RecordType -ErrorAction SilentlyContinue
            if ($recordExists) {
                Write-Output "`t$RecordType record for $HostName already exists."
                $recordCounts[$recordType]["Skipped"]++
                continue
            }
            Add-DnsServerResourceRecordCName -Name $HostName -HostNameAlias $RD -ZoneName $ZoneName -TimeToLive $TimeToLive
            $recordCounts[$recordType]["Added"]++
        }
        "NS" {
            if (-not $RD.EndsWith(".")) {
                $RD += ".$Origin"
            }
            $recordExists = Get-DnsServerResourceRecord -ZoneName $ZoneName -Name $HostName -RRType $RecordType -ErrorAction SilentlyContinue |
            Where-Object { $_.RecordData.NameServer -eq $RD }
            if ($recordExists) {
                Write-Output "`t$RecordType record for $HostName already exists."
                $recordCounts[$recordType]["Skipped"]++
                continue
            }
            Add-DnsServerResourceRecord -ZoneName $ZoneName -Name $HostName -NS -NameServer $RD -TimeToLive $TimeToLive
            $recordCounts[$recordType]["Added"]++
        }
        "MX" {
            $fields = $RD -split '[ \t]+', 2
            $Preference = $fields[0]
            $MailExchange = $fields[1]
            if (-not $MailExchange.EndsWith(".")) {
                $MailExchange += ".$Origin"
            }
            $recordExists = Get-DnsServerResourceRecord -ZoneName $ZoneName -Name $HostName -RRType $RecordType -ErrorAction SilentlyContinue |
            Where-Object { $_.RecordData.MailExchange -eq $MailExchange }
            if ($recordExists) {
                Write-Output "`t$RecordType record for $HostName already exists."
                $recordCounts[$recordType]["Skipped"]++
                continue
            }
            Add-DnsServerResourceRecordMX -Name $HostName -Preference $Preference -MailExchange $MailExchange -ZoneName $ZoneName -TimeToLive $TimeToLive
            $recordCounts[$recordType]["Added"]++
        }
        "PTR" {
            if (-not $RD.EndsWith(".")) {
                $RD += ".$Origin"
            }
            $recordExists = Get-DnsServerResourceRecord -ZoneName $ZoneName -Name $HostName -RRType $RecordType -ErrorAction SilentlyContinue |
            Where-Object { $_.RecordData.PtrDomainName -eq $RD }
            if ($recordExists) {
                Write-Output "`t$RecordType record for $HostName already exists."
                $recordCounts[$recordType]["Skipped"]++
                continue
            }
            Add-DnsServerResourceRecordPtr -Name $HostName -PtrDomainName $RD -ZoneName $ZoneName -TimeToLive $TimeToLive
            $recordCounts[$recordType]["Added"]++
        }
        "SOA" {
            $recordExists = Get-DnsServerResourceRecord -ZoneName $ZoneName -Name $HostName -RRType $RecordType -ErrorAction SilentlyContinue
            if ($recordExists) {
                Write-Output "`t$RecordType record for $HostName already exists."
                $recordCounts[$recordType]["Skipped"]++
                continue
            }
            Throw "SOA records cannot be imported."
        }
        "SRV" {
            $fields = $RD -split '[ \t]+', 4
            $Priority = $fields[0]
            $Weight = $fields[1]
            $Port = $fields[2]
            $DomainName = $fields[3]
            if (-not $DomainName.EndsWith(".")) {
                $DomainName += ".$Origin"
            }
            $recordExists = Get-DnsServerResourceRecord -ZoneName $ZoneName -Name $HostName -RRType $RecordType -ErrorAction SilentlyContinue |
            Where-Object { $_.RecordData.DomainName -eq $DomainName }
            if ($recordExists) {
                Write-Output "`t$RecordType record for $HostName already exists."
                $recordCounts[$recordType]["Skipped"]++
                continue
            }
            Add-DnsServerResourceRecord -Srv -Name $HostName -Priority $Priority -Weight $Weight -Port $Port -DomainName $DomainName -ZoneName $ZoneName -TimeToLive $TimeToLive
            $recordCounts[$recordType]["Added"]++
        }
        "TXT" {
            $RD = $RD -replace "^""", "" -replace """$", ""
            $recordExists = Get-DnsServerResourceRecord -ZoneName $ZoneName -Name $HostName -RRType $RecordType -ErrorAction SilentlyContinue |
            Where-Object { $_.RecordData.DescriptiveText -eq $RD }
            if ($recordExists) {
                Write-Output "`t$RecordType record for $HostName already exists."
                $recordCounts[$recordType]["Skipped"]++
                continue
            }
            Add-DnsServerResourceRecord -Txt -Name $HostName -DescriptiveText $RD -ZoneName $ZoneName -TimeToLive $TimeToLive
            $recordCounts[$recordType]["Added"]++
        }
        default {
            Write-Warning "Unknown RecordType: $RecordType"
            $recordCounts["Unknown"]["Skipped"]++
        }
    }
}

Write-Output "`r`nSummary:"
foreach ($recordType in $recordCounts.Keys) {
    Write-Output "`t${recordType}:`tAdded = $($recordCounts[$recordType]["Added"]),`tSkipped = $($recordCounts[$recordType]["Skipped"])"
}