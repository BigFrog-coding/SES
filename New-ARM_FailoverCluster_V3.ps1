## ADD Static IP for ARM Cluster Name IP. ##

###  Be sure to install failover feature in windows prior to running this script  ###

Param(
 [Parameter(Mandatory=$true)]$Domain = 'Redmond'
,[Parameter(Mandatory=$true)]$FQDN = 'redmond.corp.microsoft.com'
,[Parameter(Mandatory=$true)]$Nodes = @('sesuw2-sql17a','sesuw2-sql17b')
,[Parameter(Mandatory=$true)]$Listener = "sesuw2-sql17"
,[Parameter(Mandatory=$true)]$Cluster = 'sesuw2-sql17CN'
,[Parameter(Mandatory=$true)]$ClusterIP = '10.158.76.186'
,[Parameter(Mandatory=$true)]$DomainUser = 'Redmond\WDGSES'
,[Parameter(Mandatory=$true)]$DomainPassword = 'BeachHouse-1-1'
,[Parameter(Mandatory=$true)]$ou = 'OU=wdgsesre,OU=Support,OU=OSG,OU=Labs,DC=redmond,DC=corp,DC=microsoft,DC=com'
,[Parameter(Mandatory=$true)]$SKUS
,[Parameter(Mandatory=$true)]$quorumkey
,[Parameter(Mandatory=$true)]$QuorumShare
,[Parameter(Mandatory=$true)]$CloudwitnessStorageKey
)

Import-Module activedirectory

#clean up task in case of re-run
foreach($node in $Nodes){
write-verbose -verbose -message "Cleaning Up Cluster installation for [$node] if needed"
do {$result = @()
try{$result = (Get-WindowsFeature -ComputerName "${node}.${fqdn}" -Name 'Failover-Clustering', 'RSAT-Clustering-PowerShell', 'RSAT-Clustering-CmdInterface', 'RSAT-Clustering-Mgmt', 'RSAT-AD-Tools').installstate}
catch{$_}
if($result -notcontains "Available"){
Invoke-Command -ComputerName "${node}.${fqdn}" -ScriptBlock{
Clear-ClusterNode -Force -Confirm:$False
Remove-WindowsFeature 'Failover-Clustering', 'RSAT-Clustering-PowerShell', 'RSAT-Clustering-CmdInterface', 'RSAT-Clustering-Mgmt', 'RSAT-AD-Tools' -ErrorAction SilentlyContinue -Restart}
sleep 60}
}
until($result -match "Available")
}

#Cleanup and addition of AD objects for Listener and Cluster
$Computerobjects =@()
$Listener,$Cluster | foreach {
Write-Verbose -Verbose -Message "Checking Status of AD object for [ $_ ]"
$name = $_
$DN = "cn=${name},${ou}"
$securePassword = $DomainPassword | ConvertTo-SecureString -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($DomainUser, $securePassword)
DO {$cobj = @()
   try{ $COBJ = Get-ADComputer $DN -Server $FQDN -ErrorAction stop}
   catch{}

#This Removes previously deployed AD objects for Listener and Cluster
   IF($COBJ){
   Set-ADobject $DN -Server $fqdn -ProtectedFromAccidentalDeletion:$false -Confirm:$false
   Remove-ADComputer $DN -Server $FQDN -Confirm:$false -ErrorAction SilentlyContinue}
    }
   Until(!$(try{get-ADComputer $DN -Server $FQDN -ErrorAction STOP}catch{}))

#This Creates AD objects for Listener and Cluster
  tRy{ 
    if($name -eq $Cluster){
    New-ADComputer -name $name -Path $OU -Server $fqdn -Credential $cred -Description "Cluster Object" -ErrorAction STOP
    Write-Verbose -Verbose -Message "Creating AD Object for [ $name ]"}#if
    
    elseif($name -eq $Listener){
    New-ADComputer -name $name -Path $OU -Server $fqdn -Credential $cred -Description "SQL Listener Object" -ErrorAction STOP
    Write-Verbose -Verbose -Message "Creating AD Object for [ $name ]"
    }#elseif
    }
    cATCH{$_.exception.message} 
    
    $cobj = @()
    do{
    TRY{$COBJ = (Get-ADComputer $DN -Server $fqdn -ErrorAction STOP).DistinguishedName}
        cATCH{$_.exception.message}
   
    IF(!$Cobj){#Write-Verbose -Verbose -Message "Waiting for AD to Replicate Changes"
                #sleep 180} 
                 }               }
Until($COBJ)
$Computerobjects += $COBJ }


$Csid=@()
While(!$Csid){
Write-Verbose -Verbose -Message "waiting 5 minutes for replication"
Try{$CSID = (Get-ADcomputer "cn=$($Cluster),$OU" -Server $FQDN -ErrorAction stop).SID}
Catch{ $_.Exception.message}
}
#Set the cluster ad object to disabled
Set-ADComputer -Identity $CSID -Server $fqdn -Enabled $false
sleep 300

