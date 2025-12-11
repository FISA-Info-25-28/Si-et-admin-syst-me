<#
.SYNOPSIS
    Bibliothèque de fonctions communes pour la gestion des utilisateurs Active Directory Xanadu.

.DESCRIPTION
    Ce module contient des fonctions utilitaires partagées par tous les scripts de gestion
    des utilisateurs Active Directory dans l'environnement Xanadu.
    
    Fonctions disponibles :
    - Get-UniqueUsername      : Génère un nom d'utilisateur unique en ajoutant un numéro si nécessaire
    - Get-UniqueFullName      : Génère un nom complet unique dans une OU spécifique
    - New-GenericPassword     : Crée un mot de passe générique sécurisé selon les conventions Xanadu
    
    Convention de mot de passe :
    Format : [Première lettre majuscule][reste du login sans points][année][!]
    Exemple : pour "j.dupont" en 2025 → "Jdupont2025!"
    
    Ce fichier doit être placé dans le même répertoire que les scripts de gestion
    et chargé via dot-sourcing : ". .\user_functions.ps1"

.NOTES
    Auteur      : Votre Nom
    Version     : 1.0
    Date        : 11/12/2025
    Prérequis   : Module ActiveDirectory
    Utilisation : . .\user_functions.ps1 (dot-sourcing depuis un autre script)
    
#>

# ========================================
# user_functions.ps1
# Fonctions communes pour les scripts de gestion AD Xanadu
# ========================================

<#
.SYNOPSIS
    Génère un nom d'utilisateur unique en vérifiant les doublons dans Active Directory.

.DESCRIPTION
    Cette fonction prend un nom d'utilisateur de base et vérifie s'il existe déjà dans AD.
    Si le nom existe, elle ajoute un numéro incrémental (2, 3, 4...) jusqu'à trouver
    un nom disponible.
    
    Logique de génération :
    - Tentative 1 : nom de base (ex: j.dupont)
    - Tentative 2 : nom de base + 2 (ex: j.dupont2)
    - Tentative 3 : nom de base + 3 (ex: j.dupont3)
    - etc.

.PARAMETER BaseUsername
    Nom d'utilisateur de base à vérifier/générer (ex: "j.dupont")

.OUTPUTS
    String : Nom d'utilisateur unique garanti de ne pas exister dans AD

.EXAMPLE
    $username = Get-UniqueUsername -BaseUsername "j.dupont"
    # Si "j.dupont" existe déjà, retourne "j.dupont2"
    # Si "j.dupont2" existe aussi, retourne "j.dupont3", etc.

.EXAMPLE
    $username = Get-UniqueUsername -BaseUsername "m.martin"
    # Si "m.martin" est disponible, retourne "m.martin"

.NOTES
    Cette fonction effectue des requêtes AD à chaque itération.
    Pour un grand nombre de vérifications, considérer un cache local.
#>
function Get-UniqueUsername {
    param([string]$BaseUsername)
    
    # Commencer avec le nom de base
    $username = $BaseUsername
    $counter = 2
    
    # Boucler jusqu'à trouver un nom disponible
    # Vérifie si le SamAccountName existe dans AD
    while (Get-ADUser -Filter "SamAccountName -eq '$username'" -ErrorAction SilentlyContinue) {
        # Si le nom existe, ajouter un numéro incrémental
        $username = "$BaseUsername$counter"
        $counter++
    }
    
    # Retourner le premier nom d'utilisateur disponible
    return $username
}

<#
.SYNOPSIS
    Génère un nom complet (DisplayName) unique dans une unité organisationnelle spécifique.

.DESCRIPTION
    Cette fonction crée un nom complet unique en vérifiant les doublons dans une OU donnée.
    Elle gère automatiquement les homonymes en ajoutant un numéro incrémental.
    
    La vérification est limitée au niveau de l'OU spécifiée (SearchScope OneLevel),
    permettant ainsi d'avoir le même nom complet dans différentes OUs.
    
    Logique de génération :
    - Tentative 1 : Prénom Nom (ex: Jean Dupont)
    - Tentative 2 : Prénom Nom 2 (ex: Jean Dupont 2)
    - Tentative 3 : Prénom Nom 3 (ex: Jean Dupont 3)
    - etc.

.PARAMETER FirstName
    Prénom de l'utilisateur

.PARAMETER LastName
    Nom de famille de l'utilisateur

.PARAMETER OUPath
    Distinguished Name complet de l'OU où vérifier l'unicité
    (ex: "OU=Users,OU=RH,OU=SITE_ATLANTIS,DC=xanadu,DC=local")

.OUTPUTS
    String : Nom complet unique dans l'OU spécifiée

.EXAMPLE
    $fullName = Get-UniqueFullName -FirstName "Jean" -LastName "Dupont" -OUPath "OU=Users,OU=RH,OU=SITE_ATLANTIS,DC=xanadu,DC=local"
    # Si "Jean Dupont" existe dans cette OU, retourne "Jean Dupont 2"

