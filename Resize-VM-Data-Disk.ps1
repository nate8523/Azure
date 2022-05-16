<#	
	.NOTES
	===========================================================================
	 Created by:   	Nathan Carroll
	 Organization: 	M247
     Created on:    17 July 2020
     Version:       1.0
	 Filename:     	Resize-VM-Data-Disk.ps1
	===========================================================================
	
    .DESCRIPTION
		This script is used to resize the Data disk of an Azure VM
    
    .DISCLAIMER
        This script is provided AS IS without warranty of any kind. In no event shall its author,
        or anyone else involved in the creation, production, or delivery of the scripts be liable
        for any damages whatsoever (including, without limitation, damages for loss of business profits,
        business interruption, loss of business information, or other pecuniary loss) arising out
        of the use of or inability to use the scripts or documentation, even if the author has
        been advised of the possibility of such damages. 

#>

$vmName = "Cust-V365-01"
$NewDataDiskSize = "128" #GB
$DataDiskLun = "0"

# Disable Breaking Change Warnings
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

#Record Deployment Details
$Logpath = "C:\Logs"
if ((test-path C:\Logs) -eq $false) {
    new-item -ItemType Directory -path "C:\" -name "Logs" | Out-Null
}

Start-Transcript -Path "$LogPath\Resize-VM-Data-Disk.log" -Append

# Function - Managed Data Disk Resize
Function ResizeManagedDataDisk {
    # Stop the VM
    Write-Host "Stopping the VM: $vmName"
    Stop-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vmName -Force | Out-Null
    # Get Data Disk Info and Resize
    Write-Host "Setting the new Data Disk Size"
    $Datadisk= Get-AzDisk -ResourceGroupName $vm.ResourceGroupName -DiskName $vm.StorageProfile.DataDisks[$DataDiskLun].Name
    $Datadisk.DiskSizeGB = $NewDataDiskSize
    Update-AzDisk -ResourceGroupName $vm.ResourceGroupName -Disk $Datadisk -DiskName $Datadisk.Name | Out-Null
    # Start the VM
    Write-Host "Starting the VM: $vmName"
    Start-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vmName
    Write-Host "Data Disk Resize Complete"
}

# Function - UnManaged Data Disk Resize
Function ResizeUnManagedDataDisk {
    # Stop the VM
    Write-Host "Stopping the VM: $vmName"
    Stop-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vmName -Force | Out-Null
    # Set the new Data Disk Size and Update
    Write-Host "Setting the new Disk Size"
    $vm.StorageProfile.DataDisks[$DataDiskLun].DiskSizeGB = $NewDataDiskSize
    Update-AzVM -ResourceGroupName $vm.ResourceGroupName -VM $vm | Out-Null
    # Start the VM
    Write-Host "Starting the VM: $vmName"
    Start-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vmName
    Write-Host "Data Disk Resize Complete"
}

#-------------------------- [ Body ] -------------------------- #

# Get VM Info
$vm = Get-AzVM -Name $vmName

# Check if the VM uses managed or unmanaged disks
if ($VM.StorageProfile.DataDisks.ManagedDisk) {
    Write-Host "VM IS using Managed Data Disk"
    ResizeManagedDataDisk
} else {
    Write-Host "VM is NOT using Managed Data Disk"
    ResizeUnManagedDataDisk
}

Stop-Transcript