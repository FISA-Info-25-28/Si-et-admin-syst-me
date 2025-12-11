# backup_file.ps1

## Synopsis

Script de sauvegarde locale pour XANADU supportant trois types de sauvegardes : complète (Full), différentielle (Dif) et incrémentielle (Inc).

## Description

Ce script PowerShell réalise des sauvegardes de dossiers de données vers un stockage local dédié avec une gestion intelligente des fichiers à sauvegarder selon le type choisi. Il constitue la pierre angulaire du système de sauvegarde XANADU.

### Types de sauvegarde

Le script supporte **trois modes de sauvegarde** complémentaires :

#### 1. Sauvegarde complète (Full)
- **Principe** : Tous les fichiers des sources sont copiés
- **Usage** : Premier backup ou backup de référence périodique
- **Avantage** : Restauration simple et rapide, copie complète autonome
- **Inconvénient** : Consomme le plus d'espace disque
- **Fréquence recommandée** : Hebdomadaire ou mensuelle

#### 2. Sauvegarde différentielle (Dif)
- **Principe** : Sauvegarde uniquement les fichiers modifiés depuis la **dernière sauvegarde complète**
- **Usage** : Sauvegarde intermédiaire entre deux sauvegardes complètes
- **Avantage** : Plus rapide qu'un Full, restauration simple (Full + dernier Dif)
- **Inconvénient** : Taille croissante au fil du temps jusqu'au prochain Full
- **Fréquence recommandée** : Quotidienne

