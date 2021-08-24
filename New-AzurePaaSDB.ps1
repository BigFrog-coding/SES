Param(
[Parameter(Mandatory=$true)]$SubID = 'a050bf41-d37a-48e7-815e-cf342127a83b'
,[Parameter(Mandatory=$true)]$SQLServer = 'ShellUDISSQL-prod'
,[Parameter(Mandatory=$true)]$SQLLoginPassword = 'UDISD@ta$44'
,[Parameter(Mandatory=$true)]$DataBase = 'ShellUDISProd'
,[Parameter(Mandatory=$true)]$ADGROUP = 'huy.dao@microsoft.com'
,[Parameter(Mandatory=$true)]$size = 's2'
,[Parameter(Mandatory=$true)]$Environment = 'prod'
)

# namespace: System.Web.Security 
# assembly: System.Web (in System.Web.dll) 
# method: GeneratePassword(int length, int numberOfNonAlphanumericCharacters) 

#Load "System.Web" assembly in PowerShell console 
[Reflection.Assembly]::LoadWithPartialName("System.Web")

#Calling GeneratePassword Method 
[string]$password = [System.Web.Security.Membership]::GeneratePassword(63,0) #generate strong password
$SecurePassword = $password | ConvertTo-SecureString -AsPlainText -Force #store as secure string
$password = $null #dump password now thats its a secure string

#Username
$randomletter = Get-Random -Count 1 -InputObject (65..90) | % {[char]$_} #Username must start with a letters
$newguid = [guid]::NewGuid() #Generate new GUID
$groomedguid = $newguid -replace "-", "" #dashes are invalid, remove them
[string]$username = $randomletter+$groomedguid #define the username as a string and ensure the first character is a random upper or lower case letter

$loggedin = Get-AzureRmSubscription -SubscriptionId $SubID -ErrorAction SilentlyContinue

