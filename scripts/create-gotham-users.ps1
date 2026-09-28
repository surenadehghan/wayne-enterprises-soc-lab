<#
.SYNOPSIS
    Creates the Wayne Enterprises departments (OUs), employees, and groups in wayne.local.

.DESCRIPTION
    Run on WAYNE-DC01 as a domain admin, in an elevated PowerShell window.
    Safe to run more than once: anything that already exists is skipped.
#>
#Requires -Modules ActiveDirectory

$domain     = Get-ADDomain
$domainDN   = $domain.DistinguishedName
$dnsRoot    = $domain.DNSRoot
$companyOU  = "Wayne Enterprises"
$root       = "OU=$companyOU,$domainDN"

$departments = @("Executive", "Applied Sciences", "IT", "Security", "Finance", "Workstations")

$employees = @(
    @{ Sam = "bwayne";    First = "Bruce";    Last = "Wayne";     Title = "Chief Executive Officer";   Dept = "Executive" }
    @{ Sam = "lfox";      First = "Lucius";   Last = "Fox";       Title = "Chief Technology Officer";  Dept = "Applied Sciences" }
    @{ Sam = "dgrayson";  First = "Dick";     Last = "Grayson";   Title = "Research Engineer";         Dept = "Applied Sciences" }
    @{ Sam = "tdrake";    First = "Tim";      Last = "Drake";     Title = "Systems Administrator";     Dept = "IT" }
    @{ Sam = "bgordon";   First = "Barbara";  Last = "Gordon";    Title = "SOC Analyst";               Dept = "Security" }
    @{ Sam = "jtodd";     First = "Jason";    Last = "Todd";      Title = "Security Engineer";         Dept = "Security" }
    @{ Sam = "skyle";     First = "Selina";   Last = "Kyle";      Title = "Financial Analyst";         Dept = "Finance" }
    @{ Sam = "hdent";     First = "Harvey";   Last = "Dent";      Title = "Legal Counsel";             Dept = "Executive" }
)

$groups = @(
    @{ Name = "Wayne-Executives"; Members = @("bwayne", "hdent") }
    @{ Name = "Wayne-IT-Admins";  Members = @("tdrake") }
    @{ Name = "Wayne-SOC";        Members = @("bgordon", "jtodd") }
)

# --- Departments (OUs) ---
if (-not (Get-ADOrganizationalUnit -LDAPFilter "(ou=$companyOU)" -SearchBase $domainDN -SearchScope OneLevel)) {
    New-ADOrganizationalUnit -Name $companyOU -Path $domainDN
    Write-Host "[+] Created OU: $companyOU" -ForegroundColor Green
}

foreach ($dept in $departments) {
    if (Get-ADOrganizationalUnit -LDAPFilter "(ou=$dept)" -SearchBase $root -SearchScope OneLevel) {
        Write-Host "[=] OU exists: $dept"
    } else {
        New-ADOrganizationalUnit -Name $dept -Path $root
        Write-Host "[+] Created OU: $dept" -ForegroundColor Green
    }
}

# --- Employees ---
$password = Read-Host "Starting password for all Wayne Enterprises employees" -AsSecureString

foreach ($e in $employees) {
    if (Get-ADUser -Filter "SamAccountName -eq '$($e.Sam)'") {
        Write-Host "[=] User exists: $($e.Sam)"
        continue
    }
    New-ADUser `
        -Name              "$($e.First) $($e.Last)" `
        -GivenName         $e.First `
        -Surname           $e.Last `
        -DisplayName       "$($e.First) $($e.Last)" `
        -SamAccountName    $e.Sam `
        -UserPrincipalName "$($e.Sam)@$dnsRoot" `
        -Title             $e.Title `
        -Department        $e.Dept `
        -Company           $companyOU `
        -Path              "OU=$($e.Dept),$root" `
        -AccountPassword   $password `
        -Enabled           $true
    Write-Host "[+] Hired: $($e.First) $($e.Last) ($($e.Title))" -ForegroundColor Green
}

# --- Groups ---
foreach ($g in $groups) {
    if (-not (Get-ADGroup -Filter "Name -eq '$($g.Name)'")) {
        New-ADGroup -Name $g.Name -GroupScope Global -GroupCategory Security -Path $root
        Write-Host "[+] Created group: $($g.Name)" -ForegroundColor Green
    }
    Add-ADGroupMember -Identity $g.Name -Members $g.Members
}

Write-Host "`nGotham is staffed. Open 'Active Directory Users and Computers' to see everyone." -ForegroundColor Cyan
