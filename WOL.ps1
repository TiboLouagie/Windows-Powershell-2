#======3======
#region - WOL

#=============================================================================# 
#                                                                             # 
# DhcpWOL.ps1                                  				      # 
# DHCP Wake on LAN tool					                      # 
# Author: Jacob Sommerville                                                   # 
# Creation Date: 08.18.2014                                                   # 
# Modified Date: 08.22.2014                                                   # 
# Version: 4                                                                  # 
#                                                                             # 
#=============================================================================# 

 <# 
    .Synopsis 
     gets a list of clients from a DHCP server and wakes those machines up


    .Example 
     DhcpWOL.ps1 -Server dhcp01.contoso.com -Scope 192.168.1.0 
     This example polls dhcp01.contoso.com for all DHCP clients and wakes them up.


    .Example 
     DhcpWOL.ps1 -Server dhcp01.contoso.com -Scope 192.168.1.0 -Output c:\temp\machines.csv -NoWake
     This example polls dhcp01.contoso.com for all DHCP clients and creates a CSV in defined directory 
	 and doesn't wake the machines.


	.Example 
	 DhcpWOL.ps1 -Load c:\temp\machines.csv
	 This example takes machines from previously created CSV and wakes them up.


    .Description 
     The DhcpWOL.ps1 script can wake up all of the clients on a DHCP server or from a previously created
	 CSV file.
	 For example you can have the script create the CSV list sometime during the day while all machines
	 are on and then run the script again at a later time with the -Load command and wake them up 
	 again.
    .Parameter Server 
     The value for this parameter should be the FQDN of the DHCP server. The designated server must be 
	 a valid DHCP server. 
    .Parameter Scope 
     This parameter should be the DHCP scope that you want to wake up.
	.Parameter Save
	 This is where you want the CSV file to be created. Eg. C:\temp\machines.csv
	.Parameter Load
	 This is the CSV of machines to be awoken
	.Parameter NoWake
	 Use this switch to not send any wake on lan packets
	.Parameter AllowUnresolvable
	 This switch tells the script to wake hostnames that could not be reverse resolved from thier 
	 IP address. 
    .Outputs 
     DHCP_Client_list.csv
    .Notes 
     Name:   DhcpWOL.ps1
     Author: Jacob Sommerville
     Date:   08.22.2014
  #> 
  Param([Parameter(Mandatory=$false,ValueFromPipeline=$true)][string]$Server, 
        [Parameter(Mandatory=$false,ValueFromPipeline=$true)][string]$Scope, 
        [Parameter(Mandatory=$false)][string]$Save, 
		[Parameter(Mandatory=$false)][string]$Load, 
		[Parameter(Mandatory=$false)][switch]$NoWake,
		[Parameter(Mandatory=$false)][switch]$AllowUnresolvable
        ) 

$make_struct = @"
public struct DHCPClient { 
public string Host;
public string IPAddress; 
public string MACAddress;
public string Broadcast;
public string Server;
public override string ToString() { return IPAddress; } 
} 
"@

Add-Type -TypeDefinition $make_struct 

function Get-Hostname {
  [CmdletBinding()] param([Parameter(Mandatory=$true,ValueFromPipeline=$true)][PSObject]$IPAddress)
  $ErrorActionPreference = "SilentlyContinue"
  $result = [net.dns]::GetHostEntry($IPAddress)
  if (!$result.Hostname){return "Unresolvable"}
  else {return $result.Hostname}  
  }

  
