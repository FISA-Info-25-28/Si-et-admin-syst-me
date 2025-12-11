# externalize_backups.ps1

## Synopsis

Script d'externalisation des sauvegardes locales XANADU vers un site distant via SFTP (protocole sécurisé).

## Description

Ce script PowerShell permet de transférer automatiquement les sauvegardes locales XANADU vers un serveur SFTP distant (site de secours Springfield ou Atlantis). Il constitue la couche de réplication du système de sauvegarde XANADU.

### Fonctionnalités principales

#### Détection intelligente des backups
Le script :
- Parcourt automatiquement le répertoire de sauvegarde local (`C:\Backups\Local` par défaut)
- Détecte tous les dossiers de sauvegarde selon leur préfixe : `full_*`, `dif_*`, `inc_*`
- Identifie les backups selon leur niveau de politique (Critical, Important, Standard)
- Filtre par type si spécifié (full, dif, inc ou all)

#### Gestion d'état pour éviter les doublons
Le script maintient un fichier JSON (`external_state.json`) qui enregistre :
- **SentBackups** : Dictionnaire des backups déjà externalisés avec :
  - `FirstSent` : Date du premier envoi réussi
  - `LastSent` : Date du dernier envoi
  - `LastStatus` : Statut du dernier transfert (SUCCESS/FAILED)
  - `RemotePath` : Chemin complet sur le serveur distant

**Garantie** : Un backup déjà externalisé ne sera **jamais retransféré**, économisant bande passante et temps.

#### Transfert SFTP sécurisé via WinSCP
- Utilise la bibliothèque **WinSCP .NET** pour les transferts SFTP
- Connexion sécurisée avec authentification par mot de passe
- Support du transfert récursif de dossiers complets
- Création automatique de l'arborescence distante
- Log détaillé des opérations de transfert

#### Nommage avec suffixe _external
Chaque backup externalisé reçoit le suffixe `_external` sur le serveur distant pour :
- Faciliter l'identification des backups distants
- Éviter les conflits de noms
- Permettre la cohabitation de backups locaux et distants

**Exemple** :
- Local : `Critical_full_20241211_143022_A7X9Q2`
- Distant : `Critical_full_20241211_143022_A7X9Q2_external`

#### Mode DryRun (simulation)
Le paramètre `-DryRun` permet de :
- Simuler l'externalisation sans transférer de données
- Vérifier la configuration SFTP
- Identifier les backups qui seraient transférés
- Tester le script sans impact sur le réseau

#### Journalisation complète
Deux fichiers de logs sont générés :
- **Externalize.log** : Log principal du script avec toutes les opérations
- **Externalize_WinSCP.log** : Log détaillé de la session WinSCP (debug réseau)

Format des logs :
```
[YYYY-MM-DD HH:mm:ss - RUN_ID] [LEVEL] Message
```

## Paramètres

### `-Type` (Optionnel)
**Type** : `String`  
**Obligatoire** : Non  
**Valeurs autorisées** : `"full"`, `"dif"`, `"inc"`, `"all"`  
**Valeur par défaut** : `"all"`

Type de sauvegarde à externaliser.

```powershell
-Type "full"   # Uniquement les sauvegardes complètes
-Type "dif"    # Uniquement les sauvegardes différentielles
-Type "inc"    # Uniquement les sauvegardes incrémentielles
-Type "all"    # Tous les types (par défaut)
```

### `-BackupRoot` (Optionnel)
**Type** : `String`  
**Obligatoire** : Non  
**Valeur par défaut** : `"C:\Backups\Local"`

Chemin racine contenant les backups locaux à externaliser.

```powershell
-BackupRoot "C:\Backups\Local"
-BackupRoot "D:\Sauvegardes\Local"
```

### `-DryRun` (Optionnel)
**Type** : `Switch`  
**Obligatoire** : Non

Active le mode simulation : aucune donnée n'est transférée, le script indique seulement ce qu'il ferait.

```powershell
-DryRun
```

## Configuration SFTP

Le script nécessite une configuration SFTP qui doit être adaptée à votre environnement. Les paramètres sont définis dans la région **CONFIGURATION SFTP** du script :

### Variables de configuration

