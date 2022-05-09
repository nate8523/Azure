<#	
	.NOTES
	===========================================================================
	 Created by:   	Nathan Carroll
	 Organization: 	M247
     Created on:    05 Aug 2020
     Version:       1.0
	 Filename:     	Configure-Veeam-Backup.ps1
	===========================================================================
	
    .DESCRIPTION
		This script is used to provision a nsecondary disk attached to the QD-Veeam-BR Script 
        and configure the disk as a veeam backup storage repository.
    
    .DISCLAIMER
        This script is provided AS IS without warranty of any kind. In no event shall its author,
        or anyone else involved in the creation, production, or delivery of the scripts be liable
        for any damages whatsoever (including, without limitation, damages for loss of business profits,
        business interruption, loss of business information, or other pecuniary loss) arising out
        of the use of or inability to use the scripts or documentation, even if the author has
        been advised of the possibility of such damages. 

#>

# Veeam Deploy
initialize-Disk -Number 2 -PartitionStyle GPT
Get-Disk -Number 2 | New-Volume -Filesystem ReFS -DriveLetter F -AllocationUnitSize 64KB -FriendlyName "Veeam Backups"
Add-VBRBackupRepository -Name "Local Backups" -Folder "F:\" -Type WinLocal