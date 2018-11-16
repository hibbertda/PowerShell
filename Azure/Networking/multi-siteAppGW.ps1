# Ref: https://docs.microsoft.com/en-us/azure/application-gateway/application-gateway-create-multisite-azureresourcemanager-powershell

# 
$azGovRegion = "usgovarizona"
$azResourceGroupName = "hbl-applicationGW-2"
$azAppGWVnet = "hbl-vnet-AppGW"
$azAppGWVnet_appGWsubnet = "appgw-backendsubnet"
$azAppGWVnet_backendSubnet = "appgw-appgwsubnet"
$azPublicIP = "hbl-appgw-pip"

# Create Resource Group
New-AzureRmResourceGroup -Name $azResourceGroupName -Location $azGovRegion

# backend subnet
$backendSubnetConfig = New-AzureRmVirtualNetworkSubnetConfig `
    -Name $azAppGWVnet_backendSubnet `
    -AddressPrefix 10.0.1.0/24

# appGW subnet
$agSubnetConfig = New-AzureRmVirtualNetworkSubnetConfig `
    -Name $azAppGWVnet_appGWsubnet `
    -AddressPrefix 10.0.2.0/24

# VNet
$vnet = New-AzureRmVirtualNetwork `
    -ResourceGroupName $azResourceGroupName `
    -Location $azGovRegion `
    -Name $azAppGWVnet `
    -AddressPrefix 10.0.0.0/16 `
    -Subnet $backendSubnetConfig, $agSubnetConfig

# AppGW public IP
$pip = New-AzureRmPublicIpAddress `
    -ResourceGroupName $azResourceGroupName `
    -Location $azGovRegion `
    -Name $azPublicIP `
    -AllocationMethod Dynamic

# Create Application Gateway

# get vnet definiton
$vnet = Get-AzureRmVirtualNetwork `
    -ResourceGroupName $azResourceGroupName `
    -Name $azAppGWVnet

    # VNet subnets
$subnet=$vnet.Subnets[0]

$gipconfig = New-AzureRmApplicationGatewayIPConfiguration `
  -Name myAGIPConfig `
  -Subnet $subnet

$fipconfig = New-AzureRmApplicationGatewayFrontendIPConfig `
  -Name myAGFrontendIPConfig `
  -PublicIPAddress $pip

$frontendport = New-AzureRmApplicationGatewayFrontendPort `
  -Name myFrontendPort `
  -Port 80


# create backend pools and settings 
$app1Pool = New-AzureRmApplicationGatewayBackendAddressPool `
  -Name app1
$app2Pool = New-AzureRmApplicationGatewayBackendAddressPool `
  -Name app2
$poolSettings = New-AzureRmApplicationGatewayBackendHttpSettings `
  -Name myPoolSettings `
  -Port 80 `
  -Protocol Http `
  -CookieBasedAffinity Enabled `
  -RequestTimeout 120

# Create listeners and rules

$app1listener = New-AzureRmApplicationGatewayHttpListener `
  -Name app1Listener `
  -Protocol Http `
  -FrontendIPConfiguration $fipconfig `
  -FrontendPort $frontendport `
  -HostName "app1.thehibbs.net"
$app2listener = New-AzureRmApplicationGatewayHttpListener `
  -Name app2Listener `
  -Protocol Http `
  -FrontendIPConfiguration $fipconfig `
  -FrontendPort $frontendport `
  -HostName "app2.thehibbs.net"
$app1Rule = New-AzureRmApplicationGatewayRequestRoutingRule `
  -Name app1Rule `
  -RuleType Basic `
  -HttpListener $app1Listener `
  -BackendAddressPool $app1Pool `
  -BackendHttpSettings $poolSettings
$app2Rule = New-AzureRmApplicationGatewayRequestRoutingRule `
  -Name app2Rule `
  -RuleType Basic `
  -HttpListener $app2Listener `
  -BackendAddressPool $app2Pool `
  -BackendHttpSettings $poolSettings
# AppGW SKU
$sku = New-AzureRmApplicationGatewaySku `
-Name Standard_Medium `
-Tier Standard `
-Capacity 2

# Create the application gateway
$appgw = New-AzureRmApplicationGateway `
  -Name myAppGateway `
  -ResourceGroupName $azResourceGroupName `
  -Location $azGovRegion `
  -BackendAddressPools $app1Pool, $app2Pool `
  -BackendHttpSettingsCollection $poolSettings `
  -FrontendIpConfigurations $fipconfig `
  -GatewayIpConfigurations $gipconfig `
  -FrontendPorts $frontendport `
  -HttpListeners $app1Listener, $app2Listener `
  -RequestRoutingRules $app1Rule, $app2Rule `
  -Sku $sku

  