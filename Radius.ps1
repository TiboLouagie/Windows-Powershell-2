#!PowerShell
#
# Add NPS(RADIUS) clients from CSV file to multiple NPS Servers
#
# Input CSV format:
#
# Address,Secret,Name
# 10.0.1.1,SecretPassword,RadiusClientName
# 10.0.1.2,SecretPassword
#
# 2018/05

## Change this to suit your site
$npsServers = @("DC1", "DC2")


$newClientsCSV = Import-CSV $args[0]

# Simple syntax check of input
$newClientsCSV | foreach {
	if ($_.Address -notmatch "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$") {
		throw '"'+[string]$_.Address + '" does not look like an IP address'
	}
	if (! $_.Secret) {
		throw 'No secret defined for Address "'+$_.Address+'"'
	}
}

#$newClientsCSV | foreach { Write-Host $_.Address $_.Name }

foreach ($npsHost in $npsServers) {

	## Get current list of clients by Get-NpsRadiusClient, and
	## if the new client doesn't already exist, 
	## add it by New-NpsRadiusClient.

	Write-Host "Getting current NPS Clients from" $npsHost
	$clients = Invoke-Command -ComputerName $npsHost -ScriptBlock { Get-NpsRadiusClient }
	#Write-Host "NPS Clients of" $npsHost ":"
	#foreach ($client in $clients) { $client }

	foreach ($newClient in $newClientsCSV) {
		if (($clients | Where-Object {$_.Address -eq $newClient.Address}) -ne $null) {
			Write-Host "Client" $newClient.Address "exists, skipping"
			continue
		}
		## $newClient is a new client, add it
		[string]$name = $newClient.Name
		if ( ! $name ) {$name = $newClient.Address}
		Write-Host "Adding new client" $newClient.Address "as" $name

		Invoke-Command -ComputerName $npsHost -ScriptBlock {
			param([string]$name, [string]$Address, [string]$secret)
			New-NpsRadiusClient -Name $name -Address $Address -SharedSecret $secret
		} -ArgumentList $name, $newClient.Address, $newClient.Secret > $null
	}
}

Write-Host "`r`nClose this window after examining the logs above.`r`n"

