Write-Host "----------------------------------"
Write-Host "|             NEW USER SCRIPT    |"
Write-Host "----------------------------------"
#TEST
Write-Host "Be advised this script is unforgiving of errors. You will be prompted to login, use admin acct where possible"
Write-Host "You will have to enter creds a few times, having your 2 password on your clipboard is helpful."
#Clean up past sessions
Get-PSSession | Remove-PSSession
#Pre-requisites
Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
#Install-Module MSOnline
Write-Host "."
#Install-Module AzureADPreview
Write-Host ".."
Import-Module ActiveDirectory
Write-Host "..."
Import-Module ExchangeOnlineManagement
Write-Host "...."

Write-Host "Modules loaded"

$Cred = Read-Host -Prompt "Please enter your admin username"

Connect-ExchangeOnline -ShowBanner:$false #-Credential $Cred -ShowProgress $true #Connects to Exchange to enable MB creation
#New-ManagementRoleAssignment -Role "Mailbox Import Export" –User bcc\$Cred

Write-Host "1 for dom1"
Write-Host "2 for dom2"
Write-Host "3 for dom3"

Do { $choice = read-host -prompt "Please choose a domain"}
while (( $choice -gt 3 ) -or ( $choice -lt 1 )) 

#Beginning user creation
$User = Read-Host -Prompt 'Enter the username of the employee you wish to create, e.g. jsmith' 
$Fname = Read-Host -Prompt 'Enter the FIRST name of the employee you wish to create, e.g. John' 
$Lname = Read-Host -Prompt 'Enter the LAST name of the employee you wish to create, e.g. Smith' 
$Dname = Read-Host -Prompt 'Enter the display name of the employee you wish to create, e.g. John Smith' 
$NUser = $User
$Midinit = ''

#Checking if user exists in AD, prompting for a middle initial if so.
$QName = Get-ADUser -Filter {sAMAccountName -eq $User}
If ($QName -eq $Null) {
    Write-Host "User does not exist in AD, you may continue"
}
    Else {$Midinit = Read-Host -Prompt "User exists in AD, please enter a middle initial in UPPERCASE to differentiate. e.g. B "}

#Will need a string manipulator here to lower the case of the middle initial without changing Midinit, then to add the initial to the 1 index of the string. then modify User (if needed)
$FMUser = $User.Substring(0,1)
$LMUser = $User.Substring(1)
$MMIUser = $Midinit.ToLower()
$MUser = $FMUser + $MMIUser + $LMUser
$User = $MUser

If ($Midinit -eq "") {
    $Dname = $Dname
    }
    Else { $Dname = $FName + " " + $Midinit + " " + $LName }


#Continuing user creation
$Mbox = $User + '@email.com'
$Radd = $user + '@or.mail.onmicrosoft.com'
$password = (ConvertTo-SecureString -string <password> -AsPlainText -Force)
$OU = 'fqdn/ou' #CN=$User,OU=,DC=local

#Step 1. Create 365 MB
$OnPrem = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://<Exchange FQDN>/powershell -Authentication Kerberos
Import-PSSession $OnPrem -DisableNameChecking -AllowClobber | Out-Null
New-RemoteMailbox -Name $Dname -FirstName $Fname -LastName $Lname -DisplayName $Dname -SamAccountName $User -UserPrincipalName $Mbox -PrimarySmtpAddress $Mbox -Password $password -OnPremisesOrganizationalUnit $OU -ResetPasswordOnNextLogon:$true #-DomainController $Server
#Enable-RemoteMailbox $Dname -RemoteRoutingAddress $Radd

Write-Host "Got through Mailbox creation"

#Works when run as Admin in PS on VPC logged in as 2 acct
#New-ADUser -Name $DName -Initials $Midinit -samAccountName $User -UserPrincipalName $Mbox -GivenName $Fname -Surname $Lname -DisplayName $Dname -EmailAddress $Mbox
#Write-Host "Got through New-ADUser"

#STEP 3. Force AD Sync on <azure box>
Write-Host "Beginning DirSync"

Invoke-Command -ComputerName <azure box> -Credential bcc\$Cred -ScriptBlock {
	Import-Module ADSync
	Start-ADSyncSyncCycle -PolicyType Delta
    }

Write-Host "DirSync running, then waiting 120 seconds due to newfound inefficiency in the system."

Start-Sleep -s 120

$userInput = Read-Host -Prompt "Press any key AFTER checking 365 to verify mailbox was created."

#STEP 4. Join the default groups - BCC
if ($choice -eq "1") {
Add-ADGroupMember -Identity "Group" -Members $User
}
    else{}

Write-Host "Got through new default groups"

#Set OU as SysadminTest
Get-ADUser $User| Move-ADObject -TargetPath 'OU=,DC=local'

