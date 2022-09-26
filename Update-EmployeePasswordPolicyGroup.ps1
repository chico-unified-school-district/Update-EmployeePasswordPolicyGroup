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
 [Parameter(Mandatory = $True)]
 [Alias('DCs')]
 [string[]]$DomainControllers,
 [Parameter(Mandatory = $True)]
 [Alias('ADCred')]
 [System.Management.Automation.PSCredential]$ADCredential,
 [Parameter(Mandatory = $false)]
 [Alias('wi')]
 [SWITCH]$WhatIf
)

# Imported Functions
. .\lib\Add-Log.ps1
. .\lib\Clear-SessionData.ps1
. .\lib\New-ADSession.ps1
. .\lib\Select-DomainController.ps1
. .\lib\Show-TestRun.ps1

Show-TestRun
Clear-SessionData

$dc = Select-DomainController $DomainControllers
$adCmdLets = 'Get-ADUser', 'Get-ADGroupMember', 'Add-ADGroupMember'

Add-Log info 'begin checking group membership'
New-ADSession -dc $dc -cmdlets $adCmdLets -cred $ADCredential
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

Clear-SessionData
Show-TestRun