```powershell
$SftpHost   = "10.0.0.10"                           # IP/nom du serveur SFTP distant
$SftpPort   = 22                                    # Port SFTP (généralement 22)
$SftpUser   = "svc_backup"                          # Compte de service SFTP
$SftpPass   = "ChangeMe!"                           # Mot de passe (à sécuriser)
$RemoteBase = "C:\Backups\External"                 # Répertoire racine distant
$WinScpDllPath = "C:\Program Files (x86)\WinSCP\WinSCPnet.dll"
```

### Points d'attention

⚠️ **Sécurité du mot de passe** : 
- Le mot de passe est actuellement en clair dans le script
- **Recommandation** : Utiliser un coffre-fort (Azure Key Vault, CyberArk, etc.)
- Ou utiliser une authentification par clé SSH

⚠️ **Empreinte SSH (Fingerprint)** :
- Actuellement configuré avec `SshHostKeyPolicy = GiveUp` (accepte toute empreinte)
- **Recommandation** : Configurer l'empreinte réelle du serveur pour éviter les attaques MITM

⚠️ **Installation WinSCP** :
- Le script nécessite WinSCP installé avec la DLL .NET
- Télécharger : https://winscp.net/
- Vérifier le chemin de `WinSCPnet.dll` après installation

## Exemples d'utilisation

### Exemple 1 : Externalisation de tous les backups

Externalise tous les types de backups non encore transférés.

```powershell
.\externalize_backups.ps1
```

**Résultat** :
- Détecte tous les backups full, dif et inc
- Transfère uniquement ceux non encore externalisés
- Met à jour `external_state.json`
- Code de sortie : 0 si succès

### Exemple 2 : Externalisation des sauvegardes complètes uniquement

```powershell
.\externalize_backups.ps1 -Type "full"
```

**Résultat** :
- Détecte uniquement les backups `full_*`
- Ignore les backups dif et inc
- Transfère les nouveaux backups full

### Exemple 3 : Externalisation depuis un répertoire personnalisé

```powershell
.\externalize_backups.ps1 -BackupRoot "D:\Sauvegardes\Local"
```

**Résultat** : Recherche et externalise les backups depuis `D:\Sauvegardes\Local`

### Exemple 4 : Simulation (DryRun)

Teste le script sans transférer de données.

```powershell
.\externalize_backups.ps1 -DryRun
```

**Résultat** :
```
[2024-12-11 14:30:22 - ABC123] [INFO] === Démarrage externalisation (Type=all, DryRun=True) ===
[2024-12-11 14:30:23 - ABC123] [INFO] État d'externalisation chargé depuis C:\Backups\Local\external_state.json
[2024-12-11 14:30:24 - ABC123] [INFO] Sauvegardes à externaliser : Critical_full_20241211_143022_A7X9Q2, Important_dif_20241211_020000_B3K5L7
[2024-12-11 14:30:25 - ABC123] [INFO] Mode DryRun activé : aucune connexion SFTP, aucune donnée transférée.
[2024-12-11 14:30:26 - ABC123] [INFO] Traitement de la sauvegarde 'Critical_full_20241211_143022_A7X9Q2'
[2024-12-11 14:30:27 - ABC123] [INFO] Nom distant de la sauvegarde : Critical_full_20241211_143022_A7X9Q2_external (suffixe _external ajouté)
[2024-12-11 14:30:28 - ABC123] [INFO] DryRun : [SIMULATION] Création du dossier distant 'C:\Backups\External/Critical_full_20241211_143022_A7X9Q2_external' et transfert de 'C:\Backups\Local\Critical\Critical_full_20241211_143022_A7X9Q2\*'.
[2024-12-11 14:30:29 - ABC123] [INFO] Externalisation simulée (DryRun), aucune erreur de transfert réelle.
```

### Exemple 5 : Externalisation des incrémentielles uniquement

```powershell
.\externalize_backups.ps1 -Type "inc"
```

**Résultat** : Transfère uniquement les backups incrémentiels

### Exemple 6 : Combinaison Type + DryRun

Simule l'externalisation des sauvegardes complètes.

```powershell
.\externalize_backups.ps1 -Type "full" -DryRun
```

**Résultat** : Affiche quels backups full seraient transférés sans rien envoyer

## Fonctionnement détaillé

### Architecture du script

Le script est organisé en plusieurs régions fonctionnelles :

#### 1. **PARAMETERS** - Gestion des paramètres
Définit et valide les paramètres d'entrée :
- `Type` : Validé avec `ValidateSet` pour accepter uniquement "full", "dif", "inc", "all"
- `BackupRoot` : Chemin vers les backups locaux
- `DryRun` : Switch pour le mode simulation

