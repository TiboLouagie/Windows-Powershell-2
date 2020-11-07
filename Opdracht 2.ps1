#======1.1======
#region - MS share for personeel

#Making new folder
New-Item -ItemType directory -Path C:\Public

#Share new folder
New-SmbShare -Name Public -Path C:\Public -FullAccess everyone

#NTFS
    #disable inheritance

    $folder = 'C:\Public'
    $acl = Get-Acl -Path $folder
    $acl.SetAccessRuleProtection($True, $True)
    Set-Acl -Path $folder -AclObject $acl

    #adding personeel

    $Folderpath = 'C:\Public'
    $user_account = 'MIJNSCHOOL\personeel'
    $Acl = Get-Acl $folderpath
    $Ar = New-Object System.Security.AccessControl.FileSystemAccessRule($user_account, "Modify", "ContainerInherit, ObjectInherit", "None", "Allow")
    $Acl.Setaccessrule($Ar)
    Set-Acl $Folderpath $Acl

    #Deleting normal users from NTFS

    $Folderpath='C:\Public'
    $user_account='Users'
    $Acl = Get-Acl $Folderpath
    $Ar = New-Object system.Security.AccessControl.FileSystemAccessRule($user_account, "ReadAndExecute", "ContainerInherit, ObjectInherit", "None", "Allow")
    $Acl.RemoveAccessRuleAll($Ar)
    Set-Acl $Folderpath $Acl
    #testing can be done to use a user account and search for \\MS\Public

#endregion
#======1.2======
#region - MS P:-public Disk mapping

New-PSDrive -Name "P" -PSProvider FileSystem -Root "C:\Public" -Persist

#endregion
#======Optional======
#region - Intranet webserver

#Installing IIS on MS
Install-WindowsFeature -name Web-Server -IncludeManagementTools

#Intranet folder creation
New-Item -ItemType directory -Path C:\webserver\intranet

#html file
$html = @"
<style></style>
</head>
  <body>
  Intranet van de school.
  </body>
</html>
"@

$service = Get-Service | ConvertTo-Html -Fragment
ConvertTo-Html -Body $html -Title IIS | Out-File C:\webserver\intranet\index.html

#Creating new site
New-WebSite -Name intranet -IPAddress 192.168.1.4 -Port 80 -HostHeader intranet.mijnschool.be -PhysicalPath "C:\webserver\intranet"
#Remove-Website -Name intranet

#NDS-record creation (for DC1)
Add-DnsServerResourceRecordA -Name intranet -iPv4Address 192.168.1.4 -ZoneName intranet.mijnschool.be -ComputerName 192.168.1.2 -CreatePtr

#NTFS (back on MS)
    #disable inheritance
    $folder = 'C:\Public'
    $acl = Get-ACL -Path $folder
    $acl.SetAccessRuleProtection($True, $True)
    Set-Acl -Path $folder -AclObject $acl

    #adding personeel
    $Folderpath='C:\Public'
    $user_account='MIJNSCHOOL\personeel'
    $Acl = Get-Acl $Folderpath
    $Ar = New-Object system.Security.AccessControl.FileSystemAccessRule($user_account, "Modify", "ContainerInherit, ObjectInherit", "None", "Allow")
    $Acl.Setaccessrule($Ar)
    Set-Acl $Folderpath $Acl

    #removing Users group
    $Folderpath='C:\inetpub\intranet'
    $user_account='Users'
    $Acl = Get-Acl $Folderpath
    $Ar = New-Object system.Security.AccessControl.FileSystemAccessRule($user_account, "ReadAndExecute", "ContainerInherit, ObjectInherit", "None", "Allow")
    $Acl.RemoveAccessRuleAll($Ar)
    Set-Acl $Folderpath $Acl

    #install windows authentication
    Install-WindowsFeature web-windows-auth
    
    #enable windows authentication
    Set-WebConfigurationProperty -filter "/system.webServer/security/authentication/windowsAuthentication" -name enabled -value true -PSPath "IIS:\" -location 'intranet'
    
    #disable anonymous authentication
    Set-WebConfigurationProperty -filter /system.WebServer/security/authentication/AnonymousAuthentication -name enabled -value false -PSPath "IIS:\" -location 'intranet'

#endregion
#region - Resto webserver

#resto map creation
New-Item -ItemType directory -Path C:\inetpub\resto

#html file
$html = @"
<style></style>
</head>
  <body>
  Resto van de school.
  </body>
</html>
"@

$service = Get-Service | ConvertTo-Html -Fragment
ConvertTo-Html -Body $html -Title IIS | Out-File C:\webserver\resto\index.html

#Creating new site
New-WebSite -Name resto -IPAddress 192.168.1.4 -Port 80 -HostHeader resto.mijnschool.be -PhysicalPath "C:\inetpub\resto"

#DNS-record aanmaken (MOET OP DC1 WORDEN UITGEVOERD)
Add-DnsServerResourceRecordA -Name resto -IPv4Address 192.168.1.4 -ZoneName intranet.mijnschool.be -ComputerName 192.168.1.2 -CreatePtr

#enable windows authentication
Set-WebConfigurationProperty -filter "/system.webServer/security/authentication/windowsAuthentication" -name enabled -value true -PSPath "IIS:\" -location 'resto'

#disable anonymous authentication
Set-WebConfigurationProperty -filter /system.WebServer/security/authentication/AnonymousAuthentication -name enabled -value false -PSPath "IIS:\" -location 'resto'

#endregion
#======2.1======
#region - DC2 Roaming profiles

#https://sid-500.com/2017/08/27/active-directory-configuring-roaming-profiles-using-gui-and-powershell/ 

#Making new folder
New-Item -ItemType direcotry -path C:\Profiles

#Share new folder
New-SmbShare -Name Profiles -Path C:\Profiles -FullAccess Everyone

#Make directory 'hidden'
$f=get-item C:\Profiles -Force
$f.Attributes="Hidden"


#endregion
#======2.2======
#region - Roaming profiles on share -Profiles

#Changing secretary profile path (on DC1)
#Couldn't find a way to change profile path for entire group
Set-ADUser -Identity Annemieke -ProfilePath \\DC2\Profiles\%username%
Set-ADUser -Identity Rozemieke -ProfilePath \\Team08-DC2\profiles\%username%


#endregion