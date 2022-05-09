<#	
	.NOTES
	===========================================================================
	 Created by:   	Nathan Carroll
	 Organization: 	M247
     Created on:    05 Aug 2020
     Version:       2.0
	 Filename:     	QD-Veeam-BR.ps1
	===========================================================================
	
    .DESCRIPTION
		This script is used to provision a new Veeam Backup and Replication Solution into an Azure 
        tenant.  The Solution Configures a new Resource Group containing a VNET, Storage Account,
        Public IP, Network Security Group and a Virtual Machanine provisioned from the Azure Marketplace.
    
    .DISCLAIMER
        This script is provided AS IS without warranty of any kind. In no event shall its author,
        or anyone else involved in the creation, production, or delivery of the scripts be liable
        for any damages whatsoever (including, without limitation, damages for loss of business profits,
        business interruption, loss of business information, or other pecuniary loss) arising out
        of the use of or inability to use the scripts or documentation, even if the author has
        been advised of the possibility of such damages. 

#>

$CustomerPrefix = "CUST"
$Location = "UK South"

$DataSubnetAddr = "10.0.1.0/24"
$VNETAddress = "10.0.0.0/16"

# Disable Breaking Change Warnings
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

#Record Deployment Details
$Logpath = "C:\Logs"
#mkdir $Logpath
if ((test-path C:\Logs) -eq $false) {
    new-item -ItemType Directory -path "C:\" -name "Logs" | Out-Null
}
Start-Transcript -Path "$LogPath\QD-Veeam-BR.log" -Append

# Get the credentials for the Local virtual machine
$VMCredentials = Get-Credential -Message "Enter a username and password for the virtual machine."

# Create New Resource Group
Write-Host "Deploying Resource Group"
$ResourceGroup = New-AzResourceGroup -Name "$CustomerPrefix-RG-VBR-01" -Location $Location

# Create Storage Account
Write-Host "Deploying Storage Account for VM Diagnostics"
$StorageAccount = New-AzStorageAccount -ResourceGroupName $ResourceGroup.ResourceGroupName -AccountName ("$CustomerPrefix" + "addsdiagstore011").ToLower() -Location $Location -Type "Standard_LRS" -Kind "Storagev2"

# Create a subnet configuration
Write-Host "Configuring Subnets"
$SubnetConfig = New-AzVirtualNetworkSubnetConfig -Name "$CustomerPrefix-SNET-Data-01" -AddressPrefix $DataSubnetAddr

# Create a virtual network
Write-Host "Deploying Virtual Network"
$VeeamNetwork = New-AzVirtualNetwork -ResourceGroupName $ResourceGroup.ResourceGroupName -Location $Location -Name "$CustomerPrefix-VNET-Prod-01" -AddressPrefix $VNETAddress -Subnet $SubnetConfig

# Create a public IP address
Write-Host "Creating Public IP Address for Veeam"
$VeeamPiP = New-AzPublicIpAddress -ResourceGroupName $ResourceGroup.ResourceGroupName -Location $Location -Name "$CustomerPrefix-PiP-VBR-01" -AllocationMethod Static -IdleTimeoutInMinutes 4

# Create an inbound network security group rule for port 3389
Write-Host "Configuring NSG RDP Rule"
$nsgAllowRDP = New-AzNetworkSecurityRuleConfig -Name "allow-RDP-inbound" -Description "Allow RDP Port 3389 Inbound" -Access Allow -Protocol TCP -Direction Inbound -Priority 100 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 

# Create inbound network security rule for Veeam CLoud Connect
$nsgCCrule1 = New-AzNetworkSecurityRuleConfig -Name "allow-cloudconnect-tcp-inbound" -Description "Allow Cloud Connect TCP 6180 Inbound" -Access Allow -Protocol TCP -Direction Inbound -Priority 1010 -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 6180
$nsgCCrule2 = New-AzNetworkSecurityRuleConfig -Name "allow-cloudconnect-udp-inbound" -Description "Allow Cloud Connect UCP 6180 Inbound" -Access Allow -Protocol UDP -Direction Inbound -Priority 1011 -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 6180

