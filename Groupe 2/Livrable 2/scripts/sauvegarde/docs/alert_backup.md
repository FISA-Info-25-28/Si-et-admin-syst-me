# alert_backup.ps1

## Synopsis

Script d'alerte automatique pour la détection et la notification des erreurs dans les opérations de sauvegarde et de restauration du système XANADU.

## Description

Ce script PowerShell surveille les fichiers de log produits par les scripts de sauvegarde et de restauration du système XANADU. Il analyse automatiquement les journaux, détecte les anomalies, et envoie des alertes par email aux administrateurs via le serveur SMTP interne (Poste.io).

### Fonctionnalités principales

#### Surveillance centralisée des logs
Le script analyse tous les fichiers de log présents dans le répertoire configuré :
- **Logs de backup** : `Backup_<Policy>_<Type>.log`
- **Logs d'externalisation** : `Backup_<Policy>_<Type>_external.log`
- **Support multi-policy** : Critical, Important, Standard
- **Support multi-type** : full, dif, inc

#### Détection intelligente des erreurs

Le script utilise plusieurs méthodes de détection :

##### 1. Détection par niveau de log
Recherche de lignes contenant le marqueur `[ERROR]` dans les fichiers de log.

##### 2. Détection par message d'état
Identifie les messages de fin anormale :
- `"terminée avec erreurs"`
- Messages de fin de script indiquant un échec

##### 3. Détection par mots-clés
Recherche de termes indicateurs d'erreur :
- `fail` : Échec (anglais)
- `fatal` : Erreur fatale
- `échec` : Échec (français)
- `incident` : Incident

##### 4. Détection de fichiers vides
Un fichier de log vide est considéré comme suspect :
- Indique un crash avant écriture
- Script arrêté prématurément
- Problème de permissions

#### Extraction automatique des métadonnées

Pour chaque log en erreur, le script extrait automatiquement :
- **Policy** : Criticité (Critical, Important, Standard)
- **Type** : Type de backup (full, dif, inc)
- **Statut d'externalisation** : Local ou externalisé

**Parsing du nom de fichier** :
```
Backup_Critical_full.log           → Policy=Critical, Type=full, External=False
Backup_Important_dif_external.log  → Policy=Important, Type=dif, External=True
Backup_Standard_inc.log            → Policy=Standard, Type=inc, External=False
```

#### Notification par email (SMTP)

En cas d'erreur détectée, le script envoie automatiquement un email contenant :
- **Métadonnées** : Policy, Type, statut d'externalisation
- **Chemin du log** : Fichier concerné
- **Résumé** : Les 20 dernières lignes du log
- **Pièce jointe** : Fichier de log complet

**Configuration SMTP** :
- Support de Poste.io (SMTP interne)
- Authentification sécurisée
- TLS/SSL activé (port 587)
- Multi-destinataires

#### Journalisation des alertes

Toutes les opérations du script sont enregistrées dans `Alert.log` :
- Logs analysés
- Anomalies détectées
- Emails envoyés
- Erreurs d'envoi

## Paramètres

### `-LogsRoot` (Optionnel)
**Type** : `String`  
**Obligatoire** : Non  
**Valeur par défaut** : `"C:\Backups\Local\Logs"`

Répertoire racine contenant les fichiers de log à surveiller.

**Structure attendue** :
```
C:\Backups\Local\Logs\
├── Backup_Critical_full.log
├── Backup_Critical_dif.log
├── Backup_Critical_inc.log
├── Backup_Important_full.log
├── Backup_Important_dif.log
├── Backup_Important_inc.log
├── Backup_Standard_full.log
├── Backup_Standard_dif.log
├── Backup_Standard_inc.log
├── Backup_Critical_full_external.log
├── Backup_Important_dif_external.log
└── Alert.log
```

**Exemples** :
```powershell
-LogsRoot "C:\Backups\Local\Logs"
-LogsRoot "D:\Sauvegardes\Logs"
```

## Configuration SMTP (à personnaliser)

Avant la première utilisation, modifier les variables globales dans le script :

### Variables à configurer

