Param(
[Parameter(Mandatory=$true)]$nodes = @('sesuw2-sql17a','sesuw2-sql17b')
,[Parameter(Mandatory=$true)]$AvailabilityGroup = 'sesuw2-sql17AG'
,[Parameter(Mandatory=$true)]$Listener = 'sesuw2-sql17'
,[Parameter(Mandatory=$true)]$ILBIP = '10.158.76.185'
)

Begin{
function ConvertTo-DecimalIP {
  <#
    .Synopsis
      Converts a Decimal IP address into a 32-bit unsigned integer.
    .Description
      ConvertTo-DecimalIP takes a decimal IP, uses a shift-like operation on each octet and returns a single UInt32 value.
    .Parameter IPAddress
      An IP Address to convert.
  #>
  
  [CmdLetBinding()]
  param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
    [Net.IPAddress]$IPAddress
  )

  process {
    $i = 3; $DecimalIP = 0;
    $IPAddress.GetAddressBytes() | ForEach-Object { $DecimalIP += $_ * [Math]::Pow(256, $i); $i-- }

    return [UInt32]$DecimalIP
  }
}
function ConvertTo-DottedDecimalIP {
  <#
    .Synopsis
      Returns a dotted decimal IP address from either an unsigned 32-bit integer or a dotted binary string.
    .Description
      ConvertTo-DottedDecimalIP uses a regular expression match on the input string to convert to an IP address.
    .Parameter IPAddress
      A string representation of an IP address from either UInt32 or dotted binary.
  #>

  [CmdLetBinding()]
  param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
    [String]$IPAddress
  )
  
  process {
    Switch -RegEx ($IPAddress) {
      "([01]{8}.){3}[01]{8}" {
        return [String]::Join('.', $( $IPAddress.Split('.') | ForEach-Object { [Convert]::ToUInt32($_, 2) } ))
      }
      "\d" {
        $IPAddress = [UInt32]$IPAddress
        $DottedIP = $( For ($i = 3; $i -gt -1; $i--) {
          $Remainder = $IPAddress % [Math]::Pow(256, $i)
          ($IPAddress - $Remainder) / [Math]::Pow(256, $i)
          $IPAddress = $Remainder
         } )
       
        return [String]::Join('.', $DottedIP)
      }
      default {
        Write-Error "Cannot convert this format"
      }
    }
  }
}
function ConvertTo-MaskLength {
  <#
    .Synopsis
      Returns the length of a subnet mask.
    .Description
      ConvertTo-MaskLength accepts any IPv4 address as input, however the output value 
      only makes sense when using a subnet mask.
    .Parameter SubnetMask
      A subnet mask to convert into length
  #>

  [CmdLetBinding()]
  param(
    [Parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True)]
    [Alias("Mask")]
    [Net.IPAddress]$SubnetMask
  )

  process {
    $Bits = "$( $SubnetMask.GetAddressBytes() | ForEach-Object { [Convert]::ToString($_, 2) } )" -replace '[\s0]'

    return $Bits.Length
  }
}
function Get-NetworkAddress {
  <#
    .Synopsis
      Takes an IP address and subnet mask then calculates the network address for the range.
    .Description
      Get-NetworkAddress returns the network address for a subnet by performing a bitwise AND 
      operation against the decimal forms of the IP address and subnet mask. Get-NetworkAddress 
      expects both the IP address and subnet mask in dotted decimal format.
    .Parameter IPAddress
      Any IP address within the network range.
    .Parameter SubnetMask
      The subnet mask for the network.
  #>
  
  [CmdLetBinding()]
  param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
    [Net.IPAddress]$IPAddress,
    
    [Parameter(Mandatory = $true, Position = 1)]
    [Alias("Mask")]
    [Net.IPAddress]$SubnetMask
  )

  process {
    return ConvertTo-DottedDecimalIP ((ConvertTo-DecimalIP $IPAddress) -band (ConvertTo-DecimalIP $SubnetMask))
  }
}

