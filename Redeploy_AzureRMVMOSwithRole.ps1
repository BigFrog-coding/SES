##### Must Capitalize the VM names except for the scale letter #####

$VMname = 'SESUW2-SQL28a'
$VMnamenew = 'SESUW2-SQL28a'   #make the same as old for now, this is still in progress.
$ResourceGroupName = 'SESUW2-SQL28RG'
$DiskCount = '16'
$SubscriptionID = 'f7e0da06-1ea5-403b-a622-e862d7683833'
$osDiskCaching = 'ReadWrite'
$datadiskCaching = 'None'
$AvailabilitySetName = 'SESUW2-SQL28AS'
$vmsIZE = 'Standard_D13_v2'
$CloudPassword = 'CloudMade-0-0'
$role = 'sql'
$user = 'ghost'
$password = 'Sp00ky$keletons'
$KeyVaultSubID = '60306e6e-35b5-40b4-952b-e608f780496c'
$DomainUser = 'wdgses'
$FQDN = 'redmond.corp.microsoft.com'
$OU = 'OU=WDGSESRE,OU=Support,OU=OSG,OU=Labs,DC=redmond,DC=corp,DC=microsoft,DC=com'
$Function = 'Edge Code Coverage' #Pull from inventory
$FriendlyName = ''  #Listerner name for SQLAO or friendly IIS name, this can be null
$AssignedTo = 'mustjab; clmartin' #Pull from inventory
$Note = ''  #Pull from inventory, this can be null
$ServiceName = 'IE Code Coverage (CC)'  #Pull from inventory
$Environment = 'prod'  #Can determine based on VM name
$administrators = 'redmond\v-rogerb'  #Pull from inventory
$Skus = 'SQL2016SP1-WS2016'


if($role -like 'sql*'){$role = "SQL"} 
            if($role -like 'iis*'){$role = "IIS"}
            if($role -like 'app*'){$role = "APP"}

$domainusername = $DomainUser

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

##Get Secrets Section
#Select Azure Subscription
Select-AzureRmSubscription -SubscriptionId $KeyVaultSubID
#Get Secrets
[string]$domainpassword = Get-AzureKeyVaultSecret -VaultName SESKEY -Name  $domainusername | Select -ExpandProperty SecretValueText
[string]$LAPW = Get-AzureKeyVaultSecret -VaultName SESKEY -Name $user | Select -ExpandProperty SecretValueText
[string]$QuorumKey = Get-AzureKeyVaultSecret -VaultName SESKEY -Name QuorumKey | Select -ExpandProperty SecretValueText
[string]$Scriptstoragekey = Get-AzureKeyVaultSecret -VaultName SESKEY -Name scriptkey | Select -ExpandProperty SecretValueText
	        
$InventoryPassword = $domainpassword

#gather Azure variables
Write-Verbose -Verbose -Message "Setting Azure subscription"
$Subscription = (Select-AzureRmSubscription -SubscriptionID $SubscriptionID).Subscription
$VNET = Get-AzureRmVirtualNetwork | ?{$_.ResourceGroupName -eq 'ERNetwork' -or $_.ResourceGroupName -like 'Hypernet*'}
		
#Setting Location for VM and Subnet ID for IP
$Location = $Vnet.location
[string]$subnetId = $vnet[1].Subnets.Id | select -First 1

#remove VM leaving disks intact
Write-Verbose -Verbose -Message "Removing VM from Azure"
Remove-AzureRmVM -Name $vmname -ResourceGroupName $ResourceGroupName -Force


#redeploy VM

