# The constants we use for the script
# Various paths
$scriptDir = "C:\Program Files\Guestfs\Firstboot\scripts"
$restoreScriptFile = $scriptDir + "\9999-restore_config.ps1"
$firstbootScriptFile = $scriptDir + "\9999-restore_config.bat"

# Create the scripts folder if it does not exist
if (!(Get-Item $scriptDir -ErrorAction SilentlyContinue)) {
    New-Item -Type directory -Path $scriptDir
}

# Initialize the script
Write-Output ("# Migration - Reconfigure network adapters and disks") > $restoreScriptFile
Write-Output ("") >> $restoreScriptFile

Write-Output ("`$logFile = `$env:SystemDrive + '\Program Files\Guestfs\Firstboot\scripts-done\9999-restore_config.txt'") >> $restoreScriptFile
Write-Output ("Write-Output ('Starting restore_config.ps1 script') > `$logFile") >> $restoreScriptFile
Write-Output ("Write-Output ('') >> `$logFile") >> $restoreScriptFile
Write-Output ("") >> $restoreScriptFile

Write-Output ("# Exit if the machine is still on VMware") >> $restoreScriptFile
Write-Output ("`$system = Get-WmiObject Win32_ComputerSystem") >> $restoreScriptFile
Write-Output ("if (`$system.Manufacturer -eq 'VMware, Inc.') {") >> $restoreScriptFile
Write-Output ("    Write-Output ('The script is not meant to run on VMware. Exiting.') >> `$logFile") >> $restoreScriptFile
Write-Output ("    Exit") >> $restoreScriptFile
Write-Output ("}") >> $restoreScriptFile
Write-Output ("") >> $restoreScriptFile

Get-NetAdapter | ForEach-Object {
    Write-Output ("Write-Output ('Restoring network adapater for MAC address " + $_.MacAddress + "') >> `$logFile") >> $restoreScriptFile
    Write-Output ("# Disable the non-Red Hat network adapter with the MAC address") >> $restoreScriptFile
    Write-Output ("Write-Output ('  - Disable the non-Red Hat network adapter') >> `$logFile") >> $restoreScriptFile
    Write-Output ("Get-Netadapter | Where { (`$_.MacAddress -like '" + $_.MacAddress + "') -and (`$_.InterfaceDescription -notlike 'Red Hat*')} | Disable-NetAdapter") >> $scriptfile
    Write-Output ("") >> $restoreScriptFile

    Write-Output ("# Find the Red Hat network adapter with the MAC address") >> $restoreScriptFile
    Write-Output ("Write-Output ('  - Find the Red Hat network adapter') >> `$logFile") >> $restoreScriptFile
    Write-Output ("`$ifi=(Get-Netadapter | Where { (`$_.MacAddress -like '" + $_.MacAddress + "') -and (`$_.InterfaceDescription -like 'Red Hat*')}).InterfaceIndex") >> $restoreScriptFile
    Write-Output ("") >> $restoreScriptFile

    Write-Output ("# Assign the IP address and netmask to the Red Hat network adapter") >> $restoreScriptFile
    Write-Output ("Write-Output ('  - Assign the IP addresses and netmask to the Red Hat network adapter') >> `$logFile") >> $restoreScriptFile
    Get-NetIPAddress -InterfaceIndex $_.InterfaceIndex | Where-Object { $_.PrefixOrigin -like "Manual" -or $_.SuffixOrigin -like "Manual"} | ForEach-Object {
        Write-Output ("Write-Output ('    - IP address: " + $_.IPaddress + "  - PrefixLength: " + $_.PrefixLength + "') >> `$logFile") >> $restoreScriptFile
        Write-Output( "New-NetIPAddress -InterfaceIndex `$ifi -IPAddress '" + $_.IPAddress + "' -Prefixlength " + $_.PrefixLength) >> $restoreScriptFile
    }
    Write-Output ("") >> $restoreScriptFile

    Write-Output ("# Assign the routes to the Red Hat network adapter") >> $restoreScriptFile
    Write-Output ("Write-Output ('  - Assign the routes to the Red Hat network adapter') >> `$logFile") >> $restoreScriptFile
    Get-NetRoute -InterfaceIndex $_.InterfaceIndex | Where-Object { $_.NextHop -notlike "0.0.0.0" -and $_.DestinationPrefix -like "*.*" } | ForEach-Object {
        Write-Output( "Write-Output -('    - DestinationPrefix: " + $_.DestinationPrefix + " - NextHop: " + $_.NextHop + "') >> `$logFile") >> $restoreScriptFile
        Write-Output( "New-NetRoute -InterfaceIndex `$ifi -DestinationPrefix '"+$_.DestinationPrefix+"' -NextHop '"+$_.NextHop+"'") >> $restoreScriptFile
    }
    Write-Output ("") >> $restoreScriptFile

    Write-Output ("# Assign the DNS servers to the Red Hat network adapter") >> $restoreScriptFile
    $a=(Get-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex | where-Object { $_.AddressFamily -eq 2}).ServerAddresses
    Write-Output ("Write-Output ('  - Assign the DNS servers to the Red Hat network adapter: " + $a[0] +", " + $a[1] + "') >> `$logFile") >> $restoreScriptFile
    Write-Output("Set-DnsClientServerAddress -InterfaceIndex `$ifi -ServerAddresses '" + $a[0] + "','" + $a[1] + "'") >> $restoreScriptFile
    Write-Output ("") >> $restoreScriptFile

    Write-Output ("Write-Output ('') >> `$logFile") >> $restoreScriptFile
    Write-Output ("") >> $restoreScriptFile
}

