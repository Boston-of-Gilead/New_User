
#Warn
Write-Host "This script is based on 'B.docx' located in EIT documentation. Also be advised this script is unforgiving of errors. You will be prompted to login, use admin acct where possible"
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
Write-Host "....."
#Gets DN without CN
function Get-ADLocationPath {
    param (
        $FindThisGuy
    )
    $UserObj = Get-ADUser $FindThisGuy -Properties CN
    $CN = $UserObj.CN
    $DN = $UserObj.DistinguishedName
    $DN.Replace("CN=$CN,","")
}

Write-Host "Functions loaded"

#$dirCred = Get-Credential
$Cred = "admin" #Read-Host -Prompt "Please enter your admin username"
$mCred = $Cred + "@<>.net"
$aPassword = "password" #read-host -Prompt "Please enter your admin password" -AsSecureString
$encpassword = convertto-securestring $aPassword -asplaintext -force
$Cred2 = new-object system.management.automation.pscredential($Cred,$encpassword)
$Cred3 = new-object system.management.automation.pscredential($mCred,$encpassword)

Connect-ExchangeOnline -ShowBanner:$false -Credential $Cred3 -ShowProgress $true #Connects to Exchange to enable MB creation

Write-Host "1 for <>"
Write-Host "2 for <>"
Write-Host "3 for <>"

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
$Mbox = $User + '@<>.net'
$Radd = $user + '@tenant.mail.onmicrosoft.com'
$<> = $User + '@<>.org'
$<> = $User + '@<>.org'
$password = (ConvertTo-SecureString -string password -AsPlainText -Force)
$OU = '<>.<>.local//OU' 

#Step 1. Create 365 MB
$OnPrem = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://FQDN.local/powershell -Authentication Kerberos 
Import-PSSession $OnPrem -DisableNameChecking -AllowClobber | Out-Null
New-RemoteMailbox -Name $Dname -FirstName $Fname -LastName $Lname -DisplayName $Dname -SamAccountName $User -UserPrincipalName $Mbox -PrimarySmtpAddress $Mbox -OnPremisesOrganizationalUnit $OU -Password $password -ResetPasswordOnNextLogon:$true #-DomainController $Server
#Enable-RemoteMailbox $Dname -RemoteRoutingAddress $Radd

Write-Host "Got through Mailbox creation"

#STEP 3. Force AD Sync on server
Write-Host "Beginning DirSync"

Invoke-Command -ComputerName server -Credential $dirCred -ScriptBlock {
	Import-Module ADSync
	Start-ADSyncSyncCycle -PolicyType Delta
    }

For ($i=120; $i -ge 0; $i–-) {  
    Write-Progress -Activity "120s pause while 365 catches up to DirSync." -SecondsRemaining $i
    Start-Sleep 1
}

$userInput = Read-Host -Prompt "Press any key AFTER checking 365 to verify mailbox was created."

#STEP 4. Join the default groups - <>
if ($choice -eq "1") {
Add-ADGroupMember -Identity "group" -Members $User
}
    else{}

Write-Host "Got through new default groups"

#Set OU as SysadminTest
Get-ADUser $User| Move-ADObject -TargetPath 'OU=,DC=<>,DC=<>,DC=local'

#More user input or department
$Title = Read-Host -Prompt 'Please enter their job title'
#Set-ADUser -Identity $User -Title $Title
$Manager = $null
$Manager = Read-Host -Prompt 'Please enter their manager USERname (e.g. sjohnson)'
Set-ADUser -Identity $User -Manager $Manager
$bosspath = Get-ADLocationPath $Manager

if ($choice -eq "1") {
Set-ADUser -Identity $User -Company 'asdf'
}
    else {}
$employeeID = Read-Host -Prompt 'Please enter their employee ID number'
Set-ADUser -Identity $User -EmployeeID $employeeID

#Set email and proxies for <>12
if ($choice -eq "2") {
    Set-ADUser -Identity $User -EmailAddress $<> -UserPrincipalName $<> 
    Set-ADUser -Identity $User -Add @{proxyAddresses = "SMTP:" + $<> }
    Set-ADUser -Identity $User -Add @{proxyAddresses = "smtp:" + $Mbox }
}
    elseif ($choice -eq "3") {
        Set-ADUser -Identity $User -Add @{proxyAddresses = "SMTP:" + $<> }
        Set-ADUser -Identity $User -Add @{proxyAddresses = "smtp:" + $Mbox }
    }


