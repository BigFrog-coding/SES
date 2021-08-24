Param(
 [Parameter(Mandatory=$true)]$InventoryPassword
,[Parameter(Mandatory=$true)]$DomainPassword
,[Parameter(Mandatory=$true)]$DomainUser
,[Parameter(Mandatory=$true)]$user
,[Parameter(Mandatory=$true)]$password
,[Parameter(Mandatory=$true)]$InstanceSize
,[Parameter(Mandatory=$true)]$vmname
,[Parameter(Mandatory=$true)]$ResourceGroupName
,[Parameter(Mandatory=$true)]$Location
,[Parameter(Mandatory=$true)]$note
,[Parameter(Mandatory=$true)]$FQDN
,[Parameter(Mandatory=$true)]$SKUS
,[Parameter(Mandatory=$true)]$VNET
,[Parameter(Mandatory=$true)]$role = 'Sql'
,[Parameter(Mandatory=$true)]$administrators
,[Parameter(Mandatory=$true)]$friendlyname
,[Parameter(Mandatory=$true)]$AssignedTo
,[Parameter(Mandatory=$true)]$ServiceName
,[Parameter(Mandatory=$true)]$Environment
,[Parameter(Mandatory=$true)]$Storage
,[Parameter(Mandatory=$true)]$ScriptStoragekey
#,[Parameter(Mandatory=$true)]$CurrentDPMBits
 )  

Begin {
            if($role -like 'sql*'){$role = "SQL"} 
            if($role -like 'iis*'){$role = "IIS"}
            if($role -like 'app*'){$role = "APP"}  

	$CONFIG=@{
		#These settings will allow for per instance conifigurations. The current disk count is minimum for max IOPS.
		Standard_D1_v2 = @{
			StorageType = "Standard_LRS"
			DiskCount = 2
		}
		Standard_D2_v2 = @{
			StorageType = "Standard_LRS"
			DiskCount = 4
		}
		Standard_D3_v2 = @{
			StorageType = "Standard_LRS"
			DiskCount = 8
		}
		Standard_D4_v2 = @{
			StorageType = "Standard_LRS"
			DiskCount = 16
		}
		Standard_D5_v2 = @{
			StorageType = "Standard_LRS"
			DiskCount = 32
		}
		Standard_D11_v2 = @{
			StorageType = "Standard_LRS"
			DiskCount = 4
		}
		Standard_D12_v2 = @{
			StorageType = "Standard_LRS"
			DiskCount = 8
		}
		Standard_D13_v2 = @{
			StorageType = "Standard_LRS"
			DiskCount = 16
		}
		Standard_D14_v2 = @{
			StorageType = "Standard_LRS"
			DiskCount = 32
		}
		Standard_D15_v2 = @{
			StorageType = "Standard_LRS"
			DiskCount = 40
		}
		Standard_DS1_v2 =@{
			StorageType = "Premium_LRS"
			DiskCount = 1
		}
		Standard_DS2_v2 =@{
			StorageType = "Premium_LRS"
			DiskCount = 2
		}
		Standard_DS3_v2 =@{
			StorageType = "Premium_LRS"
			DiskCount = 3
		}
		Standard_DS4_v2 =@{
			StorageType = "Premium_LRS"
			DiskCount = 6
		}
		Standard_DS5_v2 =@{
			StorageType = "Premium_LRS"
			DiskCount = 12
		}
		Standard_DS11_v2 =@{
			StorageType = "Premium_LRS"
			DiskCount = 2
		}
		Standard_DS12_v2 =@{
			StorageType = "Premium_LRS"
			DiskCount = 4
		}
		Standard_DS13_v2 =@{
			StorageType = "Premium_LRS"
			DiskCount = 6
		}
		Standard_DS14_v2 =@{
			StorageType = "Premium_LRS"
			DiskCount = 12
		}
		Standard_DS15_v2 =@{
			StorageType = "Premium_LRS"
			DiskCount = 21
		}
        Standard_GS5 =@{
			StorageType = "Premium_LRS"
			DiskCount = 16
		}
        Standard_A7 =@{
			StorageType = "Standard_LRS"
			DiskCount = 16
		}
      	Standard_F16 =@{
			StorageType = "Standard_LRS"
			DiskCount = 32
		}
        Standard_A8_V2 =@{
			StorageType = "Standard_LRS"
			DiskCount = 16
		}
	}


}

