Param(
 [Parameter(Mandatory=$true)]$domain
,[Parameter(Mandatory=$true)]$ResourceGroupName
,[Parameter(Mandatory=$true)]$AvailabilitySetName
,[Parameter(Mandatory=$true)]$SubscriptionID
,[Parameter(Mandatory=$true)]$Listener
,[Parameter(Mandatory=$true)]$Cluster
,[Parameter(Mandatory=$true)]$FQDN
,[Parameter(Mandatory=$true)]$ou
,[Parameter(Mandatory=$true)]$AvailabilityGroup
,[Parameter(Mandatory=$true)]$domainuser
,[Parameter(Mandatory=$true)]$domainpassword
,[Parameter(Mandatory=$true)]$vnet
,[Parameter(Mandatory=$true)]$location
,[Parameter(Mandatory=$true)]$subnetid
,[Parameter(Mandatory=$true)]$role
,[Parameter(Mandatory=$true)]$skus
,[Parameter(Mandatory=$true)][string]$quorumkey
,[Parameter(Mandatory=$true)]$CloudwitnessStorageKey
,[Parameter(Mandatory=$true)]$QuorumShare
)

            if($role -like 'sqla*'){$role = "SQLAO"} 
            if($role -like 'iisa*'){$role = "IISAO"}

$LocalPath = $MyInvocation.Mycommand.Path
$scriptpath = Split-Path -Parent $localpath

[regex]$regex2 = "(\b[A-z]?\w+[^/]+$)"

If($role -eq "IISAO"){
$i = 0
Do {$loadbalancer = & $scriptpath\New-ARMLoadBalancer.ps1 `
-ResourceGroupName $ResourceGroupName `
-AvailabilitySetName $AvailabilitySetName `
-Listener $Listener `
-vnet $vnet `
-subnetid $subnetid `
-location $location `
-role $role 
$i++
    }#do
    until($? -or $i -eq 5)
    if ($i -eq 5){
    throw "Unable to configure, please investigate loadbalancer"
    }#if
    }#if


Elseif($role -eq "SQLAO"){
$i = 0
Do {$loadbalancer = & $scriptpath\New-ARMLoadBalancer.ps1 `
-ResourceGroupName $ResourceGroupName `
-AvailabilitySetName $AvailabilitySetName `
-Listener $Listener `
-vnet $vnet `
-subnetid $subnetid `
-location $location `
-role $role
$i++
    }#do
    until($? -or $i -eq 5)
    if ($i -eq 5){
    throw "Unable to configure, please investigate loadbalancer"
    }#if


$nodes = @()
get-AzureRmAvailabilitySet -ResourceGroupName $ResourceGroupName -Name $AvailabilitySetName | select -ExpandProperty VirtualMachinesReferences | select -ExpandProperty id | % {$_ -match $REgex2; $nodes += $Matches[0]}


$i = 0
Do {& $scriptpath\New-ARM_FailoverCluster_V3.ps1 `
-Domain $Domain `
-Nodes $Nodes `
-Listener $Listener `
-Cluster $Cluster `
-ClusterIP $loadbalancer.clusterip `
-FQDN $FQDN `
-DomainUser $domainuser `
-DomainPassword $domainpassword `
-OU $ou `
-skus $skus `
-quorumkey $quorumkey `
-CloudwitnessStorageKey $CloudwitnessStorageKey `
-QuorumShare $QuorumShare `
-ErrorAction Stop
$i++
}#do
    until($? -or $i -eq 5)
    if ($i -eq 5){
    throw "Unable to configure, Please Investigate Failover Cluster"
    }#if
    
sleep 600

$i = 0
Do {& $scriptpath\Deploy-ARM_AOSQL.ps1 `
-Nodes $Nodes `
-AvailabilityGroup $AvailabilityGroup `
-Listener $Listener `
-ILBIP $loadbalancer.lbaddress
$i++
}#do
    until($? -or $i -eq 5)
    if ($i -eq 5){
    throw "Unable to configure, please Investigate Failover Cluster and Always On configureations"
    }#if
    
    }#elseif

Write-Verbose -Verbose -message "SQL AO Complete for [ $cluster ]!  Please set up DB Maintenence Plans"