Write-Verbose -Verbose -Message "Gathering IP Info"
$bACKUPnAME = (GET-DATE).Ticks
$Networks = Get-WmiObject -ComputerName $Node[0] Win32_NetworkAdapterConfiguration | where {$_.dhcpenabled -eq $True}
$NetworkSubnet = "$(Get-NetworkAddress -IPAddress $Networks.ipaddress.get(1) -SubnetMask $Networks.IPSubnet.get(1))\$(ConvertTo-MaskLength -SubnetMask $Networks.ipsubnet.get(1))"
$Range = "$(Get-NetworkAddress -IPAddress $Networks.IPAddress.get(1) -SubnetMask $Networks.ipsubnet.get(1))"
Write-Verbose -Verbose -Message "Cleaning up environment if needed and Enabling Always On"

Foreach($node in $Nodes) {

Invoke-Command -Computername $node { 
        disable-SqlAlwayson -ServerInstance $($env:COMPUTERNAME) -force -ErrorAction SilentlyContinue -Confirm:$False -Verbose
        }#invoke
        Restart-Computer -ComputerName $node -Force
        sleep 60

Invoke-Command -Computername $node { 
        param(
         $node0
        ,$node1
        )
        Enable-SqlAlwayson -ServerInstance $($env:COMPUTERNAME) -force -Confirm:$False -Verbose
        netsh advfirewall firewall add rule name="SQL Cluster Probe 59999" dir=in action=allow protocol=TCP localport=59999
        md E:\SQLHADR 
        New-SmbShare -FullAccess "nt service\mssqlserver","$node0$","$node1$" -Path E:\SQLHADR -Name SQLHADR
        $Acl = Get-Acl "e:\SQLHADR"

"$Node0$","$node1$","nt service\mssqlserver" | % {

$Ar = New-Object System.Security.AccessControl.FileSystemAccessRule("$_", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")

$Acl.SetAccessRule($Ar)
Set-Acl "e:\SQLHADR" $Acl

} #%      
        }-ArgumentList $nodes[0],$nodes[1] #Invoke
    }#foreach
    }#begin

process{
    Write-Verbose -Verbose -Message "Creating SQL login for Each Node"
#Add Node access to cluter node and remove temporary database.
$qUERY = "USE [master] 
GO 
CREATE LOGIN [redmond\$($Nodes[0])$] FROM WINDOWS WITH DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english] 
GO 
ALTER SERVER ROLE [sysadmin] ADD MEMBER [redmond\$($Nodes[0])$] 
GO
DROP DATABASE [TestOK2Delete]
GO
"
Invoke-Sqlcmd -ServerInstance $NODEs[1] -Query $qUERY -QueryTimeout 30000 -ErrorAction SilentlyContinue
$qUERY = "USE [master] 
GO 
CREATE LOGIN [redmond\$($Nodes[1])$] FROM WINDOWS WITH DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english] 
GO 
ALTER SERVER ROLE [sysadmin] ADD MEMBER [redmond\$($Nodes[1])$] 
GO
DROP DATABASE [TestOK2Delete]
GO
"
Invoke-Sqlcmd -ServerInstance $NODEs[0] -Query $qUERY -QueryTimeout 30000 -ErrorAction SilentlyContinue
Write-Verbose -Verbose -Message "Adding Temporary DB to Cluster Node a"
#Add temporary DB to Cluster Node A
$qUERY = "USE [master]
GO
CREATE DATABASE [TestOK2Delete]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'TestOK2Delete', FILENAME = N'E:\SQLData\TestOK2Delete.mdf' , SIZE = 4096KB , MAXSIZE = 1048576KB , FILEGROWTH = 10240KB )
 LOG ON 
