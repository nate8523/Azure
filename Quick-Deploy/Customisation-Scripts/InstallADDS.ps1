#Record Deplyment Details
$Logpath = "C:\Logs"
mkdir $Logpath
Start-Transcript -Path "$LogPath\AD-Deploy.log" -Append

#Install AD Role
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementtools

$DomainName=$args[0]

# Configure forest deployment parameters
$SafeModePassword = ConvertTo-SecureString -String "ADDSRMP@ssw0rd" -AsPlainText -Force
$ADParameters = @{
    CreateDnsDelegation             = $false
    DomainName                      = $DomainName
    NoRebootOnCompletion            = $true
    SafeModeAdministratorPassword   = $SafeModePassword
    Force                           = $true
    Verbose                         = $true
}
# Install domain controller and DNS with new forest
Install-ADDSForest @ADParameters
        
Stop-Transcript

# Schedule restart after script finishes
Invoke-Expression "shutdown /r /t 5"

<#
#Create NEW AD Forest and Domain
param ($DomainFQDN)
param ($DSRMPassword)
$DomainNetBios    =  $DomainFQDN.Split('.') | Select-Object -First 1
$SafeModePassword = ConvertTo-SecureString $DSRMPassword -AsPlainText -Force
Install-ADDSForest -CreateDnsDelegation:$false -DatabasePath C:\Windows\NTDS -DomainMode WinThreshold -DomainName $DomainFQDN -DomainNetbiosName $DomainNetBios -ForestMode WinThreshold -InstallDns:$true -LogPath C:\Windows\NTDS -NoRebootOnCompletion:$true -SafeModeAdministratorPassword $SafeModePassword -SysvolPath C:\Windows\SYSVOL -Force:$true
#>

  # DatabasePath = "C:\Windows\NTDS"
    # DomainMode = "WinThreshold"
    # DomainName = $DomainFQDN
    # DomainNetbiosName = $DomainNetBios
    # ForestMode = WinThreshold
    # InstallDns = $true 
    # LogPath C:\Windows\NTDS
    # SysvolPath = C:\Windows\SYSVOL