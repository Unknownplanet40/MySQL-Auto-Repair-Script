 
param( # For Development/Debugging Purposes only
    [switch]$WhatIf,   # Enable safe dry-run mode (no actual file/service actions)
    [switch]$Verbose,   # Show detailed actions (useful for debugging)
    [switch]$BackupBeforeRepair  # Backup and zip databases before repair
)

<#
  MySQL Auto Repair Script (Safe for User Databases)
  By: Unknownplanet40 (because we learn the hard way 😅)
  It's recommended to back up your databases before running this script.
  This script is designed to repair MySQL installations in XAMPP without
  affecting user databases. It stops the MySQL service, backs up the data folder,
  and attempts repairs safely.
  Note: Not all MySQL issues can be resolved with this script.
#>


# === CONFIG ===
$xamppPath = "C:\xampp"
$dataPath = "$xamppPath\mysql\data"
$backupPath = "$xamppPath\mysql\backup"
$BackupFolderPath = "$xamppPath\mysql\GeneratedBackups"
$UserDatabaseBackupPath = ""
$serviceName = "mysql"
$isAdmin = $false
$RepairCounter = 0
$MaxRepairs = 5
$HaveZippedBackup = $false
$backupdatabaseslist = @()

if (-not (Test-Path $dataPath)) {
    Write-Host "ERROR: Data path not found at $dataPath" -ForegroundColor Red
    $CustomPath = Read-Host "Please enter the correct MySQL data path"
    if (Test-Path $CustomPath) {
        $dataPath = $CustomPath
    }
    else {
        Write-Host "ERROR: Provided path is invalid. Exiting." -ForegroundColor Red
        exit 1
    }
}
if (-not (Test-Path $backupPath)) {
    Write-Host "ERROR: Backup path not found at $backupPath" -ForegroundColor Red
    $CustomPath = Read-Host "Please enter the correct MySQL backup path"
    if (Test-Path $CustomPath) {
        $backupPath = $CustomPath
    }
    else {
        Write-Host "ERROR: Provided path is invalid. Exiting." -ForegroundColor Red
        exit 1
    }
}

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "ERROR: This script must be run as Administrator." -ForegroundColor Red
    Write-Host "Please restart PowerShell as Administrator and re-run the script." -ForegroundColor Red
    exit 1
}
else {
    $isAdmin = $true
}

function Show-Title {
    Clear-Host
    Write-Host "[===== MySQL Auto Repair Script =====]" -ForegroundColor Cyan
    Write-Host "By: Unknownplanet40 (because we learn the hard way)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Working safely to keep your databases intact!" 
    Write-Host "--------------------------------------------------"
    Write-Host "XAMPP Path:  $xamppPath" -ForegroundColor DarkGray
    Write-Host "Data Path:   $dataPath" -ForegroundColor DarkGray
    Write-Host "Backup Path: $backupPath" -ForegroundColor DarkGray
    if ($UserDatabaseBackupPath -ne "") {
        Write-Host "Database Backup Zip: $UserDatabaseBackupPath" -ForegroundColor DarkGray
    }
    else {
        if ($BackupBeforeRepair) {
            Write-Host "Database Backup Zip: (Not created)" -ForegroundColor DarkGray
        }
    }
    $attempt = $RepairCounter + 1
    if ($attempt -in 3, 4) {
        $color = 'Yellow'
    }
    elseif ($attempt -eq 5) {
        $color = 'Red'
    }
    else {
        $color = 'Green'
    }
    Write-Host "Attempt:     $attempt of $MaxRepairs" -ForegroundColor $color
    Write-Host -NoNewline "ADMIN RIGHTS: "
    if ($isAdmin) {
        Write-Host "ENABLED" -ForegroundColor Green
    }
    else {
        Write-Host "DISABLED" -ForegroundColor Red
    }
    if ($WhatIf) { Write-Host "MODE: TESTING (-WhatIf ENABLED)" -ForegroundColor Yellow } # Safe dry-run mode (no actual changes)
    if ($Verbose) { Write-Host "VERBOSE: ENABLED" -ForegroundColor DarkGray }
    if ($BackupBeforeRepair) { Write-Host "BACKUP DATABASES BEFORE REPAIR: ENABLED" -ForegroundColor DarkGray }
    Write-Host "--------------------------------------------------"
    Write-Host ""
}

