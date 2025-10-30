# MySQL-Auto-Repair-Script
### By: **Unknowplanet40** (because we learn the hard way)

# Overview
This PowerShell script automatically repairs MySQL data corruption or startup issues — specifically for XAMPP installations.

It safely removes broken system tables, restores them from backup, and keeps your user-created databases untouched.

# Features
- **Automatic Backup**: Creates a backup of the data folder before making any changes. (data_OLD_YYYYMMDD_HHMMSS)
- **Deletes System Folders**: Only removes the problematic system databases (mysql, performance_schema, test, phpmyadmin) to avoid affecting user data.
- **Restores from Backup**: Copies system database files from the backup folder to the main data directory.
- **Keep User Created Databases Safe**: User databases remain unaffected by the repair process.
- **Auto Stop/Start MySQL Service**: Stops the MySQL service before making changes and restarts it afterward.
- **Automatic Retry**: If Error is not resolved, the script will retry the repair process up to 5 times. (with user intervention)

# Modes
- **Normal Mode**: Executes the repair process with standard output.
- **WhatIf Mode**: Simulates the repair process without making any changes. (for testing purposes)
- **Verbose Mode**: Provides detailed output during the repair process.
- **WhatIf + Verbose Mode**: Simulates the repair process with detailed output.

# Prerequisites
- PowerShell (Windows) 5.1 or higher <sup> (butits recommended to use PowerShell 7.x or higher)</sup>
- XAMPP installed with MySQL component.
- Administrator privileges to run the script. <sup> (Right-click PowerShell and select "Run as Administrator")</sup>

**note**: If not run as Administrator, It will not be able to stop/start the MySQL service.

# Usage
1. Download the repository from GitHub
2. Find the `RunMySQLRepair.bat` file in the downloaded folder.
3. Right-click on `RunMySQLRepair.bat` and select "Run as Administrator".
4. Choose the desired mode (Normal, WhatIf, Verbose, or WhatIf + Verbose).
5. The script will execute and attempt to repair MySQL issues automatically.
6. Follow any on-screen prompts if necessary.
7. Check the MySQL service status in XAMPP after the script completes.
8. If issues persist, just type "Y" when prompted to retry the repair process.
9. If problems continue after 5 attempts, consider seeking further assistance or consulting MySQL documentation.
10. Enjoy your repaired MySQL server!

# What It Does Internally
|Step | Description |
|-----|-------------|
|1 | Stops the MySQL service (or `mysqld` process) |
|2 | Creates a timestamped backup of the current `data` folder |
|3 | Deletes only **system-related folders/files** |
|4 | Restores system folders and files from the MySQL `backup` directory |
|5 | Starts MySQL again and asks if the issue is fixed |
|6 | If not, it repeats the process up to 5 times |
# Important Notes
- Always ensure you have backups of your data before running repair operations.
- The script only targets system databases; user-created databases are not affected.
- Make sure `C:\xampp\mysql\backup` exists before running.
- Running the script requires Administrator privileges to manage the MySQL service.
- If MySQL is installed elsewhere, the script will prompt for the correct paths.
- If your issue persists after 5 attempts, manual inspection is recommended.
- To prevent this error from recurring, consider running MySQL and Apache as services from the XAMPP Control Panel (check the "Svc" checkbox). This method works 99% of the time.
- If you have custom configurations like user-defined users or privileges, you may need to reapply them after the repair.

This script is **recommended for specific MySQL issues** related to **XAMPP installations** and may not resolve all types of database corruption.

For example, it may help if you encounter the following error:
```log
12:00:00 AM  [mysql] 	Error: MySQL shutdown unexpectedly.
12:00:00 AM  [mysql] 	This may be due to a blocked port, missing dependencies, 
12:00:00 AM  [mysql] 	improper privileges, a crash, or a shutdown by another method
12:00:00 AM  [mysql] 	Press the Logs button to view error logs and check
12:00:00 AM  [mysql] 	the Windows Event Viewer for more clues
12:00:00 AM  [mysql] 	If you need more help, copy and post this
12:00:00 AM  [mysql] 	entire log window on the forums

```
or errors related to **corrupted system tables**.

Other issues may require different troubleshooting steps. Keep this in mind before running the script.
Always make a **backup** of your `data` folder before running this script!

# License
This project is licensed under the Apache License 2.0 - see the LICENSE file for details.

# Credits

### Author: **Unknowplanet40**
    “Because sometimes we break it just to fix it better.”

# Disclaimer
Use this script at your own risk. Always ensure you have backups of your data before running repair operations. The author is not responsible for any data loss or damage caused by the use of this script.

    I'm just a beginner in PowerShell and scripting, so if you find any issues or have suggestions for
    improvement, feel free to open an issue or submit a pull request on GitHub! Your feedback is greatly
    appreciated! 😊
