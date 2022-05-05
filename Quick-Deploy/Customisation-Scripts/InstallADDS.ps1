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
    ForestMode                      = "WinThreshold"
    DomainMode                      = "WinThreshold"
    # DomainNetbiosName = $DomainNetBios
    InstallDns                      = $true 
    LogPath                         = "C:\Windows\NTDS"
    SysvolPath                      = "C:\Windows\SYSVOL"
    DatabasePath                    = "C:\Windows\NTDS"
}
# Install domain controller and DNS with new forest
Install-ADDSForest @ADParameters
        
Stop-Transcript

# Schedule restart after script finishes
Invoke-Expression "shutdown /r /t 5"

<#
$DomainNetBios    =  $DomainFQDN.Split('.') | Select-Object -First 1
#>