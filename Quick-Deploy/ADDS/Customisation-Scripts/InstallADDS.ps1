Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementtools

#Create NEW AD Forest and Domain
param ($DomainFQDN)
param ($DSRMPassword)
$DomainNetBios    =  $DomainFQDN.Split('.') | Select-Object -First 1
$SafeModePassword = ConvertTo-SecureString $DSRMPassword -AsPlainText -Force
Install-ADDSForest -CreateDnsDelegation:$false -DatabasePath C:\Windows\NTDS -DomainMode WinThreshold -DomainName $DomainFQDN -DomainNetbiosName $DomainNetBios -ForestMode WinThreshold -InstallDns:$true -LogPath C:\Windows\NTDS -NoRebootOnCompletion:$true -SafeModeAdministratorPassword $SafeModePassword -SysvolPath C:\Windows\SYSVOL -Force:$true