#### 2. **CONFIGURATION SFTP** - Paramètres de connexion
Variables à adapter selon l'environnement :
- `$SftpHost` : Adresse IP ou nom d'hôte du serveur SFTP
- `$SftpPort` : Port SFTP (généralement 22)
- `$SftpUser` : Nom d'utilisateur pour l'authentification
- `$SftpPass` : Mot de passe (à sécuriser)
- `$RemoteBase` : Répertoire racine sur le serveur distant
- `$WinScpDllPath` : Chemin vers la DLL WinSCP .NET

#### 3. **GLOBALS / LOGGING** - Initialisation et journalisation
- Crée le dossier `Logs` si nécessaire
- Génère un identifiant unique de session (`RunID`) pour le traçage
- Fonction `Write-Log` pour enregistrer toutes les opérations
- Initialise les fichiers de log

#### 4. **VÉRIFICATIONS PRÉALABLES** - Validation de l'environnement
Trois vérifications critiques :
1. **Existence de BackupRoot** : Vérifie que le dossier de backups existe
2. **Présence de WinSCP DLL** : Vérifie et charge la bibliothèque WinSCP .NET
3. **Chargement de l'état** : Lit `external_state.json` pour connaître les backups déjà envoyés

#### 5. **DÉTECTION DES BACKUPS À ENVOYER** - Analyse et filtrage
- Liste tous les dossiers de backup dans `BackupRoot`
- Filtre selon le pattern : `^(full|dif|inc)_`
- Applique le filtre de type si spécifié (full/dif/inc)
- Exclut les backups déjà présents dans `external_state.json`
- Génère la liste des backups en attente d'externalisation

#### 6. **SESSION SFTP** - Connexion au serveur distant
En mode normal (non DryRun) :
- Crée un objet `SessionOptions` avec les paramètres SFTP
- Initialise une session WinSCP
- Configure le log détaillé WinSCP
- Ouvre la connexion SFTP
- Gère les erreurs de connexion

#### 7. **TRANSFERTS** - Exécution des envois
Pour chaque backup en attente :
- Ajoute le suffixe `_external` au nom distant
- Crée le répertoire distant
- Configure les options de transfert (mode binaire)
- Effectue le transfert récursif (`PutFiles`)
- Vérifie le résultat du transfert
- Met à jour l'état avec le statut (SUCCESS/FAILED)
- Comptabilise les erreurs

#### 8. **SAUVEGARDE DE L'ÉTAT** - Persistance des métadonnées
- Sérialise l'objet `$state` en JSON
- Écrit dans `external_state.json`
- Gère les erreurs d'écriture

#### 9. **FIN** - Finalisation et codes de retour
- Ferme la session SFTP si ouverte
- Journalise le résumé de l'exécution
- Retourne le code de sortie approprié

### Algorithme d'externalisation

```
1. Valider les paramètres et charger la configuration
2. Vérifier l'existence de BackupRoot
3. Charger la DLL WinSCP .NET
4. Charger l'état d'externalisation (external_state.json)
5. Détecter tous les backups locaux selon le pattern
6. Filtrer par Type si spécifié
7. Exclure les backups déjà externalisés (présents dans l'état)
8. Si aucun backup à transférer → sortie avec code 2
9. Si DryRun → simuler et sortir avec code 0
10. Sinon :
    a. Ouvrir la session SFTP
    b. Pour chaque backup en attente :
       - Ajouter suffixe _external au nom distant
       - Créer le répertoire distant
       - Transférer récursivement tous les fichiers
       - Mettre à jour l'état selon le résultat
    c. Fermer la session SFTP
11. Sauvegarder l'état dans external_state.json
12. Retourner code de sortie selon les erreurs
```

### Gestion des erreurs

Le script gère plusieurs types d'erreurs :

| Erreur | Message | Action | Code sortie |
|--------|---------|--------|-------------|
| BackupRoot introuvable | `Répertoire de sauvegarde introuvable` | Arrêt immédiat | 1 |
| DLL WinSCP introuvable | `DLL WinSCP introuvable` | Arrêt immédiat | 1 |
| Erreur chargement DLL | `Erreur lors du chargement de la DLL WinSCP` | Arrêt immédiat | 1 |
| Erreur lecture état | `Impossible de lire external_state.json` | Continue (WARN), état vide | 0 |
| Aucun backup à envoyer | `Aucune sauvegarde locale trouvée` | Arrêt propre | 2 |
| Tous déjà externalisés | `Toutes les sauvegardes ont déjà été externalisées` | Arrêt propre | 2 |
| Erreur connexion SFTP | `Erreur lors de l'ouverture de la session SFTP` | Arrêt immédiat | 3 |
| Échec transfert | `Échec du transfert` | Continue les autres (ERROR) | 4 à la fin |
| Exception transfert | `Exception lors du transfert` | Continue les autres (ERROR) | 4 à la fin |
| Erreur écriture état | `Erreur lors de l'écriture du fichier d'état` | Continue (ERROR) | Selon erreurs transfert |