#Get-DHCPClient was adapted from JeremyEngelWork's code
#http://gallery.technet.microsoft.com/scriptcenter/05b1d766-25a6-45cd-a0f1-8741ff6c04ec
function Get-DHCPClient { 

  Param([Parameter(Mandatory=$true,ValueFromPipeline=$true)][PSObject]$Server, 
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)][PSObject]$Scope,
		[bool]$local=$true,
		[string]$Broadcast
        ) 
  
  $reservations = @() 
  
  if ($local){
    Write-Host "Getting DHCP leases on local server"
	$text = netsh dhcp server \\ scope $Scope show clients
	} else {
	Write-Host "Getting DHCP leases on remote server $server"
	try {
       $text = Invoke-Command -computer $Server {netsh dhcp server \\$using:Server scope $using:Scope show clients} -ErrorAction Stop
	} catch {
	   Write-Error "FAIL: Are you sure that WinRM is enabled on the remote server????  http://support.microsoft.com/kb/555966"
	   break
	}
  }

  $result = if($text.GetType() -eq [string]){$text}else{$text[($text.Count-1)]}   
  if($result.Contains("The command needs a valid Scope IP Address")) { Write-Host "ERROR: $Scope is not a valid scope on $Server." -ForeGroundColor Red; return }   
  if($result.Contains("Server may not function properly")) { Write-Host "ERROR: $Server is inaccessible or is not a DHCP server." -ForeGroundColor Red; return }   
  if($result.Contains("The following command was not found")) { Write-Host "This command must be run on a local or remote DHCP server"; return }
  for($i=8;$i -lt $text.Count;$i++) { 
    if(!$text[$i]) {break} 
    $parts = $text[$i].Split("-") | %{ $_.Trim() } 
    if($IPAddress -and $parts[0] -ne $IPAddress) { continue } 
    $reservation = New-Object DHCPClient 
    $reservation.IPAddress = $parts[0] 
    $reservation.MACAddress = [string]::Join("-",$parts[2..7])  
	$reservation.Host = Get-Hostname($reservation.IPAddress)
	$reservation.Broadcast = $Broadcast
	$reservation.Server = $Server
    $reservations += $reservation 	
    } 
  return $reservations 
  } 
  
#The Send-WOL function was snagged directly from Barry Chum's code 
#http://gallery.technet.microsoft.com/scriptcenter/Send-WOL-packet-using-0638be7b
function Send-WOL 
{ 
<#  
  .SYNOPSIS   
    Send a WOL packet to a broadcast address 
  .PARAMETER mac 
   The MAC address of the device that need to wake up 
  .PARAMETER ip 
   The IP address where the WOL packet will be sent to 
  .EXAMPLE  
   Send-WOL -mac 00:11:32:21:2D:11 -ip 192.168.8.255  
#> 
 
param([Parameter(Mandatory=$true,ValueFromPipeline=$true)][string]$mac,
      [Parameter(Mandatory=$true,ValueFromPipeline=$true)][string]$broadcast,
      [int]$port=9 
) 
$broadcast = [Net.IPAddress]::Parse($broadcast) 
$mac=(($mac.replace(":","")).replace("-","")).replace(".","") 
$target=0,2,4,6,8,10 | % {[convert]::ToByte($mac.substring($_,2),16)} 
$packet = (,[byte]255 * 6) + ($target * 16) 
  
$UDPclient = new-Object System.Net.Sockets.UdpClient 
$UDPclient.Connect($broadcast,$port) 
[void]$UDPclient.Send($packet, 102)  
 
} 

function Get-Broadcast
{
	<#  
  .SYNOPSIS   
    Converts scope to broadcast address 
  .PARAMETER Scope 
   The Scope to convert 
  .EXAMPLE  
   Get-Broadcast 192.168.0.0
	returns --> 192.168.255.255
	I don't see how this would be useful for anything other than this script
#> 
	param([string]$Scope)
	
	$octets = $Scope.split(".")
    for($i=$octets.count-1;$i -gt 0;$i--){
	if ($octets[$i] -eq "0"){$octets[$i] = "255"
	} else {
	return $octets -join "."
	}
	}
}

$Load
if((!$Load -and !$Scope -and !$Server) -or ($Scope -and !$Server) -or (!$Scope -and $Server))
	{Write-Host "You must define either a Server and Scope or define a CSV file to use as Load" -ForeGroundColor Red;Get-Help .\DhcpWOL.ps1 -Detailed; break}
$Broadcast = Get-Broadcast -Scope $Scope
if ($server -eq "$env:computername.$env:userdnsdomain" -or $server -eq "$env:computername"){$local=$true}else{$local=$false}
if (!$Load){
	$ClientList = Get-DHCPClient -Server $Server -Scope $Scope -Local $local -Broadcast $Broadcast}
else
{$ClientList = Import-CSV $Load}
if ($Save){$ClientList | Export-CSV -path $Save}
if(!$NoWake){
	foreach ($Client in $ClientList) {
	if($Client.Host -ne "Unresolvable" -or $AllowUnresolvable){
		Write-Host "Waking" $Client.Host "on" $Client.IPAddress
		if ($local){Send-WOL -mac $Client.MACAddress -Broadcast $Client.Broadcast}
		else {Invoke-Command -ComputerName $Client.Server -ScriptBlock ${function:Send-WOL} -ArgumentList $Client.MACAddress,$Client.Broadcast}
		Start-Sleep -s 1
	}
	}

}
if($NoWake -and !$Save -and !$Load){$ClientList}
exit 0

#endregion

#github link
#https://github.com/TiboLouagie/Windows-Powershell-2