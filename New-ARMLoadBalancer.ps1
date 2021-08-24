Param(

[Parameter(Mandatory=$true)]$ResourceGroupName #= 'WSDDAPPE'
,[Parameter(Mandatory=$true)]$AvailabilitySetName #= 'SESUW2-SQLP14SA'
,[Parameter(Mandatory=$true)]$Listener #= 'SESUW2-SQLP14'
,[ValidateSet(“SQLAO”,”IISAO”)][Parameter(Mandatory=$true)]$role = 'iisAO'
,[Parameter(Mandatory=$true)]$VNET
,[Parameter(Mandatory=$true)]$location
,[Parameter(Mandatory=$true)]$subnetid
)


[regex]$REgex = "(\b[A-z]?\w+[^/]+$)"
$FEIPConfigName = "${Listener}FEIPConfig"
$ProbeName = "${listener}Probe"
$LBBEpoolName = "${Listener}BEPOOL" 
$LBName = "${listener}LB"
$LBRuleNameRDPTCP = "${Listener}LBRule3389TCP"
$LBRuleNameRDPUDP = "${Listener}LBRule3389UDP"
$LBRuleNameSQL = "${Listener}LBRule1433"
$LBRuleNameIIS1 = "${Listener}LBRule80"
$LBRuleNameIIS2 = "${Listener}LBRule443"


###### Need to add logic for more than one VNET ######
#Checking for VM
write-verbose -Verbose -Message "Creating on ER [ $($Vnet.Name) ] in [ $Location ]"
###### Need to add logic for more than one VNET ######


write-verbose -Verbose -Message "Creating Frontend Config [ $FEIPConfigName ] on Subnet [ $( $Vnet.Subnets[0].name ) ]"
$frontend = New-AzureRmLoadBalancerFrontendIpConfig -Name $FEIPConfigName -SubnetId $subnetId 


#SQLAO Probe
write-verbose -Verbose -Message "Creating Probe [ $ProbeName ] Protocal [ TCP ] Port [ 59999 ]"
$probe = New-AzureRmLoadBalancerProbeConfig -Name $ProbeName -Protocol "TCP" -Port 59999 -IntervalInSeconds 5 -ProbeCount 2

write-verbose -Verbose -Message "Creating BE POOL [ $LBBEpoolName ]"
$backendAddressPool = New-AzureRmLoadBalancerBackendAddressPoolConfig -Name $LBBEpoolName 

write-verbose -Verbose -Message "Gathering servers in AvailabilitySet"
$Servers=@()
$Server=(Get-AzureRmAvailabilitySet -ResourceGroupName $ResourceGroupName -Name $AvailabilitySetName | select -ExpandProperty VirtualMachinesReferences | select -ExpandProperty id)| % {$_ -match $REgex; $Servers += $Matches[0]}

#Defining Inbound NAT Rule for LB
$inboundNATRuleSQLTCP= New-AzureRmLoadBalancerInboundNatRuleConfig -Name "RDP" -FrontendIpConfiguration $frontend -Protocol TCP -FrontendPort 3389 -BackendPort 3389 -EnableFloatingIP 
$inboundNATRuleSQLUDP= New-AzureRmLoadBalancerInboundNatRuleConfig -Name "RDP" -FrontendIpConfiguration $frontend -Protocol UDP -FrontendPort 3389 -BackendPort 3389 -EnableFloatingIP 
$inboundNATRuleIISTCP= New-AzureRmLoadBalancerInboundNatRuleConfig -Name "RDP" -FrontendIpConfiguration $frontend -Protocol TCP -FrontendPort 3389 -BackendPort 3389 
$inboundNATRuleIISUDP= New-AzureRmLoadBalancerInboundNatRuleConfig -Name "RDP" -FrontendIpConfiguration $frontend -Protocol UDP -FrontendPort 3389 -BackendPort 3389 

