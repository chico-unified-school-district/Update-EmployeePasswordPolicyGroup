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

function Add-ADPasswordGRoupMembers ($group, [pscredential]$cred) {
 process {
  Write-Host ('{0},{1},{2}' -f $MyInvocation.MyCommand.Name, $group, $_) -F Blue
  Add-ADGroupMember -Identity $group -Members $_ -Credential $cred -WhatIf:$WhatIf
 }
}

function Get-ADGroupMemberSams ([pscredential]$cred) {
 begin {
  $groupSams = @()
 }
 process {
  $groupSams += (Get-ADGroupMember -Identity $_ -Credential $cred).SamAccountName
 }
 end {
  $results = $groupSams | Sort-Object -Unique
  Write-Host ('{0},Count: {1}' -f $MyInvocation.MyCommand.Name, @($results).count) -F Green
  $results
 }
}

function Get-ADStaffSams ($ou, $filter, [pscredential]$cred) {
 $aDParams = @{
  Filter     = "mail -like '*@*' -and employeeID -like '*'"
  Searchbase = $ou
  Properties = 'employeeId', 'Description', 'Title'
  Credential = $cred
 }
 $results = (Get-ADUser @aDParams | Where-Object {
   $_.employeeId -match '\d{4,}' -and
   ($_.Description -notmatch $Filter -and $_.Title -notmatch $filter)
  }).samAccountName

 Write-Host ('{0},Count: {1}' -f $MyInvocation.MyCommand.Name, @($results).count) -F Green
 $results
}

# ============================================================================================
Import-Module -Name CommonScriptFunctions
Import-Module -Name ActiveDirectory -Cmdlet Add-ADGroupMember, Get-ADGroupMember, Get-ADUser -WarningAction SilentlyContinue -ErrorAction Stop

if ($WhatIf) { Show-TestRun }
Show-BlockInfo main

$groupSams = $Groups | Get-ADGroupMemberSams -cred $ADCredential
$staffSams = Get-ADStaffSams -ou $SearchBase -filter $Filter -cred $ADCredential

$missingSams = Compare-Object -ReferenceObject $groupSams -DifferenceObject $staffSams |
 Where-Object { $_.SideIndicator -eq '=>' }

if ($missingSams) { $missingSams.InputObject | Add-ADPasswordGRoupMembers -group $TargetGroup -cred $ADCredential }

$result = Get-ADGroupMember -Identity $TargetGroup -Credential $ADCredential
Write-Host ('{0},Count: {1}' -f $MyInvocation.MyCommand.Name, @($result).count) -F Green

Show-BlockInfo end
if ($WhatIf) { Show-TestRun }