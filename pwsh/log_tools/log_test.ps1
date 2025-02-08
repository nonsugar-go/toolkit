$logNames = @("Application", "System")

foreach ($logName in $logNames) {
    $source = "TestLogSource" + $logName
    if (-not [System.Diagnostics.EventLog]::SourceExists($source)) {
        New-EventLog -LogName $logName -Source $source
    }

    for ($i = 1; $i -le 1000; $i++) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-EventLog -LogName $logName -Source $source `
            -EventId $i -EntryType Information `
            -Message "[$timestamp] Test log entry $i in $logName"
    }
}