( NAME = N'TestOK2Delete_log', FILENAME = N'E:\SQLLog\TestOK2Delete_log.ldf' , SIZE = 1024KB , MAXSIZE = 1048576KB , FILEGROWTH = 10240KB )
GO
ALTER DATABASE [TestOK2Delete] SET COMPATIBILITY_LEVEL = 120
GO
ALTER DATABASE [TestOK2Delete] SET ANSI_NULL_DEFAULT OFF 
GO
ALTER DATABASE [TestOK2Delete] SET ANSI_NULLS OFF 
GO
ALTER DATABASE [TestOK2Delete] SET ANSI_PADDING OFF 
GO
ALTER DATABASE [TestOK2Delete] SET ANSI_WARNINGS OFF 
GO
ALTER DATABASE [TestOK2Delete] SET ARITHABORT OFF 
GO
ALTER DATABASE [TestOK2Delete] SET AUTO_CLOSE OFF 
GO
ALTER DATABASE [TestOK2Delete] SET AUTO_SHRINK OFF 
GO
ALTER DATABASE [TestOK2Delete] SET AUTO_CREATE_STATISTICS ON
GO
ALTER DATABASE [TestOK2Delete] SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE [TestOK2Delete] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE [TestOK2Delete] SET CURSOR_DEFAULT  GLOBAL 
GO
ALTER DATABASE [TestOK2Delete] SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE [TestOK2Delete] SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE [TestOK2Delete] SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE [TestOK2Delete] SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE [TestOK2Delete] SET  DISABLE_BROKER 
GO
ALTER DATABASE [TestOK2Delete] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE [TestOK2Delete] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE [TestOK2Delete] SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE [TestOK2Delete] SET READ_COMMITTED_SNAPSHOT OFF 
GO
ALTER DATABASE [TestOK2Delete] SET  READ_WRITE 
GO
ALTER DATABASE [TestOK2Delete] SET RECOVERY FULL 
GO
ALTER DATABASE [TestOK2Delete] SET  MULTI_USER 
GO
ALTER DATABASE [TestOK2Delete] SET PAGE_VERIFY CHECKSUM  
GO
ALTER DATABASE [TestOK2Delete] SET TARGET_RECOVERY_TIME = 0 SECONDS 
GO
ALTER DATABASE [TestOK2Delete] SET DELAYED_DURABILITY = DISABLED 
GO
USE [TestOK2Delete]
GO
IF NOT EXISTS (SELECT name FROM sys.filegroups WHERE is_default=1 AND name = N'PRIMARY') ALTER DATABASE [TestOK2Delete] MODIFY FILEGROUP [PRIMARY] DEFAULT
GO
"
Invoke-Sqlcmd -ServerInstance $NODEs[0] -Query $qUERY -QueryTimeout 30000 -ErrorAction SilentlyContinue

#cREATE hadr eNDpoint
Write-Verbose -Verbose -Message "Creating HADR Endpoints"
$qUERY = "
USE [master]

GO

CREATE ENDPOINT [Hadr_endpoint] 
	AS TCP (LISTENER_PORT = 5022)
	FOR DATA_MIRRORING (ROLE = ALL, ENCRYPTION = REQUIRED ALGORITHM AES)

GO

IF (SELECT state FROM sys.endpoints WHERE name = N'Hadr_endpoint') <> 0
BEGIN
	ALTER ENDPOINT [Hadr_endpoint] STATE = STARTED
END


GO

use [master]

GO

GRANT CONNECT ON ENDPOINT::[Hadr_endpoint] TO [NT Service\MSSQLSERVER]

GO
"
Invoke-Sqlcmd -ServerInstance $NODEs[0] -Query $qUERY -QueryTimeout 30000 -ErrorAction SilentlyContinue
#cREATE hadr eNDpoint
$qUERY ="
USE [master]

GO

CREATE ENDPOINT [Hadr_endpoint] 
	AS TCP (LISTENER_PORT = 5022)
	FOR DATA_MIRRORING (ROLE = ALL, ENCRYPTION = REQUIRED ALGORITHM AES)

GO

IF (SELECT state FROM sys.endpoints WHERE name = N'Hadr_endpoint') <> 0
BEGIN
	ALTER ENDPOINT [Hadr_endpoint] STATE = STARTED
END


GO

use [master]

GO

GRANT CONNECT ON ENDPOINT::[Hadr_endpoint] TO [NT Service\MSSQLSERVER]

