# Must run as user with OU rights #

Param(
[Parameter(Mandatory=$true)]$CSVpath = "\\redmond\coreops\SES\Logs\AzureDeploymentLogs\CSV\splunkexpand.csv"
,[Parameter(Mandatory=$true)]$CloudPassWord = ''
,[Parameter(Mandatory=$true)]$domainusername = 'wdgses'
,[Parameter(Mandatory=$true)]$user
,[Parameter(Mandatory=$true)]$KeyVaultSubID
,[Parameter(Mandatory=$true)]$QuorumShare
,[Parameter(Mandatory=$true)]$TranscriptShare
,[Parameter(Mandatory=$true)]$NUAUserName
,[Parameter(Mandatory=$true)]$NUATenant
#,[Parameter(Mandatory=$true)]$DPMbitshare = '\\sesred-dpmb5006\agents\RA\4.2.1417.0\amd64\1033\'
)

Begin {
$LocalPath = $MyInvocation.Mycommand.Path
$scriptpath = Split-Path -Parent $localpath
#$startprocesstime = date -DisplayHint DateTime -Format g
date -DisplayHint DateTime
$GUID = (New-Guid).guid
Start-Transcript -Path "$TranscriptShare\${GUID}.txt" -Append
$csv = Import-Csv -Path $csvpath
}

