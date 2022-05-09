<#	
	.NOTES
	===========================================================================
	 Created by:   	Nathan Carroll
	 Organization: 	M247
     Created on:    07 June 2020
     Version:       1.0
	 Filename:     	InstallADDS.ps1
	===========================================================================
	
    .DESCRIPTION
		The script installs the ADDS feature and configures a new ADDS Forest and Domain.
    
    .DISCLAIMER
        This script is provided AS IS without warranty of any kind. In no event shall its author,
        or anyone else involved in the creation, production, or delivery of the scripts be liable
        for any damages whatsoever (including, without limitation, damages for loss of business profits,
        business interruption, loss of business information, or other pecuniary loss) arising out
        of the use of or inability to use the scripts or documentation, even if the author has
        been advised of the possibility of such damages. 

#>

# Disable Breaking Change Warnings
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

#Record Deployment Details
$Logpath = "C:\Logs"
if ((test-path C:\Logs) -eq $false) {
  new-item -ItemType Directory -path "C:\" -name "Logs" | Out-Null
}
Start-Transcript -Path "$LogPath\InstallADDS.log" -Append

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
