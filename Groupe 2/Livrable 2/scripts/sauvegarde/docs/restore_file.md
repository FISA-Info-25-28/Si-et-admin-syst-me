# restore_file.ps1

## Synopsis

Script de restauration des sauvegardes locales XANADU permettant de restaurer tout ou partie d'un backup créé par le système de sauvegarde local.

## Description

Ce script PowerShell offre une solution complète et flexible pour restaurer des backups créés par le système de sauvegarde local XANADU. Il propose **quatre modes d'utilisation** distincts adaptés à différents scénarios :

### Modes d'utilisation

1. **Restauration complète d'un backup** : Restaure l'intégralité d'un backup avec son arborescence
2. **Restauration ciblée** : Restaure uniquement les fichiers correspondant à un terme de recherche
3. **Affichage du contenu** : Liste tous les fichiers contenus dans un backup (mode `-List`)
4. **Sélection interactive** : Affiche tous les backups disponibles et propose un choix interactif

### Fonctionnalités principales

#### Mode automatique de sélection
Lorsque aucun paramètre `-BackupLabel` n'est fourni, le script :
- Détecte automatiquement tous les backups présents dans `BackupRoot`
- Parcourt les emplacements Local et/ou External selon le paramètre `-Location`
- Recherche dans les dossiers de politiques (Critical, Important, Standard, Logs)
- Affiche une liste numérotée des backups avec leur emplacement et politique
- Propose une sélection interactive via le terminal
- Exemple d'affichage : `1) full_20241201_203011_AB12C3 [Local] (Policy: Critical)`

#### Gestion intelligente des collisions
Le script garantit qu'**aucun fichier existant n'est écrasé** :
- En cas de conflit, le fichier restauré reçoit un suffixe horodaté
- Format du suffixe : `_YYYY-MM-DD_HH-mm-ss_restore`
- Exemple : `contrat.pdf` → `contrat_2025-12-04_10-30-22_restore.pdf`
- Si plusieurs restaurations ont lieu dans la même seconde, un compteur incrémental est ajouté : `_restore_1`, `_restore_2`, etc.

#### Reconstruction de l'arborescence
- L'arborescence d'origine est entièrement reconstruite dans le répertoire cible
- Les dossiers manquants sont créés automatiquement
- La structure relative des fichiers est préservée

#### Journalisation complète
Toutes les opérations sont consignées dans `Restore.log` avec :
- Horodatage précis de chaque action
- Identifiant unique de session (BackupID)
- Niveau de gravité (INFO, WARN, ERROR)
- Détails des fichiers restaurés

## Paramètres

### `-BackupRoot` (Obligatoire)
**Type** : `String`
**Obligatoire** : Oui

Chemin racine contenant les backups. La structure attendue est `BackupRoot/Location/Policy/Backup`.

```powershell
-BackupRoot "C:\Backups"
```

### `-BackupLabel` (Optionnel)
**Type** : `String`
**Obligatoire** : Non
**Valeur par défaut** : `$null`

Nom du backup à restaurer (ex : `full_20241204_135954_A7X9Q2`).

- Si absent : le script liste tous les backups disponibles et propose une sélection interactive
- Format attendu : `(full|dif|inc)_YYYYMMDD_HHMMSS_XXXXXX`

```powershell
-BackupLabel "full_20241204_135954_A7X9Q2"
```

### `-Location` (Optionnel)
**Type** : `String`
**Obligatoire** : Non
**Valeurs autorisées** : `"Local"`, `"External"`
**Valeur par défaut** : `$null` (recherche dans les deux emplacements)

Permet de filtrer les backups par emplacement.

- Si absent : recherche dans Local et External
- Si spécifié : recherche uniquement dans l'emplacement choisi

```powershell
-Location "Local"      # Recherche uniquement dans Local
-Location "External"   # Recherche uniquement dans External
```

### `-TargetPath` (Optionnel)
**Type** : `String`
**Obligatoire** : Non
**Valeur par défaut** : `C:\Restore`

Répertoire dans lequel les données seront restaurées.

- Le dossier est créé automatiquement s'il n'existe pas
- L'arborescence source y sera recréée

```powershell
-TargetPath "D:\Restored_Files"
```

### `-FileToRestore` (Optionnel)
**Type** : `String`
**Obligatoire** : Non
**Valeur par défaut** : `$null`

Terme de recherche d'un fichier spécifique. Le script restaure **tous les fichiers** dont le nom contient ce terme.