**Principe** : Le script continue le plus loin possible malgré les erreurs de transfert individuelles, mais les trace toutes dans le log.

## Fichier d'état (external_state.json)

### Format JSON

```json
{
  "SentBackups": {
    "Critical_full_20241211_143022_A7X9Q2": {
      "FirstSent": "2024-12-11T14:30:45.1234567+01:00",
      "LastSent": "2024-12-11T14:30:45.1234567+01:00",
      "LastStatus": "SUCCESS",
      "RemotePath": "C:/Backups/External/Critical_full_20241211_143022_A7X9Q2_external"
    },
    "Important_dif_20241211_020000_B3K5L7": {
      "FirstSent": "2024-12-11T14:32:10.9876543+01:00",
      "LastSent": "2024-12-11T14:32:10.9876543+01:00",
      "LastStatus": "SUCCESS",
      "RemotePath": "C:/Backups/External/Important_dif_20241211_020000_B3K5L7_external"
    },
    "Standard_inc_20241211_080000_C8Q1XK": {
      "FirstSent": null,
      "LastSent": "2024-12-11T14:35:22.5555555+01:00",
      "LastStatus": "FAILED",
      "RemotePath": "C:/Backups/External/Standard_inc_20241211_080000_C8Q1XK_external"
    }
  }
}
```

### Structure

- **SentBackups** : Dictionnaire clé-valeur
  - **Clé** : Nom du dossier de backup local
  - **Valeur** : Objet contenant :
    - `FirstSent` : Date du premier envoi réussi (null si jamais réussi)
    - `LastSent` : Date du dernier envoi (réussi ou échoué)
    - `LastStatus` : Statut du dernier transfert ("SUCCESS" ou "FAILED")
    - `RemotePath` : Chemin complet du backup sur le serveur distant

### Emplacement

```
$BackupRoot\external_state.json
```

Exemple : `C:\Backups\Local\external_state.json`

### Importance

Ce fichier est **critique** pour le fonctionnement du script :
- Évite les transferts en double (économie de bande passante)
- Permet de relancer le script sans retransférer les backups déjà envoyés
- Conserve l'historique des transferts
- **Sa suppression forcera le retransfert de tous les backups**

## Journalisation

### Fichiers de logs

Le script génère deux fichiers de logs :

```
C:\Backups\Local\Logs\Externalize.log          # Log principal du script
C:\Backups\Local\Logs\Externalize_WinSCP.log   # Log détaillé WinSCP
```

### Format des entrées (Externalize.log)

```
[YYYY-MM-DD HH:mm:ss - RUN_ID] [LEVEL] Message
```

**Exemple** :
```
[2024-12-11 14:30:22 - ABC123] [INFO] === Démarrage externalisation (Type=all, DryRun=False) ===
[2024-12-11 14:30:23 - ABC123] [INFO] DLL WinSCP chargée avec succès.
[2024-12-11 14:30:24 - ABC123] [INFO] État d'externalisation chargé depuis C:\Backups\Local\external_state.json
[2024-12-11 14:30:25 - ABC123] [INFO] Sauvegardes à externaliser : Critical_full_20241211_143022_A7X9Q2, Important_dif_20241211_020000_B3K5L7
[2024-12-11 14:30:26 - ABC123] [INFO] Connexion SFTP ouverte vers 10.0.0.10:22.
[2024-12-11 14:30:27 - ABC123] [INFO] Traitement de la sauvegarde 'Critical_full_20241211_143022_A7X9Q2'
[2024-12-11 14:30:28 - ABC123] [INFO] Nom distant de la sauvegarde : Critical_full_20241211_143022_A7X9Q2_external (suffixe _external ajouté)
[2024-12-11 14:30:29 - ABC123] [INFO] Création du répertoire distant : C:/Backups/External/Critical_full_20241211_143022_A7X9Q2_external
[2024-12-11 14:30:30 - ABC123] [INFO] Début du transfert de 'C:\Backups\Local\Critical\Critical_full_20241211_143022_A7X9Q2\*' vers 'C:/Backups/External/Critical_full_20241211_143022_A7X9Q2_external'.
[2024-12-11 14:35:42 - ABC123] [INFO] Transfert réussi pour 'Critical_full_20241211_143022_A7X9Q2'.
[2024-12-11 14:35:43 - ABC123] [INFO] Session SFTP fermée.
[2024-12-11 14:35:44 - ABC123] [INFO] État d'externalisation mis à jour dans C:\Backups\Local\external_state.json.
[2024-12-11 14:35:45 - ABC123] [INFO] Externalisation terminée avec succès, aucune erreur de transfert.
[2024-12-11 14:35:45 - ABC123] [INFO] === Fin externalisation (OK) ===
```

