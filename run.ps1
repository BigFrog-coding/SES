$domainusername = 'DOMAIN\USER'
$currentuser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

try{
$currentuser = $currentuser.ToLower() -eq $domainusername
}

catch{$_.exception.message}

if(!$currentuser){
write-verbose -Verbose -Message "Deployment halted, script must run as ${domainusername}"
} #end if

else{
$domainusername = $domainusername -replace "redmond\\", ""
$LocalPath = $MyInvocation.Mycommand.Path
$scriptpath = Split-Path -Parent $localpath
& $scriptPath\DeploymentAutomation.ps1 `
-CSVpath "\\PATH\Logs\AzureDeploymentLogs\CSV\scripttest_AO.csv" `
-CloudPassWord 'PW' `
-domainusername $domainusername `
-user 'User' `
-KeyVaultSubID 'GUID' `
-QuorumShare '\\Server\QuorumFiles' `
-TranscriptShare '\\PATH\Logs\AzureDeploymentLogs\Transcripts' `
-NUAUserName 'GUID' `
-NUATenant 'GUID' `
#-DPMbitshare '\\PATH\agents\RA\4.2.1417.0\amd64\1033'

}#end else