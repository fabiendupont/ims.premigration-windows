<#
.SYNOPSIS
  This script extracts the network adapters IP configuration when
  configuration is static, as well as the drives letters. This configuration
  is written is a script that will be run during next boot. It also installs
  RHV-APT if it is absent.

.DESCRIPTION
  When migrating a Windows virtual machine from VMware to KVM, the drivers
  are modified by virt-v2v. The consequence is that the new network adapters
  are created with the same MAC addresses as the original network adapters.
  With Windows, the new network adapters IP configuration is not bound to the
  the MAC addresses, so the new network adapters are not configured, so the
  virtual machine is unreachable.

  Another potential hickup is that drives may be ordered differently after the
  migration. This may lead to having wrong drive letters and programs not being
  able to find their data. 

  We also have noticed that sometimes RHV-APT is not installed after the
  migration, even though virt-v2v first boot scripts have run successfully.
  The consequence is that, even though the VirtIO Win ISO image is attached to
  the virtual machine, the additional drivers and the RHV Guest Agent will not
  be installed.

  This script collects the configuration of the Windows virtual machine and
  adds commands to a new script, in order to:

    1. Disable the original network adapters to avoid conflict after migration.
    2. Configure the new network adapters based on MAC address.
    3. Configure the drives letters based on WMI object id.
    4. Install and start RHV-APT if it is absent.

  In order to run the generated script, we also create a batch file (.bat)
  under C:\Program Files\Guestfs\Firstboot\scripts, so that virt-v2v first boot
  script runs it. This avoids creating another scheduled task.

.NOTES
  Version:        1.0
  Author:         Fabien Dupont <fdupont@redhat.com>
  Purpose/Change: Extract system configuration during premigration
#>

$scriptDir = "C:\Program Files\Guestfs\Firstboot\scripts"
$restoreScriptFile = $scriptDir + "\9999-restore_config.ps1"
$firstbootScriptFile = $scriptDir + "\9999-restore_config.bat"

# Create the scripts folder if it does not exist
if (!(Get-Item $scriptDir -ErrorAction SilentlyContinue)) {
    New-Item -Type directory -Path $scriptDir
}

# Initialize the generated script
Write-Output ("# Migration - Reconfigure network adapters and disks") > $restoreScriptFile
Write-Output ("") >> $restoreScriptFile

# Initialize the log file created by the generated script
Write-Output ("`$logFile = `$env:SystemDrive + '\Program Files\Guestfs\Firstboot\scripts-done\9999-restore_config.txt'") >> $restoreScriptFile
Write-Output ("Write-Output ('Starting restore_config.ps1 script') > `$logFile") >> $restoreScriptFile
Write-Output ("Write-Output ('') >> `$logFile") >> $restoreScriptFile
Write-Output ("") >> $restoreScriptFile

# Make the generated script exit if run on VMware.
# If it runs on VMware, it means that the migration rolled back, so
# we don't want to impact the configuration of the source virtual machine.
Write-Output ("# Exit if the machine is still on VMware") >> $restoreScriptFile
Write-Output ("`$system = Get-WmiObject Win32_ComputerSystem") >> $restoreScriptFile
Write-Output ("if (`$system.Manufacturer -eq 'VMware, Inc.') {") >> $restoreScriptFile
Write-Output ("    Write-Output ('The script is not meant to run on VMware. Exiting.') >> `$logFile") >> $restoreScriptFile
Write-Output ("    Exit") >> $restoreScriptFile
Write-Output ("}") >> $restoreScriptFile
Write-Output ("") >> $restoreScriptFile

# Generate the script section for each network adapter
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

# Generate the script section to re-enable all offline drives
Write-Output ("# Re-enable all offline drives") >> $restoreScriptFile
Write-Output ("Write-Output ('Re-enabling all offline drives') >> `$logFile") >> $restoreScriptFile
Write-Output ("Get-Disk | Where { `$_.OperationalStatus -like 'Offline' } | % {") >> $restoreScriptFile
Write-Output ("     Write-Output ('  - ' + `$_.Number + ': ' + `$_.FriendlyName + '(' + [math]::Round(`$_.Size/1GB,2) + 'GB)') >> `$logFile") >> $restoreScriptFile
Write-Output ("    `$_ | Set-Disk -IsOffline `$false") >> $restoreScriptFile
Write-Output ("    `$_ | Set-Disk -IsReadOnly `$false") >> $restoreScriptFile
Write-Output ("}") >> $restoreScriptFile
Write-Output ("Write-Output ('') >> `$logFile") >> $restoreScriptFile
Write-Output ("") >> $restoreScriptFile

# Generate the script section to remove the access path on all partitions
# but SystemDrive
Write-Output ("# Remove the access path on all partitions but SystemDrive") >> $restoreScriptFile
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

# Gnerate the script section to restore the drive letters
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

# Generate the script section to install and start RHV-APT service
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
Write-Output ("    Write-Output ('Service rhev-apt is present. Starting it.') >> `$logFile") >> $restoreScriptFile
Write-Output ("    Start-Service -Name rhev-apt") >> $restoreScriptFile
Write-Output ("}") >> $restoreScriptFile
Write-Output ("else {") >> $restoreScriptFile
Write-Output ("    Write-Output ('Service rhev-apt is still not installed. Something went wrong with rhev-apt.exe') >> `$log_File") >> $restoreScriptFile
Write-Output ("}") >> $restoreScriptFile
Write-Output ("Write-Output ('') >> `$logFile") >> $restoreScriptFile
Write-Output ("") >> $restoreScriptFile

# Generate the batch script that will be run by virt-v2v first boot script
# Using Out-File instead of Write-Output to set encoding and avoid UTF-8 BOM
'@echo off' | Out-File -FilePath $firstbootScriptFile -Encoding ascii 
'' | Out-File -FilePath $firstbootScriptFile -Encoding ascii -Append
'echo Restore configuration for network adapters and disks' | Out-File -FilePath $firstbootScriptFile -Encoding ascii -Append
'PowerShell.exe -ExecutionPolicy ByPass -File "' + $restoreScriptFile + '"' | Out-File -FilePath $firstbootScriptFile -Encoding ascii -Append