- Recherche insensible à la casse (utilise `-like "*term*"`)
- Permet de restaurer plusieurs fichiers en une seule commande
- Exemple : `contrat` restaurera `contrat.pdf`, `contrat_final.docx`, `sous-contrat.xlsx`, etc.

```powershell
-FileToRestore "contrat"
```

### `-List` (Optionnel)
**Type** : `Switch`
**Obligatoire** : Non

Active le mode affichage du contenu d'un backup sans effectuer de restauration.

- Affiche la liste complète des fichiers contenus dans le backup
- Affiche les chemins relatifs par rapport à la racine du backup
- Aucune modification n'est apportée au système

```powershell
-List
```

## Exemples d'utilisation

### Exemple 1 : Restauration complète d'un backup

Restaure l'intégralité du backup spécifié dans le répertoire par défaut `C:\Restore`.

```powershell
.\restore_file.ps1 -BackupRoot "C:\Backups" -Location "Local" -BackupLabel "full_20241204_135954_A7X9Q2"
```

**Résultat** :
- Tous les fichiers du backup sont restaurés
- L'arborescence complète est recréée
- Les fichiers sont copiés vers `C:\Restore\`

### Exemple 2 : Restauration complète vers un répertoire personnalisé

```powershell
.\restore_file.ps1 -BackupRoot "C:\Backups" -Location "Local" -BackupLabel "full_20241204_135954_A7X9Q2" -TargetPath "D:\Recovery"
```

**Résultat** : Les fichiers sont restaurés dans `D:\Recovery\` au lieu du répertoire par défaut.

### Exemple 3 : Restauration ciblée d'un fichier spécifique

Restaure uniquement les fichiers dont le nom contient "contrat".

```powershell
.\restore_file.ps1 -BackupRoot "C:\Backups" -Location "Local" -BackupLabel "full_20241204_135954_A7X9Q2" -FileToRestore "contrat"
```

**Résultat** :
- Recherche tous les fichiers contenant "contrat" dans leur nom
- Restaure uniquement ces fichiers (ex : `contrat.pdf`, `contrat_2024.docx`)
- Préserve l'arborescence relative pour chaque fichier trouvé

### Exemple 4 : Lister le contenu d'un backup (mode inspection)

Affiche le contenu du backup sans effectuer de restauration.

```powershell
.\restore_file.ps1 -BackupRoot "C:\Backups" -Location "Local" -BackupLabel "inc_20241205_023110_Z8Q1XK" -List
```

**Résultat** :
```
Documents\rapport_2024.pdf
Documents\Contrats\contrat_client_A.docx
Images\logo.png
Data\export.csv
```

### Exemple 5 : Sélection interactive d'un backup

Lance le mode automatique qui propose tous les backups disponibles.

```powershell
.\restore_file.ps1 -BackupRoot "C:\Backups" -Location "Local"
```

**Interaction** :
```
1) full_20241201_203011_AB12C3 [Local] (Policy: Critical)
2) dif_20241202_140522_XY98Z1 [Local] (Policy: Important)
3) inc_20241203_081234_QW45ER [External] (Policy: Standard)
Sélectionner un numéro: 1
```

**Résultat** : Le backup sélectionné (ici `full_20241201_203011_AB12C3`) est restauré complètement.

### Exemple 6 : Sélection interactive avec filtrage par emplacement

Affiche uniquement les backups de l'emplacement External.

```powershell
.\restore_file.ps1 -BackupRoot "C:\Backups" -Location "External"
```

**Interaction** :
```
1) full_20241208_120000_ABC123 [External] (Policy: Critical)
2) dif_20241209_140000_DEF456 [External] (Policy: Important)
Sélectionner un numéro: 1
```

**Résultat** : Seuls les backups External sont listés et proposés à la sélection.

### Exemple 7 : Restauration ciblée avec répertoire personnalisé

Combine restauration ciblée et chemin de destination personnalisé.

```powershell
.\restore_file.ps1 -BackupRoot "C:\Backups" -Location "Local" -BackupLabel "full_20241204_135954_A7X9Q2" -FileToRestore "facture" -TargetPath "C:\RecoveredInvoices"
```

**Résultat** :
- Recherche tous les fichiers contenant "facture"
- Les restaure dans `C:\RecoveredInvoices\`
- Préserve l'arborescence d'origine

## Fonctionnement détaillé

### Architecture du script

Le script est organisé en plusieurs régions fonctionnelles :

#### 1. **PARAMETERS** - Gestion des paramètres
Définit et valide les paramètres d'entrée du script.

#### 2. **GLOBALS** - Variables globales
- Définit le chemin du fichier de log : `$TargetPath\Logs\Restore.log`
- Génère un identifiant unique de session (BackupID) pour le traçage

#### 3. **LOGGING** - Journalisation
Fonction `Write-Log` qui enregistre toutes les opérations avec :
- Horodatage
- Identifiant de session
- Niveau de gravité (INFO, WARN, ERROR)
- Message descriptif

#### 4. **VALIDATION** - Vérifications préalables
- Fonction `Get-AvailableBackups` : Parcourt l'arborescence BackupRoot/Location/Policy/Backups
  - Recherche dans Local et/ou External selon le paramètre `-Location`
  - Parcourt les dossiers de politiques (Critical, Important, Standard, Logs)
  - Retourne une liste d'objets contenant : Location, Policy, Name, FullPath
- Vérifie l'existence de `BackupRoot`
- Si aucun `BackupLabel` n'est fourni, liste les backups disponibles et propose un choix interactif
- Vérifie l'existence du backup sélectionné
- Crée le répertoire de restauration si nécessaire

#### 5. **RENAME_LOGIC** - Gestion des collisions
Deux fonctions principales :
- `Test-NewSplitPathFeatures` : Détecte si PowerShell supporte `-LeafBase` (PS 7+)
- `Get-RestoredFilePath` : Génère un nom unique pour éviter les écrasements
  - Ajoute un suffixe horodaté : `_YYYY-MM-DD_HH-mm-ss_restore`
  - Incrémente si nécessaire : `_restore_1`, `_restore_2`, etc.

#### 6. **RESTORE_LOGIC** - Logique de restauration
Trois modes de fonctionnement :

**Mode List** (`-List`) :
- Parcourt récursivement le backup
- Affiche tous les chemins relatifs
- Se termine sans restauration

**Mode ciblé** (`-FileToRestore`) :
- Recherche les fichiers correspondants avec `-like "*$FileToRestore*"`
- Restaure uniquement les correspondances
- Préserve l'arborescence relative

**Mode complet** (par défaut) :
- Parcourt tous les fichiers du backup
- Restaure chaque fichier avec son arborescence
- Gère les collisions automatiquement

#### 7. **END** - Finalisation
- Journalise la fin de la restauration
- Retourne un code de sortie (0 = succès, 1 = erreur)

### Algorithme de restauration

```
1. Valider les paramètres et le chemin du backup
2. Si aucun BackupLabel → rechercher les backups disponibles :
   a. Parcourir BackupRoot/Location(s)/Policy(s)/Backups
   b. Afficher la liste avec Location et Policy
   c. Proposer une sélection interactive