#Defining rules according to Role
switch ($role) {
    SQLAO {
        #Creating Probe with TCP Protocol with Port 59999
        write-verbose -Verbose -Message "Creating Probe [ $ProbeName ] Protocal [ TCP ] Port [ 59999 ]"
        $probe = New-AzureRmLoadBalancerProbeConfig -Name $ProbeName -Protocol "TCP" -Port 59999 -IntervalInSeconds 5 -ProbeCount 2

        write-verbose -Verbose -Message "Creating Load Balancer Rule [ $LbRuleNameSQL ]"
        $SQLRule1433 = New-AzureRmLoadBalancerRuleConfig -Name $LBRuleNameSQL -FrontendIPConfiguration $frontend -BackendAddressPool $backendAddressPool -Probe $probe -Protocol "Tcp" -FrontendPort 1433 -BackendPort 1433 -IdleTimeoutInMinutes 4 -EnableFloatingIP
        $RDPRule3389TCP = New-AzureRmLoadBalancerRuleConfig -Name $LBRuleNameRDPTCP -FrontendIPConfiguration $frontend -BackendAddressPool $backendAddressPool -Probe $probe -Protocol "Tcp" -FrontendPort 3389 -BackendPort 3389 -IdleTimeoutInMinutes 4 -EnableFloatingIP
        $RDPRule3389UDP = New-AzureRmLoadBalancerRuleConfig -Name $LBRuleNameRDPUDP -FrontendIPConfiguration $frontend -BackendAddressPool $backendAddressPool -Probe $probe -Protocol "UDP" -FrontendPort 3389 -BackendPort 3389 -IdleTimeoutInMinutes 4 -EnableFloatingIP
        $lbrule=$SQLRule1433   
        write-verbose -Verbose -Message "Creating Load Balancer [ $LbName ]"
        $lb = New-AzureRmLoadBalancer -Name $LBName -ResourceGroupName $ResourceGroupName -Location $Location -FrontendIpConfiguration $frontend -BackendAddressPool $backendAddressPool -Probe $probe -InboundNatRule $inboundNATRuleSQLTCP -LoadBalancingRule $lbrule -Force
 
    }
    IISAO {
        #Creating Probe with TCP Protocol with Port 80
        write-verbose -Verbose -Message "Creating Probe [ $ProbeName ] Protocal [ TCP ] Port [ 80 ]"
        $probe80 = New-AzureRmLoadBalancerProbeConfig -Name "${ProbeName}80" -Protocol tcp -Port 80 -IntervalInSeconds 5 -ProbeCount 2
        $probe443 = New-AzureRmLoadBalancerProbeConfig -Name "${ProbeName}443" -Protocol tcp -Port 443 -IntervalInSeconds 5 -ProbeCount 2
        
        write-verbose -Verbose -Message "Creating Load Balancer Rule [ $LBRuleNameIIS1 ]"
        $IISRule80 = New-AzureRmLoadBalancerRuleConfig -Name $LBRuleNameIIS1 -FrontendIPConfiguration $frontend -BackendAddressPool $backendAddressPool -Probe $probe80 -Protocol "Tcp" -FrontendPort 80 -BackendPort 80 -IdleTimeoutInMinutes 4 
        
        write-verbose -Verbose -Message "Creating Load Balancer Rule [ $LBRuleNameIIS2 ]"
        $IISRule443 = New-AzureRmLoadBalancerRuleConfig -Name $LBRuleNameIIS2 -FrontendIPConfiguration $frontend -BackendAddressPool $backendAddressPool -Probe $probe443 -Protocol "Tcp" -FrontendPort 443 -BackendPort 443 -IdleTimeoutInMinutes 4 
        $RDPRule3389TCP = New-AzureRmLoadBalancerRuleConfig -Name $LBRuleNameRDPTCP -FrontendIPConfiguration $frontend -BackendAddressPool $backendAddressPool -Probe $probe -Protocol "Tcp" -FrontendPort 3389 -BackendPort 3389 -IdleTimeoutInMinutes 4
        $RDPRule3389UDP = New-AzureRmLoadBalancerRuleConfig -Name $LBRuleNameRDPUDP -FrontendIPConfiguration $frontend -BackendAddressPool $backendAddressPool -Probe $probe -Protocol "UDP" -FrontendPort 3389 -BackendPort 3389 -IdleTimeoutInMinutes 4
        
        $lbrule=$IISRule80,$IISRule443
        write-verbose -Verbose -Message "Creating Load Balancer [ $LbName ]"
      
$lb = New-AzureRmLoadBalancer -Name $LBName -ResourceGroupName $ResourceGroupName -Location $Location -FrontendIpConfiguration $frontend -BackendAddressPool $backendAddressPool -Probe $probe80,$probe443 -InboundNatRule $inboundNATRuleIISTCP -LoadBalancingRule $lbrule -Force

    }
    default {
        throw "Role $role not found! Choose any of the given roles - SQLAO, IISAO"
    }
}
#write-verbose -Verbose -Message "Creating Load Balancer Rule [ $LbRuleName ]"
#$lbrule = New-AzureRmLoadBalancerRuleConfig -Name $LBRuleName -FrontendIPConfiguration $frontend -BackendAddressPool $backendAddressPool -Probe $probe -Protocol "Tcp" -FrontendPort 1433 -BackendPort 1433 -IdleTimeoutInMinutes 4 -EnableFloatingIP 


$LB = Get-AzureRmLoadBalancer -Name $LBName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue

Write-Verbose -Verbose -message "[ $LBName ] IP Address is [ $($LB.FrontendIpConfigurations.PrivateIPAddress) ]"

Foreach ($Server in $Servers){
Write-Verbose -verbose -message "Adding [ $Server ] to Azure LBBEPool [ $LBBEPOOLNAME ]" 
$Nic = Get-AzureRmNetworkInterface -ResourceGroupName $ResourceGroupName | where {$_.name  -like "*${Server}*"}  
$Nic.IpConfigurations[0].LoadBalancerBackendAddressPools=$BackendAddressPool
$NIC = Set-AzureRmNetworkInterface -NetworkInterface $Nic
IF($NIC.IpConfigurations.LoadBalancerBackendAddressPools.id -like "*$LBBEpoolName"){ Write-Verbose -Verbose -Message "[ $Server ] has been added to [ $LBBEpoolName ]" }
}

$ClusterNic = New-AzureRmNetworkInterface `
						-Force `
						-Name "${Listener}CN" `
						-ResourceGroupName $ResourceGroupName `
						-Location $LOCATION `
						-SubnetId $subnetId

$ClusterNic = Get-AzureRmNetworkInterface -Name "${Listener}CN" -ResourceGroupName $ResourceGroupName

New-Object psobject -Property @{
    LBName = $LBName
    LBAddress = $LB.FrontendIpConfigurations.PrivateIPAddress
    ClusterIP = $ClusterNic.IpConfigurations.PrivateIPAddress
    }

Write-Verbose -Verbose -message "ILB creation Complete, Moving on to Failover cluster creation"