```powershell
# SMTP interne (poste.io)
$SmtpServer = "192.168.X.X"       # Adresse IP du serveur SMTP
$SmtpPort   = 587                 # Port SMTP (25 sans TLS, 587 avec TLS)

# Compte d'envoi
$MailFrom   = "sauvegardes@xanadu.local"     # Adresse d'expédition
$MailUser   = "sauvegardes@xanadu.local"     # Identifiant SMTP
$MailPass   = "CHANGE_ME"                    # Mot de passe SMTP

# Destinataires
$MailTo     = @("admin@xanadu.local")        # Liste des administrateurs
```

### Configuration recommandée

#### Serveur SMTP Poste.io
```powershell
$SmtpServer = "192.168.1.10"      # IP du serveur Poste.io
$SmtpPort   = 587                 # Port TLS
```

#### Compte de service dédié
```powershell
$MailFrom   = "backup-alerts@xanadu.local"
$MailUser   = "backup-alerts@xanadu.local"
$MailPass   = "M0tD3P@ss3C0mpl3x3!"
```

#### Multi-destinataires
```powershell
$MailTo = @(
    "admin1@xanadu.local",
    "admin2@xanadu.local",
    "supervision@xanadu.local"
)
```

#### Objet et log personnalisés
```powershell
$MailSubject = "[XANADU] ALERTE : Erreur dans une sauvegarde/restauration"
$AlertLog    = Join-Path $LogsRoot "Alert.log"
```

## Exemples d'utilisation

### Exemple 1 : Analyse avec configuration par défaut

Analyse les logs dans `C:\Backups\Local\Logs`.

```powershell
.\alert_backup.ps1
```

**Résultat attendu** (aucune erreur) :
```
# Rien en sortie console
# Dans Alert.log :
[2024-12-11 16:00:00] [INFO] Analyse des logs dans C:\Backups\Local\Logs
[2024-12-11 16:00:01] [INFO] Aucune anomalie détectée.
```

**Résultat attendu** (avec erreurs) :
```
# Dans Alert.log :
[2024-12-11 16:00:00] [INFO] Analyse des logs dans C:\Backups\Local\Logs
[2024-12-11 16:00:01] [WARN] 2 log(s) présentent des anomalies.
[2024-12-11 16:00:01] [WARN]  → Anomalie détectée dans : C:\Backups\Local\Logs\Backup_Critical_full.log
[2024-12-11 16:00:01] [WARN]  → Anomalie détectée dans : C:\Backups\Local\Logs\Backup_Important_dif.log
[2024-12-11 16:00:02] [INFO] Alerte envoyée (log : C:\Backups\Local\Logs\Backup_Critical_full.log)
[2024-12-11 16:00:03] [INFO] Alerte envoyée (log : C:\Backups\Local\Logs\Backup_Important_dif.log)
```

### Exemple 2 : Analyse avec répertoire personnalisé

```powershell
.\alert_backup.ps1 -LogsRoot "D:\Sauvegardes\Logs"
```

**Résultat** : Analyse les logs dans `D:\Sauvegardes\Logs`

### Exemple 3 : Planification quotidienne avec Scheduler

Exécute automatiquement l'analyse tous les jours à 8h00.

```powershell
# Créer une tâche planifiée Windows
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\Scripts\alert_backup.ps1"

$trigger = New-ScheduledTaskTrigger -Daily -At "08:00"

$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

Register-ScheduledTask -TaskName "XANADU_Alert_Daily" `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Description "Analyse quotidienne des logs de sauvegarde XANADU"
```

### Exemple 4 : Intégration avec CRON (PowerShell Core Linux)

```bash
# Ajouter au crontab
crontab -e

# Exécuter tous les jours à 8h00
0 8 * * * pwsh -File /opt/xanadu/scripts/alert_backup.ps1 -LogsRoot "/mnt/backups/logs"
```

### Exemple 5 : Test manuel après un backup

Tester immédiatement après un backup pour vérifier les erreurs.

```powershell
# Lancer un backup
.\backup_file.ps1 -Includes "C:\Data\includes.txt" -Type "full" -Policy "Critical"

# Analyser immédiatement
.\alert_backup.ps1

