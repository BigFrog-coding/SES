##### Must Capitalize the VM names except for the scale letter #####

$VMname = 'SESUW2-SQL28a'
$VMnamenew = 'SESUW2-SQL28a'
$ResourceGroupName = 'SESUW2-SQL28RG'
$DiskCount = '16'
$SubscriptionID = 'f7e0da06-1ea5-403b-a622-e862d7683833'
$osDiskName = "${vmname}_osDisk"
$osDiskCaching = 'ReadWrite'
$datadiskCaching = 'None'
$AvailabilitySetName = 'SESUW2-SQL28AS'
$vmsIZE = 'Standard_D13_v2'
$CloudPassword = 'CloudMade-0-0'


Try { 


$SecurePassword = $PlainPassword | ConvertTo-SecureString -AsPlainText -Force

$UserName = "d2f52bd8-bc65-4b16-8054-4b7edca81533"
$creds = New-Object System.Management.Automation.PSCredential `
      -ArgumentList $UserName, $SecurePassword 


$tenant = '72f988bf-86f1-41af-91ab-2d7cd011db47'

Add-AzureRmAccount -Credential $creds -ServicePrincipal -TenantId $tenant
    
    }#Try

catch{ 
    IF ($_.exception.message -eq "Run Login-AzureRmAccount to login."){
        
        Login-AzureRmAccount 
        
        }
        
        Else {

        Throw $_.exception.message
        
        }
        }#Catch
        

#gather Azure variables
Write-Verbose -Verbose -Message "Setting Azure subscription"
$Subscription = (Select-AzureRmSubscription -SubscriptionID $SubscriptionID).Subscription
$VNET = Get-AzureRmVirtualNetwork | ?{$_.ResourceGroupName -eq 'ERNetwork' -or $_.ResourceGroupName -like 'Hypernet*'}
		
#Setting Location for VM and Subnet ID for IP
$Location = $Vnet.location
#use if need new VNET			[string]$subnetId = $vnet[1].Subnets.Id | select -First 1

#remove VM leaving disks intact
Write-Verbose -Verbose -Message "Removing VM from Azure"
Remove-AzureRmVM -Name $vmname -ResourceGroupName $ResourceGroupName -Force


#redeploy VM
$StorageAccountName = ($VMNAME.ToLower() -replace "-",'')
$AvailabilitySet = get-AzureRmAvailabilitySet -ResourceGroupName $ResourceGroupName -Name $AvailabilitySetName
$VM = New-AzureRmVMConfig `
	-VMName $VMNAMEnew `
	-VMSize $VMSIZE `
	-AvailabilitySetId $AvailabilitySet.ID

#get nic and add to template
Write-Verbose -Verbose -Message "gathering details for VM template"
$nic = GET-AzureRmNetworkInterface -Name "${vmname}"  -ResourceGroupName $ResourceGroupName #-Location $location -SubnetId $subnetid
$vm = Add-AzureRmVMNetworkInterface -VM $vm -Id $nic.Id

#set template options for OS disk
Write-Verbose -Verbose -Message "Setting Template OS to Windows"

$VM = set-azurermvmosdisk -Name $osDiskName -VhdUri "https://$StorageAccountName.blob.core.windows.net/vhds/$osdiskname.vhd" -Caching $osDiskCaching -CreateOption Attach -Windows -vm $vm

# Create Virtual Machine
#attaching data disks
Write-Verbose -Verbose -Message "Attaching [ $DiskCount ] Data Disks to VM template ."
			for ($i = 0; $i -lt $DiskCount; $i++){ 

				$Name = "${VMNAME}DataDisk${I}"
				$Disk = Add-AzureRmVMDataDisk `
						-VM $VM `
						-Name $Name `
						-VhdUri "https://$StorageAccountName.blob.core.windows.net/vhds/$Name.vhd" `
						-Caching $datadiskCaching `
						-DiskSizeInGB 1023 `
						-Lun ($I) `
						-CreateOption attach `
						-Verbose

			}

Write-Verbose -Verbose -Message "Creating Virtual Machine [ $VMNamenew ]"

$VM = New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $Location -VM $VM 
#$Vm = Get-AzureRmVM -ResourceGroupName $ResourceGroup -Name $VMNAME -ErrorAction SilentlyContinue 

#############################################################################################################################################
<#
$StorageAccountName = "sesscripts"
			$Key = $ScriptstorageKey 
			$ExtensionName = 'PostConfig'
			$TypeHandlerVersion = '1.8'

		#DOMAIN JOIN
			$SettingString = @{
				Name = $FQDN
				User = $DomainUser
				OUPATH = $OU
				Restart = $true
				Options = 3
			}

			$ProtectedSettings = @{ Password = $DomainPassword }

$Join = Set-AzureRmVMExtension `
-ResourceGroupName $ResourceGroupName `
-ExtensionType "JsonADDomainExtension" `
-Name "DomainJoin" `
-Publisher "Microsoft.Compute" `
-TypeHandlerVersion "1.0" `
-VMName $VMNAME `
-Location $Location `
-Settings $SettingString `
-ProtectedSettings $ProtectedSettings `
-ErrorAction SilentlyContinue
#>