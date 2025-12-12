<#
.Synopsis
    User management utilities for Active Directory.

.DESCRIPTION
    Contains functions to manage Active Directory users.

.EXAMPLE
    Import-Module .\Users.ps1
#>


function New-XanaduUser {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Nom,
        [Parameter(Mandatory=$true)]
        [string]$Prenom,
        [Parameter(Mandatory=$true)]
        [string]$Group,
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    $SamAccountName = "$($Prenom.ToLower()).$($Nom.ToLower())"
    $DisplayName    = "$Prenom $Nom"
    $UserPrincipalName = "$SamAccountName@$((Get-ADDomain).DNSRoot)"
    $Path              = "OU=$Group,$Path"

    $existingUser = Get-ADUser -Filter { SamAccountName -eq $SamAccountName } -ErrorAction SilentlyContinue
    if ($existingUser) {
        Write-Host "L'utilisateur '$SamAccountName' existe déjà dans Active Directory." -ForegroundColor Yellow
        return $null
    }

    $year = Get-Date -Format "yyyy"

    try {
        # Write-Host New-ADUser `
        $newUser = New-ADUser `
            -Name $DisplayName `
            -GivenName $Prenom `
            -Surname $Nom `
            -SamAccountName $SamAccountName `
            -UserPrincipalName $UserPrincipalName `
            -Path $Path `
            -AccountPassword (ConvertTo-SecureString "Xanadu$year!" -AsPlainText -Force) `
            -Enabled $true `
            -ChangePasswordAtLogon $true

        Write-Host "Utilisateur '$DisplayName' créé avec succès dans le groupe '$Group'." -ForegroundColor Green
        return $newUser
    }
    catch {
        Write-Host "Erreur lors de la création de l'utilisateur '$DisplayName': $_" -ForegroundColor Red
        return $null
    }
}

function Select-XanaduUser {
    <#
    .SYNOPSIS
        Sélection interactive et récursive d'un utilisateur dans l'arborescence AD.
    .DESCRIPTION
        Permet de naviguer dans les OU avec possibilité de revenir en arrière,
        et de sélectionner un utilisateur.
    .EXAMPLE
        $user = Select-XanaduUser
    #>
    [CmdletBinding()]
    param(
        [string]$SearchBase
    )

    if (-not $SearchBase) {
        $DomainDN = (Get-ADDomain).DistinguishedName
        $SearchBase = "OU=Users,OU=Xanadu,$DomainDN"
    }

    $currentOUName = ($SearchBase -split ',')[0] -replace '^OU=', ''

    $ouParams = @{
        Filter      = '*'
        SearchBase  = $SearchBase
        SearchScope = 'OneLevel'
        ErrorAction = 'SilentlyContinue'
    }

    $subOUs = Get-ADOrganizationalUnit @ouParams |
        Select-Object -ExpandProperty Name |
        Sort-Object


    $userParams = @{
        Filter      = '*'
        SearchBase  = $SearchBase
        SearchScope = 'OneLevel'
        Properties  = 'DisplayName','SamAccountName'
        ErrorAction = 'SilentlyContinue'
    }

    $usersInOU = Get-ADUser @userParams |
        Sort-Object DisplayName

    $options = @()

    $DomainDN = (Get-ADDomain).DistinguishedName
    $RootOU = "OU=Users,OU=Xanadu,$DomainDN"
    foreach ($ou in $subOUs) {
        $options += "[OU] $ou"
    }
    foreach ($user in $usersInOU) {
        $displayText = if ($user.DisplayName) { $user.DisplayName } else { $user.Name }
        $options += "[User] $displayText ($($user.SamAccountName))"
    }
    if ($SearchBase -ne $RootOU) {
        $options += "[..] Retour"
    }

    if ($options.Count -eq 0 -or ($options.Count -eq 1 -and $options[0] -eq "[..] Retour")) {
        if ($options.Count -eq 1) {
            Write-Host "Aucun utilisateur ni sous-groupe dans '$currentOUName'." -ForegroundColor Yellow
        } else {
            Write-Host "Aucun élément trouvé." -ForegroundColor Red
            return $null
        }
    }

    $selection = Select-FromList -Title "=== $currentOUName ===" -Options $options

    if ($selection -eq "[..] Retour" -or $selection -eq "Quitter") {
        if ($SearchBase -eq $RootOU) {
            Write-Host "Annulation" -ForegroundColor Yellow
            return $null
        }
        $parentOU = ($SearchBase -split ',', 2)[1]
        return Select-XanaduUser -SearchBase $parentOU
    }

    if ($selection -match '^\[OU\] (.+)$') {
        $selectedOUName = $Matches[1]
        $newSearchBase = "OU=$selectedOUName,$SearchBase"
        return Select-XanaduUser -SearchBase $newSearchBase
    }

    if ($selection -match '^\[User\] .+ \((.+)\)$') {
        $selectedSam = $Matches[1]
        $selectedUser = Get-ADUser -Filter "SamAccountName -eq '$selectedSam'" -Properties * -ErrorAction SilentlyContinue

        if ($selectedUser) {
            Write-Host "`nUtilisateur sélectionné : $($selectedUser.DisplayName)" -ForegroundColor Green
            return $selectedUser
        } else {
            Write-Host "Erreur: Utilisateur non trouvé." -ForegroundColor Red
            return $null
        }
    }

    return $null
}