3. Créer le répertoire de destination si nécessaire
4. Selon le mode :
   a. Mode List : afficher le contenu et terminer
   b. Mode ciblé : 
      - Rechercher les fichiers correspondants
      - Pour chaque fichier :
        * Calculer le chemin de destination
        * Vérifier les collisions et renommer si nécessaire
        * Recréer l'arborescence
        * Copier le fichier
   c. Mode complet :
      - Pour chaque fichier du backup :
        * Calculer le chemin de destination
        * Vérifier les collisions et renommer si nécessaire
        * Recréer l'arborescence
        * Copier le fichier
5. Journaliser toutes les opérations
6. Terminer avec un code de sortie approprié
```

### Gestion des erreurs

Le script gère plusieurs cas d'erreur :

| Erreur | Message | Action |
|--------|---------|--------|
| BackupRoot introuvable | `Répertoire de sauvegarde introuvable` | Arrêt avec code 1 |
| Aucun backup disponible | `Aucun backup disponible` | Arrêt avec code 1 |
| Backup spécifié introuvable | `Le backup 'XXX' n'existe pas` | Arrêt avec code 1 |
| Fichier ciblé introuvable | `Le fichier 'XXX' est introuvable` | Arrêt avec code 1 |

Toutes les erreurs sont journalisées avec le niveau `ERROR`.

## Journalisation

### Format des logs

Chaque entrée de log suit ce format :

```
[YYYY-MM-DD HH:mm:ss - BACKUP_ID] [LEVEL] Message
```

**Exemple** :
```
[2024-12-04 13:59:54 - AB12C3] [INFO] Début de la restauration depuis full_20241204_135954_A7X9Q2
[2024-12-04 13:59:55 - AB12C3] [INFO] Restauré : C:\Restore\Documents\contrat_2025-12-04_13-59-55_restore.pdf
[2024-12-04 13:59:56 - AB12C3] [INFO] Restauration terminée avec succès.
```