Process {
$Status=@()
# $Success=$False 
 #           While($Success -eq $False){

#Ensuring the Instance Size exists in the config Hash
			If($Config.keys -notcontains $InstanceSize) {
				Throw "Instance Size [ $InstanceSize ] is not supported at this time, please update the config settings in this script."
			}
	
			$StorageAccountName = ($VMNAME.ToLower() -replace "-",'')
    
    #Removal of old VM
        Write-Verbose -Verbose -Message "Remove VM [$VMNAME]"
        $Remrmvm=  get-azurermvm -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue | where {$_.Name -contains $VMNAME} 
        IF($Remrmvm){
             $Remrmvm | remove-azurermvm -Confirm:$False -Force 
             }#if
        $RemStorAcc = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -erroraction silentlycontinue
        If($RemStorAcc){ 
            $RemStorAcc | Remove-AzureRmStorageAccount -Force -Confirm:$fALSE ; sleep 120
            }#if
        $RemRes = get-azurermresource -ResourceName $VMNAME -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
        If($RemRes){
            $RemRes | Remove-AzureRmResource -Confirm:$False -force
            }#if


			#Verifying Instance Size is available in selected region
			Write-Verbose -Verbose -Message "Checking for [ $($instanceSize) ] in [ $Location ]"

			#Gathering Instances in the specified location
			$Instance = Get-AzureRmVMsize -Location $Location | ?{$_.Name -eq $($instanceSize)}

			If (!$Instance){
				$THASH[$VMNAME]["Status"] = "FAILED"
				Throw "Instance size [ $($instanceSize) ] not available in [ $Location ]"
			}#IF
		
			Else{
                Write-Verbose -Verbose -Message "Instance size [ $($instanceSize) ] found"
			}#ELSE

            #Note has to be something even if the user doesnt send anything
            if($note -eq $null){$Note = '  '}
			            
			#Setting the Storage Type and Diskcount from the Hash
			$StorageType = $Config[$InstanceSize]['StorageType']
			$DiskCount = $Config[$InstanceSize]['DiskCount']
			$THASH = @{
				$VMNAME = @{
					Name = $VMNAME
					Domain = $FQDN
					SKU = $SKUS
					InstanceSize = $InstanceSize
					StorageAccount = $StorageAccountName
					StorageType = $StorageType
					DiskCount = $DiskCount
					Location = $Location
					VNET = $($VNET.Name)
				}
			}
            
	#Variables for OS selection change based on role this gathers the correct image.
    
            IF($Role -eq 'SQL'){
	        $PublisherName = 'MicrosoftSQLServer'
	        $Offer = $Skus
            $Sku = 'enterprise'
                 Switch ($SKUS){
                 {$_ -like '*WS2012*'} { $SXS = "Server2012-R2-Datacentersxs.zip" <# ; $DPM = $CurrentDPMBits #> }
                 {$_ -like '*WS2016*'} { $SXS = "Server2016-Datacentersxs.zip" <# ; $DPM = "DPMAgentInstaller_x64.exe"#> }
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
                                    {$_ -like '2012*'} { $SXS = "Server2012-R2-Datacentersxs.zip" <#; $DPM = $CurrentDPMBits #> }
                                    {$_ -like '2016*'} { $SXS = "Server2016-Datacentersxs.zip" <#; $DPM = "DPMAgentInstaller_x64.exe" #>}
                                   }

            }#Else

			#Checking for the existance of the Resource Group and Create it if not exists.
			Write-Verbose -verbose -message "Checking for ResourceGroup [ $ResourceGroupName ]"

			$ResourceGroup = Get-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location -ErrorAction SilentlyContinue

			If ($ResourceGroup) {
				Write-Verbose -verbose -message "ResourceGroup [ $ResourceGroupName ] found"    
			}#IF
			Else{
				Write-Verbose -verbose -message "Creating ResourceGroup [ $ResourceGroupName ]"
				$ResourceGroup =  New-AzureRmResourceGroup `
									-Name $ResourceGroupName `
									-Location $Location `
									-Force
			}#ELSE

			#Checking for and creating Availability set

If($AvailabilitySetName -eq $null){$AvailabilitySetName = "${vmname}AS"}
			

			Write-Verbose -verbose -message "Checking for AvailabilitySet [ $AvailabilitySetName ]"
			$AvailabilitySet = Get-AzureRmAvailabilitySet -ResourceGroupName $ResourceGroupName -Name $AvailabilitySetName -ErrorAction SilentlyContinue

				If ( $AvailabilitySet ) {
					Write-Verbose -verbose -message "Found AvailabilitySet [ $AvailabilitySetName ]"
                    }#if
                    #Remove-AzureRmAvailabilitySet -ResourceGroupName $ResourceGroupName -Name $AvailabilitySetname -Force
                  Else{Write-Verbose -verbose -message "Creating AvailabilitySet [ $AvailabilitySetName ]"
					$AvailabilitySet = New-AzureRmAvailabilitySet -ResourceGroupName $ResourceGroupName -Name $AvailabilitySetName -Location $Location
				}#else
				
				#Create VM Config based off availability set   
				$VM = New-AzureRmVMConfig `
					-VMName $VMNAME `
					-VMSize $InstanceSize.trim() `
					-AvailabilitySetId $AvailabilitySet.ID
			

			#Create Storage Account
			Write-Verbose -Verbose -Message "Checking for StorageAccount [ $StorageAccountName ]"
date -DisplayHint DateTime | select -ExpandProperty datetime
			$StorageAccount = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -erroraction silentlycontinue

			IF($StorageAccount){
				Write-Verbose -Verbose -Message "StorageAccount [ $StorageAccountName ] found"
			}#IF
			Else{

				Write-Verbose -Verbose -Message "Creating StorageAccount [ $StorageAccountName ]"
				$StorageAccount = New-AzurermStorageAccount `
					-ResourceGroupName $ResourceGroupName `
					-Name $StorageAccountName `
					-Location $Location `
					-Type $StorageType 
			}#ELSE

date -DisplayHint DateTime | select -ExpandProperty datetime

			#Creating the NIC for the VM
			try{$nic = Get-AzureRmNetworkInterface -Name $vmname  -ResourceGroupName $ResourceGroupName}
catch{}

	IF($NIC){
				Write-Verbose -Verbose -Message "NIC [ $nic ] found"
			}#IF
			Else{

			Write-Verbose -Verbose -Message "Creating network interface"
			$nic = New-AzureRmNetworkInterface `
						-Force `
						-Name $vmname `
						-ResourceGroupName $ResourceGroupName `
						-Location $LOCATION `
						-SubnetId $subnetId

			$nic = Get-AzureRmNetworkInterface -Name $vmname  -ResourceGroupName $ResourceGroupName
}
			# Add NIC to VM
			Write-Verbose -Verbose -Message "Creating VM Template"
			Write-Verbose -Verbose -Message "Adding Network Interface"
			$vm = Add-AzureRmVMNetworkInterface -VM $vm -Id $nic.Id

			#Creating and Attaching the OS Disk
			Write-Verbose -Verbose -Message "Creating and attaching OS Disk"
			$osDiskName = "${vmname}_osDisk"
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
			Write-Verbose -Verbose -Message "Attaching [ $DiskCount ] Disks to Instance Size [ $InstanceSize ]."
			for ($i = 0; $i -lt $DiskCount; $i++){ 

				$Name = "${VMNAME}DataDisk${I}"
				$Disk = Add-AzureRmVMDataDisk `
						-VM $VM `
						-Name $Name `
						-VhdUri "https://$StorageAccountName.blob.core.windows.net/vhds/$Name.vhd" `
						-Caching ReadOnly `
						-DiskSizeInGB 1023 `
						-Lun ($I) `
						-CreateOption empty `
						-Verbose
			}
date -DisplayHint DateTime | select -ExpandProperty datetime
			Write-Verbose -Verbose -Message "Creating Virtual Machine [ $VMName ]"
			$VM = New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $Location -VM $VM -ErrorAction continue
			$Vm = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMNAME -ErrorAction SilentlyContinue 
date -DisplayHint DateTime | select -ExpandProperty datetime
			IF(!$VM){
				$THASH[$VMNAME]["Status"] = "FAILED"
				return "VM Creation Failed"
                
			}#IF

Else{
     #Enable Recovery Backup Protection
            $policy = Get-AzureRmRecoveryServicesBackupProtectionPolicy -Name "StandardPolicy"
            Enable-AzureRmRecoveryServicesBackupProtection -Policy $policy -Name $vmname -ResourceGroupName $ResourceGroupName

			$NICConfig = Get-AzureRmNetworkInterfaceIpConfig -NetworkInterface $nic
			$Thash[$VMNAME]["IP"]= $($NicConfig.PrivateIpAddress)

### Post Config Settings Section ###            
            
            $StorageAccountName = "sesscripts"
			$Key = $ScriptstorageKey 
			$ExtensionName = 'PostConfig'
			$TypeHandlerVersion = '1.8'
            
            #Edit this to change the files and commands run on the deployed VM
			$CommandToRun = "postconfig.ps1  -Role $Role -Function `"$Function`" -SXS $SXS -FriendlyName $FriendlyName -SQLUser $User -SQLPWD $Password -AssignedTO $AssignedTo -Note $Note -ServiceName `"$ServiceName`" -Environment $Environment -Location $Location -domain $FQDN -storage $Storage -administrators $administrators -InventoryPassword $InventoryPassword"
            
            #-Role $Role -Function $Function -SXS $SXS -FriendlyName $FriendlyName -SQLUser $SQLUSER -SQLPWD $SQLPWD -AssignedTO $AssignedTo -Note $Note -ServiceName $ServiceName -Environment $Environment -Location $Location
            
                   
            Switch($Role){

            SQL {
                $FilesTodownload = "storage.ps1", "postconfig.ps1", "configure${_}.ps1", "$SXS", "$DPM", "Microsoft.SharePoint.Client.Runtime.dll", "Microsoft.SharePoint.Client.dll" ,"MOMAgent.msi" ,"SCEPInstall.exe" ,"Set-InventoryRegStamp.ps1", "Machine2Inventory.ps1"
                                #Edit this to change the files and commands run on the deployed VM
			    $CommandToRun = "postconfig.ps1  -Role $_ -Function `"$Function`" -SXS $SXS -SQLUser $User -SQLPWD $Password -AssignedTO $AssignedTo -Note `"$Note`" -ServiceName `"$ServiceName`" -Environment $Environment -Location $Location -domain $FQDN -storage $Storage -administrators $administrators -InventoryPassword $InventoryPassword"
                }#SQL
            IIS { 
            $FilesTodownload = "storage.ps1", "postconfig.ps1", "configure${_}.ps1", "$SXS", "$DPM", "Microsoft.SharePoint.Client.Runtime.dll", "Microsoft.SharePoint.Client.dll" ,"MOMAgent.msi" ,"SCEPInstall.exe" ,"Set-InventoryRegStamp.ps1" ,"WebDeploy_amd64_en-US.msi", "Machine2Inventory.ps1" # ,"SES DAILY DIFF.dtsx" ,"SES WEEKLY FULL.dtsx" , "SES TRN MAINTENANCE.dtsx"
                  $CommandToRun = "postconfig.ps1  -Role $_ -FriendlyName $FriendlyName -Function `"$Function`" -SXS $SXS -AssignedTO $AssignedTo -Note `"$Note`" -ServiceName `"$ServiceName`" -Environment $Environment -Location $Location -domain $FQDN -storage $Storage -administrators $administrators -InventoryPassword $InventoryPassword"
                }#IIS
            APP {
                  $FilesTodownload = "storage.ps1", "postconfig.ps1", "configure${_}.ps1", "$SXS", "$DPM", "Microsoft.SharePoint.Client.Runtime.dll", "Microsoft.SharePoint.Client.dll" ,"MOMAgent.msi" ,"SCEPInstall.exe" ,"Set-InventoryRegStamp.ps1", "Machine2Inventory.ps1" #,"WebDeploy_amd64_en-US.msi" # ,"SES DAILY DIFF.dtsx" ,"SES WEEKLY FULL.dtsx" , "SES TRN MAINTENANCE.dtsx"
                  $CommandToRun = "postconfig.ps1  -Role $_ -Function `"$Function`" -SXS $SXS -AssignedTO $AssignedTo -Note `"$Note`" -ServiceName `"$ServiceName`" -Environment $Environment -Location $Location -domain $FQDN -storage $Storage -administrators $administrators -InventoryPassword $InventoryPassword"
                }#App
         }#end switch
         Write-Verbose -Verbose -Message "Performing additional configurations depending on the role selected. If a failure occurs, check the Azure deployment logs on the VM at 'C:\WindowsAzure\Logs\Plugins\Microsoft.Compute.CustomScriptExtension\1.8' for general logs. 'C:\Packages\Plugins\Microsoft.Compute.JsonADDomainExtension\1.0\Status\0.status', or C:\Windows\debug for Domain Join Errors. 'C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.8\Status\0.status' for postconfig errors on the VM."

         # Adding SQLIaaSExtension
            
            if(( $ROLE -like "SQL")){
                        Write-Verbose -Verbose -Message "Adding SQLIaasExtension"

                        
                        $vmname=($VMNAME.ToLower() -replace "-",'')
                        $BackupStorageAccount = New-AzurermStorageAccount `
					                                -ResourceGroupName $ResourceGroupName `
					                                -Name $storageaccountname `
					                                -Location $Location `
					                                -Type "Standard_LRS" -Kind Storage

                        
                        $skey=(Get-AzureRMStorageAccountKey -Name $storageaccountname -ResourceGroupName $ResourceGroupName)
                        $SecureSkey = $skey[0].Value | ConvertTo-SecureString -AsPlainText -Force  # Primary Key
                        
                        $AutoPatchingConfig = New-AzureRmVMSqlServerAutoPatchingConfig -PatchCategory "Important" `
                                                                    -DayOfWeek Sunday `
                                                                    -MaintenanceWindowStartingHour 2 `
                                                                    -MaintenanceWindowDuration 60 

                        $autobackupconfig = New-AzureRmVMSqlServerAutoBackupConfig `
                                                -Enable `
                                                -RetentionPeriod 30 `
                                                -EnableEncryption `
                                                -CertificatePassword $securePassword `
                                                -ResourceGroupName $ResourceGroupName `
                                                -StorageKey $SecureSkey `
                                                -StorageUri "https://${storageaccountname}.blob.core.windows.net/" -BackupScheduleType Automated

                                                

                        Write-Verbose -Verbose -Message "."
                        $StorageContext
                        Write-Verbose -Verbose -Message "."
                        $AutoBackupConfig
                        Write-Verbose -Verbose -Message "."
                        $VMNAME
                        Write-Verbose -Verbose -Message "."
                        $ResourceGroupName

                        Set-AzureRmVMSqlServerExtension -AutoBackupSettings $autobackupconfig `
                                                                                    -VMName $VMNAME `
                                                                                    -ResourceGroupName $ResourceGroupName `
                                                                                    -Name "${VMNAME}SQLIaasExtension" `
                                                                                    -Version 1.2 `
                                                                                    -Location $Location `
                                                                                    -AutoPatchingSettings $AutoPatchingConfig 


<#
                        Set-AzureRmVMSqlServerExtension -AutoBackupSettings $autobackupconfig `
                                                            -VMName $VMNAME `
                                                            -ResourceGroupName $ResourceGroupName `
                                                            -Name "SQLIaasExtension" `
                                                            -Version 1.2 `
                                                            -Location $Location
                                                            

<#
                        $vmname="vsssql03b"
                        $ResourceGroupName="vshshaikh3"
                        $Location="West US 2"
                        $StorageType="StorageType"

                        $vmname=($VMNAME.ToLower() -replace "-",'')
                                                $BackupStorageAccount = New-AzurermStorageAccount `
					                                                        -ResourceGroupName $ResourceGroupName `
					                                                        -Name $storageaccountname `
					                                                        -Location $Location `
					                                                        -Type $StorageType -Kind Storage

                        $skey=(Get-AzureRMStorageAccountKey -Name "vsssql2" -ResourceGroupName $ResourceGroupName)
                        $SecureSkey = $skey[0].Value | ConvertTo-SecureString -AsPlainText -Force  # Primary Key
                     

                        $AutoPatchingConfig = New-AzureRmVMSqlServerAutoPatchingConfig -PatchCategory "Important" `
                                                                    -DayOfWeek Sunday `
                                                                    -MaintenanceWindowStartingHour 2 `
                                                                    -MaintenanceWindowDuration 60 
                                            
                        $autobackupconfig=New-AzureRmVMSqlServerAutoBackupConfig -Enable `
                                                                -RetentionPeriodInDays 30 `
                                                                -EnableEncryption $true `
                                                                -StorageKey $SecureSkey `
                                                                -StorageUri "https://vsssql2.blob.core.windows.net/" 

                        #$KeyVaultCredentialConfig=New-AzureRmVMSqlServerKeyVaultCredentialConfig -CredentialName "" 

                        Set-AzureRmVMSqlServerExtension -AutoBackupSettings $autobackupconfig `
                                                                                    -VMName $VMNAME `
                                                                                    -ResourceGroupName $ResourceGroupName `
                                                                                    -Name "${VMNAME}Extension" `
                                                                                    -Version 1.2 `
                                                                                    -Location $Location `
                                                                                    -AutoPatchingSettings $AutoPatchingConfig 


#>


                        $SqlExtension=Get-AzureRmVMSqlServerExtension -VMName $VMNAME -ResourceGroupName $ResourceGroupName

                        if($SqlExtension){
                                Write-Verbose -Verbose -Message "SQLIaasExtension added" 
                                $SqlExtension                               
                        }
                        else {
                                Write-Verbose -Verbose -Message "Failed to add SQLIaasExtension!"  
                        }
            }
            else{
                Write-Verbose -Verbose -Message "Failed to add SQLIaasExtension"  
            }


         date -DisplayHint DateTime | select -ExpandProperty datetime
         Write-Verbose -Verbose -Message "Performing Domain Join on [ $FQDN ]"

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
       
			Switch ($Join.IsSuccessStatusCode) {
				$TRUE { Write-verbose -Verbose -Message "Domain Join Success for [ $VMNAME ] IP [ $($Thash[$VMNAME]['IP']) ]"
						$THASH[$VMNAME]["Status"] = "Domain Join Success"}
				Default {Write-Warning  -Verbose -Message "Domain Join for [ $VMNAME ] Failed. IP [ $($Thash[$VMNAME]['IP']) ]"
						$THASH[$VMNAME]["Status"] = "FAILED"}
			}


}#Else

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
                           $_.exception.message
                           }#catch
                        
                           if($postconfig){
                           Write-verbose -Verbose -Message "Post Congfiguration Completed Successfully!"
                           }#if
                        
                           #$I++}#do
                          #until($? -or $I -eq 3) 
                          #}#if
                          #Finally{$Success = $False}

		date -DisplayHint DateTime | select -ExpandProperty datetime

		$Status += New-Object PSobject -Property $THASH[$VMNAME]

  #  $Test = Invoke-Command "$VMNAME.$FQDN" {Hostname}

 #   IF($TEst){$Success = $True}

# }#While
}#PROCESS

End {
   Write-Verbose -Verbose -Message "Deployment Complete"
   $Status | Fl
}