### Niveaux de gravité

- **INFO** : Opération normale (démarrage, connexion, transfert réussi, fin)
- **WARN** : Avertissement (état non lisible, aucun backup à transférer)
- **ERROR** : Erreur (connexion échouée, transfert échoué, DLL introuvable)

### Log WinSCP (Externalize_WinSCP.log)

Fichier de log technique généré par WinSCP contenant :
- Détails de la connexion SSH/SFTP
- Négociation des algorithmes de chiffrement
- Transferts de fichiers individuels
- Erreurs réseau détaillées
- Utile pour le débogage des problèmes de connexion ou de transfert

## Sécurité et bonnes pratiques

### Garanties

**Pas de retransfert** : Les backups déjà externalisés ne sont jamais retransférés  
**Traçabilité complète** : Toutes les opérations sont journalisées  
**Identifiant unique** : Chaque exécution a un RunID unique  
**Validation stricte** : Vérification de l'existence de tous les prérequis  
**Isolation des erreurs** : Une erreur sur un backup n'arrête pas les autres transferts  
**Suffixe _external** : Identification claire des backups distants  

### Recommandations

#### 1. **Sécurisation des identifiants**
⚠️ **Critique** : Le mot de passe est actuellement en clair dans le script.

**Solutions recommandées** :
- Utiliser un coffre-fort de mots de passe (Azure Key Vault, CyberArk)
- Utiliser l'authentification par clé SSH (plus sécurisée)
- Utiliser des variables d'environnement chiffrées
- Ne jamais versionner le script avec les identifiants réels

**Exemple avec SecureString** :
```powershell
$securePass = Read-Host "Mot de passe SFTP" -AsSecureString
$SftpPass = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePass))
```

#### 2. **Configuration de l'empreinte SSH**
⚠️ **Sécurité** : Actuellement configuré avec `SshHostKeyPolicy = GiveUp` (accepte toute empreinte).

**Recommandation** :
```powershell
# Récupérer l'empreinte du serveur SFTP (à faire une fois)
# Puis configurer :
$sessionOptions.SshHostKeyFingerprint = "ssh-rsa 2048 xx:xx:xx:xx:..."
```

#### 3. **Surveillance et alertes**
- Vérifier régulièrement `Externalize.log` pour détecter les erreurs
- Automatiser l'envoi d'alertes en cas d'échec de transfert
- Monitorer l'espace disque sur le serveur distant
- Surveiller le délai entre backup et externalisation

#### 4. **Test du DryRun avant mise en production**
- Toujours tester avec `-DryRun` avant la première exécution réelle
- Vérifier la configuration SFTP
- Valider les chemins distants
- Confirmer que les backups détectés sont corrects

#### 5. **Planification automatique**
Créer une tâche planifiée pour externaliser régulièrement :
```powershell
# Exemple : externalisation quotidienne à 4h00
.\scheduler_backup.ps1 -Cron "0 4 * * *" `
    -Type "full" `
    -Includes "C:\Scripts\externalize.txt" `
    -TaskName "externalize_daily"