#### 3. Sauvegarde incrémentielle (Inc)
- **Principe** : Sauvegarde uniquement les fichiers modifiés depuis la **dernière sauvegarde** (quelle qu'elle soit)
- **Usage** : Sauvegarde très fréquente avec minimum d'espace
- **Avantage** : Très rapide, consomme peu d'espace
- **Inconvénient** : Restauration plus complexe (nécessite Full + tous les Inc)
- **Fréquence recommandée** : Horaire ou toutes les 4 heures

### Fonctionnalités principales

#### Gestion par politique de sauvegarde (Policy)
Le script organise les backups selon des **niveaux de criticité** :
- **Critical** : Données métiers critiques
- **Important** : Données importantes mais non vitales
- **Standard** : Données classiques

Chaque politique possède :
- Son propre dossier : `C:\Backups\Local\{Policy}\`
- Son propre fichier de métadonnées : `backup_state.json`
- Ses propres logs : `Backup_{Policy}_{Type}.log`

Cette séparation permet d'appliquer des **durées de rétention différentes** selon la criticité.

#### Gestion d'état par métadonnées
Le script maintient un fichier JSON (`backup_state.json`) qui enregistre :
- **LastFullDate** : Date de la dernière sauvegarde complète
- **LastBackupDate** : Date de la dernière sauvegarde (quel que soit le type)

Ces métadonnées permettent de calculer automatiquement quels fichiers doivent être inclus dans les sauvegardes différentielles et incrémentielles.

#### Protection contre les erreurs
- **Forçage automatique en Full** : Si aucune sauvegarde complète n'existe, le script force un Full même si Dif ou Inc est demandé
- **Validation des sources** : Vérification de l'existence de chaque chemin source
- **Gestion des erreurs par fichier** : Une erreur sur un fichier n'arrête pas le backup complet
- **Logs détaillés** : Toutes les opérations et erreurs sont tracées

#### Préservation de l'arborescence
- L'arborescence complète de chaque source est recréée dans le backup
- Chaque source est isolée dans son propre sous-dossier (nom du dossier source)
- Les chemins relatifs sont préservés

#### Nommage intelligent des backups
Format : `{Policy}_{Type}_{Timestamp}_{BackupID}`
- **Policy** : `Critical`, `Important` ou `Standard`
- **Type** : `full`, `dif` ou `inc`
- **Timestamp** : `YYYYMMDD_HHMMSS` (ex: `20241208_143022`)
- **BackupID** : Identifiant unique de 6 caractères alphanumériques (ex: `A7X9Q2`)

Exemple : `Critical_full_20241208_143022_A7X9Q2`

#### Journalisation complète
Un fichier de log est généré pour chaque combinaison Policy + Type :
- `Backup_Critical_full.log` : Logs des sauvegardes complètes Critical
- `Backup_Important_dif.log` : Logs des sauvegardes différentielles Important
- `Backup_Standard_inc.log` : Logs des sauvegardes incrémentielles Standard
- etc.

Format des logs :
```
[YYYY-MM-DD HH:mm:ss - BACKUP_ID] [LEVEL] Message
```

## Paramètres

### `-Type` (Obligatoire)
**Type** : `String`
**Obligatoire** : Oui
**Valeurs autorisées** : `"full"`, `"dif"`, `"inc"`

Type de sauvegarde à effectuer.

```powershell
-Type "full"   # Sauvegarde complète
-Type "dif"    # Sauvegarde différentielle
-Type "inc"    # Sauvegarde incrémentielle
```

### `-Policy` (Obligatoire)
**Type** : `String`
**Obligatoire** : Oui
**Valeurs autorisées** : `"Critical"`, `"Important"`, `"Standard"`

Classe de criticité de la sauvegarde. Détermine le dossier de stockage et permet d'appliquer des durées de rétention différentes.

```powershell
-Policy "Critical"    # Données critiques (rétention longue)
-Policy "Important"   # Données importantes (rétention moyenne)
-Policy "Standard"    # Données standard (rétention courte)
```

### `-IncludesFile` (Obligatoire)
**Type** : `String`
**Obligatoire** : Oui

Chemin vers un fichier texte contenant la liste des chemins à sauvegarder (un par ligne).

```powershell
-IncludesFile "C:\Config\backup_sources.txt"
```

**Format du fichier includes** :
```
C:\Users\JohnDoe\Documents
C:\Data\Projects
D:\Important\Contracts
```

- Une ligne par chemin source
- Les lignes vides sont ignorées
- Pas de commentaires supportés
- Chemins absolus recommandés

## Exemples d'utilisation

### Exemple 1 : Sauvegarde complète

Effectue une sauvegarde complète de toutes les sources listées dans le fichier includes.

```powershell
.\backup_file.ps1 -Type "full" -IncludesFile "C:\Config\backup_sources.txt" -Policy "Critical"
```

**Résultat** :
- Tous les fichiers des sources sont copiés
- Un dossier `Critical_full_YYYYMMDD_HHMMSS_XXXXXX` est créé dans `C:\Backups\Local\Critical`
- Les métadonnées sont mises à jour dans `C:\Backups\Local\Critical\backup_state.json`

### Exemple 2 : Sauvegarde différentielle

Sauvegarde uniquement les fichiers modifiés depuis la dernière sauvegarde complète.

```powershell
.\backup_file.ps1 -Type "dif" -IncludesFile "C:\Config\backup_sources.txt" -Policy "Important"
```

**Résultat** :
- Seuls les fichiers avec `LastWriteTime > LastFullDate` sont copiés
- Un dossier `Important_dif_YYYYMMDD_HHMMSS_XXXXXX` est créé
- `LastBackupDate` est mise à jour (mais pas `LastFullDate`)

### Exemple 3 : Sauvegarde incrémentielle

Sauvegarde uniquement les fichiers modifiés depuis la dernière sauvegarde (quelle qu'elle soit).

```powershell
.\backup_file.ps1 -Type "inc" -IncludesFile "C:\Config\backup_sources.txt" -Policy "Standard"
```

**Résultat** :
- Seuls les fichiers avec `LastWriteTime > LastBackupDate` sont copiés
- Un dossier `Standard_inc_YYYYMMDD_HHMMSS_XXXXXX` est créé
- `LastBackupDate` est mise à jour

### Exemple 4 : Première sauvegarde (forçage automatique en Full)

```powershell
.\backup_file.ps1 -Type "dif" -IncludesFile "C:\Config\backup_sources.txt" -Policy "Critical"
```

**Comportement** :
- Le script détecte qu'aucun Full n'existe
- **Force automatiquement le type en "full"**
- Message dans le log : `"Aucune sauvegarde complète précédente trouvée. Forçage en 'full'."`

### Exemple 5 : Avec sources multiples

**Fichier `backup_sources.txt`** :
```
C:\Users\Alice\Documents
D:\SharedData\Projects
E:\Archives\2024
```

```powershell
.\backup_file.ps1 -Type "full" -IncludesFile "C:\Config\backup_sources.txt" -Policy "Critical"
```

**Structure créée** :
```
C:\Backups\Local\Critical\Critical_full_20241208_143022_A7X9Q2\
├── Documents\          (contenu de C:\Users\Alice\Documents)
│   ├── file1.docx
│   └── subfolder\
├── Projects\           (contenu de D:\SharedData\Projects)
│   └── project1\
└── 2024\              (contenu de E:\Archives\2024)
    └── archive.zip
```

### Exemple 6 : Stratégie de sauvegarde automatisée (Tâche planifiée)

**Sauvegarde complète hebdomadaire (Dimanche à 2h00)** :
```powershell
.\backup_file.ps1 -Type "full" -IncludesFile "C:\Config\backup_sources.txt" -Policy "Critical"
```

**Sauvegarde différentielle quotidienne (Lundi-Samedi à 2h00)** :
```powershell
.\backup_file.ps1 -Type "dif" -IncludesFile "C:\Config\backup_sources.txt" -Policy "Important"
```

**Sauvegarde incrémentielle toutes les 4h (8h, 12h, 16h, 20h)** :
```powershell
.\backup_file.ps1 -Type "inc" -IncludesFile "C:\Config\backup_sources.txt" -Policy "Standard"
```

## Fonctionnement détaillé

### Architecture du script

Le script est organisé en plusieurs régions fonctionnelles :

#### 1. **PARAMETERS** - Gestion des paramètres
Définit et valide les paramètres d'entrée :
- `Type` : Validé avec `ValidateSet` pour accepter uniquement "full", "dif", "inc"
- `IncludesFile` : Chemin vers le fichier de sources

#### 2. **GLOBAL_VARIABLES** - Variables globales
- `$timestamp` : Horodatage du backup au format `YYYYMMDD_HHMMSS`
- `$BackupID` : Identifiant unique de 6 caractères (généré par `New-ShortID`)
- `$LocalBackupRoot` : Racine de stockage (`C:\Backups\Local`)
- `$PolicyRoot` : Sous-répertoire de la policy (`C:\Backups\Local\{Policy}`)
- `$LogRoot` : Dossier des logs (`C:\Backups\Local\Logs`)
- `$LogFile` : Fichier de log spécifique (`Backup_{Policy}_{Type}.log`)

#### 3. **LOGGING** - Journalisation
Fonction `Write-Log` qui enregistre :
- Horodatage précis
- Identifiant de session (BackupID)
- Niveau de gravité (INFO, WARN, ERROR)
- Message descriptif

#### 4. **INPUT_VALIDATION** - Validation des entrées
- Vérifie l'existence du fichier includes
- Charge les chemins sources depuis le fichier
- Filtre les lignes vides

#### 5. **ENVIRONMENT_INITIALIZATION** - Initialisation de l'environnement
- Définit le chemin du fichier de métadonnées par policy (`$PolicyRoot\backup_state.json`)
- Crée les dossiers nécessaires (`LocalBackupRoot`, `PolicyRoot`, `LogRoot`)
- Génère le nom du backup courant : `{Policy}_{Type}_{timestamp}_{BackupID}`
- Crée le dossier de destination du backup dans `$PolicyRoot`

#### 6. **LOAD_METADATA** - Chargement des métadonnées
- Charge le fichier JSON d'état (si existant)
- Récupère `LastFullDate` et `LastBackupDate`
- Gère les erreurs de lecture (force un Full en cas d'échec)
- Vérifie qu'un Full existe pour les types Dif et Inc

#### 7. **DETERMINE_BACKUP_SCOPE** - Détermination de la portée
Calcule la date de référence selon le type :
- **Full** : Aucune date de référence (tous les fichiers)
- **Dif** : `referenceDate = LastFullDate`
- **Inc** : `referenceDate = LastBackupDate`

#### 8. **SCAN_SOURCES** - Analyse des sources
Pour chaque source :
- Vérifie l'existence du chemin
- Récupère les fichiers selon le mode :
  - Full : Tous les fichiers (`Get-ChildItem -Recurse`)
  - Dif/Inc : Fichiers avec `LastWriteTime > referenceDate`
- Construit une liste `$filesToBackup` avec la source et le fichier

#### 9. **BACKUP_EXECUTION** - Exécution de la sauvegarde
Pour chaque fichier à sauvegarder :
- Calcule le chemin relatif depuis la racine source
- Reconstruit l'arborescence dans le dossier de backup
- Copie le fichier avec gestion d'erreur individuelle
- Compte les fichiers copiés et les erreurs

#### 10. **UPDATE_METADATA** - Mise à jour des métadonnées
Selon le type de backup :
- **Full** : Met à jour `LastFullDate` ET `LastBackupDate`
- **Dif** : Met à jour uniquement `LastBackupDate`
- **Inc** : Met à jour uniquement `LastBackupDate`

Sauvegarde l'état dans `backup_state.json` au format JSON.

#### 11. **END** - Finalisation
- Vérifie s'il y a eu des erreurs
- Retourne un code de sortie approprié (0 = succès, 1 = erreurs)

### Algorithme de sauvegarde

```
1. Valider les paramètres et le fichier includes
2. Initialiser l'environnement (dossiers, logs)
3. Charger les métadonnées (backup_state.json)
4. Vérifier les prérequis :
   a. Si Type = "dif" ou "inc" ET pas de Full précédent → Forcer en "full"
5. Déterminer la date de référence selon le type
6. Pour chaque source dans le fichier includes :
   a. Vérifier l'existence du chemin
   b. Scanner les fichiers selon le critère de date
   c. Ajouter les fichiers à la liste de backup
7. Pour chaque fichier à sauvegarder :
   a. Calculer le chemin de destination
   b. Créer l'arborescence si nécessaire
   c. Copier le fichier
   d. Gérer les erreurs individuellement
8. Mettre à jour les métadonnées selon le type
9. Sauvegarder backup_state.json
10. Terminer avec code de sortie approprié
```

### Gestion des erreurs

Le script gère plusieurs types d'erreurs :

| Erreur | Message | Action | Code sortie |
|--------|---------|--------|-------------|
| Fichier includes introuvable | `Le fichier include liste est introuvable` | Arrêt immédiat | 1 |
| Métadonnées corrompues | `Impossible de lire le fichier de métadonnées` | Forçage en Full (WARN) | Continue |
| Pas de Full pour Dif/Inc | `Aucune sauvegarde complète précédente trouvée` | Forçage en Full (WARN) | Continue |
| Source introuvable | `Chemin source introuvable` | Ignore la source (WARN) | Continue |
| Aucune source valide | `Aucune source valide` | Arrêt | 2 |
| Erreur de copie d'un fichier | `Erreur lors de la copie de...` | Continue le backup (ERROR) | 1 à la fin |
| Erreur écriture métadonnées | `Erreur lors de l'écriture des métadonnées` | Continue (ERROR) | 1 |

**Principe** : Le script continue le plus loin possible malgré les erreurs non-critiques, mais les trace toutes dans le log.

## Fichier de métadonnées

### Format JSON (`backup_state.json`)

```json
{
  "LastFullDate": "2024-12-08T14:30:22.1234567+01:00",
  "LastBackupDate": "2024-12-08T18:15:45.9876543+01:00"
}
```

### Emplacement

```
C:\Backups\Local\{Policy}\backup_state.json
```

**Note** : Chaque policy possède son propre fichier de métadonnées indépendant.

Exemples :
- `C:\Backups\Local\Critical\backup_state.json`
- `C:\Backups\Local\Important\backup_state.json`
- `C:\Backups\Local\Standard\backup_state.json`

### Mise à jour selon le type

| Type de backup | LastFullDate | LastBackupDate |
|----------------|--------------|----------------|
| Full | Mise à jour | Mise à jour |
| Dif | Inchangé | Mise à jour |
| Inc | Inchangé | Mise à jour |

### Importance

Ce fichier est **critique** pour le fonctionnement des sauvegardes Dif et Inc :
- Sa suppression forcera un Full au prochain backup
- Sa corruption sera détectée et forcera un Full
- Il doit être protégé en écriture (éviter les modifications manuelles)

## Journalisation

### Fichiers de logs

Le script génère des logs séparés par combinaison Policy + Type :

```
C:\Backups\Local\Logs\Backup_Critical_full.log
C:\Backups\Local\Logs\Backup_Critical_dif.log
C:\Backups\Local\Logs\Backup_Critical_inc.log
C:\Backups\Local\Logs\Backup_Important_full.log
C:\Backups\Local\Logs\Backup_Important_dif.log
C:\Backups\Local\Logs\Backup_Important_inc.log
C:\Backups\Local\Logs\Backup_Standard_full.log
C:\Backups\Local\Logs\Backup_Standard_dif.log
C:\Backups\Local\Logs\Backup_Standard_inc.log
```

### Format des entrées

```
[YYYY-MM-DD HH:mm:ss - BACKUP_ID] [LEVEL] Message
```

**Exemple** :
```
[2024-12-08 14:30:22 - A7X9Q2] [INFO] Démarrage de la sauvegarde locale. Type = full; Policy = Critical
[2024-12-08 14:30:23 - A7X9Q2] [INFO] Métadonnées chargées depuis C:\Backups\Local\Critical\backup_state.json
[2024-12-08 14:30:24 - A7X9Q2] [INFO] Sauvegarde complète : tous les fichiers seront copiés.
[2024-12-08 14:30:25 - A7X9Q2] [INFO] Nombre total de fichiers à sauvegarder : 1247
[2024-12-08 14:32:18 - A7X9Q2] [ERROR] Erreur lors de la copie de 'C:\Data\locked.db' : Le fichier est utilisé par un autre processus
[2024-12-08 14:35:42 - A7X9Q2] [INFO] Copie terminée. Fichiers copiés : 1246 ; erreurs : 1
[2024-12-08 14:35:43 - A7X9Q2] [INFO] Métadonnées mises à jour dans C:\Backups\Local\Critical\backup_state.json
[2024-12-08 14:35:43 - A7X9Q2] [WARN] Sauvegarde terminée avec erreurs. Vérifier le log pour plus de détails.
```

### Niveaux de gravité

- **INFO** : Opération normale (démarrage, progression, succès)
- **WARN** : Avertissement (source introuvable, forçage en Full, fin avec erreurs)
- **ERROR** : Erreur (fichier non copié, métadonnées non sauvegardées)

## Sécurité et bonnes pratiques

### Garanties

**Pas d'écrasement** : Chaque backup crée un nouveau dossier unique  
**Traçabilité complète** : Toutes les opérations sont journalisées  
**Identifiant unique** : Chaque backup a un BackupID unique  
**Validation stricte** : Vérification de l'existence des sources  
**Isolation des erreurs** : Une erreur sur un fichier n'arrête pas le backup  

### Recommandations

#### 1. **Surveillance des logs**
- Vérifier régulièrement les logs pour détecter les erreurs récurrentes
- Automatiser l'envoi d'alertes en cas d'erreurs
- Monitorer le nombre de fichiers copiés (détection d'anomalies)

#### 2. **Test de restauration**
- Tester régulièrement la restauration (via `restore_file.ps1`)
- Vérifier l'intégrité des backups
- Documenter les procédures de restauration

#### 4. **Gestion de l'espace disque**
- Monitorer l'espace disponible dans `C:\Backups\Local`
- Mettre en place une politique de rétention (suppression des anciens backups)
- Estimer la croissance des Dif dans le temps

#### 5. **Protection du fichier includes**
- Sauvegarder le fichier includes lui-même
- Versionner les modifications (Git)
- Documenter les raisons des ajouts/suppressions de sources

#### 6. **Droits d'accès**
- Exécuter avec un compte ayant les droits en lecture sur toutes les sources
- Protéger le dossier `C:\Backups\Local` en écriture
- Restreindre l'accès au fichier de métadonnées

### Limitations connues

- Pas de compression des fichiers
- Pas de chiffrement des données
- Pas de vérification d'intégrité (checksum)
- Pas de déduplication
- Pas de limitation de bande passante
- Pas de gestion de la rétention automatique
- Fichiers verrouillés non sauvegardés (erreur silencieuse)

## Compatibilité

### Versions PowerShell

- **PowerShell 5.1** (Windows PowerShell) : Entièrement compatible
- **PowerShell 7+** (PowerShell Core) : Entièrement compatible

### Systèmes d'exploitation

- Windows 10/11
- Windows Server 2016+
- Windows Server 2019/2022
- Linux/macOS : Non testé, nécessiterait adaptation des chemins

## Notes importantes

### Stratégie de restauration

Pour restaurer des données, vous aurez besoin de :

**Depuis un Full** :
- Le dossier Full uniquement

**Depuis un Dif** :
- Le dernier Full + le Dif souhaité

**Depuis un Inc** :
- Le dernier Full + tous les Inc jusqu'à celui souhaité

### Optimisation des performances

**Pour accélérer les backups** :
- Exclure les fichiers temporaires du fichier includes
- Éviter les sources réseau (privilégier les disques locaux)
- Planifier les Full pendant les heures creuses
- Utiliser des SSD pour le stockage des backups

## Fichiers associés

- **Script principal** : `backup_file.ps1`
- **Documentation** : `docs/backup_file.md`
- **Script de restauration** : `restore_file.ps1`
- **Fichier de métadonnées** : `C:\Backups\Local\backup_state.json`
- **Logs** : `C:\Backups\Local\Logs\Backup_{type}.log`
- **Configuration** : Fichier includes (chemin personnalisé)

## Codes de sortie

| Code | Signification |
|------|---------------|
| 0 | Sauvegarde réussie sans erreur |
| 1 | Sauvegarde terminée avec des erreurs (fichiers non copiés) ou fichier includes introuvable ou erreur métadonnées |
| 2 | Aucune source valide trouvée |

## Exemple de structure de backup

### Avant sauvegarde

**Sources** :
```
C:\Users\Alice\Documents\
├── Contrats\
│   ├── client_A.pdf
│   └── client_B.docx
└── Rapports\
    └── 2024.xlsx

D:\Projects\
├── ProjectX\
│   └── code.py
└── ProjectY\
    └── data.csv
```

### Après sauvegarde Full

**Backup créé : `C:\Backups\Local\Critical\Critical_full_20241208_143022_A7X9Q2\`**
```
Critical_full_20241208_143022_A7X9Q2\
├── Documents\              (depuis C:\Users\Alice\Documents)
│   ├── Contrats\
│   │   ├── client_A.pdf
│   │   └── client_B.docx
│   └── Rapports\
│       └── 2024.xlsx
└── Projects\               (depuis D:\Projects)
    ├── ProjectX\
    │   └── code.py
    └── ProjectY\
        └── data.csv
```

### Après sauvegarde Dif (modification de 2 fichiers)

**Fichiers modifiés** :
- `client_A.pdf` (modifié)
- `code.py` (modifié)

**Backup créé : `C:\Backups\Local\Important\Important_dif_20241209_020000_B3K5L7\`**
```
Important_dif_20241209_020000_B3K5L7\
├── Documents\
│   └── Contrats\
│       └── client_A.pdf    (version modifiée)
└── Projects\
    └── ProjectX\
        └── code.py         (version modifiée)
```

---

**Auteur** : Projet XANADU
**Version** : 1.1
**Dernière mise à jour** : 11 décembre 2025
