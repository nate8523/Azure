<#	
	.NOTES
	===========================================================================
	 Created by:   	Nathan Carroll
	 Organization: 	M247
     Created on:    17 July 2020
     Version:       1.0
	 Filename:     	Migrate-VM-to-New-VNET.ps1
	===========================================================================
	
    .DESCRIPTION
		This script is used to migrate a VM to a new VNet. VNET-to-VNet migrations are not supported.  
        This script redployes the VM to the new VNET.  A downtime window for the VM is required
    
    .DISCLAIMER
        This script is provided AS IS without warranty of any kind. In no event shall its author,
        or anyone else involved in the creation, production, or delivery of the scripts be liable
        for any damages whatsoever (including, without limitation, damages for loss of business profits,
        business interruption, loss of business information, or other pecuniary loss) arising out
        of the use of or inability to use the scripts or documentation, even if the author has
        been advised of the possibility of such damages. 

#>

$VMName = "VM Name"
$NewVNetName = "New-VNet-Name"
$NewSubnetName = "New-SNet-Name"
$NewPrivateIp = "10.0.0.4"
$NewNicName = "$VMName-Nic0"
$NewPublicIpName = "$VMName-PiP0"

# Disable Breaking Change Warnings
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

#Record Deployment Details
$Logpath = "C:\Logs"
if ((test-path C:\Logs) -eq $false) {
    new-item -ItemType Directory -path "C:\" -name "Logs" | Out-Null
}

Start-Transcript -Path "$LogPath\Migrate-VM-to-New-VNET.log" -Append

# Retrieve VM details
$VM = Get-AzVM -Name $VMName
Write-Host "VM Details Retrieved"

# Check if the VM uses managed or unmanaged disks
if ($VM.StorageProfile.OsDisk.ManagedDisk) {
    $ManagedDisks = $true
    Write-Host "VM is using Managed Disks"
} else {
    $ManagedDisks = $false
    Write-Host "VM is Not using Managed Disks"
}

# Stop the VM
Write-Host "Stopping VM"
Stop-AzVM -Name $VMName -ResourceGroupName $vm.ResourceGroupName -Force
Write-Host "VM Stopped"

# Get VM current networking details
Write-Host "Getting current Network Configuration"
$Nic = (Get-AzNetworkInterface | Where-Object -FilterScript { $_.VirtualMachine.Id -like $VM.Id })
$PublicIp = Get-AzPublicIpAddress | Where-Object -FilterScript { $_.Id -like $Nic.IpConfigurations.PublicIpAddress.Id }

# Get new virtual network details
Write-Host "Getting Destination Network details"
$NewVNet = Get-AzVirtualNetwork | Where-Object -FilterScript { $_.Name -like $NewVNetName }
$NewSubnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $NewVNet -Name $NewSubnetName

# Create new VM networking resources
Write-Host "Createing New VM Networking"
$NewPublicIp = New-AzPublicIpAddress -Name $NewPublicIpName -Location $NewVNet.Location -ResourceGroupName $NewVNet.ResourceGroupName -Sku $PublicIp.Sku.Name -AllocationMethod $PublicIp.PublicIpAllocationMethod
$NewIpConfig = New-AzNetworkInterfaceIpConfig -Subnet $NewSubnet -Name "ipconfig2" -Primary -PrivateIpAddress $NewPrivateIp -PublicIpAddress $NewPublicIp
$NewNic = New-AzNetworkInterface -Name $NewNicName -ResourceGroupName $NewVNet.ResourceGroupName -Location $NewVNet.Location -IpConfiguration $NewIpConfig -NetworkSecurityGroupId $Nic.NetworkSecurityGroup.Id -Force

# Retrieve VM data disk details
Write-Host "Getting Current Disk Info"
if ($VM.StorageProfile.DataDisks) {
    $Lun = 0
    if ($ManagedDisks) {
        $Disks = Get-AzDisk -ResourceGroupName $RGName | Where-Object -FilterScript { $_.ManagedBy -like "*$VMName" } | Where-Object -FilterScript { $_.Id -notlike $VM.StorageProfile.OsDisk.ManagedDisk.Id }
    } else {
        $Disks = $VM.StorageProfile.DataDisks
    }
}

# Create new VM configuration
Write-Host "Creating new VM Configuration"
$NewVmConfig = New-AzVMConfig -VMName $VMName -VMSize $VM.HardwareProfile.VmSize

if ($ManagedDisks) {
    # Add OS disk to new VM configuration
    if ($VM.OsProfile.WindowsConfiguration) {
        $NewVmConfig = Set-AzVMOSDisk -VM $NewVmConfig -ManagedDiskId $VM.StorageProfile.OsDisk.ManagedDisk.Id -CreateOption "Attach" -Windows
    } else {
        $NewVmConfig = Set-AzVMOSDisk -VM $NewVmConfig -ManagedDiskId $VM.StorageProfile.OsDisk.ManagedDisk.Id -CreateOption "Attach" -Linux
    }
    # Add data disk(s) to new VM configuration
    foreach ($Disk in $Disks) {
        $NewVmConfig = Add-AzVMDataDisk -VM $NewVmConfig -ManagedDiskId $Disk.Id -CreateOption "Attach" -Lun $Lun -DiskSizeInGB $Disk.DiskSizeGB
        $Lun++
    }
} else {
    # Add OS disk to new VM configuration
    if ($VM.OsProfile.WindowsConfiguration) {
        $NewVmConfig = Set-AzVMOSDisk -VM $NewVmConfig -VhdUri $VM.StorageProfile.OsDisk.Vhd.Uri -CreateOption Attach -Name $VM.StorageProfile.OsDisk.Name -Windows
    } else {
        $NewVmConfig = Set-AzVMOSDisk -VM $NewVmConfig -VhdUri $VM.StorageProfile.OsDisk.Vhd.Uri -CreateOption Attach -Name $VM.StorageProfile.OsDisk.Name -Linux
    }
    # Add data disk(s) to new VM configuration
    foreach ($Disk in $Disks) {
        $NewVmConfig = Add-AzVMDataDisk -VM $NewVmConfig -Name $Disk.Name -CreateOption "Attach" -Lun $Lun -DiskSizeInGB $Disk.DiskSizeGB
        $Lun++
    }
}

# Add new NIC to new VM configuration
Write-Host "Adding Nic Info to new VM Config"
$NewVmConfig = Add-AzVMNetworkInterface -VM $NewVmConfig -NetworkInterface $NewNic

# Remove the old VM
Write-Host "Deleting Old VM"
Write-Output -InputObject "Removing old virtual machine"
Remove-AzVM -Name $VMName -ResourceGroupName $ResourceGroup -Force

# Create the new VM from the new VM configuration
Write-Output -InputObject "Creating new virtual machine"
New-AzVM -VM $NewVmConfig -ResourceGroupName $NewVNet.ResourceGroupName -Location $NewVNet.Location
Get-AzVM -ResourceGroupName $ResourceGroup -Name $VMName
Write-Output -InputObject "The virtual machine has been created successfully"

Stop-Transcript