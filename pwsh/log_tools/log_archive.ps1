$log_pattern = Join-Path $Env:SystemRoot "System32\Winevt\Logs\Archive-*.evtx"
$log_archive = "C:\Logs\Evt"

$logFiles = Get-ChildItem -Path $log_pattern

foreach ($logFile in $logFiles) {
    $destinationPath = Join-Path -Path $log_archive -ChildPath $logFile.Name
    Move-Item -Path $logFile.FullName -Destination $destinationPath -Force
    Write-Output "Moved log file: $($logFile.FullName) to $destinationPath"
}

$cutoffDate = (Get-Date).AddYears(-1).ToUniversalTime()
$cutoffDate = (Get-Date).AddMinutes(-10).ToUniversalTime() # For testing

$archiveLogFiles = Get-ChildItem -Path (Join-Path -Path $log_archive -ChildPath "Archive-*.evtx")

foreach ($archiveLogFile in $archiveLogFiles) {
    if ($archiveLogFile.Name -match "Archive-.*-(\d{4})-(\d{2})-(\d{2})-(\d{2})-(\d{2})-(\d{2})-\d{3}\.evtx") {
        $fileDate = Get-Date "$($matches[1])-$($matches[2])-$($matches[3]) $($matches[4]):$($matches[5]):$($matches[6])"

        if ($fileDate -lt $cutoffDate) {
            Remove-Item -Path $archiveLogFile.FullName -Force
            Write-Output "Deleted archived log file: $($archiveLogFile.FullName)"
        }
        else {
            Write-Output "Archived log file: $($archiveLogFile.FullName)"
        }
    }
}