GO
"
Invoke-Sqlcmd -ServerInstance $NODEs[1] -Query $qUERY -QueryTimeout 30000 -ErrorAction SilentlyContinue
Write-Verbose -Verbose -Message "Creating Always on Health Events"
#Create Always On Health Event
$qUERY ="
IF EXISTS(SELECT * FROM sys.server_event_sessions WHERE name='AlwaysOn_health')
BEGIN
  ALTER EVENT SESSION [AlwaysOn_health] ON SERVER WITH (STARTUP_STATE=ON);
END
IF NOT EXISTS(SELECT * FROM sys.dm_xe_sessions WHERE name='AlwaysOn_health')
BEGIN
  ALTER EVENT SESSION [AlwaysOn_health] ON SERVER STATE=START;
END

GO
"
Invoke-Sqlcmd -ServerInstance $NODEs[0] -Query $qUERY -QueryTimeout 30000 -ErrorAction SilentlyContinue

#Create Always On Health Event
$qUERY="
BACKUP DATABASE [TestOK2Delete] TO  DISK = N'E:\SQLBackup\TestOK2Delete.bak' WITH NOFORMAT, NOINIT,  NAME = N'TestOK2Delete-Full Database Backup', SKIP, NOREWIND, NOUNLOAD,  STATS = 10
GO

USE [master]

GO

CREATE AVAILABILITY GROUP [$AvailabilityGroup]
WITH (AUTOMATED_BACKUP_PREFERENCE = Primary)
FOR DATABASE [TestOK2Delete]
REPLICA ON N'$($Nodes[0])' WITH
                (ENDPOINT_URL = N'TCP://$($Nodes[0]).redmond.corp.microsoft.com:5022', 
                FAILOVER_MODE = AUTOMATIC, 
                AVAILABILITY_MODE = SYNCHRONOUS_COMMIT, 
                BACKUP_PRIORITY = 50, 
                SECONDARY_ROLE(ALLOW_CONNECTIONS = ALL)),
	       N'$($Nodes[1])' WITH (ENDPOINT_URL = N'TCP://$($Nodes[1]).redmond.corp.microsoft.com:5022', 
                FAILOVER_MODE = AUTOMATIC, 
                AVAILABILITY_MODE = SYNCHRONOUS_COMMIT, 
                BACKUP_PRIORITY = 50, 
                SECONDARY_ROLE(ALLOW_CONNECTIONS = ALL));
GO


"
Invoke-Sqlcmd -ServerInstance $NODEs[0] -Query $qUERY -QueryTimeout 30000 -ErrorAction Stop
#Create Listener
Write-Verbose -Verbose -Message "Creating Listener"
$Query = "
ALTER AVAILABILITY GROUP [$AvailabilityGroup]
ADD LISTENER '$Listener' ( WITH IP ( (N'$ILBIP' , N'$($Networks.ipsubnet.get(1))') ) ,Port = 1433 )
GO
"
Invoke-Sqlcmd -ServerInstance $NODEs[0] -Query $qUERY -QueryTimeout 30000 -ErrorAction Stop

#Join Availability group for node
Write-Verbose -Verbose -Message "Joining Node to AG"
$qUERY ="
ALTER AVAILABILITY GROUP [$AvailabilityGroup] JOIN;

GO
"
Invoke-Sqlcmd -ServerInstance $NODEs[1] -Query $qUERY -QueryTimeout 30000 -ErrorAction Stop
#Backup Database
Write-Verbose -Verbose -Message "Creating DB Backup"
$qUERY ="
BACKUP DATABASE [TestOK2Delete] TO  DISK = N'e:\sqlhadr\TestOK2Delete.bak' WITH  COPY_ONLY, FORMAT, INIT, SKIP, REWIND, NOUNLOAD, COMPRESSION,  STATS = 5

GO
"
Invoke-Sqlcmd -ServerInstance $NODEs[0] -Query $qUERY -QueryTimeout 30000 -ErrorAction Stop
#Restore Database
Write-Verbose -Verbose -Message "Restoring DB to Node"
$qUERY ="

RESTORE DATABASE [TestOK2Delete] FROM  DISK = N'\\$($Nodes[0])\sqlhadr\TestOK2Delete.bak' WITH  NORECOVERY,  NOUNLOAD,  STATS = 5

