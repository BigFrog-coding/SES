$VMNAMEs = gc 'C:\Users\wdgses\Desktop\server list.txt'
$location = "West US"

foreach($VMNAME in $VMNAMEs){
IF($vmname -notcontains "b"){$ResourceGroupName = ($VMNAME -replace "A",'RG')}
#else{$ResourceGroupName = ($VMNAME -replace "B",'RG')}

Set-AzureRmVMSqlServerExtension -ResourceGroupName $ResourceGroupName -VMName $VMNAME -Name "SQLIaasExtension" -Version "1.2" -Location $Location


Get-AzureRmVMSqlServerExtension -VMName $VMNAME -ResourceGroupName $ResourceGroupName

}

$SubscriptionID = 'e31a1ede-eac1-45ec-bffd-8459f00728f6'

$Subscription = (Select-AzureRmSubscription -SubscriptionID $SubscriptionID).Subscription

Install-module AzureRM