process {
Write-Verbose -Verbose -Message "WDGSES AZURE RM VM Deployment tool V4.20"

#Runs Azure interactions with NUA Azure Cloud Account
Try { 

$SecurePassword = $CloudPassword | ConvertTo-SecureString -AsPlainText -Force

$creds = New-Object System.Management.Automation.PSCredential `
      -ArgumentList $NUAUserName, $SecurePassword 


Add-AzureRmAccount -Credential $creds -ServicePrincipal -TenantId $NUAtenant
    
    }#Try

catch{ 
    IF ($_.exception.message -eq "Run Login-AzureRmAccount to login."){
        
        Login-AzureRmAccount 
        
        }
        
        Else {

        Throw $_.exception.message
        
        }
        }#Catch
        
##Get Secrets Section
#Select Azure Subscription
Select-AzureRmSubscription -SubscriptionId $KeyVaultSubID
#Get Secrets
[string]$domainpassword = Get-AzureKeyVaultSecret -VaultName SESKEY -Name  $domainusername | Select -ExpandProperty SecretValueText
[string]$LAPW = Get-AzureKeyVaultSecret -VaultName SESKEY -Name $user | Select -ExpandProperty SecretValueText
[string]$QuorumKey = Get-AzureKeyVaultSecret -VaultName SESKEY -Name QuorumKey | Select -ExpandProperty SecretValueText
[string]$Scriptstoragekey = Get-AzureKeyVaultSecret -VaultName SESKEY -Name scriptkey | Select -ExpandProperty SecretValueText
[string]$CloudwitnessStorageKey = Get-AzureKeyVaultSecret -VaultName SESKEY -Name CloudwitnessStorageKey | Select -ExpandProperty SecretValueText

#$CurrentDPMbits = Get-Childitem -Path $DPMbitshare | select -First 1 | select -ExpandProperty name

Write-Verbose -Verbose -Message "Verifying CSV Data"
	$Status=@()

Write-Verbose -Verbose -Message "Gathering Variables"
$Group = $CSV | Where-Object {$_.vmname -ne ''} | Group-Object -Property SubscriptionID

Write-Verbose -Verbose -Message "Setting Subscription per group object and deploying servers"
Foreach ($G in $Group) {

		#Setting the subscription
	    [string]$SubscriptionID = $g.group.SubscriptionID -replace " ","" | select -First 1
 		Write-Verbose -verbose -message "There are [ $($g.vmname.Count) ] Servers in this deployment"
		Write-Verbose -verbose -message "Checking for Subscription..."

		$Subscription = (Select-AzureRmSubscription -SubscriptionID $SubscriptionID).Subscription

		#Select Location by vnet location
		If ($Subscription.SubscriptionId -ne $SubscriptionID) {
                Throw "Subscription not found, please investigate!"
		}#IF
	
		Else {
			Write-Verbose -verbose -message "Subscription [ $($Subscription.SubscriptionName) ] found"

			$VNET = Get-AzureRmVirtualNetwork | ?{$_.ResourceGroupName -eq 'ERNetwork' -or $_.ResourceGroupName -like 'Hypernet*'}
		
			#Setting Location for VM and Subnet ID for IP
			[string]$Location = $Vnet.location | select -First 1
			[string]$subnetId = $vnet.Subnets.Id | select -First 1
    
			write-verbose -Verbose -Message "Using ER [ $($Vnet.Name) ] in [ $Location ]" 
		}#ELSE

#Determine if there is enough cores to deploy the servers in the CSV.
if($g.instancesize -like 'Standard_A*'){
$deploymentcoretotal = $csv.cores | Measure-Object -Sum | select -ExpandProperty sum
$subusage = Get-AzureRmVMUsage -location $Location
$CoresavailableA = $subusage | select -skip 7 | select -First 1 | select -ExpandProperty limit
$CoresusedA = $subusage | select -skip 7 | select -First 1 | select -ExpandProperty currentvalue
$coresremaining = +$CoresavailableA - +$CoresusedA
}
elseif($g.instancesize -like 'Standard_DS*_V2'){
$deploymentcoretotal = $csv.cores | Measure-Object -Sum | select -ExpandProperty sum
$subusage = Get-AzureRmVMUsage -location $Location
$CoresavailableDS_V2 = $subusage | select -skip 4 | select -First 1 | select -ExpandProperty limit
$CoresusedDS_V2 = $subusage | select -skip 4 | select -First 1 | select -ExpandProperty currentvalue
$coresremaining = +$CoresavailableDS_V2 - +$CoresusedDS_V2
}
elseif($g.instancesize -like 'Standard_D*_V2'){
$deploymentcoretotal = $csv.cores | Measure-Object -Sum | select -ExpandProperty sum
$subusage = Get-AzureRmVMUsage -location $Location
$CoresavailableD_V2 = $subusage | select -skip 5 | select -First 1 | select -ExpandProperty limit
$CoresusedD_V2 = $subusage | select -skip 5 | select -First 1 | select -ExpandProperty currentvalue
$coresremaining = +$CoresavailableD_V2 - +$CoresusedD_V2
}
elseif($g.instancesize -like 'Standard_GS*'){
$deploymentcoretotal = $csv.cores | Measure-Object -Sum | select -ExpandProperty sum
$subusage = Get-AzureRmVMUsage -location $Location
$CoresavailableGS = $subusage | select -skip 12 | select -First 1 | select -ExpandProperty limit
$CoresusedGS = $subusage | select -skip 12 | select -First 1 | select -ExpandProperty currentvalue
$coresremaining = +$CoresavailableGS - +$CoresusedGS
}
elseif($g.instancesize -like 'Standard_G*'){
$deploymentcoretotal = $csv.cores | Measure-Object -Sum | select -ExpandProperty sum
$subusage = Get-AzureRmVMUsage -location $Location
$CoresavailableG = $subusage | select -skip 10 | select -First 1 | select -ExpandProperty limit
$CoresusedG = $subusage | select -skip 10 | select -First 1 | select -ExpandProperty currentvalue
$coresremaining = +$CoresavailableG - +$CoresusedG
}

$subusage = Get-AzureRmVMUsage -location $Location
$Gencoresavail = $subusage | select -skip 1 | select -First 1 | select -ExpandProperty limit
$Gencoresused = $subusage | select -skip 10 | select -First 1 | select -ExpandProperty currentvalue
$Gencoresremaining = +$gencoresavail - +$gencoresused

If($deploymentcoretotal -gt $CoresRemaining -xor $deploymentcoretotal -gt $Gencoresremaining){
Write-Warning -Message "Not enough Cores in Subscription!  Please get core count increase and try again!"
} #If

Else{
Write-Verbose -Verbose -Message "There are enough cores available, proceeding with deployment"

$Group2 = $CSV | Where-Object {$_.vmname -ne ''} | Group-Object -Property ResourceGroupName

Foreach ($G2 in $group2.Group) {

        #Creating recovery vault for resource group
            $vaultname = "${ResourceGroupName}RecoveryVault"
            $vault = Get-AzureRmRecoveryServicesVault –Name $vaultname
            If ($vault) {
				Write-Verbose -verbose -message "Recovery Vault ${vaultname} found"    
			}#IF
			Else{
				Write-Verbose -verbose -message "Creating Recovery Vault ${vaultname}"
                 
                New-AzureRmRecoveryServicesVault -Name $vaultname `
                                                    -ResourceGroupName $ResourceGroupName `
                                                    -Location $Location
			}#ELSE


            $vault1 = Get-AzureRmRecoveryServicesVault –Name $vaultname	
            Set-AzureRmRecoveryServicesBackupProperties  -Vault $vault1 -BackupStorageRedundancy GeoRedundant		
            Get-AzureRmRecoveryServicesVault -Name $vaultname | Set-AzureRmRecoveryServicesVaultContext

            #Creating New Policy
            $schPol = Get-AzureRmRecoveryServicesBackupSchedulePolicyObject -WorkloadType "AzureVM"
            $retPol = Get-AzureRmRecoveryServicesBackupRetentionPolicyObject -WorkloadType "AzureVM"
            New-AzureRmRecoveryServicesBackupProtectionPolicy -Name "StandardPolicy" -WorkloadType AzureVM -RetentionPolicy $retPol -SchedulePolicy $schPol


Foreach ($Server in $G2.Group) {
            #These are paramaters
            [regex]$regex1 = "^\w+"
            [String]$ServiceName = $Server.ServiceName
            [String]$Environment = $Server.Environment
			[String]$InstanceSize = $Server.InstanceSize.trim()
			[String]$VMNAME = $Server.VMName.trim()
			[STRING]$SKUS = $Server.OFFER.trim()
			[STRING]$ROLE = $Server.Role.trim()
            [STRING]$Function = $Server.Function
            [STRING]$FriendlyName = $Server.Listener
            [STRING]$AssignedTo = $Server.AssignedTo
            [String]$Note = $Server.Note
            [string]$Storage = [System.Int32]$Server.StorageGB * 1024 * 1024 * 1024
            [String]$Administrators = $Server.Administrators
            [STRING]$Server.Domain -match $REgex1|Out-Null;[STRING]$Domain = $Matches[0] #= 'Redmond'
            [STRING]$FQDN = $Server.Domain #= "redmond.corp.microsoft.com",
            [STRING]$Listener = $Server.Listener #= "SESUW2-TSSQL1",
            [STRING]$Cluster = $Server.clustername #= 'SESUW2-TSSQL1CN'
            [STRING]$ResourceGroupName = $Server.ResourceGroupName #= '
            [STRING]$AvailabilitySetName = $Server.AvailabilitySetName #= '
            [STRING]$AvailabilityGroup = $Server.AvailabilityGroup #= '
            [STRING]$OU = $Server.OU
            [STRING]$domainuser = "${domain}\$domainusername"

& $scriptpath\new-rmvm_V2.ps1 `
-InventoryPassword $domainpassword `
-DomainPassword $domainpassword `
-domainuser $domainuser `
-user $user `
-password $LAPW `
-InstanceSize $InstanceSize `
-vmname $vmname `
-ResourceGroupName $ResourceGroupName `
-Location $Location `
-note $note `
-FQDN $FQDN `
-SKUS $SKUS `
-VNET $VNET `
-role $role `
-Administrators $Administrators `
-FriendlyName $FriendlyName `
-AssignedTo $AssignedTo `
-ServiceName $ServiceName `
-Environment $Environment `
-Storage $Storage `
-ScriptStoragekey $Scriptstoragekey `
-ErrorAction SilentlyContinue #-CurrentDPMBits $CurrentDPMbits `


}#foreach server

	[STRING]$ROLE = $group2.group.Role.trim() | select -first 1


Write-Verbose -Verbose -Message " Starting AO configurations "
& $scriptpath\Azure-ARM_AO_Runner.ps1 `
-domain $domain `
-ResourceGroupName $ResourceGroupName `
-AvailabilitySetName $AvailabilitySetName `
-SubscriptionID $SubscriptionID `
-Listener $Listener `
-Cluster $Cluster `
-FQDN $FQDN `
-ou $ou `
-AvailabilityGroup $AvailabilityGroup `
-vnet $vnet `
-subnetid $subnetid `
-role $role `
-location $location `
-domainuser $domainuser `
-domainpassword $domainpassword `
-skus $skus `
-QuorumShare $QuorumShare `
-quorumkey $QuorumKey `
-CloudwitnessStorageKey $CloudwitnessStorageKey `
-ErrorAction SilentlyContinue

}#foreach group2
}#foreach group

}#process
}#else


End {
   Write-Verbose -Verbose -Message "Deployment Complete"
   $Status | Fl
 #  $endprocesstime = date -DisplayHint DateTime -Format g
 date -DisplayHint DateTime
   Stop-Transcript
  # $Processtimetotal = $endprocesstime - $startprocesstime
   #
}