### Niveaux de gravité

- **INFO** : Opération normale (début, fin, fichier restauré)
- **WARN** : Avertissement (non utilisé actuellement)
- **ERROR** : Erreur bloquante (backup introuvable, fichier non trouvé)

### Emplacement du fichier de log

```
$TargetPath\Logs\Restore.log
```

## Sécurité et bonnes pratiques

### Garanties

**Aucun écrasement de fichier** : Les fichiers existants ne sont jamais remplacés  
**Traçabilité complète** : Toutes les opérations sont journalisées  
**Identifiant unique** : Chaque session de restauration a un BackupID unique  
**Validation stricte** : Vérification de l'existence de tous les chemins requis  

### Recommandations

1. **Vérifier l'espace disque** : S'assurer que le volume de destination dispose d'assez d'espace
2. **Tester avec `-List`** : Inspecter le contenu avant une restauration complète
3. **Utiliser `-FileToRestore`** : Pour des restaurations partielles rapides
4. **Vérifier les logs** : Consulter `Restore.log` après chaque restauration
5. **Droits d'accès** : S'assurer d'avoir les permissions nécessaires sur BackupRoot et TargetPath

### Limitations connues

- Le script ne gère pas la compression (les backups doivent être décompressés)
- Pas de vérification d'intégrité par checksum (MD5, SHA256)
- Pas de restauration incrémentale intelligente (chaque fichier est copié)
- Pas de filtrage par date ou par type de fichier (sauf recherche par nom)

## Compatibilité

### Versions PowerShell

- **PowerShell 5.1** (Windows PowerShell) : ✅ Compatible
- **PowerShell 7+** (PowerShell Core) : ✅ Compatible avec optimisations

Le script détecte automatiquement la version et adapte son comportement :
- PowerShell 7+ : Utilise `-LeafBase` et `-Extension` natifs
- PowerShell 5.1 : Utilise `[System.IO.Path]::GetFileNameWithoutExtension()`

### Systèmes d'exploitation

- Windows 10/11
- Windows Server 2016+
- Linux/macOS : Nécessite PowerShell Core avec adaptation des chemins

## Notes importantes

- **Préservation de l'arborescence** : La structure complète des dossiers est recréée dans le répertoire cible
- **Compatible avec exécution interactive ou programmée** : Peut être utilisé manuellement ou via des tâches planifiées
- **BackupID unique** : Chaque exécution génère un identifiant de 6 caractères alphanumériques pour le traçage
- **Recherche inclusive** : `-FileToRestore` utilise un filtre `-like` qui retourne toutes les correspondances partielles
- **Pas de suppression** : Le script ne supprime jamais de fichiers, uniquement copie et création

## Fichiers associés

- Script principal : `restore_file.ps1`
- Documentation : `docs/restore_file.md`
- Log de restauration : `$TargetPath\Logs\Restore.log`

## Codes de sortie

| Code | Signification |
|------|---------------|
| 0 | Restauration réussie |
| 1 | Erreur (backup introuvable, fichier introuvable, répertoire invalide) |

## Cas d'usage avancés

### Restauration depuis un emplacement spécifique

```powershell
# Lister et restaurer uniquement depuis External
.\restore_file.ps1 -BackupRoot "C:\Backups" -Location "External"

# Restaurer un backup Local spécifique
.\restore_file.ps1 -BackupRoot "C:\Backups" -Location "Local" -BackupLabel "full_20241204_135954_A7X9Q2"
```

### Restauration sélective par type de fichier

```powershell
# Restaurer uniquement les PDF
.\restore_file.ps1 -BackupRoot "C:\Backups" -Location "Local" -BackupLabel "full_20241204_135954_A7X9Q2" -FileToRestore ".pdf"
```

### Vérification avant restauration

```powershell
# Étape 1 : Lister le contenu
.\restore_file.ps1 -BackupRoot "C:\Backups" -Location "Local" -BackupLabel "full_20241204_135954_A7X9Q2" -List

# Étape 2 : Confirmer et restaurer
.\restore_file.ps1 -BackupRoot "C:\Backups" -Location "Local" -BackupLabel "full_20241204_135954_A7X9Q2"
```

---

**Auteur** : Projet XANADU
**Version** : 1.1
**Dernière mise à jour** : 11 décembre 2025