#Set login script and H drive
if ($choice -eq "1" ) {
Set-ADUser -Identity $User –scriptPath “logon.bat” 
Set-ADUser -Identity $User -HomeDirectory \\server\home\$User -HomeDrive H;
}
    elseif ($choice -eq "2") {
    Set-ADUser -Identity $User –scriptPath “<>logon.bat” 
    Set-ADUser -Identity $User -HomeDirectory \\server\home\$User -HomeDrive H;
    }
        else{
        #Set-ADUser -Identity $User –scriptPath “.bat” 
        Set-ADUser -Identity $User -HomeDirectory \\server\user\$User -HomeDrive H;
        }

Write-Host "Employee creation successful. Beginning license portion. You will be prompted to login again."

#STEP 5. Licensing.

$licans = Read-host -Prompt "Do you want to assign an Office license to this user? Y/N "
$licans = $licans.ToLower()

if ($licans -eq "y") { 
    Connect-MsolService -Credential $Cred3
    Write-Host $User
    Set-MsolUser -UserPrincipalName $MBox -UsageLocation "US" -BlockCredential $false

    #License assignment switchcase. 

    $LOF = New-MsolLicenseOptions -AccountSkuId "<>:DESKLESSPACK_<>"#"<>:EXCHANGEARCHIVE_ADDON_<>" -DisabledPlans "FLOW_FREE_o365_P2", "POWERAPPS_O365_P2", "STREAM_O365_F3"
    $LOS = New-MsolLicenseOptions -AccountSkuId "<>:STANDARDPACK_<>"#"<>:EXCHANGEARCHIVE_ADDON_<>" -DisabledPlans "FLOW_FREE_o365_P2", "POWERAPPS_o365_P2", "STREAM_O365_G1"
    $LOE = New-MsolLicenseOptions -AccountSkuId "<>:ENTERPRISEPACK_<>"

    $jobmap = import-csv -path \\path_to\title-365-license-map.csv

    (import-csv \\path_to\title-365-license-map.csv -Delimiter ',') | ForEach-Object {

    foreach ($row in $jobmap){
        if ($row.jtitle -like $title) {
            $Ulic = $row.jlic
        break
            }
    }
    }
    Write-Host "The license applied will be" $Ulic

    If ($Ulic -eq 'F3') {Set-MsolUserLicense -UserPrincipalName $MBox -AddLicenses "<>:DESKLESSPACK_<>" -LicenseOptions $LOF}
        Elseif ($Ulic -eq 'G1') {Set-MsolUserLicense -UserPrincipalName $MBox -AddLicenses "<>:STANDARDPACK_<>" -LicenseOptions $LOS}
            Elseif ($Ulic -eq 'G3'){Set-MsolUserLicense -UserPrincipalName $MBox -AddLicenses "<>:ENTERPRISEPACK_<>" -LicenseOptions $LOE}
                Else {}
}

#Set-ADAccountPassword -Identity $User -NewPassword $password
Enable-RemoteMailbox -Identity $Mbox -Archive
Enable-ADAccount -Identity $User
#Set-ADUser -Identity $User -HomeDirectory \\server\home\$User -HomeDrive H;

if ($choice -eq "1" ) {
NEW-ITEM –path "\\server\home\$User" -type directory -force
}

if ($choice -eq "1" ) {
$Acl = Get-Acl "\\server\home\$User"
$Ar = New-Object System.Security.AccessControl.FileSystemAccessRule("$User", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
$Acl.SetAccessRule($Ar)
Set-Acl "\\server\home\$User" $Acl
}

#Moves user to their boss's OU
if ($Manager -ne $null) {
    Get-ADUser $User | Move-ADObject -TargetPath $bosspath
}
else {
    Write-Host "Since no manager was specified, the new user is in test folder, and will need to be manually moved to the correct OU."
}

Write-Host "User and mailbox creation complete. Please remove Flow Free, PowerApps, and Stream (hoping to resolve this in future versions)."