```

#### 6. **Gestion de la bande passante**
- Planifier les externalisations pendant les heures creuses
- Externaliser les backups full pendant la nuit
- Externaliser les dif/inc plus fréquemment (plus légers)
- Monitorer l'utilisation du réseau WAN

#### 7. **Protection du fichier d'état**
- Sauvegarder régulièrement `external_state.json`
- Le versionner avec le système de gestion de configuration
- Ne pas le modifier manuellement
- En cas de perte, tous les backups seront retransférés

#### 8. **Vérification post-transfert**
- Implémenter un script de vérification d'intégrité côté distant
- Comparer le nombre de fichiers transférés
- Vérifier la taille totale des backups
- Tester régulièrement la restauration depuis le site distant

### Limitations connues

- Pas de compression des transferts SFTP
- Pas de reprise de transfert en cas d'interruption (fichiers partiels perdus)
- Pas de vérification d'intégrité par checksum automatique
- Pas de limitation de bande passante
- Pas de parallélisation des transferts (un à la fois)
- Mot de passe en clair dans le script (à sécuriser)
- Pas de gestion automatique de la rétention sur le site distant
- Pas de notification par email en cas d'erreur

## Compatibilité

### Versions PowerShell

- **PowerShell 5.1** (Windows PowerShell) : ✅ Compatible
- **PowerShell 7+** (PowerShell Core) : ✅ Compatible

### Dépendances

**WinSCP .NET** :
- Version requise : 5.17+ recommandée
- Téléchargement : https://winscp.net/
- Installation : Installer WinSCP avec l'option ".NET assembly/COM library"
- La DLL `WinSCPnet.dll` doit être accessible

### Systèmes d'exploitation

- Windows 10/11
- Windows Server 2016+
- Windows Server 2019/2022
- Linux/macOS : Non compatible (utilise WinSCP .NET, spécifique Windows)

### Protocoles supportés

- **SFTP** (SSH File Transfer Protocol) : ✅ Supporté et recommandé
- **FTP** : ❌ Non supporté par ce script (non sécurisé)
- **FTPS** : ❌ Non supporté par ce script
- **SCP** : ❌ Non supporté par ce script

## Notes importantes

### Différences Local vs External

**Structure locale** :
```
C:\Backups\Local\
├── Critical\
│   ├── Critical_full_20241211_143022_A7X9Q2\
│   └── Critical_dif_20241211_020000_B3K5L7\
├── Important\
│   └── Important_inc_20241211_080000_C8Q1XK\
└── Standard\
```

**Structure distante** (avec suffixe _external) :
```
C:\Backups\External\
├── Critical_full_20241211_143022_A7X9Q2_external\
├── Critical_dif_20241211_020000_B3K5L7_external\
├── Important_inc_20241211_080000_C8Q1XK_external\
└── Standard_...
```

**Note** : La structure par Policy n'est pas recréée sur le distant, tous les backups sont au même niveau avec le suffixe `_external`.

### Stratégie d'externalisation recommandée

**Backups Full** :
- Externaliser immédiatement après création
- Priorité maximale (données complètes)
- Prévoir suffisamment de temps pour le transfert

**Backups Dif** :
- Externaliser quotidiennement
- Moins prioritaire que Full
- Plus rapide à transférer

**Backups Inc** :
- Externaliser toutes les 4-6 heures
- Priorité faible (données minimales)
- Transfert très rapide

### Ordre de restauration depuis le distant

Pour restaurer depuis le site distant, il faut :

**Depuis un Full** :
- Télécharger le backup Full correspondant

**Depuis un Dif** :
- Télécharger le dernier Full + le Dif souhaité

**Depuis un Inc** :
- Télécharger le dernier Full + tous les Inc jusqu'à celui souhaité

## Fichiers associés

- **Script principal** : `externalize_backups.ps1`
- **Documentation** : `docs/externalize_backups.md`
- **Script de backup local** : `backup_file.ps1`
- **Script de restauration** : `restore_file.ps1`
- **Fichier d'état** : `C:\Backups\Local\external_state.json`
- **Log principal** : `C:\Backups\Local\Logs\Externalize.log`
- **Log WinSCP** : `C:\Backups\Local\Logs\Externalize_WinSCP.log`

## Codes de sortie

| Code | Signification |
|------|---------------|
| 0 | Externalisation réussie sans erreur (ou DryRun simulé) |
| 1 | Erreur de configuration (BackupRoot introuvable, DLL WinSCP manquante) |
| 2 | Aucune sauvegarde à externaliser (rien de nouveau ou tous déjà envoyés) |
| 3 | Erreur de connexion SFTP (serveur inaccessible, identifiants incorrects) |
| 4 | Erreur de transfert (un ou plusieurs backups n'ont pas pu être transférés) |

## Cas d'usage avancés

### Externalisation immédiate après backup

Chaîner l'externalisation après chaque backup :

```powershell
# Backup Full
.\backup_file.ps1 -Type "full" -IncludesFile "C:\Config\sources.txt" -Policy "Critical"

