#======1.1 MS share for personeel======
#region MS

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
#======1.2 MS P:-public
#region Disk mapping

New-PSDrive -Name "P" -PSProvider FileSystem -Root "C:\Public" -Persist

#endregion
#======Optional======
#region Intranet webserver

#Installing IIS on MS
Install-WindowsFeature -name Web-Server -IncludeManagementTools

#Intranet folder creation
New-Item -ItemType directory -Path C:\intranet\intranet

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
ConvertTo-Html -Body $html -Title IIS | Out-File C:\intranet\intranet\index.html

#creating new site
New-WebSite -Name intranet -IPAddress 192.168.1.4 -Port 80 -HostHeader intranet.mijnschool.be -PhysicalPath "C:\intranet\intranet"
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