 
param( # For Development/Debugging Purposes only
    [switch]$WhatIf,   # Enable safe dry-run mode (no actual file/service actions)
    [switch]$Verbose   # Show detailed actions (useful for debugging)
)

<#
  MySQL Auto Repair Script (Safe for User Databases)
  By: Unknownplanet40 (because we learn the hard way 😅)
#>


# === CONFIG ===
$xamppPath = "C:\xampp"
$dataPath = "$xamppPath\mysql\data"
$backupPath = "$xamppPath\mysql\backup"
$serviceName = "mysql"
$isAdmin = $false
$RepairCounter = 0
$MaxRepairs = 5

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
    Write-Host "Running as Admin: $isAdmin" -BackgroundColor DarkGray -ForegroundColor White
    Write-Host "--------------------------------------------------"
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
    if ($WhatIf) { Write-Host "MODE: TESTING (-WhatIf ENABLED)" -ForegroundColor Yellow }
    if ($Verbose) { Write-Host "VERBOSE: ENABLED" -ForegroundColor DarkGray }
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
            Write-Host "Stopping MySQL service..."
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
            Write-Host "Starting MySQL service..."
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

while ($RepairCounter -lt $MaxRepairs) {
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
            Write-Host "You can access phpMyAdmin at: http://localhost/phpmyadmin/" -ForegroundColor Green
            Start-Sleep -Seconds 3
            exit 0
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