# Create a network security group
Write-Host "Deploying NSG"
$VeeamNSG = New-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroup.ResourceGroupName -Location $Location -Name "$CustomerPrefix-NSG-VBR-01" -SecurityRules $nsgAllowRDP,$nsgCCrule1,$nsgCCrule2

# Create a virtual network card and associate with public IP address and NSG
Write-Host "Deploying Network Interface for Veeam VM"
$VeeamNIC = New-AzNetworkInterface -Name "$CustomerPrefix-VBR-NIC-01" -ResourceGroupName $ResourceGroup.ResourceGroupName -Location $Location -SubnetId $VeeamNetwork.Subnets[0].Id -PublicIpAddressId $VeeamPiP.Id -NetworkSecurityGroupId $VeeamNSG.Id

# Set the Marketplace image
$Publisher = "veeam"
$offerName = "veeam-backup-replication"
$skuName = "veeam-backup-replication-v11"
$version = "11.1.2"

# Get the Veeam VM Image and accept the terms
Write-Host "Accepting Terms and Conditions of Marketplace Image"
Get-AzVMImage -Location $Location -PublisherName $Publisher -Offer $offerName -Skus $skuName -Version $version
Get-AzMarketplaceterms -Publisher $Publisher -Product $offerName -Name $skuName | Set-AzMarketplaceTerms -Accept

#Create a virtual machine configuration
Write-Host "Configuring Virtual machine"
$vmConfig = New-AzVMConfig -VMName "$CustomerPrefix-VBR-01" -VMSize "Standard_B1ms"
$vmConfig = Set-AzVMPlan -VM $vmConfig -Publisher $Publisher -Product $offerName -Name $skuName
$vmConfig = Set-AzVMOperatingSystem -Windows -VM $vmConfig -ComputerName "$CustomerPrefix-VBR-01" -Credential $VMCredentials
$vmConfig = Set-AzVMSourceImage -VM $vmConfig -PublisherName $Publisher -Offer $offerName -Skus $skuName -Version $version
$vmConfig = Add-AzVMNetworkInterface -Id $VeeamNIC.Id -VM $vmConfig
$vmConfig = Set-AzVMOSDisk -VM $vmConfig -CreateOption "FromImage" -Name "$CustomerPrefix-VBR-01-OSDisk"
$vmConfig = Set-AzVMBootDiagnostic -VM $vmConfig -Enable -StorageAccountName $StorageAccount.StorageAccountName -ResourceGroupName $ResourceGroup.ResourceGroupName

# Optional: Add an additional data disk.
$vmDataDisk01Config = New-AzDiskConfig -SkuName Standard_LRS -Location $Location -CreateOption Empty -DiskSizeGB 128
$vmDataDisk01 = New-AzDisk -DiskName "$CustomerPrefix-VBR-01-DataDisk-1" -Disk $vmDataDisk01Config -ResourceGroupName $ResourceGroup.ResourceGroupName
$vmConfig = Add-AzVMDataDisk -VM $vmConfig -Name "$CustomerPrefix-VBR-01-DataDisk-1" -CreateOption Attach -ManagedDiskId $vmDataDisk01.Id -Lun 0

# Deploy Virtual Machine
Write-Host "Deploying Virtual Machine"
New-AzVM -ResourceGroupName $ResourceGroup.ResourceGroupName -Location $Location -VM $vmConfig

# Start Script installation of Azure PowerShell requirement for adding Azure Compute Account
Set-AzVMCustomScriptExtension -ResourceGroupName $ResourceGroup `
    -VMName "$CustomerPrefix-VBR-01" `
    -Location $Location `
    -FileUri https://raw.githubusercontent.com/nate8523/Azure/main/Quick-Deploy/Customisation-Scripts/Configure-Veeam-Backup.ps1 `
    -Run 'Configure-Veeam-Backup.ps1' `
    -Name ConfigureVeeamBackup

Start-Sleep -s 15

Write-host "Your public IP address is $($VeeamPiP.IpAddress)"
mstsc /v:$($VeeamPiP.IpAddress)

Stop-Transcript