# Vérifier le résultat
Get-Content "C:\Backups\Local\Logs\Alert.log" -Tail 10
```

### Exemple 6 : Surveillance continue (boucle)

Script de surveillance en continu toutes les 10 minutes.

```powershell
# Script de surveillance continue
while ($true) {
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Analyse des logs..."
    
    .\alert_backup.ps1
    
    Write-Host "Prochaine analyse dans 10 minutes..."
    Start-Sleep -Seconds 600
}
```

## Format du mail d'alerte

### Exemple de mail reçu

**De** : `sauvegardes@xanadu.local`  
**À** : `admin@xanadu.local`  
**Objet** : `[XANADU] ALERTE : Erreur dans une sauvegarde/restauration`  
**Pièce jointe** : `Backup_Critical_full.log`

**Corps du message** :
```
Une erreur a été détectée dans les opérations de sauvegarde/restauration XANADU.

Détails :
Type        : full
Criticité   : Critical
Externalisé : False

Fichier concerné :
C:\Backups\Local\Logs\Backup_Critical_full.log

Résumé des dernières lignes :
[2024-12-11 14:30:00] [INFO] === Démarrage backup (Type=full, Policy=Critical) ===
[2024-12-11 14:30:01] [INFO] Lecture du fichier d'inclusion...
[2024-12-11 14:30:02] [INFO] Création du dossier de backup...
[2024-12-11 14:35:45] [INFO] Traitement de C:\Data\fichier1.txt
[2024-12-11 14:36:12] [ERROR] Impossible de copier C:\Data\fichier2.txt : Accès refusé
[2024-12-11 14:40:00] [ERROR] Impossible de copier C:\Data\fichier3.txt : Le fichier est utilisé par un autre processus
[2024-12-11 14:45:30] [INFO] 100 fichiers copiés, 2 erreurs
[2024-12-11 14:45:31] [INFO] Sauvegarde terminée avec erreurs.
[2024-12-11 14:45:32] [INFO] === Fin backup ===

Veuillez consulter le fichier joint pour plus de détails.
```

## Fonctionnement détaillé

### Architecture du script

Le script est organisé en 6 régions fonctionnelles :

#### 1. **PARAMÈTRES** - Gestion des arguments
Définit le paramètre `-LogsRoot` avec valeur par défaut.

#### 2. **VARIABLES GLOBALES** - Configuration SMTP
Centralise toutes les variables de configuration :
- Serveur SMTP et port
- Identifiants d'authentification
- Destinataires
- Objet du mail
- Chemin du log interne

#### 3. **LOGGING** - Fonction de journalisation
`Write-AlertLog` : Enregistre tous les événements dans `Alert.log`
- Format : `[YYYY-MM-DD HH:mm:ss] [LEVEL] Message`
- Niveaux : INFO, WARN, ERROR

#### 4. **EXTRACTION DES MÉTADONNÉES** - Parsing des noms
`Get-BackupMetadataFromLogPath` : Analyse le nom du fichier de log
- Extrait : Policy, Type, statut External
- Pattern regex : `^Backup_([A-Za-z]+)_([a-z]+)(?:_external)?\.log$`
- Retourne un objet PSCustomObject

#### 5. **DÉTECTION DES ERREURS** - Analyse des logs
`Get-LastLogsWithErrors` : Parcourt tous les logs et détecte les anomalies
- Vérifie si les fichiers sont vides
- Recherche les marqueurs d'erreur
- Retourne la liste des logs problématiques

#### 6. **ENVOI DE MAIL** - Notification SMTP
`Send-ErrorAlert` : Construit et envoie l'email d'alerte
- Extrait les métadonnées du log
- Construit le corps du message
- Attache le fichier de log
- Envoie via `Send-MailMessage` avec authentification

#### 7. **EXÉCUTION PRINCIPALE** - Orchestration
- Initialise le logging
- Recherche les logs avec erreurs
- Affiche le résumé
- Envoie les alertes pour chaque log problématique
- Sort avec code 0

### Algorithme de détection

```
1. Initialiser la journalisation
2. Récupérer tous les fichiers *.log dans LogsRoot
3. Pour chaque fichier de log :
   a. Si le fichier est vide → ALERTE
   b. Sinon, lire le contenu
   c. Rechercher les patterns d'erreur :
      - [ERROR]
      - "terminée avec erreurs"
      - fail|fatal|échec|incident
   d. Si trouvé → Ajouter à la liste des alertes