IF($Role -eq 'SQL'){
	        $PublisherName = 'MicrosoftSQLServer'
	        $Offer = $Skus
            $Sku = 'enterprise'
                 Switch ($SKUS){
                 {$_ -like '*WS2012*'} { $SXS = "Server2012-R2-Datacentersxs.zip" ; $DPM = "DPMAgentInstaller_KB3112306_AMD64.exe"  }
                 {$_ -like '*WS2016*'} { $SXS = "Server2016-Datacentersxs.zip" ; $DPM = "DPMAgentInstaller_x64.exe" }
                 }

			#Getting the most recent OS image
			$AzureImage = (Get-AzureRmVMImage -Location $Location `
								-PublisherName $PublisherName `
								-Offer $offer `
								-Skus $Sku `
                                -ErrorAction Stop ) | sort version | select -Last 1
         
            }#if
            Else{ 
            $PublisherName = 'microsoftwindowsserver'
	        $Offer = 'WindowsServer'
            

			#Getting the most recent OS image
			$AzureImage = (Get-AzureRmVMImage -Location $Location `
								-PublisherName $PublisherName `
								-Offer $offer `
								-Skus $skus `
                                -ErrorAction Stop ) | sort version | select -Last 1
                                  
                                  Switch ($SKUS){
                                    {$_ -like '2012*'} { $SXS = "Server2012-R2-Datacentersxs.zip" ; $DPM = "DPMAgentInstaller_KB3112306_AMD64.exe"  }
                                    {$_ -like '2016*'} { $SXS = "Server2016-Datacentersxs.zip" ; $DPM = "DPMAgentInstaller_x64.exe" }
                                   }

            }#Else

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
Write-Verbose -Verbose -Message "Creating and attaching OS Disk"
			$osDiskName = "${vmname}_osnew"
			$osDiskCaching = 'ReadWrite'
			$osDiskVhdUri = "https://$StorageAccountName.blob.core.windows.net/vhds/$osDiskName.vhd"
			# Setup OS & Image

			$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
			$cred = New-Object System.Management.Automation.PSCredential ($user, $securePassword)
 
			Write-Verbose -Verbose -Message "Setting Template OS to Windows"

			$vm = Set-AzureRmVMOperatingSystem `
						-VM $vm `
						-Windows `
						-ComputerName $vmname `
						-Credential $cred

			Write-Verbose -Verbose -Message "Selecting OS [ $($AzureImage.Skus) ], Image Version [ $($AzureImage.Version) ]"

			$vm = Set-AzureRmVMSourceImage `
						-VM $vm `
						-PublisherName $AzureImage.PublisherName `
						-Offer $AzureImage.Offer `
						-Skus $AzureImage.Skus `
						-Version $AzureImage.Version

			$vm = Set-AzureRmVMOSDisk -VM $vm -VhdUri $osDiskVhdUri -name $osDiskName -CreateOption fromImage -Caching $osDiskCaching

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


### Post Config Settings Section ###            
            
            $StorageAccountName = "sesscripts"
			$Key = $ScriptstorageKey 
			$ExtensionName = 'PostConfig'
			$TypeHandlerVersion = '1.8'
            
            #Edit this to change the files and commands run on the deployed VM
			$CommandToRun = "postconfigforredeploy.ps1  -Role $Role -Function `"$Function`" -SXS $SXS -FriendlyName $FriendlyName -SQLUser $User -SQLPWD $Password -AssignedTO $AssignedTo -Note $Note -ServiceName `"$ServiceName`" -Environment $Environment -Location $Location -domain $FQDN -administrators $administrators -InventoryPassword $InventoryPassword"
            
            #-Role $Role -Function $Function -SXS $SXS -FriendlyName $FriendlyName -SQLUser $SQLUSER -SQLPWD $SQLPWD -AssignedTO $AssignedTo -Note $Note -ServiceName $ServiceName -Environment $Environment -Location $Location
            
                   
            Switch ($Role){

            SQL {
                $FilesTodownload = "postconfigforredeploy.ps1", "configure${_}.ps1", "$SXS", "$DPM", "Microsoft.SharePoint.Client.Runtime.dll", "Microsoft.SharePoint.Client.dll" ,"MOMAgent.msi" ,"SCEPInstall.exe" ,"Set-InventoryRegStamp.ps1", "Machine2Inventory.ps1"
                                #Edit this to change the files and commands run on the deployed VM
			    $CommandToRun = "postconfigforredeploy.ps1  -Role $_ -Function `"$Function`" -SXS $SXS -SQLUser $User -SQLPWD $Password -AssignedTO $AssignedTo -Note `"$Note`" -ServiceName `"$ServiceName`" -Environment $Environment -Location $Location -domain $FQDN -administrators $administrators -InventoryPassword $InventoryPassword"
                
                }
            IIS { 
            $FilesTodownload =  "postconfigforredeploy.ps1", "configure${_}.ps1", "$SXS", "$DPM", "Microsoft.SharePoint.Client.Runtime.dll", "Microsoft.SharePoint.Client.dll" ,"MOMAgent.msi" ,"SCEPInstall.exe" ,"Set-InventoryRegStamp.ps1" ,"WebDeploy_amd64_en-US.msi", "Machine2Inventory.ps1" # ,"SES DAILY DIFF.dtsx" ,"SES WEEKLY FULL.dtsx" , "SES TRN MAINTENANCE.dtsx"
                  $CommandToRun = "postconfigforredeploy.ps1  -Role $_ -FriendlyName $FriendlyName -Function `"$Function`" -SXS $SXS -AssignedTO $AssignedTo -Note `"$Note`" -ServiceName `"$ServiceName`" -Environment $Environment -Location $Location -domain $FQDN -administrators $administrators -InventoryPassword $InventoryPassword"
                }
            APP {
                  $FilesTodownload = "postconfigforredeploy.ps1", "configure${_}.ps1", "$SXS", "$DPM", "Microsoft.SharePoint.Client.Runtime.dll", "Microsoft.SharePoint.Client.dll" ,"MOMAgent.msi" ,"SCEPInstall.exe" ,"Set-InventoryRegStamp.ps1", "Machine2Inventory.ps1" #,"WebDeploy_amd64_en-US.msi" # ,"SES DAILY DIFF.dtsx" ,"SES WEEKLY FULL.dtsx" , "SES TRN MAINTENANCE.dtsx"
                  $CommandToRun = "postconfigforredeploy.ps1  -Role $_ -Function `"$Function`" -SXS $SXS -AssignedTO $AssignedTo -Note `"$Note`" -ServiceName `"$ServiceName`" -Environment $Environment -Location $Location -domain $FQDN -administrators $administrators -InventoryPassword $InventoryPassword"

            }
         }#end switch
         Write-Verbose -Verbose -Message "Performing additional configurations depending on the role selected. If a failure occurs, check the Azure deployment logs at 'C:\WindowsAzure\Logs\Plugins\Microsoft.Compute.CustomScriptExtension\1.8' for general logs. 'C:\Packages\Plugins\Microsoft.Compute.JsonADDomainExtension\1.0\Status\0.status', or C:\Windows\debug for Domain Join Errors. 'C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.8\Status\0.status' for postconfig errors on the VM."

         date -DisplayHint DateTime | select -ExpandProperty datetime
         Write-Verbose -Verbose -Message "Performing Domain Join on [ $FQDN ]"

			#DOMAIN JOIN
			$SettingString = @{
				Name = $FQDN
				User = $DomainUser
				OUPATH = $OU
				Restart = $true
				Options = 1
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
       
			
            #List of files to download to the VM FIX THIS!
			#$FilesTodownload = "storage.ps1", "postconfig.ps1", "configure${Role}.ps1", "$SXS", "Machine2Inventory.ps1", "$DPM", "Microsoft.SharePoint.Client.Runtime.dll", "Microsoft.SharePoint.Client.dll" ,"MOMAgent.msi" ,"SCEPInstall.exe" ,"Set-InventoryRegStamp.ps1","WebDeploy_amd64_en-US.msi" # ,"SES DAILY DIFF.dtsx" ,"SES WEEKLY FULL.dtsx" , "SES TRN MAINTENANCE.dtsx"
            #FOR PROD BLOB			
              $ContainerName = "prod"
              date -DisplayHint DateTime | select -ExpandProperty datetime
                  #$Test = Invoke-Command "$VMNAME.$FQDN" {Hostname}
                  Write-verbose -Verbose -Message "Starting Post Config now"
                      #IF($TEst){$i=0
                      #do{
                      try{	$PostConfig = Set-AzureRmVMCustomScriptExtension `
                            -ResourceGroupName $ResourceGroupName `
							-Location $Location `
							-VMName $VMName `
							-Name $ExtensionName `
							-TypeHandlerVersion $TypeHandlerVersion `
							-StorageAccountName $StorageAccountName `
							-StorageAccountKey $ScriptstorageKey `
							-FileName $FilesTodownload `
							-Run $CommandToRun `
							-ContainerName $ContainerName `
                            -SecureExecution `
                            -ErrorAction Stop
                           }#try
                           Catch{
                           $_
                           }#catch
                           finally{ 
                           if($postconfig){Write-verbose -Verbose -Message "Post Congfiguration Completed Successfully!"}
                           }