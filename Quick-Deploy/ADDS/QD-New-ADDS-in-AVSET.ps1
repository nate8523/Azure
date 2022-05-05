<#	
	.NOTES
	===========================================================================
	 Created by:   	Nathan Carroll
	 Organization: 	M247
     Created on:    07 June 2020
     Version:       2.0
	 Filename:     	QD-New-ADDS-in-AVSET.ps1
	===========================================================================
	
    .DESCRIPTION
		The script installs the a new VNET and deploys a single domain controller with a new domain.
    
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

$DomainName = "domain.local"

#Record Deployment Details
$Logpath = "C:\Logs"
mkdir $Logpath
Start-Transcript -Path "$LogPath\QD-ADDS-in-VNET.log" -Append

# Get the credentials for the Local virtual machine
$VMCredentials = Get-Credential -Message "Enter a username and password for the virtual machine."

# Create New Resource Group
Write-Host "Deploying Resource Group"
$ResourceGroup = New-AzResourceGroup -Name "$CustomerPrefix-RG-ADDS-01" -Location $Location

# Create Storage Account
Write-Host "Deploying Storage Account for VM Diagnostics"
$StorageAccount = New-AzStorageAccount -ResourceGroupName $ResourceGroup.ResourceGroupName -AccountName ("$CustomerPrefix" + "addsdiagstore011").ToLower() -Location $Location -Type "Standard_LRS" -Kind "Storagev2"

# Create a subnet configuration
Write-Host "Configuring Subnets"
$SubnetConfig = New-AzVirtualNetworkSubnetConfig -Name "$CustomerPrefix-SNET-Data-01" -AddressPrefix $DataSubnetAddr

# Create a virtual network
Write-Host "Deploying Virtual Network"
$ADDSNetwork = New-AzVirtualNetwork -ResourceGroupName $ResourceGroup.ResourceGroupName -Location $Location -Name "$CustomerPrefix-VNET-Prod-01" -AddressPrefix $VNETAddress -Subnet $SubnetConfig

# Create an inbound network security group rule for port 3389
Write-Host "Configuring NSG RDP Rule"
$nsgAllowRDP = New-AzNetworkSecurityRuleConfig -Name "allow-RDP-inbound" -Description "Allow RDP Port 3389 Inbound" -Access Allow -Protocol TCP -Direction Inbound -Priority 100 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 

# Create a network security group
Write-Host "Deploying NSG"
$ADDSNSG = New-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroup.ResourceGroupName -Location $Location -Name "$CustomerPrefix-NSG-ADDS-01" -SecurityRules $nsgAllowRDP

# Create an availability set
Write-Host "Deploying Availability Set for ADDS VM's"
$ADDSAVset = New-AzAvailabilitySet -ResourceGroupName $ResourceGroup.ResourceGroupName -Location $Location -Name "$CustomerPrefix-AVSet-ADDS-01" -Sku Aligned -platformFaultDomainCount 2

# Get the VM Source Image
Write-Host "Creating Source Image Reference ... This can take up 10 minutes"
$Image = Get-AzVMImagePublisher -Location $Location | Get-AzVMImageOffer | Get-AzVMImageSku | Where-Object -FilterScript { $_.Id -like "*/WindowsServer/Skus/2022-Datacenter" }


for ($i = 01; $i -le 01; $i++) {
    $i2 = "{0:D2}" -f $i
    Write-Host "Creating VM: $CustomerPrefix-ADDS-$i2"

    # Create a public IP address
    Write-Host "Creating Public IP for $CustomerPrefix-ADDS-$i2"
    $ADDSPiP = New-AzPublicIpAddress -ResourceGroupName $ResourceGroup.ResourceGroupName -Location $Location -Name "$CustomerPrefix-ADDS-$i2-PiP-01" -AllocationMethod Static -IdleTimeoutInMinutes 4
  
    # Create a virtual network card and associate with public IP address and NSG
    Write-Host "Configure Network Card for $CustomerPrefix-ADDS-$i2"
    $ADDSNIC = New-AzNetworkInterface -Name "$CustomerPrefix-ADDS-$i2-Nic-01" -ResourceGroupName $ResourceGroup.ResourceGroupName -Location $Location -SubnetId $ADDSNetwork.Subnets[0].Id -PublicIpAddressId $ADDSPiP.Id -NetworkSecurityGroupId $ADDSNSG.Id
  
    #Create a virtual machine configuration
    Write-Host "Creating VM Configuration for $CustomerPrefix-ADDS-$i2"
    $vmConfig = New-AzVMConfig -Name "$CustomerPrefix-ADDS-$i2"-VMSize "Standard_B1ms" -AvailabilitySetId $ADDSAVset.Id
    $vmconfig = Set-AzVMOperatingSystem -VM $vmconfig -Windows -ComputerName "$CustomerPrefix-ADDS-$i2" -Credential $VMCredentials
  
    # Set the VM Source Image
    Write-Host "Configuring Source Image for $CustomerPrefix-ADDS-$i2"
    $vmConfig = Set-AzVMSourceImage -VM $vmConfig -PublisherName $Image.PublisherName -Offer $Image.Offer -Skus $Image.Skus -Version "latest"
  
    # Add Network Interface Card
    Write-Host "Adding Network Card to $CustomerPrefix-ADDS-$i2"
    $vmConfig = Add-AzVMNetworkInterface -Id $ADDSNIC.Id -VM $vmConfig
  
    # Applies the OS disk properties
    Write-Host "Configuring OS Disk Properties of $CustomerPrefix-ADDS-$i2"
    $vmConfig = Set-AzVMOSDisk -VM $vmConfig -CreateOption "FromImage" -Name "$CustomerPrefix-ADDS-$i2-OSDisk" -StorageAccountType "StandardSSD_LRS"
  
    # Enable boot diagnostics.
    Write-Host "Configuring Boot Diagnostics for $CustomerPrefix-ADDS-$i2"
    $vmConfig = Set-AzVMBootDiagnostic -VM $vmConfig -Enable -StorageAccountName $StorageAccount.StorageAccountName -ResourceGroupName $ResourceGroup.ResourceGroupName
    $NewVM = New-AzVM -ResourceGroupName $ResourceGroup.ResourceGroupName -Location $Location -VM $vmConfig
    Write-Host "$CustomerPrefix-ADDS-$i2 Deployed"
    $NewVM

    # Configure VM Roles
    Write-Host "Installing and Confguring ADDS"
    ConfigureVM
}

Function ConfigureVM {
    # Start Script installation of Azure PowerShell requirement for adding Azure Compute Account
        Set-AzVMCustomScriptExtension -ResourceGroupName $ResourceGroup.ResourceGroupName `
        -VMName $CustomerPrefix-ADDS-$i2 `
        -Location $Location `
        -FileUri https://raw.githubusercontent.com/nate8523/Azure/main/Quick-Deploy/Customisation-Scripts/InstallADDS.ps1 `
        -Argument $DomainName `
        -Run 'InstallADDS.ps1' `
        -Name InstallADDS

    Start-Sleep -s 15
}

Stop-Transcript