#More user input or department
#$Description = Read-Host -Prompt 'Please enter an AD description or department for the user'
#Set-ADUser -Identity $User -Description $Description
#Set-ADUser -Identity $User -Department $Description
#$Office = Read-Host -Prompt  'Please enter the office location for the user'
#Set-ADUser -Identity $User -Office $Office
$Title = Read-Host -Prompt 'Please enter their job title'
#Set-ADUser -Identity $User -Title $Title
$Manager = Read-Host -Prompt 'Please enter their manager USERname (e.g. sjohnson)'
Set-ADUser -Identity $User -Manager $Manager
if ($choice -eq "1") {
Set-ADUser -Identity $User -Company 'Thing'
}
    else {}
$employeeID = Read-Host -Prompt 'Please enter their employee ID number'
Set-ADUser -Identity $User -EmployeeID $employeeID

#Set login script and H drive
if ($choice -eq "1" ) {
Set-ADUser -Identity $User –scriptPath “logon.bat” 
Set-ADUser -Identity $User -HomeDirectory \\unc\to\homedir -HomeDrive H;
}
    elseif ($choice -eq "2") {
    Set-ADUser -Identity $User –scriptPath “other.bat” 
    Set-ADUser -Identity $User -HomeDirectory \\\unc\to\homedir\$User -HomeDrive H;
    }
        else{
        #Set-ADUser -Identity $User –scriptPath “.bat” 
        Set-ADUser -Identity $User -HomeDirectory \\unc\to\homedir\user\$User -HomeDrive H;
        }

Write-Host "Employee creation successful. Beginning license portion. You will be prompted to login again."

#$delay = Get-Random -Minimum 95 -Maximum 115
#while ($delay -ge 0)
#{
#  start-sleep 1
#  Write-Host "Seconds Remaining: " $delay
#  $delay -= 1
#}

#STEP 5. Licensing.

$licans = Read-host -Prompt "Do you want to assign an Office license to this user? Y/N "
$licans = $licans.ToLower()

if ($licans -eq "y") { 
    Connect-MsolService
    Write-Host $User
    Set-MsolUser -UserPrincipalName $MBox -UsageLocation "US" -BlockCredential $false

    $LOF = New-MsolLicenseOptions -AccountSkuId "SKU"#"" -DisabledPlans
    $LOS = New-MsolLicenseOptions -AccountSkuId "SKU"#"" -DisabledPlans 
    $LOE = New-MsolLicenseOptions -AccountSkuId "SKU"

    #Below works but hopefully replaced by the subsequent foreach
    #$Ulic = Read-Host -Prompt "Please select a license for the user. Choices are G1 and G3. The F3 is coming soon"
    #$Ulic = $Ulic.ToUpper()
    #switch ($Ulic)
    #{
    #    F3 {"F3"}
    #    G1 {"G1"} 
    #    G3 {"G3"} 
    #}

    $jobmap = import-csv -path \\unc\to\Scripts\title-365-license-map.csv

    (import-csv \\unc\to\Scripts\title-365-license-map.csv -Delimiter ',') | ForEach-Object {

    foreach ($row in $jobmap){
        if ($row.jtitle -like $title) {
            $Ulic = $row.jlic
        break
            }
    }
    }
    Write-Host "The license applied will be" $Ulic

    If ($Ulic -eq 'F3') {Set-MsolUserLicense -UserPrincipalName $MBox -AddLicenses "SKU" -LicenseOptions $LOF}
        Elseif ($Ulic -eq 'G1') {Set-MsolUserLicense -UserPrincipalName $MBox -AddLicenses "SKU" -LicenseOptions $LOS}
            Elseif ($Ulic -eq 'G3'){Set-MsolUserLicense -UserPrincipalName $MBox -AddLicenses "SKU" -LicenseOptions $LOE}
                Else {}
}
#If ($Ulic -eq '1') {Get-Mailbox -Identity $MBox | Enable-Mailbox -Archive}
#    Else {}

#Set-ADAccountPassword -Identity $User -NewPassword $password
Enable-RemoteMailbox -Identity $Mbox -Archive
Enable-ADAccount -Identity $User
#Set-ADUser -Identity $User -HomeDirectory \\unc\to\$User -HomeDrive H;
if ($choice -eq "1" ) {
NEW-ITEM –path "\\unc\to\$User" -type directory -force
}
#start-process 'icacls.exe' -ArgumentList '"\\unc\to\$User" /T /grant $User:F'
if ($choice -eq "1" ) {
$Acl = Get-Acl "\\unc\to\$User"
$Ar = New-Object System.Security.AccessControl.FileSystemAccessRule("$User", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
$Acl.SetAccessRule($Ar)
Set-Acl "\\unc\to\$User" $Acl
}
    #elseif ($choice -eq "2") {
    #$Acl = Get-Acl "\\unc\to\$User"
    #$Ar = New-Object System.Security.AccessControl.FileSystemAccessRule("$User", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
    #$Acl.SetAccessRule($Ar)
    #Set-Acl "\\unc\to\$User" $Acl
    #}
            #else{
            #$Acl = Get-Acl "\\unc\to\user\$User"
            #$Ar = New-Object System.Security.AccessControl.FileSystemAccessRule("$User", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
            #$Acl.SetAccessRule($Ar)
            #Set-Acl "\\unc\to\user\$User" $Acl
            #}


Write-Host "User and mailbox creation complete."
Get-PSSession | Remove-PSSession