If(!$loggedin){Login-AzureRmAccount}


    $FWRANGE=@{
        CORP1 =@{
            Name = 'Corp Redmond 1'
            Start = '131.107.174.0'
            END = '131.107.174.255'
            }
        CORP2 =@{
             Name = 'Corp Redmond 2'
            Start = '131.107.160.0'
            END = '131.107.160.255'
            }
        CORP3 =@{
             Name = 'Corp Redmond 3'
            Start = '131.107.159.0'
            END = '131.107.159.255'
            }
        CORP4 =@{
             Name = 'Corp Redmond 4'
            Start = '131.107.147.0'
            END = '131.107.147.255'
            }
        Datagrid1 =@{
             Name = 'DataGridEgress_1'
            Start = '40.77.163.129'
            END = '40.77.163.190'
            }
        Datagrid2 =@{
             Name = 'DataGridEgress_2'
            Start = '40.77.166.1'
            END = '40.77.166.62'
            }
        Datagrid3 =@{
             Name = 'DataGridEgress_3'
            Start = '40.77.163.252'
            END = '40.77.163.252'
            }
        EENAPEX1 =@{
             Name = 'EEN-APEX1'
            Start = '167.220.2.0'
            END = '167.220.2.255'
            }
        EENAPEX2 =@{
             Name = 'EEN-APEX2'
            Start = '167.220.0.0'
            END = '167.220.1.255'
            }
             AllowAureServices =@{
             Name = 'AllowAureServices'
            Start = '0.0.0.0'
            END = '0.0.0.0'
            }
            }

    Set-AzureRmContext -SubscriptionId $subID
    $SQLServer= $SQLServer.ToLower()
    $servicealias = $SQLServer.trimEnd("sql-${Environment}")
    
    $ResourceGroupName = $servicealias + "-${Environment}"
    $StorageAccountName = ($SQLServer.ToLower() -replace "-",'')
    $SQLServer = $SQLServer.ToLower()
    $creds = New-Object System.Management.Automation.PSCredential -ArgumentList $UserName, $SecurePassword 
 			
    #$VNET = Get-AzureRmVirtualNetwork | ?{$_.ResourceGroupName -eq 'ERNetwork' -or $_.ResourceGroupName -like 'Hypernet*'}
		
	#Setting Location for VM and Subnet ID for IP
	[string]$Location = "westus2"
    
    $ResourceGroup = Get-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location -erroraction silentlycontinue
    IF(!$ResourceGroup){
    New-AzureRmResourceGroup -Name $ResourceGroupName -Location $location
    }
    $StorageAccount = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction SilentlyContinue
    IF(!$StorageAccount){
    New-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -SkuName Standard_LRS -Location $location -Kind Storage -EnableEncryptionService Blob
    }
    $Server = Get-AzureRmSqlServer -ResourceGroupName $ResourceGroupName -ServerName $SQLServer -ErrorAction SilentlyContinue
    IF(!$Server){
    New-AzureRmSqlServer -ServerName $SQLServer -SqlAdministratorCredentials  $creds -ServerVersion '12.0' -Location $location -ResourceGroupName $ResourceGroupName
    }
    $DB = Get-AzureRmSqlDatabase -DatabaseName $DataBase -ServerName $SQLServer -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    IF(!$DB){
    New-AzureRmSqlDataBase -DataBaseName $DataBase -ServerName $SQLServer -RequestedServiceObjectiveName $size -ResourceGroupName $ResourceGroupName
    }
    $SADA = Get-AzureRmSqlServerActiveDirectoryAdministrator -ServerName $SQLServer -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    IF(!$SADA){
    Set-AzureRmSqlServerActiveDirectoryAdministrator -DisplayName 'WDGSESADMIN' -ObjectId '962ee80c-0db8-4217-8432-396e813fc737' -ServerName $SQLSERVER -ResourceGroupName $ResourceGroupName
    }
    $DBTDE = Get-AzureRmSqlDataBaseTransparentDataEncryption -ServerName $sqlserver -DatabaseName $DataBase -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    IF(!$DBTDE){
    Set-AzureRmSqlDataBaseTransparentDataEncryption -State Enabled -ServerName $SQLServer -DataBaseName $DataBase -ResourceGroupName $ResourceGroupName -Verbose
    }
    $DBTDP = get-AzureRmSqlDataBaseThreatDetectionPolicy -ServerName $SQLServer -DatabaseName $DataBase -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    IF(!$DBTDP){
    Set-AzureRmSqlDatabaseAuditingPolicy -AuditType Blob -StorageAccountName $StorageAccountName -ServerName $SQLServer -DatabaseName $DataBase -ResourceGroupName $ResourceGroupName -RetentionInDays 30 -StorageKeyType Primary -EventType All
    Set-AzureRmSqlDataBaseThreatDetectionPolicy -EmailAdmins:$True -ServerName $SQLServer -ResourceGroupName $ResourceGroupName -DataBaseName $DataBase -StorageAccountName $StorageAccountName
    }
    
    
    $FWRANGE[$FWRANGE.Keys] | %{
    $_['name']
    $_['Start']
    $_['end']

    $FWRule = get-AzureRmSqlServerFirewallRule -FirewallRuleName $_['NAME'] -ServerName $SQLServer -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    IF(!$FWRule){
    New-AzureRmSqlServerFirewallRule -ResourceGroupName $ResourceGroupName -ServerName $SQLServer  -FirewallRuleName $_['NAME'] -StartIpAddress $_['Start'] -EndIpAddress $_['END']
    }
    }

$Query = "
CREATE LOGIN [${servicealias}ADMIN] WITH password='$SQLLoginPassword'
GO

CREATE USER [${servicealias}ADMIN] FOR LOGIN [${servicealias}ADMIN]
CREATE USER [$ADGROUP] FROM  EXTERNAL PROVIDER  
exec sp_addrolemember [loginmanager], [${servicealias}ADMIN]
exec sp_addrolemember [DBmanager], [${servicealias}ADMIN]
exec sp_addrolemember [Dbmanager],[$ADGROUP] 
"
Invoke-Sqlcmd -ConnectionString "Server=tcp:${SQLSERVER}.DataBase.windows.net,1433;Initial Catalog=Master;Persist Security Info=False;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Authentication='Active Directory Integrated';" -Query $Query


$Query="
CREATE USER [${servicealias}ADMIN] FOR LOGIN [${servicealias}ADMIN]
CREATE USER [$ADGROUP] FROM  EXTERNAL PROVIDER
exec sp_addrolemember 'db_owner', [${servicealias}ADMIN] 
exec sp_addrolemember 'db_owner', [$ADGROUP]

grant alter to [${servicealias}ADMIN]
grant alter to [$ADGROUP]
"

Invoke-Sqlcmd -ConnectionString "Server=tcp:${SQLSERVER}.DataBase.windows.net,1433;Initial Catalog=$DataBase;Persist Security Info=False;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Authentication='Active Directory Integrated';" -Query $Query
