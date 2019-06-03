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
  [Parameter(Position=0,Mandatory=$True)]
  [Alias('DC','Server')]
  [string]$DomainController,
  [Parameter(Position=1,Mandatory=$True)]
  [Alias('ADCred')]
  [System.Management.Automation.PSCredential]$Credential,
  [Parameter(Position=3,Mandatory=$false)]
  [SWITCH]$WhatIf
 )

$adCmdLets = 'Get-ADUser','Get-ADGroupMember','Add-ADGroupMember'
$adSession = New-PSSession -ComputerName $DomainController -Credential $Credential
Import-PSSession -Session $adSession -Module ActiveDirectory -CommandName $adCmdLets -AllowClobber

$aDParams = @{ 
 Filter = {
   (mail -like "*@*") -and
   (employeeID -like "*")
 }
 Searchbase = 'OU=Employees,OU=Users,OU=Domain_Root,DC=chico,DC=usd'
 Properties = 'employeeId'
}
$staffSams = (Get-Aduser @aDParams | Where-Object{ $_.employeeId -match "\d{4,}" }).samAccountName
$groupSams = (Get-ADGroupMember -Identity 'Employee-Password-Policy').SamAccountName

$missingSams = (Compare-Object -ReferenceObject $groupSams -DifferenceObject $staffSams).InputObject
if ($missingSams) {
 "Missing user objects`:"
 $missingSams
 "Adding missing user objects to Employee-Password-Policy group."
 Add-ADGroupMember -Identity 'Employee-Password-Policy' -Members $missingSams -WhatIf:$WhatIf
} else { "Employee-Password-Policy security group has no missing user objects." }

'Tearing down sessions...'
Get-PSSession | Remove-PSSession