<# 
.SYNOPSIS
.DESCRIPTION
.EXAMPLE
.INPUTS
.OUTPUTS
.NOTES
#>
[cmdletbinding()]
param ( 
 [Parameter(Position = 0, Mandatory = $True)]
 [ValidateScript( { Test-Connection -ComputerName $_ -Quiet -Count 1 })]
 [Alias('DC')]
 [string]$DomainController,
 [Parameter(Position = 1, Mandatory = $True)]
 [Alias('ADCred')]
 [System.Management.Automation.PSCredential]$Credential,
 [Parameter(Position = 3, Mandatory = $false)]
 [SWITCH]$WhatIf
)

$adCmdLets = 'Get-ADUser', 'Get-ADGroupMember', 'Add-ADGroupMember'
$adSession = New-PSSession -ComputerName $DomainController -Credential $Credential
Import-PSSession -Session $adSession -Module ActiveDirectory -CommandName $adCmdLets -AllowClobber | Out-Null

# Imported Functions
. .\lib\Add-Log.ps1

Add-Log info 'begin checking group membership'
$groupSams = (Get-ADGroupMember -Identity 'Employee-Password-Policy').SamAccountName
$aDParams = @{ 
 Filter     = {
  (mail -like "*@*") -and
  (employeeID -like "*")
 }
 Searchbase = 'OU=Employees,OU=Users,OU=Domain_Root,DC=chico,DC=usd'
 Properties = 'employeeId'
}
$staffSams = (Get-Aduser @aDParams | Where-Object { $_.employeeId -match "\d{4,}" }).samAccountName
# if $staffSams has an entry that is missing from $groupsSams then add that entry to the group.
$missingSams = Compare-Object -ReferenceObject $groupSams -DifferenceObject $staffSams | Where-Object { $_.SideIndicator -eq '=>' }
if ($missingSams) {
 foreach ($item in $missingSams) {
  Add-Log add $item.InputObject $WhatIf
  Add-ADGroupMember -Identity 'Employee-Password-Policy' -Members $item.InputObject -WhatIf:$WhatIf
 }
}
else { Add-Log info 'Employee-Password-Policy security group has no missing user objects' }

$groupSams = (Get-ADGroupMember -Identity 'Employee-Password-Policy').SamAccountName
Add-Log info ('Total Group Members : {0}' -f $groupSams.count)

Add-Log script 'Tearing down sessions...'
Get-PSSession | Remove-PSSession