.EXAMPLE
    $fullName = Get-UniqueFullName -FirstName "Marie" -LastName "Martin" -OUPath "OU=Users,OU=COMMERCIAL,OU=SITE_ATLANTIS,DC=xanadu,DC=local"
    # Si "Marie Martin" est disponible dans cette OU, retourne "Marie Martin"

.NOTES
    La recherche est limitée à l'OU spécifiée (pas de recherche récursive dans les sous-OUs).
    Cela permet d'avoir "Jean Dupont" à la fois dans RH et dans COMMERCIAL.
#>
function Get-UniqueFullName {
    param(
        [string]$FirstName,
        [string]$LastName,
        [string]$OUPath
    )
    
    # Construire le nom complet de base
    $fullName = "$FirstName $LastName"
    $counter = 2
    
    # Boucler jusqu'à trouver un nom complet disponible dans l'OU
    # SearchScope OneLevel = chercher uniquement au premier niveau de l'OU (pas dans les sous-OUs)
    while (Get-ADUser -Filter "Name -eq '$fullName'" -SearchBase $OUPath -SearchScope OneLevel -ErrorAction SilentlyContinue) {
        # Si le nom existe, ajouter un espace et un numéro incrémental
        $fullName = "$FirstName $LastName $counter"
        $counter++
    }
    
    # Retourner le premier nom complet disponible
    return $fullName
}

<#
.SYNOPSIS
    Génère un mot de passe temporaire sécurisé selon les conventions Xanadu.

.DESCRIPTION
    Cette fonction crée un mot de passe générique automatique basé sur le nom d'utilisateur
    et l'année en cours, suivant la convention de l'entreprise Xanadu.
    
    Format du mot de passe :
    [Première lettre en majuscule][reste du login sans points][année courante][!]
    
    Exemples de génération :
    - Pour "j.dupont" en 2025 : "Jdupont2025!"
    - Pour "m.martin" en 2025 : "Mmartin2025!"
    - Pour "adm_j.dupont" en 2025 : "Adm_jdupont2025!"
    
    Le mot de passe généré respecte les exigences de complexité :
    - Contient des majuscules
    - Contient des minuscules
    - Contient des chiffres
    - Contient un caractère spécial (!)
    - Longueur minimale > 8 caractères
    
    IMPORTANT : Ce mot de passe est temporaire. L'utilisateur doit le changer
    à sa première connexion (paramètre ChangePasswordAtLogon = $true).

.PARAMETER Username
    Nom d'utilisateur (SamAccountName) servant de base pour générer le mot de passe

.OUTPUTS
    Hashtable contenant deux propriétés :
    - SecureString : Mot de passe au format SecureString (pour New-ADUser)
    - PlainText : Mot de passe en clair (pour communiquer à l'utilisateur)

.EXAMPLE
    $passwordObj = New-GenericPassword -Username "j.dupont"
    $securePassword = $passwordObj.SecureString    # Pour création du compte AD
    $plainPassword = $passwordObj.PlainText        # Pour affichage/communication
    
    # Résultat : PlainText = "Jdupont2025!"

.EXAMPLE
    $pwd = New-GenericPassword -Username "m.martin"
    New-ADUser -Name "Marie Martin" -AccountPassword $pwd.SecureString
    Write-Host "Mot de passe temporaire : $($pwd.PlainText)"

.NOTES
    La fonction retire tous les points (.) du nom d'utilisateur pour le mot de passe.
    Le mot de passe est basé sur l'année système actuelle (Get-Date).Year
    
    Sécurité :
    - Ne jamais logger les mots de passe en clair dans des fichiers
    - Toujours afficher avec -ForegroundColor Yellow pour visibilité
    - Communiquer de manière sécurisée à l'utilisateur final
#>
function New-GenericPassword {
    param([string]$Username)
    
    # Récupérer l'année en cours (ex: 2025)
    $year = (Get-Date).Year
    
    # Extraire la première lettre du login et la mettre en majuscule
    $firstLetterUpper = $Username.Substring(0, 1).ToUpper()
    
    # Extraire le reste du login (à partir du 2e caractère)
    $restOfUsername = $Username.Substring(1)
    
    # Construire le mot de passe générique selon la convention Xanadu
    # Format : [Majuscule][reste du login sans points][année][!]
    # .Replace(".", "") retire tous les points du nom d'utilisateur
    $genericPassword = "$firstLetterUpper$restOfUsername$year!".Replace(".", "")
    
    # Convertir le mot de passe en SecureString (format requis par AD)
    $securePassword = ConvertTo-SecureString -String $genericPassword -AsPlainText -Force
    
    # Retourner les deux formats : SecureString pour AD, PlainText pour affichage
    return @{
        SecureString = $securePassword    # Pour New-ADUser -AccountPassword
        PlainText = $genericPassword      # Pour communiquer à l'utilisateur
    }
}