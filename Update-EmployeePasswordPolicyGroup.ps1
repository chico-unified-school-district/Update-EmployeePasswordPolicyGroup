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
 [string]$SearchBase,
 [Parameter(Mandatory = $True)]
 [string[]]$Groups,
 [Parameter(Mandatory = $True)]
 [string]$TargetGroup,
 [Parameter(Mandatory = $false)]
 [string]$Filter,
 [Alias('wi')]
 [SWITCH]$WhatIf
)

function Add-ADPasswordGRoupMembers ($group) {
 process {
  Write-Host ('{0},{1}' -f $MyInvocation.MyCommand.Name, $_) -F Blue
  Add-ADGroupMember -Identity $group -Members $_ -WhatIf:$WhatIf
 }
}

function Get-ADGroupMemberSams {
 begin {
  $groupSams = @()
 }
 process {
  $groupSams += (Get-ADGroupMember -Identity $_).SamAccountName
 }
 end {
  $results = $groupSams | Sort-Object -Unique
  Write-Host ('{0},Count: {1}' -f $MyInvocation.MyCommand.Name, @($results).count) -F Green
  $results
 }
}

function Get-ADStaffSams ($ou, $filter) {
 $aDParams = @{
  Filter     = "mail -like '*@*' -and employeeID -like '*'"
  Searchbase = $ou
  Properties = 'employeeId', 'Description', 'Title'
 }
 $results = (Get-Aduser @aDParams | Where-Object {
   $_.employeeId -match "\d{4,}" -and
   ($_.Description -notmatch $Filter -and $_.Title -notmatch $filter)
  }).samAccountName

 Write-Host ('{0},Count: {1}' -f $MyInvocation.MyCommand.Name, @($results).count) -F Green
 $results
}

# ============================================================================================
Import-Module -Name CommonScriptFunctions

if ($WhatIf) { Show-TestRun }
Show-BlockInfo main

$cmdLets = 'Get-ADUser', 'Get-ADGroupMember', 'Add-ADGroupMember'
Connect-ADSession -DomainControllers $DomainControllers -Cmdlets $cmdLets -Credential $ADCredential

$groupSams = $Groups | Get-ADGroupMemberSams
$staffSams = Get-ADStaffSams $SearchBase $Filter

$missingSams = Compare-Object -ReferenceObject $groupSams -DifferenceObject $staffSams |
 Where-Object { $_.SideIndicator -eq '=>' }

$missingSams.InputObject | Add-ADPasswordGRoupMembers $TargetGroup

Show-BlockInfo end
if ($WhatIf) { Show-TestRun }