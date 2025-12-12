<#
.SYNOPSIS
    Gestion des utilisateurs Active Directory - Point d'entrée.

.DESCRIPTION
    Script interactif pour créer, modifier ou supprimer des utilisateurs AD.

.EXAMPLE
    .\UserManagement.ps1
    .\UserManagement.ps1 -Action "Create" -Nom "Doe" -Prenom "John"
#>

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8


function Show-MainMenu {
    <#
    .SYNOPSIS
        Affiche le menu principal et retourne le choix.
    #>
    $options = @(
        "Créer un utilisateur",
        "Modifier un utilisateur",
        "Supprimer un utilisateur",
        "Lister les utilisateurs",
        "Réinitialiser le mot de passe utilisateur",
        "Quitter"
    )

    return Select-FromList -Title "=== Gestion des Utilisateurs ===" -Options $options
}

function Invoke-CreateUser {
    <#
    .SYNOPSIS
        Lance le processus de création d'un utilisateur.
    #>
    [CmdletBinding()]
    param (
        [string]$Nom,
        [string]$Prenom,
        [string]$Group
    )

    if (-not $Nom) {
        $Nom = Read-HostWithEscape "Veuillez spécifier le nom (ESC pour annuler)"
        if (-not $Nom) {
            Write-Host "Opération annulée par l'utilisateur." -ForegroundColor Yellow
            return
        }
    }

    if (-not $Prenom) {
        $Prenom = Read-Host "Veuillez spécifier le prénom (ESC pour annuler)"
        if (-not $Prenom) {
            Write-Host "Opération annulée par l'utilisateur." -ForegroundColor Yellow
            return
        }
    }

    if ($Group -notin $myGroups) {
        $Group = Select-OUGroup
        if (-not $Group -or $Group -eq "Quitter") {
            Write-Host "Opération annulée par l'utilisateur." -ForegroundColor Yellow
            return
        }
    }

    $SamAccountName = "$($Prenom.ToLower()).$($Nom.ToLower())"
    $DisplayName    = "$Prenom $Nom"
    $UserPrincipalName = "$SamAccountName@$((Get-ADDomain).DNSRoot)"

    Write-Host "`n=== User to create ===" -ForegroundColor Green
    Write-Host "  Display Name : $DisplayName"
    Write-Host "  SamAccountName : $SamAccountName"
    Write-Host "  UPN : $UserPrincipalName"
    Write-Host "  Group : $Group"
    Write-Host ""

    $confirmation = Read-Host "Confirmez-vous la création de cet utilisateur ? (O/N)"
    if ($confirmation -ine 'O') {
        Write-Host "Opération annulée par l'utilisateur." -ForegroundColor Yellow
        return
    }
    New-XanaduUser -Nom $Nom `
        -Prenom $Prenom `
        -Group $Group `
        -Path "OU=Users,OU=Xanadu,$((Get-ADDomain).DistinguishedName)"
}

function Invoke-UpdateUser {
    <#
    .SYNOPSIS
        Lance le processus de modification d'un utilisateur.
    #>
    [CmdletBinding()]
    param (
        [string]$Nom,
        [string]$Prenom,
        [string]$SamAccountName
    )
    $user = $null

    if ($SamAccountName) {
        $user = Get-ADUser -Filter "SamAccountName -eq '$SamAccountName'" -Properties * -ErrorAction SilentlyContinue
    }

    if (-not $user -and (-not $Nom -or -not $Prenom)) {
        if (-not $Nom) {
            $Nom = Read-Host "Nom de l'utilisateur à modifier"
        }
        if (-not $Prenom) {
            $Prenom = Read-Host "Prénom de l'utilisateur à modifier"
        }

        if ($Nom -and $Prenom) {
            $searchSam = "$($Prenom.ToLower()).$($Nom.ToLower())"
            $user = Get-ADUser -Filter "SamAccountName -eq '$searchSam'" -Properties * -ErrorAction SilentlyContinue

            if (-not $user) {
                $user = Get-ADUser -Filter "GivenName -eq '$Prenom' -and Surname -eq '$Nom'" -Properties * -ErrorAction SilentlyContinue
            }
        }
    }

    if (-not $user) {
        Write-Host "Aucun utilisateur trouvé." -ForegroundColor Yellow
        $user = Select-XanaduUser
        if (-not $user) {
            Write-Host "Opération annulée." -ForegroundColor Yellow
            return
        }
    }

    if ($user -is [array]) {
        Write-Host "Plusieurs utilisateurs trouvés :" -ForegroundColor Yellow
        $userNames = $user | ForEach-Object { "$($_.Name) ($($_.SamAccountName))" }
        $selectedName = Select-FromList -Title "Sélectionnez l'utilisateur" -Options $userNames
        if (-not $selectedName) {
            Write-Host "Opération annulée." -ForegroundColor Yellow
            return
        }
        $selectedSam = ($selectedName -split '\(')[1].TrimEnd(')')
        $user = $user | Where-Object { $_.SamAccountName -eq $selectedSam }
    }


    Write-Host "`n=== Utilisateur trouvé ===" -ForegroundColor Cyan
    Write-Host "  Nom complet    : $($user.Name)"
    Write-Host "  Prénom         : $($user.GivenName)"
    Write-Host "  Nom            : $($user.Surname)"
    Write-Host "  SamAccountName : $($user.SamAccountName)"
    Write-Host "  Email          : $($user.EmailAddress)"
    Write-Host "  OU             : $($user.DistinguishedName -replace '^CN=[^,]+,','')"
    Write-Host "  Activé         : $($user.Enabled)"
    Write-Host ""

    $attributesToUpdate = @(
        "Nom",
        "Prénom",
        "Email",
        "Groupe"
    )
    if ($user.Enabled) {
        $attributesToUpdate += "Désactiver le compte"
    } else {
        $attributesToUpdate += "Activer le compte"
    }
    $attributesToUpdate += "Quitter"

    $continue = $true
    while ($continue) {
        $attributeChoice = Select-FromList -Title "Sélectionnez l'attribut à modifier" -Options $attributesToUpdate
        switch ($attributeChoice) {
            "Nom" {
                Write-Host "`nMise à jour du nom de $($user.Surname)" -ForegroundColor Cyan
                $newNom = Read-HostWithEscape -Prompt "Nouveau nom (Esc pour annuler)"
                if (-not $newNom) {
                    Write-Host "Modification annulée." -ForegroundColor Yellow
                } else {
                    Update-UserName -Nom $newNom -Prenom $user.GivenName `
                    -SamAccountName $user.SamAccountName
                }
            }
            "Prénom" {
                Write-Host "`nMise à jour du prénom de $($user.Surname)" -ForegroundColor Cyan
                $newPrenom = Read-HostWithEscape -Prompt "Nouveau prénom (Esc pour annuler)"
                if (-not $newPrenom) {
                    Write-Host "Modification annulée." -ForegroundColor Yellow
                } else {
                    Update-UserName -Nom $user.Surname -Prenom $newPrenom `
                    -SamAccountName $user.SamAccountName
                }
            }
            "Email" {
                Write-Host "`nMise à jour de l'email de $($user.EmailAddress)" -ForegroundColor Cyan
                $newEmail = Read-HostWithEscape -Prompt "Nouvel email (Esc pour annuler)"
                if (-not $newEmail) {
                    Write-Host "Modification annulée." -ForegroundColor Yellow
                } else {
                    try {
                        Set-ADUser -Identity $user.SamAccountName -EmailAddress $newEmail -ErrorAction Stop
                        Write-Host "Email mis à jour avec succès en '$newEmail'." -ForegroundColor Green
                    } catch {
                        Write-Host "Erreur lors de la mise à jour de l'email : $_" -ForegroundColor Red
                    }
                }
            }
            "Groupe" {
                Write-Host "`nMise à jour du groupe de $($user.SamAccountName)" -ForegroundColor Cyan
                $newGroup = Select-OUGroup
                if (-not $newGroup) {
                    Write-Host "Modification annulée." -ForegroundColor Yellow
                } else {
                    try {
                        $currentOU = ($user.DistinguishedName -split ',')[1..($user.DistinguishedName.Length)] -join ','
                        $newOU = "OU=$newGroup,$currentOU"
                        Write-Host "Old OU: $currentOU, New OU: $newOU" -ForegroundColor Yellow
                        # Move-ADObject -Identity $user.DistinguishedName -TargetPath $newOU
                        # Write-Host "Groupe mis à jour avec succès en '$newGroup'." -ForegroundColor Green
                    } catch {
                        Write-Host "Erreur lors de la mise à jour du groupe : $_" -Foreground Red
                    }
                }
            }
            "Activer/Désactiver le compte" {
                $newState = -not $user.Enabled
                try {
                    Set-ADUser -Identity $user.SamAccountName -Enabled $newState -ErrorAction Stop
                    $stateText = if ($newState) { "activé" } else { "désactivé" }
                    Write-Host "Le compte utilisateur a été $stateText avec succès." -ForegroundColor Green
                } catch {
                    Write-Host "Erreur lors de la mise à jour de l'état du compte : $_" -ForegroundColor Red
                }
            }

            "Quitter" {$continue = $false}
        }
    }
}

function Invoke-DeleteUser {
    <#
    .SYNOPSIS
        Lance le processus de suppression d'un utilisateur.
    #>

    $user = Select-XanaduUser
    if (-not $user) {
        Write-Host "Opération annulée." -ForegroundColor Yellow
        return
    }
    $confirmation = Read-Host "Confirmez-vous la suppression de l'utilisateur '$($user.DisplayName)' ? (O/N)"
    if ($confirmation -ine 'O') {
        Write-Host "Opération annulée par l'utilisateur." -ForegroundColor Yellow
        return
    }
    Remove-ADUser -Identity $user.SamAccountName
}

function Invoke-ListUsers {
    <#
    .SYNOPSIS
        Lance le processus de listing des utilisateurs.
    #>
    Show-XanaduUsersTree
}

function Invoke-ResetUserPassword {
    <#
    .SYNOPSIS
        Lance le processus de réinitialisation du mot de passe d'un utilisateur.
    #>
    [CmdletBinding()]

    $user = Select-XanaduUser
    if (-not $user) {
        Write-Host "Opération annulée." -ForegroundColor Yellow
        return
    }

    try {
        $newPassword = ConvertTo-SecureString -AsPlainText "Xanadu$(Get-Date -Format 'yyyy')!" -Force

        Get-ADUser -Identity $user.SamAccountName |
            Set-ADAccountPassword -Reset -NewPassword $newPassword -PassThru |
            Set-ADUser -ChangePasswordAtLogon $true

        Write-Host "Mot de passe réinitialisé pour '$($user.DisplayName)'." -ForegroundColor Green
    } catch {
        Write-Host "Erreur lors de la réinitialisation du mot de passe : $_" -ForegroundColor Red
        return
    }
}

function Start-UserManagement {
    <#
    .SYNOPSIS
        Point d'entrée principal du script.
    .EXAMPLE
        Start-UserManagement
    #>
    [CmdletBinding(DefaultParameterSetName='Encode')]
    param(
        [ValidateSet("Create", "Update", "Delete", "List")]
        [string]$Action,

        [string]$Nom,
        [string]$Prenom,
        [string]$Group,
        [string]$SamAccountName
    )

    if ($Action) {
        switch ($Action) {
            "Create" { Invoke-CreateUser -Nom $Nom -Prenom $Prenom -Group $Group }
            "Update" { Invoke-UpdateUser }
            "Delete" { Invoke-DeleteUser }
            "List"   { Invoke-ListUsers }
        }
        return
    }

    $continue = $true
    while ($continue) {
        $choice = Show-MainMenu

        switch ($choice) {
            "Créer un utilisateur"    { Invoke-CreateUser }
            "Modifier un utilisateur" { Invoke-UpdateUser }
            "Supprimer un utilisateur"{ Invoke-DeleteUser }
            "Lister les utilisateurs" { Invoke-ListUsers }
            "Réinitialiser le mot de passe utilisateur" { Invoke-ResetUserPassword }
            "Quitter"                 { $continue = $false }
            $null                     { $continue = $false }
        }
    }

    Write-Host "Au revoir !" -ForegroundColor Cyan
}