4. Si aucune alerte → Logger "Aucune anomalie" et sortir
5. Sinon, pour chaque log en alerte :
   a. Extraire les métadonnées (Policy, Type, External)
   b. Construire le corps du mail
   c. Envoyer l'email avec pièce jointe
   d. Logger le résultat (succès ou échec)
6. Sortir avec code 0
```

### Patterns de détection

| Pattern | Description | Exemple |
|---------|-------------|---------|
| `[ERROR]` | Ligne avec niveau ERROR | `[2024-12-11 14:36:12] [ERROR] Accès refusé` |
| `terminée avec erreurs` | Message de fin anormale | `Sauvegarde terminée avec erreurs.` |
| `fail` | Mot-clé échec (anglais) | `Failed to copy file` |
| `fatal` | Erreur fatale | `Fatal error during backup` |
| `échec` | Mot-clé échec (français) | `Échec de la connexion` |
| `incident` | Incident | `Incident lors du backup` |
| Fichier vide | 0 octets | - |

### Extraction des métadonnées (regex)

**Pattern** : `^Backup_([A-Za-z]+)_([a-z]+)(?:_external)?\.log$`

**Groupes de capture** :
- `([A-Za-z]+)` : Policy (Critical, Important, Standard)
- `([a-z]+)` : Type (full, dif, inc)
- `(?:_external)?` : Optionnel, présence du suffixe `_external`

**Exemples** :
```
Backup_Critical_full.log
→ Policy=Critical, Type=full, External=False

Backup_Important_dif_external.log
→ Policy=Important, Type=dif, External=True

Backup_Standard_inc.log
→ Policy=Standard, Type=inc, External=False
```

## Gestion des erreurs

Le script gère plusieurs types d'erreurs :

| Erreur | Message | Action | Impact |
|--------|---------|--------|--------|
| Serveur SMTP inaccessible | `Échec de l'envoi du mail` | Log dans Alert.log | Continue les autres alertes |
| Authentification SMTP échouée | `Échec de l'envoi du mail` | Log dans Alert.log | Continue les autres alertes |
| Fichier de log verrouillé | Lecture impossible | Log ignoré | Continue les autres logs |
| LogsRoot introuvable | Aucun fichier trouvé | Sortie propre | Aucune alerte |
| Fichier de log corrompu | Lecture partielle | Analyse partielle | Peut manquer des erreurs |

**Principe** : Le script ne s'arrête jamais, il continue à traiter tous les logs même en cas d'échec d'envoi.

## Journalisation

### Fichier de log

```
$LogsRoot\Alert.log
```

Exemple : `C:\Backups\Local\Logs\Alert.log`

### Format des entrées

```
[YYYY-MM-DD HH:mm:ss] [LEVEL] Message
```

**Exemple de log complet** (aucune erreur) :
```
[2024-12-11 08:00:00] [INFO] Analyse des logs dans C:\Backups\Local\Logs
[2024-12-11 08:00:01] [INFO] Aucune anomalie détectée.
```

**Exemple de log complet** (avec erreurs) :
```
[2024-12-11 08:00:00] [INFO] Analyse des logs dans C:\Backups\Local\Logs
[2024-12-11 08:00:01] [WARN] 3 log(s) présentent des anomalies.
[2024-12-11 08:00:01] [WARN]  → Anomalie détectée dans : C:\Backups\Local\Logs\Backup_Critical_full.log
[2024-12-11 08:00:01] [WARN]  → Anomalie détectée dans : C:\Backups\Local\Logs\Backup_Important_dif.log
[2024-12-11 08:00:01] [WARN]  → Anomalie détectée dans : C:\Backups\Local\Logs\Backup_Standard_inc_external.log
[2024-12-11 08:00:02] [INFO] Alerte envoyée (log : C:\Backups\Local\Logs\Backup_Critical_full.log)
[2024-12-11 08:00:03] [INFO] Alerte envoyée (log : C:\Backups\Local\Logs\Backup_Important_dif.log)
[2024-12-11 08:00:04] [ERROR] Échec de l'envoi du mail : La connexion SMTP a expiré
```

