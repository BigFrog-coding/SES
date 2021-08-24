Param(
$CloudPassWord = 'CloudMade-0-0'
)
Try { 

$SecurePassword = $CloudPassWord | ConvertTo-SecureString -AsPlainText -Force

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

Function Upload-AzureRMBlob {
Param (
$SubscriptionID
,$ResourceGroupName
,$StorageAccountName
,$storageContainer
,$FilesToUpload
)

(Select-AzureRmSubscription -SubscriptionID $SubscriptionID).Subscription
$storageKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName)
$StorageContext = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey  $storageKey[0].value
$StorageAccountName = $StorageAccountName.ToLower()
$storageContainer = $storageContainer.ToLower()

Foreach ($File in $FilesToUpload){
Set-AzureStorageBlobContent -File $File -Context $StorageContext -Container $storageContainer -ConcurrentTaskCount 50 -BlobType Block -Force
}

}

$SubscriptionID = "81f532f5-7866-4934-9a21-d1960fd24f59"
$ResourceGroupName = 'sesautomation'
$StorageAccountName = 'sesscripts'
#$storageContainer = 'ppe'
#Set to Branch to upload to appropriate blob
$Branch = "prod"
Switch ($Branch){
prod {$storageContainer = 'prod'}
ppe {$storageContainer = 'ppe'}
dev {$storageContainer = 'dev'}

}
#Stage files in the below directory to upload
$FilesToUpload =@( GCi \\sesdfs.corp.microsoft.com\coreops\SES\PSLib\AzureDeployment\$Branch\BLOBSTAGE\ ).fullname

Upload-AzureRMBlob -SubscriptionID $SubscriptionID -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName -storageContainer $storageContainer.ToLower() -FilesToUpload $FilesToUpload