ForEach($comobj in $Computerobjects) {
Foreach($Node in $Nodes){    
     Write-Verbose -Verbose -message "Configuring AD for [$Node] on [$comobj] "     
Do {$acl = get-acl "ad:$comobj" -erroraction silentlycontinue }
until($?)
$results = $acl.access #to get access right of the OU
$computer = get-adcomputer $node -Server $fqdn -Properties *
$sid = [System.Security.Principal.SecurityIdentifier] $computer.SID

# Create a new access control entry to allow access to the OU
$identity = [System.Security.Principal.IdentityReference] $SID
$adRights = [System.DirectoryServices.ActiveDirectoryRights] "GenericAll"
$type = [System.Security.AccessControl.AccessControlType] "Allow"
$inheritanceType = [System.DirectoryServices.ActiveDirectorySecurityInheritance] "All"
$ACE = New-Object System.DirectoryServices.ActiveDirectoryAccessRule $identity,$adRights,$type,$inheritanceType

# Add the ACE to the ACL, then set the ACL to save the changes
$acl.AddAccessRule($ace) 
do{$result = Set-acl -aclobject $acl "ad:$comobj"}      
until($?)
Write-Verbose -verbose -message "Added [ $node ] to [ $comobj ] "
}#foreach node
}#foreach cob confirmed working
    
Write-Verbose -Verbose -message "Configuring AD for [$listener] "
$DN1 = "cn=${listener},${OU}"
$acl = get-acl "ad:${dn1}"
$results = $acl.access #to get access right of the OU
$DN2 = "cn=${cluster},${ou}"
$computer = get-adcomputer $dn2 -Server $fqdn
$sid = [System.Security.Principal.SecurityIdentifier] $computer.SID

# Create a new access control entry to allow access to the OU
$identity = [System.Security.Principal.IdentityReference] $SID
$adRights = [System.DirectoryServices.ActiveDirectoryRights] "GenericAll"
$type = [System.Security.AccessControl.AccessControlType] "Allow"
$inheritanceType = [System.DirectoryServices.ActiveDirectorySecurityInheritance] "All"
$ACE = New-Object System.DirectoryServices.ActiveDirectoryAccessRule $identity,$adRights,$type,$inheritanceType

# Add the ACE to the ACL, then set the ACL to save the changes
$acl.AddAccessRule($ace) 
Do {$result = Set-acl -aclobject $acl "ad:${dn1}"}
until($?)
Write-Verbose -verbose -message "Added [ $Cluster ]"


Write-Verbose -Verbose -message "Configuring AD for [$Cluster] "
$acl = get-acl "ad:${OU}"
$results = $acl.access #to get access right of the OU
$computer = get-adcomputer $DN2 -Server $fqdn
$sid = [System.Security.Principal.SecurityIdentifier] $computer.SID
# Create a new access control entry to allow access to the OU
$identity = [System.Security.Principal.IdentityReference] $SID
$adRights1 = [System.DirectoryServices.ActiveDirectoryRights] "GenericAll"
$type = [System.Security.AccessControl.AccessControlType] "Allow"
$inheritanceType = [System.DirectoryServices.ActiveDirectorySecurityInheritance] "All"
$ACE = New-Object System.DirectoryServices.ActiveDirectoryAccessRule $identity,$adRights1,$type,$inheritanceType
# Add the ACE to the ACL, then set the ACL to save the changes
$acl.AddAccessRule($ace) 
Do {$result = Set-acl -aclobject $acl "ad:${OU}"}
until($?)

$acl = get-acl "ad:${OU}"
$results = $acl.access #to get access right of the OU
$computer = get-adcomputer $DN2 -Server $fqdn
$sid = [System.Security.Principal.SecurityIdentifier] $computer.SID
# Create a new access control entry to allow access to the OU
$identity = [System.Security.Principal.IdentityReference] $SID
$adRights2 = [System.DirectoryServices.ActiveDirectoryRights] "CreateChild"
$type = [System.Security.AccessControl.AccessControlType] "Allow"
$inheritanceType = [System.DirectoryServices.ActiveDirectorySecurityInheritance] "All"
$ACE = New-Object System.DirectoryServices.ActiveDirectoryAccessRule $identity,$adRights2,$type,$inheritanceType
# Add the ACE to the ACL, then set the ACL to save the changes
$acl.AddAccessRule($ace) 
Do {$result = Set-acl -aclobject $acl "ad:${OU}"}
until($?)


$CNodes=@()
Foreach($Node in $Nodes){
$CNodes += "${node}.${Fqdn}"
    Write-Verbose -Verbose -message "Installing Failover Cluster Role for [$node]"
        Invoke-Command -ComputerName "${Node}.${FQDN}" -ScriptBlock{
        Add-WindowsFeature 'Failover-Clustering', 'RSAT-Clustering-PowerShell', 'RSAT-Clustering-CmdInterface', 'RSAT-Clustering-Mgmt', 'RSAT-AD-Tools' -IncludeAllSubFeature -Restart} -ErrorAction Continue
       }
#Create the Cluster
Write-Verbose -Verbose -message "Creating Failover Cluster now."
$Cluster = new-cluster -Name $Cluster -Node $Cnodes -NoStorage -StaticAddress $ClusterIP -verbose

IF($SKUS -like 'sql2016*'){
Invoke-Command -ComputerName $cnodes[0] -ScriptBlock{
Set-ClusterQuorum –CloudWitness -AccessKey 'MUc9qWvg9eOLEs8IVaQGyoSmkpxjv4yNeAK86VC6jt1Unq1Uv8PIyMzPack/WR+p9cowiPgw6wuSTnKoutguDQ==' -AccountName sesclusterwitnesssa -ErrorAction SilentlyContinue
}
 }
 elseif($SKUS -like 'sql2014*' -or $SKUS -like 'sql2012*' ){
 Invoke-Command -ComputerName $cnodes[0] -ScriptBlock{
Set-ClusterQuorum -FileShareWitness "${using:QuorumShare}\${using:cluster}" -ErrorAction SilentlyContinue
 }
 }
Write-Verbose -Verbose -message "Failover cluster is now created, moving on to AO Configuration."