### Niveaux de gravité

- **INFO** : Opération normale (démarrage, aucune anomalie, alerte envoyée)
- **WARN** : Avertissement (anomalie détectée dans un log)
- **ERROR** : Erreur (échec d'envoi de mail)

## Sécurité et bonnes pratiques

### Protection des identifiants SMTP

⚠️ **Critique** : Le mot de passe SMTP est stocké en clair dans le script.

**Recommandations** :

#### 1. Utiliser un compte de service dédié
Créer un compte spécifique pour les alertes :
- `backup-alerts@xanadu.local`
- Droits limités : uniquement envoi de mail
- Pas d'accès aux autres ressources

#### 2. Stocker le mot de passe de manière sécurisée

**Option A** : Fichier chiffré (Windows)
```powershell
# Créer le fichier sécurisé (une seule fois)
Read-Host "Mot de passe SMTP" -AsSecureString | 
    ConvertFrom-SecureString | 
    Out-File "C:\Scripts\smtp_password.txt"

# Dans le script, remplacer $MailPass par :
$MailPass = Get-Content "C:\Scripts\smtp_password.txt" | ConvertTo-SecureString
```

**Option B** : Variable d'environnement
```powershell
# Définir la variable (session ou système)
$env:XANADU_SMTP_PASSWORD = "M0tD3P@ss3"

# Dans le script :
$MailPass = $env:XANADU_SMTP_PASSWORD
```

**Option C** : Azure Key Vault / HashiCorp Vault
Pour les environnements d'entreprise :
```powershell
# Récupérer depuis un coffre-fort
$MailPass = Get-AzKeyVaultSecret -VaultName "xanadu-vault" -Name "smtp-password" -AsPlainText
```

#### 3. Restreindre les permissions du script
```powershell
# Seul SYSTEM et les Admins peuvent lire le script
icacls "C:\Scripts\alert_backup.ps1" /inheritance:r
icacls "C:\Scripts\alert_backup.ps1" /grant:r "SYSTEM:(R)"
icacls "C:\Scripts\alert_backup.ps1" /grant:r "Administrators:(R)"
```

### Configuration SMTP sécurisée

#### TLS/SSL obligatoire
```powershell
$SmtpPort = 587           # Port TLS
# Paramètre -UseSsl activé dans Send-MailMessage
```

#### Authentification forte
- Utiliser un mot de passe complexe (16+ caractères)
- Activer l'authentification à deux facteurs si possible
- Renouveler le mot de passe régulièrement

#### Restriction d'accès au serveur SMTP
- Firewall : autoriser uniquement l'IP du serveur de backup
- Poste.io : configurer les relais autorisés
- Limiter les envois par heure (protection contre le spam)

### Surveillance du script d'alerte

⚠️ **Question** : Qui surveille le surveillant ?

**Solutions** :

#### 1. Alerte sur échec d'envoi
Ajouter un mécanisme de notification secondaire :
```powershell
# Si l'envoi échoue, écrire dans l'Event Log Windows
if (-not $emailSent) {
    Write-EventLog -LogName Application -Source "XANADU" `
        -EventId 1001 -EntryType Error `
        -Message "Échec d'envoi d'alerte pour $LogPath"
}
```

#### 2. Monitoring externe
- Vérifier régulièrement l'existence d'`Alert.log`
- Alerter si le fichier n'a pas été modifié depuis 24h
- Utiliser un système de supervision (PRTG, Zabbix, Nagios)

#### 3. Heartbeat quotidien
Envoyer un email de confirmation quotidien :
```powershell
# À la fin du script, si aucune erreur
if ($badLogs.Count -eq 0) {
    Send-MailMessage -Subject "[XANADU] OK - Surveillance active" `
        -Body "Aucune anomalie détectée le $(Get-Date -Format 'yyyy-MM-dd')"
    # ... (même config SMTP)
}
```

## Limitations connues

- **Détection basique** : Recherche par mots-clés, peut manquer des erreurs subtiles
- **Pas d'analyse sémantique** : Ne comprend pas le contexte des erreurs
- **Alertes multiples** : Envoie un email par log en erreur (peut saturer)
- **Pas de déduplication** : Alertes répétées si le log reste en erreur
- **Pas de dashboard** : Aucune visualisation centralisée
- **Dépendance SMTP** : Si le serveur SMTP est down, aucune alerte
- **Mot de passe en clair** : Risque de sécurité dans le script
- **Pas de retry** : Si l'envoi échoue, pas de nouvelle tentative
- **Pas de filtrage** : Envoie toutes les erreurs, même mineures

## Compatibilité

### Versions PowerShell

- **PowerShell 5.1** (Windows PowerShell) : ✅ Compatible
- **PowerShell 7+** (PowerShell Core) : ✅ Compatible

### Systèmes d'exploitation

- Windows 10/11
- Windows Server 2016+
- Windows Server 2019/2022
- Linux/macOS : Compatible avec adaptation de Send-MailMessage (utiliser `MailKit` ou `System.Net.Mail`)

### Dépendances

- **Send-MailMessage** : Cmdlet intégrée à PowerShell
- **Serveur SMTP** : Poste.io ou autre serveur SMTP accessible
- **Accès réseau** : Port 25/587 ouvert vers le serveur SMTP

## Fichiers associés

- **Script principal** : `alert_backup.ps1`
- **Documentation** : `docs/alert_backup.md`
- **Log interne** : `C:\Backups\Local\Logs\Alert.log`
- **Logs surveillés** : `C:\Backups\Local\Logs\Backup_*.log`
- **Script de backup** : `backup_file.ps1`
- **Script d'externalisation** : `externalize_backups.ps1`

## Codes de sortie

| Code | Signification |
|------|---------------|
| 0 | Exécution réussie (avec ou sans alertes envoyées) |

**Note** : Le script retourne toujours 0, même en cas d'erreur d'envoi. Les erreurs sont loggées dans `Alert.log`.

## Dépannage

### Problème : Aucun mail reçu

**Causes possibles** :
- Serveur SMTP inaccessible
- Identifiants incorrects
- Port bloqué par le firewall
- TLS non supporté

**Diagnostic** :
```powershell
# Tester la connexion au serveur SMTP
Test-NetConnection -ComputerName "192.168.1.10" -Port 587