GO
"
Invoke-Sqlcmd -ServerInstance $NODEs[1] -Query $qUERY -QueryTimeout 30000 -ErrorAction Stop
#Backup Log
Write-Verbose -Verbose -Message "Creating Log Backup"
$qUERY ="

BACKUP LOG [TestOK2Delete] TO  DISK = N'e:\sqlhadr\TestOK2Delete_$bACKUPnAME.trn' WITH NOFORMAT, NOINIT, NOSKIP, REWIND, NOUNLOAD, COMPRESSION,  STATS = 5

GO
"
Invoke-Sqlcmd -ServerInstance $NODEs[0] -Query $qUERY -QueryTimeout 30000 -ErrorAction Stop
#Restore Log
Write-Verbose -Verbose -Message "Restoring Log to node"
$qUERY ="

RESTORE LOG [TestOK2Delete] FROM  DISK = N'\\$($Nodes[0])\sqlhadr\TestOK2Delete_$bACKUPnAME.trn' WITH  NORECOVERY,  NOUNLOAD,  STATS = 5

GO
"
Invoke-Sqlcmd -ServerInstance $NODEs[1] -Query $qUERY -QueryTimeout 30000 -ErrorAction Stop
#join DB to availability group
Write-Verbose -Verbose -Message "Adding DB to AG"
$qUERY ="
begin try
declare @conn bit
declare @count int
declare @replica_id uniqueidentifier 
declare @group_id uniqueidentifier
set @conn = 0
set @count = 30 -- wait for 5 minutes 

if (serverproperty('IsHadrEnabled') = 1)
	and (isnull((select member_state from master.sys.dm_hadr_cluster_members where upper(member_name COLLATE Latin1_General_CI_AS) = upper(cast(serverproperty('ComputerNamePhysicalNetBIOS') as nvarchar(256)) COLLATE Latin1_General_CI_AS)), 0) <> 0)
	and (isnull((select state from master.sys.database_mirroring_endpoints), 1) = 0)
begin
    select @group_id = ags.group_id from master.sys.availability_groups as ags where name = N'$AvailabilityGroup'
	select @replica_id = replicas.replica_id from master.sys.availability_replicas as replicas where upper(replicas.replica_server_name COLLATE Latin1_General_CI_AS) = upper(@@SERVERNAME COLLATE Latin1_General_CI_AS) and group_id = @group_id
	while @conn <> 1 and @count > 0
	begin
		set @conn = isnull((select connected_state from master.sys.dm_hadr_availability_replica_states as states where states.replica_id = @replica_id), 1)
		if @conn = 1
		begin
			-- exit loop when the replica is connected, or if the query cannot find the replica status
			break
		end
		waitfor delay '00:00:10'
		set @count = @count - 1
	end
end
end try
begin catch
	-- If the wait loop fails, do not stop execution of the alter database statement
end catch
ALTER DATABASE [TestOK2Delete] SET HADR AVAILABILITY GROUP = [$AvailabilityGroup];

GO


GO

"
Invoke-Sqlcmd -ServerInstance $NODEs[1] -Query $qUERY -QueryTimeout 30000 -ErrorAction Stop
}#process

end{
#Make the listener work
[string]$IPResourceName = "${AvailabilityGroup}_${ILBIP}" #(Get-ClusterResource | select -Property name | where {$_.name -like "${AvailabilityGroup}_1*"}).name
[string]$ClusterNetworkName = "Cluster Network 1"

invoke-command -ComputerName $nodes[0] -ScriptBlock{
Get-ClusterResource -Name $using:IPResourceName | Set-ClusterParameter `
-Multiple @{"Address"="${using:ILBIP}";"ProbePort"="59999";"SubnetMask"="255.255.255.255";"Network"="${using:ClusterNetworkName}";"EnableDhcp"=0}
}
Write-Verbose -Verbose -Message "Restarting computer for changes to set"
Restart-Computer -ComputerName $nodes[0] -Force -ErrorAction SilentlyContinue
sleep 60

$Nodes | Foreach {
invoke-command -ComputerName $_ {net start SQLSERVERAGENT}
}

Write-Verbose -Verbose -Message "Complete"
}


