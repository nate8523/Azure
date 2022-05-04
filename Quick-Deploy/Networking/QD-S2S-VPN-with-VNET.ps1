$CustomerPrefix = "CUST"
$Location = "UK South"

$GatewaySubnetAddr ="10.0.0.0/28"
$DataSubnetAddr = "10.0.1.0/24"
$VNETAddress = "10.0.0.0/16"

$OnPremiseExternalIP = "82.45.26.11"
$OnPremiseInternalIP = "192.168.0.0/24"

# Create New Resource Group
Write-Host "Deploying Resource Group"
$ResourceGroup = New-AzResourceGroup -Name "$CustomerPrefix-RG-VPN-01" -Location $Location

# Configure Subnets
Write-Host "Configuring Subnets"
$GatewaySubnetName = "GatewaySubnet"
$DataSubnetName = "$CustomerPrefix-SNet-Data-01"
$GatewaySubnet = New-AzVirtualNetworkSubnetConfig -Name $GatewaySubnetName -AddressPrefix $GatewaySubnetAddr 
$DataSubnet = New-AzVirtualNetworkSubnetConfig -Name $DataSubnetName -AddressPrefix $DataSubnetAddr

# Deploy virtual Network
Write-Host "Deploying Virtual Network"
$VNET = New-AzVirtualNetwork -Name "$CustomerPrefix-VNET-Prod-01" -ResourceGroupName $ResourceGroup.ResourceGroupName -Location $Location -AddressPrefix $VNETAddress -Subnet $GatewaySubnet, $DataSubnet

# Deploy Local Network Gateway
Write-Host "Deploying Local Network Gateway"
$LocalGateway = New-AzLocalNetworkGateway -Name "$CustomerPrefix-GW-HQ-01" -ResourceGroupName $ResourceGroup.ResourceGroupName -Location $Location -GatewayIpAddress $OnPremiseExternalIP -AddressPrefix $OnPremiseInternalIP

# Deploy Public IP for Gateway VPN
Write-Host "Deploying Public IP for VPN Gateway"
$GatewayPiP = New-AzPublicIpAddress -Name "$CustomerPrefix-VPNGW-PiP-01" -ResourceGroupName $ResourceGroup.ResourceGroupName -Location $Location -AllocationMethod "Dynamic" -IdleTimeoutInMinutes 30 -SKU "Basic"

# Configure VPN Gateway
Write-Host "Creating VPN Gateway Configuration"
$GatewayVNETInfo = Get-AzVirtualNetwork -Name $VNet.Name -ResourceGroupName $ResourceGroup.ResourceGroupName
$GatewaySubnetInfo = Get-AzVirtualNetworkSubnetConfig -Name 'GatewaySubnet' -VirtualNetwork $GatewayVNETInfo
$GatewayIPconfig = New-AzVirtualNetworkGatewayIpConfig -Name "$CustomerPrefix-VPN-GW-01-Config" -SubnetId $GatewaySubnetInfo.id -PublicIpAddressId $GatewayPiP.id

# Deploy VPN Gateway
Write-Host "Deploying VPN Gateway.... Deployment may take around 40 minutes to complete"
$VPNGW = New-AzVirtualNetworkGateway -Name "$CustomerPrefix-VPN-GW-01" -ResourceGroupName $ResourceGroup.ResourceGroupName -Location $Location -IPConfigurations $GatewayIPconfig -GatewayType "VPN" -VpnType "RouteBased" -GatewaySku "Basic"

# Generate PSK
Write-Host "Generating a 28 Character Pre Shared Key"
$GatewayPSK = ( -join ((0x30..0x39) + ( 0x41..0x5A) + ( 0x61..0x7A) | Get-Random -Count 28  | ForEach-Object {[char]$_}) )

# Create VPN Connection
Write-Host "Creating VPN Connection"
$Gateway1 = Get-AzVirtualNetworkGateway -Name $VPNGW.name -ResourceGroupName $ResourceGroup.ResourceGroupName
$local = Get-AzLocalNetworkGateway -Name $LocalGateway.name -ResourceGroupName $ResourceGroup.ResourceGroupName

## Configure VPN Connectivity
Write-Host "Configuring VPN Connections"
New-AzVirtualNetworkGatewayConnection -Name "$CustomerPrefix-Azure-HQ-VPN" -ResourceGroupName $ResourceGroup.ResourceGroupName -Location $Location -VirtualNetworkGateway1 $Gateway1 -LocalNetworkGateway2 $local -ConnectionType "IPsec" -RoutingWeight "10" -SharedKey $GatewayPSK

Write-Host "VPN Deployment Complete"