Write-Output ("# Re-enable all offline disks") >> $restoreScriptFile
Write-Output ("Write-Output ('Re-enabling all offline disks') >> `$logFile") >> $restoreScriptFile
Write-Output ("Get-Disk | Where { `$_.OperationalStatus -like 'Offline' } | % {") >> $restoreScriptFile
Write-Output ("     Write-Output ('  - ' + `$_.Number + ': ' + `$_.FriendlyName + '(' + [math]::Round(`$_.Size/1GB,2) + 'GB)') >> `$logFile") >> $restoreScriptFile
Write-Output ("    `$_ | Set-Disk -IsOffline `$false") >> $restoreScriptFile
Write-Output ("    `$_ | Set-Disk -IsReadOnly `$false") >> $restoreScriptFile
Write-Output ("}") >> $restoreScriptFile
Write-Output ("Write-Output ('') >> `$logFile") >> $restoreScriptFile
Write-Output ("") >> $restoreScriptFile

Write-Output ("# Remove the partition access path on all partitions but SystemDrive") >> $restoreScriptFile
Write-Output ("`$a = (Get-Item env:SystemDrive).Value.substring(0,1)") >> $restoreScriptFile
Write-Output ("Write-Output('Remove the partition access path on all partitions but SystemDrive (" + $a +")') >> `$logFile") >> $restoreScriptFile
Write-Output ("Get-Partition | Where { `$_.DriveLetter -notlike `$a -and `$_.DriveLetter.length -gt 0 } | % {") >> $restoreScriptFile
Write-Output ("    if ([string]::IsNullOrWhiteSpace(`$_.DriveLetter)) {") >> $restoreScriptFile
Write-Output ("        Write-Output ('  - DiskNumber: ' + `$_.DiskNumber + ' - PartitionNumber: ' + `$_.PartitionNumber + ' - No AccessPath. Skipping') >> `$logFile") >> $restoreScriptFile
Write-Output ("    }") >> $restoreScriptFile
Write-Output ("    else {") >> $restoreScriptFile
Write-Output ("        Write-Output ('  - DiskNumber: ' + `$_.DiskNumber + ' - PartitionNumber: ' + `$_.PartitionNumber + ' - AccessPath: ' + `$_.DriveLetter + ':') >> `$logFile") >> $restoreScriptFile
Write-Output ("        Remove-PartitionAccessPath -DiskNumber `$_.DiskNumber -PartitionNumber `$_.PartitionNumber -AccessPath (`$_.DriveLetter + ':')") >> $restoreScriptFile
Write-Output ("    }") >> $restoreScriptFile
Write-Output ("}") >> $restoreScriptFile
Write-Output ("Write-Output ('') >> `$logFile") >> $restoreScriptFile
Write-Output ("") >> $restoreScriptFile