# Externalisation immédiate
if ($LASTEXITCODE -eq 0) {
    .\externalize_backups.ps1 -Type "full"
}
```

### Script de vérification de l'état

Vérifier quels backups ont été externalisés :

```powershell
$state = Get-Content "C:\Backups\Local\external_state.json" | ConvertFrom-Json

foreach ($backup in $state.SentBackups.PSObject.Properties) {
    Write-Host "Backup: $($backup.Name)"
    Write-Host "  Status: $($backup.Value.LastStatus)"
    Write-Host "  Last Sent: $($backup.Value.LastSent)"
    Write-Host "  Remote: $($backup.Value.RemotePath)"
    Write-Host ""
}
```

### Externalisation avec retry automatique

Script avec retry en cas d'échec :

```powershell
$maxRetries = 3
$retryCount = 0
$success = $false

while (-not $success -and $retryCount -lt $maxRetries) {
    .\externalize_backups.ps1 -Type "all"
    
    if ($LASTEXITCODE -eq 0) {
        $success = $true
        Write-Host "Externalisation réussie."
    }
    else {
        $retryCount++
        Write-Host "Échec de l'externalisation. Tentative $retryCount/$maxRetries"
        Start-Sleep -Seconds 300  # Attendre 5 minutes avant de réessayer
    }
}
```

### Notification par email après externalisation

```powershell
.\externalize_backups.ps1

if ($LASTEXITCODE -eq 0) {
    Send-MailMessage -To "admin@company.com" `
                     -From "backup@xanadu.local" `
                     -Subject "Externalisation XANADU - Succès" `
                     -Body "Les backups ont été externalisés avec succès." `
                     -SmtpServer "smtp.company.com"
}
else {
    Send-MailMessage -To "admin@company.com" `
                     -From "backup@xanadu.local" `
                     -Subject "Externalisation XANADU - ÉCHEC" `
                     -Body "L'externalisation a échoué. Code: $LASTEXITCODE. Vérifier les logs." `
                     -SmtpServer "smtp.company.com" `
                     -Priority High
}
```

## Dépannage

### Problème : "DLL WinSCP introuvable"

**Cause** : WinSCP n'est pas installé ou le chemin de la DLL est incorrect.

**Solution** :
1. Télécharger WinSCP : https://winscp.net/
2. Installer avec l'option ".NET assembly/COM library"
3. Vérifier le chemin de la DLL :
```powershell
Get-ChildItem "C:\Program Files*\WinSCP\WinSCPnet.dll" -Recurse
```
4. Ajuster `$WinScpDllPath` dans le script

### Problème : "Erreur lors de l'ouverture de la session SFTP"

**Causes possibles** :
- Serveur SFTP inaccessible (réseau, firewall)
- Identifiants incorrects
- Port SFTP incorrect
- Problème d'empreinte SSH

**Diagnostic** :
1. Tester la connexion réseau :
```powershell
Test-NetConnection -ComputerName 10.0.0.10 -Port 22
```
2. Vérifier les identifiants
3. Consulter `Externalize_WinSCP.log` pour les détails
4. Tester avec WinSCP GUI pour valider la configuration

### Problème : "Aucune sauvegarde à externaliser" (alors qu'il y en a)

**Cause** : Le fichier `external_state.json` contient déjà ces backups.

**Solution** :
- Vérifier le contenu de `external_state.json`
- Si besoin de retransférer : supprimer l'entrée correspondante dans le fichier
- Ou supprimer complètement `external_state.json` (retransfère tout)

### Problème : Transfert très lent

**Causes possibles** :
- Bande passante limitée
- Gros volume de données
- Problèmes réseau

**Solutions** :
- Planifier pendant les heures creuses
- Vérifier la bande passante disponible
- Externaliser par type (full séparément des inc/dif)
- Monitorer les performances réseau

### Problème : Backup partiel sur le distant

**Cause** : Interruption du transfert avant la fin.

**Solution** :
- Les fichiers partiels restent sur le distant
- L'état marque le backup comme "FAILED"
- Le prochain run tentera de retransférer
- Supprimer manuellement le dossier partiel sur le distant si nécessaire

---

**Auteur** : Projet XANADU  
**Version** : 1.0  
**Dernière mise à jour** : 11 décembre 2025