# Vérifier les identifiants manuellement
$secPass = ConvertTo-SecureString "CHANGE_ME" -AsPlainText -Force
$cred = New-Object PSCredential("sauvegardes@xanadu.local", $secPass)

Send-MailMessage -From "sauvegardes@xanadu.local" `
    -To "admin@xanadu.local" `
    -Subject "Test" `
    -Body "Test connexion SMTP" `
    -SmtpServer "192.168.1.10" `
    -Port 587 `
    -UseSsl `
    -Credential $cred
```

**Solutions** :
- Vérifier la configuration réseau
- Tester avec un autre port (25, 465, 587)
- Désactiver temporairement le firewall
- Vérifier les logs du serveur SMTP (Poste.io)

### Problème : Trop d'alertes (spam)

**Causes possibles** :
- Même erreur détectée à chaque exécution
- Logs non nettoyés après résolution
- Faux positifs (détection trop sensible)

**Solutions** :
- Implémenter la déduplication (état des erreurs)
- Nettoyer les logs après résolution
- Ajuster les patterns de détection
- Utiliser un système d'agrégation

### Problème : "Échec de l'envoi du mail : La connexion SMTP a expiré"

**Cause** : Timeout de connexion au serveur SMTP.

**Solutions** :
- Augmenter le timeout (non disponible nativement dans Send-MailMessage)
- Vérifier la charge du serveur SMTP
- Utiliser un serveur SMTP local (relay)

---

**Auteur** : Projet XANADU  
**Version** : 1.0  
**Dernière mise à jour** : 11 décembre 2024