# Find the current CD-ROM drive
Write-Output ("# Restore drive letters") >> $restoreScriptFile
Write-Output ("Write-Output ('Restore drive letters') >> `$logFile") >> $restoreScriptFile
Get-Volume | ForEach-Object {
    if ($_.FileSystemLabel -ne "System Reserved") {
        if ([string]::IsNullOrWhiteSpace($_.DriveLetter)) {
            Write-Output ("Write-Output ('  - DeviceId: " + $_.ObjectId + " - No DriveLetter. Skipping.') >> `$logFile") >> $restoreScriptFile
        }
        else {
            Write-Output ("Write-Output ('  - DeviceId: " + $_.ObjectId + " - DriveLetter: " + $_.DriveLetter + ":') >> `$logFile") >> $restoreScriptFile
            $escObjectId = $_.ObjectId -replace "\\", "\\"
            Write-Output ("`$wmiObject = Get-WmiObject -Class Win32_Volume -Filter `"DeviceId='" + $escObjectId + "'`"") >> $restoreScriptFile
            Write-Output ("`$wmiObject.DriveLetter = '" + $_.DriveLetter + ":'") >> $restoreScriptFile
            Write-Output ("`$wmiObject.Put()") >> $restoreScriptFile
            Write-Output ("") >> $restoreScriptFile
        }
    }
}
Write-Output ("Write-Output ('') >> `$logFile") >> $restoreScriptFile
Write-Output ("") >> $restoreScriptFile

Write-Output ("# Install RHV APT service if absent") >> $restoreScriptFile
Write-Output ("if ((Get-Service rhev-apt -ErrorAction SilentlyContinue)) {") >> $restoreScriptFile
Write-Output ("    Write-Output('Service rhev-apt is already installed. Skipping.') >> `$logFile") >> $restoreScriptFile
Write-Output ("}") >> $restoreScriptFile
Write-Output ("else {") >> $restoreScriptFile
Write-Output ("    Write-Output ('Service rhev-apt is not installed. Check if rhev-apt.exe is present.') >> `$logFile") >> $restoreScriptFile
Write-Output ("    `$rhevAptExe = `$env:SystemDrive + '\rhev-apt.exe'") >> $restoreScriptFile
Write-Output ("    Write-Output (`"rhev-apt.exe path is `$rhevAptExe`") >> `$logFile") >> $restoreScriptFile
Write-Output ("    if (Get-Item `$rhevAptExe -ErrorAction SilentlyContinue) {") >> $restoreScriptFile
Write-Output ("        Write-Output (`"File `$rhevAptExe is present. Running it.`") >> `$logFile") >> $restoreScriptFile
Write-Output ("        Start-Process -Wait -FilePath `$rhevAptExe -ArgumentList '/S', '/v/qn'") >> $restoreScriptFile
Write-Output ("        Write-Output (`"Execution of `$rhevAptExe is finished.`") >> `$logFile") >> $restoreScriptFile
Write-Output ("    }") >> $restoreScriptFile
Write-Output ("}") >> $restoreScriptFile
Write-Output ("Write-Output ('') >> `$logFile") >> $restoreScriptFile
Write-Output ("") >> $restoreScriptFile

Write-Output ("# Start rhev-apt service if present.') >> `$logFile") >> $restoreScriptFile
Write-Output ("if (Get-Service rhev-apt -ErrorAction SilentlyContinue) {") >> $restoreScriptFile
Write-Output ("    Write-Output ('Service rhev-apt is present. Starting it.') >> `$logFile") >> $scripFile
Write-Output ("    Start-Service -Name rhev-apt") >> $restoreScriptFile
Write-Output ("}") >> $restoreScriptFile
Write-Output ("else {") >> $restoreScriptFile
Write-Output ("    Write-Output ('Service rhev-apt is still not installed. Something went wrong with rhev-apt.exe') >> `$log_File") >> $restoreScriptFile
Write-Output ("}") >> $restoreScriptFile
Write-Output ("Write-Output ('') >> `$logFile") >> $restoreScriptFile
Write-Output ("") >> $restoreScriptFile

# Using Out-File to set encoding and avoid UTF-8 BOM
'@echo off' | Out-File -FilePath $firstbootScriptFile -Encoding ascii 
'' | Out-File -FilePath $firstbootScriptFile -Encoding ascii -Append
'echo Restore configuration for network adapters and disks' | Out-File -FilePath $firstbootScriptFile -Encoding ascii -Append
'PowerShell.exe -ExecutionPolicy ByPass -File "' + $restoreScriptFile + '"' | Out-File -FilePath $firstbootScriptFile -Encoding ascii -Append