function Update-UserName {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Nom,
        [Parameter(Mandatory=$true)]
        [string]$Prenom,
        [Parameter(Mandatory=$true)]
        [string]$SamAccountName
    )

    $NewSamAccountName = "$($Prenom.ToLower()).$($Nom.ToLower())"
    $NewUPN = "$NewSamAccountName@$((Get-ADDomain).DNSRoot)"
    $NewDisplayName = "$Prenom $Nom"

    try {
        Set-ADUser -Identity $SamAccountName `
            -Surname $Nom `
            -GivenName $Prenom `
            -DisplayName $NewDisplayName `
            -UserPrincipalName $NewUPN `
            -SamAccountName $NewSamAccountName `
            -ErrorAction Stop


        $user = Get-ADUser -Identity $NewSamAccountName
        Rename-ADObject -Identity $user.DistinguishedName -NewName $NewDisplayName -ErrorAction Stop

        Write-Host "Le nom de l'utilisateur a été mis à jour avec succès en '$Nom'." -ForegroundColor Green
    }
    catch {
        Write-Host "Erreur lors de la mise à jour du nom de l'utilisateur '$SamAccountName': $_" -ForegroundColor Red
    }
}

function Show-XanaduUsersTree {
    <#
    .SYNOPSIS
        Affiche l'arborescence des utilisateurs AD sous forme d'arbre.
    .DESCRIPTION
        Parcourt récursivement les OU et affiche les utilisateurs dans un format arbre.
    .EXAMPLE
        Show-XanaduUsersTree
    #>
    [CmdletBinding()]
    param(
        [string]$SearchBase,
        [int]$Indent = 0,
        [bool]$IsLast = $false
    )

    # Caracteres box-drawing via codes ASCII/Unicode
    $verticalLine = [char]0x2502   # │
    $branchEnd    = [char]0x2514   # └
    $branchTee    = [char]0x251C   # ├
    $horizontal   = [char]0x2500   # ─

    if (-not $SearchBase) {
        $DomainDN = (Get-ADDomain).DistinguishedName
        $SearchBase = "OU=Users,OU=Xanadu,$DomainDN"

        Write-Host ""
        Write-Host "USERS" -ForegroundColor Cyan
    }

    $prefix = "" * ($Indent * 4)
    for ($i = 0; $i -lt $Indent; $i++) {
        if ($IsLast) {
            $prefix += "     "
        } else {
            $prefix += " $verticalLine  "
        }
    }

    $subOUs = @(Get-ADOrganizationalUnit -Filter 'Name -like "*"' -SearchBase $SearchBase -SearchScope OneLevel -ErrorAction SilentlyContinue |
    Sort-Object Name)

    $users = @(Get-ADUser -Filter 'Name -like "*"' -SearchBase $SearchBase -SearchScope OneLevel -Properties DisplayName, GivenName, Surname -ErrorAction SilentlyContinue |
        Sort-Object Surname, GivenName)

    $allItems = @()
    foreach ($ou in $subOUs) { $allItems += @{ Type = "OU"; Item = $ou } }
    foreach ($u in $users) { $allItems += @{ Type = "User"; Item = $u } }

    for ($i = 0; $i -lt $allItems.Count; $i++) {
        $isLastItem = ($i -eq $allItems.Count - 1)
        $connector = if ($isLastItem) { $branchEnd } else { $branchTee }


        if ($allItems[$i].Type -eq "OU") {
            $ou = $allItems[$i].Item
            Write-Host "$prefix $connector$horizontal$horizontal " -ForegroundColor DarkGray -NoNewline
            Write-Host "$($ou.Name)" -ForegroundColor Yellow

            $newPrefix = if ($isLastItem) { "$prefix    " } else { "$prefix $verticalLine   " }
            Show-XanaduUsersTree -SearchBase $ou.DistinguishedName -Indent ($Indent + 1) -IsLast $isLastItem
        }
        else {
            $user = $allItems[$i].Item
            $displayName = if ($user.GivenName -and $user.Surname) {
                "$($user.GivenName) $($user.Surname.ToUpper())"
            } elseif ($user.DisplayName) {
                $user.DisplayName
            } else {
                $user.Name
            }

            Write-Host "$prefix $connector$horizontal$horizontal " -ForegroundColor DarkGray -NoNewline
            Write-Host "$displayName" -ForegroundColor White
        }
    }
}


