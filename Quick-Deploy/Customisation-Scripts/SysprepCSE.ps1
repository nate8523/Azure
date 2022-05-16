<#	
	.NOTES
	===========================================================================
	 Created by:   	Nathan Carroll
	 Organization: 	M247
     Created on:    17 July 2020
     Version:       1.0
	 Filename:     	Resize-VM-Data-Disk.ps1
	===========================================================================
	
    .DESCRIPTION
		This script is used to sysprep a windows VM
    
    .DISCLAIMER
        This script is provided AS IS without warranty of any kind. In no event shall its author,
        or anyone else involved in the creation, production, or delivery of the scripts be liable
        for any damages whatsoever (including, without limitation, damages for loss of business profits,
        business interruption, loss of business information, or other pecuniary loss) arising out
        of the use of or inability to use the scripts or documentation, even if the author has
        been advised of the possibility of such damages. 

#>

#Record Deployment Details
$Logpath = "C:\Logs"
if ((test-path C:\Logs) -eq $false) {
    new-item -ItemType Directory -path "C:\" -name "Logs" | Out-Null
}

Start-Transcript -Path "$LogPath\SysprepCSE.log" -Append

#Run Sysprep
Start-Process -filepath 'c:\Windows\system32\sysprep\sysprep.exe' -ErrorAction Stop -ArgumentList '/generalize', '/oobe', '/mode:vm', '/shutdown'


Stop-Transcript