function Show-ProgressAnimation($text, $seconds = 3) {
    if ($WhatIf) { return }
    $end = (Get-Date).AddSeconds($seconds)
    $frames = @("|", "/", "-", "\")
    $i = 0
    while ((Get-Date) -lt $end) {
        Write-Host -NoNewline "`r$text ${frames[$i]}"
        Start-Sleep -Milliseconds 200
        $i = ($i + 1) % $frames.Length
    }
    Write-Host "`r$text ... Done!`n"
}

function Stop-MySQLIfRunning {
    Show-Title
    Write-Host "[===== MySQL Service Check =====]" -ForegroundColor Cyan
    $randomDelay = Get-Random -Minimum 2 -Maximum 4

    if ($WhatIf) {
        Write-Host "(WhatIf) Would stop MySQL service or process."
        return
    }

    $svc = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($svc -ne $null) {
        if ($svc.Status -ne 'Stopped') {
            Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
            Show-ProgressAnimation "Stopping MySQL service" $randomDelay
        }
        else {
            Write-Host "MySQL service is already stopped." -ForegroundColor Green
        }
    }
    else {
        Get-Process -Name "mysqld" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Write-Host "MySQL service not found. If you use XAMPP, ensure it's stopped via the control panel." -ForegroundColor Yellow
    }

    Write-Host "MySQL service/process is stopped." -ForegroundColor Green
    Start-Sleep -Seconds 1
}

function Backup-DataFolder {
    Show-Title
    Write-Host "[===== Backing Up Data Folder =====]" -ForegroundColor Cyan
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupCopy = "$dataPath`_OLD_$timestamp"
    $randomDelay = Get-Random -Minimum 2 -Maximum 4

    if ($WhatIf) {
        Write-Host "(WhatIf) Would copy $dataPath → $backupCopy"
        return
    }

    Write-Host "Creating backup at: $backupCopy"
    Copy-Item $dataPath $backupCopy -Recurse -Force
    Show-ProgressAnimation "Backing up data folder" $randomDelay
    if (-not (Test-Path -Path $BackupFolderPath)) {
        New-Item -ItemType Directory -Path $BackupFolderPath -Force | Out-Null
    }
    $finalBackupPath = Join-Path $BackupFolderPath ("data_OLD_$timestamp")
    Move-Item -Path $backupCopy -Destination $finalBackupPath -Force
    Write-Host "Backup completed successfully." -ForegroundColor Green
    Start-Sleep -Seconds 1
}

function Remove-SystemFolders {
    Show-Title
    Write-Host "[===== Cleaning System Folders =====]" -ForegroundColor Cyan
    $foldersToDelete = @("mysql", "performance_schema", "phpmyadmin", "test")
    $randomDelay = Get-Random -Minimum 2 -Maximum 4

    foreach ($folder in $foldersToDelete) {
        $target = Join-Path $dataPath $folder
        if (Test-Path $target) {
            if ($WhatIf) {
                Write-Host "(WhatIf) Would delete system folder: $folder"
            }
            else {
                Remove-Item $target -Recurse -Force -ErrorAction SilentlyContinue
                if ($Verbose) { Write-Host "Deleted: $folder" -ForegroundColor DarkGray }
            }
        }
    }

    Write-Host "`nDeleting stray files (except ibdata1)..." -ForegroundColor Yellow
    $files = Get-ChildItem -Path $dataPath -File | Where-Object { $_.Name -ne "ibdata1" }
    foreach ($file in $files) {
        if ($WhatIf) {
            Write-Host "(WhatIf) Would delete file: $($file.Name)"
        }
        else {
            Remove-Item $file.FullName -Force -ErrorAction SilentlyContinue
            if ($Verbose) { Write-Host "Deleted file: $($file.Name)" -ForegroundColor DarkGray }
        }
    }

    Show-ProgressAnimation "Cleaning system folders" $randomDelay
    Write-Host "System folders and stray files cleaned." -ForegroundColor Green
    Start-Sleep -Seconds 1
}

function Restore-FromBackup {
    Show-Title
    Write-Host "[===== Restoring from Backup =====]" -ForegroundColor Cyan
    $randomDelay = Get-Random -Minimum 2 -Maximum 4

    Get-ChildItem -Path $backupPath | ForEach-Object {
        if ($_.Name -ieq "ibdata1") {
            Write-Host "Skipping ibdata1 restoration (preserve user data)." -ForegroundColor Yellow
            return
        }
        $dest = Join-Path $dataPath $_.Name
        if (-not (Test-Path $dest)) {
            if ($WhatIf) {
                Write-Host "(WhatIf) Would copy: $($_.Name) → $dest"
            }
            else {
                Copy-Item $_.FullName $dest -Recurse -Force
                if ($Verbose) { Write-Host "Restored: $($_.Name)" -ForegroundColor DarkGray }
            }
        }
    }

    Show-ProgressAnimation "Restoring system folders from backup" $randomDelay
    Write-Host "Restoration completed successfully." -ForegroundColor Green
    Start-Sleep -Seconds 1
}

function Start-MySQL {
    Show-Title
    Write-Host "[===== Starting MySQL =====]" -ForegroundColor Cyan
    $randomDelay = Get-Random -Minimum 2 -Maximum 4

    if ($WhatIf) {
        Write-Host "(WhatIf) Would start MySQL service."
        return
    }

    $svc = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($svc -ne $null) {
        if ($svc.Status -ne 'Running') {
            Start-Service -Name $serviceName -ErrorAction SilentlyContinue
            Show-ProgressAnimation "Starting MySQL service" $randomDelay
        }
        else {
            Write-Host "MySQL service is already running." -ForegroundColor Green
        }
    }
    else {
        Start-Process -FilePath "$xamppPath\mysql\bin\mysqld.exe" -ArgumentList "--defaults-file=`"$xamppPath\mysql\bin\my.ini`"" -NoNewWindow
        Show-ProgressAnimation "Forcing start of MySQL process" $randomDelay
    }
}

function Backup-And-Zip-Databases {
    Show-Title
    Write-Host "[===== Backing Up and Zipping Databases =====]" -ForegroundColor Cyan

    $excluded = @(
        "test",
        "performance_schema",
        "mysql",
        "phpmyadmin",
        "aria_log.00000001",
        "aria_log_control",
        "ib_buffer_pool",
        "ib_logfile0",
        "ib_logfile1",
        "ibtmp1",
        "mysql_upgrade_info",
        "multi-master.info",
        "my.ini"
    )

    $FailedtoBackup = @()
    $DatabaseItems = @()

    if (-not (Test-Path -Path $dataPath)) {
        Write-Host "ERROR: Data path not found: $dataPath" -ForegroundColor Red
        return
    }
    if (-not (Test-Path -Path $backupPath)) {
        if ($WhatIf) {
            Write-Host "(WhatIf) Would create backup path: $backupPath"
        }
        else {
            try {
                New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
            }
            catch {
                Write-Host "ERROR: Failed to create backup path: $backupPath" -ForegroundColor Red
                Write-Host $_.Exception.Message -ForegroundColor Red
                return
            }
        }
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $zipPath = Join-Path $backupPath "databases_backup_$timestamp.zip"
    $tempBackupPath = Join-Path $backupPath "temp_backup_$timestamp"

    if ($WhatIf) {
        Write-Host "(WhatIf) Would create temporary backup folder: $tempBackupPath"
        Write-Host "(WhatIf) Would compress into: $zipPath"
        return
    }

    try {
        New-Item -ItemType Directory -Path $tempBackupPath -Force | Out-Null
        $items = Get-ChildItem -Path $dataPath -Force | Where-Object { $excluded -notcontains $_.Name }
        if (-not $items -or $items.Count -eq 0) {
            Write-Host "No user databases or objects found to backup (after exclusions)." -ForegroundColor Yellow
            return
        }

        $count = $items.Count
        $i = 0
        foreach ($it in $items) {
            $i++
            Write-Progress -Activity "Copying database files" -Status "$($it.Name) ($i of $count)" -PercentComplete ([int](($i / $count) * 100))
            $dest = Join-Path $tempBackupPath $it.Name
            try {
                Copy-Item -Path $it.FullName -Destination $dest -Recurse -Force -ErrorAction Stop
                if ($Verbose) { Write-Host "Copied for backup: $($it.Name)" -ForegroundColor DarkGray }
                $DatabaseItems += $it.Name
                $script:backupdatabaseslist += $it.Name
            }
            catch {
                Write-Host "WARNING: Failed copying $($it.Name): $($_.Exception.Message)" -ForegroundColor Yellow
                $FailedtoBackup += $it.Name
            }
        }

        if ($FailedtoBackup.Count -gt 0) {
            Write-Host "`nThe following items failed to backup:" -ForegroundColor Yellow
            foreach ($fail in $FailedtoBackup) {
                Write-Host "- $fail" -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "All database files copied successfully for backup." -ForegroundColor Green
        }

        Write-Host "Compressing backup to: $zipPath" -ForegroundColor DarkGray
        Compress-Archive -Path (Join-Path $tempBackupPath '*') -DestinationPath $zipPath -CompressionLevel Optimal -Force -ErrorAction Stop

        Write-Host "Database backup and zipping completed: $zipPath" -ForegroundColor Green
        $script:HaveZippedBackup = $true

        if (-not (Test-Path -Path $BackupFolderPath)) {
            New-Item -ItemType Directory -Path $BackupFolderPath -Force | Out-Null
        }

        $finalZipPath = Join-Path $BackupFolderPath ("databases_backup_$timestamp.zip")
        Move-Item -Path $zipPath -Destination $finalZipPath -Force
        $script:UserDatabaseBackupPath = $finalZipPath
        Write-Host "Backed up database items:" -ForegroundColor DarkGray
        foreach ($dbItem in $DatabaseItems) {
            Write-Host "- $dbItem" -ForegroundColor DarkGray
        }
    }
    catch {
        Write-Host "ERROR: Backup and zip failed: $($_.Exception.Message)" -ForegroundColor Red
        try { if (Test-Path $zipPath) { Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue } } catch {}
    }
    finally {
        try {
            if (Test-Path $tempBackupPath) {
                Remove-Item -Path $tempBackupPath -Recurse -Force -ErrorAction SilentlyContinue
                if ($Verbose) { Write-Host "Removed temporary backup folder: $tempBackupPath" -ForegroundColor DarkGray }
            }
        }
        catch {
            Write-Host "WARNING: Failed to remove temporary folder: $tempBackupPath" -ForegroundColor Yellow
        }
        Write-Progress -Activity "Copying database files" -Completed
    }

    Start-Sleep -Seconds 2
    return $zipPath
}

while ($RepairCounter -lt $MaxRepairs) {

    if ($BackupBeforeRepair) {
        $zipFile = Backup-And-Zip-Databases
        if ($HaveZippedBackup) {
            Show-Title
            Write-Host "Database backup created at: $zipFile" -ForegroundColor Green
            Start-Sleep -Seconds 3
        }
        else {
            Show-Title
            Write-Host "Database backup failed. Proceeding without backup." -ForegroundColor Red
            Start-Sleep -Seconds 3
        }
    }
    else {
        Show-Title
        Write-Host "Skipping database backup as per user choice." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
    }

    Stop-MySQLIfRunning
    Backup-DataFolder
    Remove-SystemFolders
    Restore-FromBackup
    Start-MySQL

    do {
        Show-Title
        $answer = Read-Host "Did this fix your MySQL issue? (Y/N)"
        $response = $answer.Trim().ToUpper()

        if ($response -eq "Y") {
            Show-Title
            Write-Host "Great! MySQL should be operational now." -ForegroundColor Green
            Write-Host "Resolved after $($RepairCounter + 1) attempt(s)." -ForegroundColor Green
            if ($WhatIf) {
                Write-Host "(WhatIf) Would open phpMyAdmin at: http://localhost/phpmyadmin/" -ForegroundColor Yellow
            }
            else {
                $url = "http://localhost/phpmyadmin/"
                try {
                    Start-Process $url
                    Write-Host "Opened phpMyAdmin: $url" -ForegroundColor Green
                }
                catch {
                    Write-Host "ERROR: Failed to open URL $url - $($_.Exception.Message)" -ForegroundColor Red
                }
            }
            
            if ($backupdatabaseslist.Count -gt 0) {
                $showBackupdatabase = Read-Host "Would you like to see the list of backed up databases? (Y/N)"
                if ($showBackupdatabase.Trim().ToUpper() -eq "Y") {
                    Show-Title
                    Write-Host "Backed Up Databases:" -ForegroundColor Cyan
                    foreach ($db in $backupdatabaseslist) {
                        Write-Host "- $db" -ForegroundColor DarkGray
                    }
                    exit 0

                }
                else {
                    Show-Title
                    Write-Host "You chose not to view the list of backed up databases." -ForegroundColor Yellow
                    write-Host "Now exiting..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 2
                    exit 0
                }
            }
            else {
                Write-Host "Thanks for using the MySQL Auto Repair Script!" -ForegroundColor Cyan
                Start-Sleep -Seconds 2
                exit 0
            }
            
        }
        elseif ($response -eq "N") {
            $RepairCounter++
            if ($RepairCounter -ge $MaxRepairs) {
                Show-Title
                Write-Host "Maximum repair attempts reached ($MaxRepairs)." -ForegroundColor Red
                Write-Host "Please manually inspect your MySQL setup if issues persist." -ForegroundColor Red
                Start-Sleep -Seconds 5
                exit 1
            }
            else {
                Show-Title
                Write-Host "Retrying repair (Attempt $($RepairCounter + 1) of $MaxRepairs)..." -ForegroundColor Yellow
                Start-Sleep -Seconds 2
            }
            break
        }
        else {
            Clear-Host
            Show-Title
            Write-Host "Invalid input. Please enter only 'Y' or 'N'." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    } while ($response -ne "Y" -and $response -ne "N")
}