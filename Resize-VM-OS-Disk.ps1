<#	
	.NOTES
	===========================================================================
	 Created by:   	Nathan Carroll
	 Organization: 	M247
     Created on:    17 July 2020
     Version:       1.0
	 Filename:     	Resize-VM-OS-Disk.ps1
	===========================================================================
	
    .DESCRIPTION
		This script is used to resize the OS disk of an Azure VM
    
    .DISCLAIMER
        This script is provided AS IS without warranty of any kind. In no event shall its author,
        or anyone else involved in the creation, production, or delivery of the scripts be liable
        for any damages whatsoever (including, without limitation, damages for loss of business profits,
        business interruption, loss of business information, or other pecuniary loss) arising out
        of the use of or inability to use the scripts or documentation, even if the author has
        been advised of the possibility of such damages. 

#>

$vmName = "Cust-V365-01"
$NewOSDiskSize = "128" #GB

# Disable Breaking Change Warnings
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

#Record Deployment Details
$Logpath = "C:\Logs"
if ((test-path C:\Logs) -eq $false) {
    new-item -ItemType Directory -path "C:\" -name "Logs" | Out-Null
}
Start-Transcript -Path "$LogPath\Resize-VM-OS-Disk.log" -Append

# Function - Managed OS Disk Resize
Function ResizeManagedOSDisk {
    # Stop the VM
    Write-Host "Stopping the VM: $vmName"
    Stop-AzVM -ResourceGroupName $VM.ResourceGroupName -Name $vmName -Force | Out-Null
    # Get OS Disk Info and Resize
    Write-Host "Setting the new Disk Size"
    $OSdisk= Get-AzDisk -ResourceGroupName $VM.ResourceGroupName -DiskName $vm.StorageProfile.OsDisk.Name
    $OSdisk.DiskSizeGB = $NewOSDiskSize
    Update-AzDisk -ResourceGroupName $VM.ResourceGroupName -Disk $OSdisk -DiskName $OSdisk.Name | Out-Null
    # Start the VM
    Write-Host "Starting the VM: $vmName"
    Start-AzVM -ResourceGroupName $VM.ResourceGroupName -Name $vmName
    Write-Host "OS Disk Resize Complete"
}


# Function - UnManaged OS Disk Resize

Function ResizeUnManagedOSDisk {
    # Stop the VM
    Write-Host "Stopping the VM: $vmName"
    Stop-AzVM -ResourceGroupName $VM.ResourceGroupName -Name $vmName -Force | Out-Null
    # Set the new OS Disk Size and Update
    Write-Host "Setting the new Disk Size"
    $vm.StorageProfile.OSDisk.DiskSizeGB = $NewOSDiskSize
    Update-AzVM -ResourceGroupName $VM.ResourceGroupName -VM $vm | Out-Null
    # Start the VM
    Write-Host "Starting the VM: $vmName"
    Start-AzVM -ResourceGroupName $VM.ResourceGroupName -Name $vmName
    Write-Host "OS Disk Resize Complete"
}

# Get VM Info
$vm = Get-AzVM -Name $vmName

# Check if the VM uses managed or unmanaged disks
if ($VM.StorageProfile.OsDisk.ManagedDisk) {
    Write-Host "VM IS using Managed OS Disk"
    ResizeManagedOSDisk
} else {
    Write-Host "VM is NOT using Managed OS Disk"
    ResizeUnManagedOSDisk
}

Stop-Transcript