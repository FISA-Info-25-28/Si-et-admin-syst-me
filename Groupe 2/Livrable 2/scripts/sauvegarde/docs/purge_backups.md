# purge_backups.ps1

## Synopsis

Script de purge automatique des sauvegardes XANADU basé sur des règles de rétention par niveau de criticité (Policy) et sa provenance (local ou externe).

## Description

Ce script PowerShell gère la rétention des sauvegardes locales et externalisées selon des règles définies par politique (Critical, Important, Standard). Il constitue la couche de gestion du cycle de vie des backups dans le système XANADU.

### Fonctionnalités principales

#### Gestion par politique de rétention
Le script applique des **règles de rétention différenciées** selon trois critères :
- **Policy** : Critical, Important, Standard (niveau de criticité des données)
- **Emplacement** : Local vs External (rétention plus longue pour les backups externalisés)
- **Type** : Full, Dif, Inc (traitement spécifique des sauvegardes complètes)

Chaque politique possède ses propres paramètres :
- **KeepFull** : Nombre minimum de sauvegardes complètes à conserver
- **RetentionDays** : Durée de rétention pour les backups locaux (en jours)
- **RetentionExternalDays** : Durée de rétention pour les backups externalisés (en jours)

#### Configuration JSON centralisée
Le script utilise un fichier JSON (`retention.json`) pour définir les règles de rétention :

```json
{
  "Critical": {
    "KeepFull": 3,
    "RetentionDays": 7,
    "RetentionExternalDays": 30
  },
  "Important": {
    "KeepFull": 2,
    "RetentionDays": 7,
    "RetentionExternalDays": 30
  },
  "Standard": {
    "KeepFull": 1,
    "RetentionDays": 7,
    "RetentionExternalDays": 30
  }
}
```

#### Règles de purge intelligentes

##### 1. Règle RGPD (priorité absolue)
**Tout backup ayant dépassé l'âge maximal RGPD est supprimé sans exception.**
- Âge par défaut : **150 jours** (≈ 5 mois)
- Paramétrable via `-MaxAgeDays`
- S'applique à **tous** les types de backups (full, dif, inc)
- S'applique **même aux sauvegardes complètes** (conformité RGPD)

##### 2. Purge des dif/inc obsolètes
**Les sauvegardes différentielles et incrémentielles plus anciennes que la dernière sauvegarde complète sont supprimées.**
- Logique : Un dif/inc sans full de référence est inutile pour la restauration
- S'applique par Policy
- Conserve uniquement les dif/inc postérieurs à la dernière full

##### 3. Application des rétentions par emplacement
**Chaque backup est évalué selon sa rétention spécifique :**
- **Local** : Rétention courte (RetentionDays)
- **External** : Rétention longue (RetentionExternalDays)
- Les dif/inc sont supprimés dès que leur âge dépasse la rétention
- Les full sont marquées pour suppression mais respectent les règles KeepFull

##### 4. Conservation minimale des full
**Le script garantit qu'il reste au moins une sauvegarde complète par Policy.**
- Exception : Si toutes les full dépassent l'âge maximal RGPD
- Priorité : Conservation des N full les plus récentes (KeepFull)
- Si KeepFull = 3 : les 3 full les plus récentes sont conservées
- Garantie : Au moins 1 full reste disponible pour la restauration

#### Détection du statut d'externalisation
Le script tient compte du fichier `external_state.json` pour appliquer la bonne rétention :
- Si le backup est dans `External/` : rétention externe
- Si le backup est dans `Local/` : rétention locale
- Permet d'appliquer des durées différentes selon l'emplacement

#### Mode DryRun (simulation)
Le paramètre `-DryRun` permet de :
- Simuler la purge sans supprimer de données
- Vérifier les règles de rétention
- Identifier les backups qui seraient supprimés
- Valider la configuration avant exécution réelle

#### Journalisation détaillée
Toutes les opérations sont enregistrées dans `Purge.log` :
- Backups conservés avec raison
- Backups supprimés avec raison détaillée
- Récapitulatif des actions (total, conservés, supprimés)
- Erreurs de suppression

## Paramètres

### `-BackupRoot` (Optionnel)
**Type** : `String`  
**Obligatoire** : Non  
**Valeur par défaut** : `"C:\Backups"`

Chemin racine contenant les backups locaux et externes à purger.

Structure attendue :
```
C:\Backups\
├── Local\
│   ├── Critical\
│   ├── Important\
│   └── Standard\
├── External\
│   ├── Critical\
│   ├── Important\
│   └── Standard\
└── Logs\
    └── Purge.log
```

```powershell
-BackupRoot "C:\Backups"
-BackupRoot "D:\Sauvegardes"
```

### `-RetentionConfigPath` (Optionnel)
**Type** : `String`  
**Obligatoire** : Non  
**Valeur par défaut** : `"C:\Backups\retention.json"`

Chemin vers le fichier JSON contenant les règles de rétention par Policy.

```powershell
-RetentionConfigPath "C:\Backups\retention.json"
-RetentionConfigPath "C:\Config\backup_retention.json"
```

### `-MaxAgeDays` (Optionnel)
**Type** : `Int`  
**Obligatoire** : Non  
**Valeur par défaut** : `150`

Âge maximal en jours avant suppression forcée pour conformité RGPD.

```powershell
-MaxAgeDays 150    # 5 mois (par défaut)
-MaxAgeDays 180    # 6 mois
-MaxAgeDays 365    # 1 an
```

### `-DryRun` (Optionnel)
**Type** : `Switch`  
**Obligatoire** : Non

Active le mode simulation : aucune suppression réelle, le script indique seulement ce qu'il ferait.

```powershell
-DryRun
```

## Configuration de rétention (retention.json)

### Format du fichier

```json
{
  "Critical": {
    "KeepFull": 3,
    "RetentionDays": 30,
    "RetentionExternalDays": 90
  },
  "Important": {
    "KeepFull": 2,
    "RetentionDays": 21,
    "RetentionExternalDays": 60
  },
  "Standard": {
    "KeepFull": 1,
    "RetentionDays": 14,
    "RetentionExternalDays": 45
  }
}
```

### Paramètres par Policy

#### KeepFull
Nombre minimum de sauvegardes complètes à conserver pour cette Policy.
- **Critical** : 3 (conservation maximale)
- **Important** : 2 (conservation moyenne)
- **Standard** : 1 (conservation minimale)

#### RetentionDays
Durée de rétention en jours pour les backups **locaux** (non externalisés).
- **Critical** : 30 jours (1 mois)
- **Important** : 21 jours (3 semaines)
- **Standard** : 14 jours (2 semaines)

#### RetentionExternalDays
Durée de rétention en jours pour les backups **externalisés** (sur le site distant).
- **Critical** : 90 jours (3 mois)
- **Important** : 60 jours (2 mois)
- **Standard** : 45 jours (1,5 mois)

## Exemples d'utilisation

### Exemple 1 : Purge standard avec configuration par défaut

Applique les règles de rétention définies dans le fichier JSON.

```powershell
.\purge_backups.ps1
```

**Résultat** :
- Charge `C:\Backups\retention.json`
- Parcourt `C:\Backups\Local` et `C:\Backups\External`
- Applique les règles par Policy
- Supprime les backups obsolètes
- Log dans `C:\Backups\Logs\Purge.log`

### Exemple 2 : Purge avec répertoire personnalisé

```powershell
.\purge_backups.ps1 -BackupRoot "D:\Sauvegardes" -RetentionConfigPath "D:\Sauvegardes\retention.json"
```

**Résultat** : Purge les backups dans `D:\Sauvegardes` selon les règles du fichier spécifié

### Exemple 3 : Simulation (DryRun)

Teste la purge sans supprimer de données.

```powershell
.\purge_backups.ps1 -DryRun
```

**Résultat** :
```
[2024-12-11 16:00:00] [INFO] === Démarrage purge (BackupRoot=C:\Backups, DryRun=True) ===
[2024-12-11 16:00:01] [INFO] Configuration de rétention chargée depuis C:\Backups\retention.json
[2024-12-11 16:00:02] [INFO] Traitement de la Policy 'Critical' (KeepFull=3, Ret=30 j, RetExt=90 j).
[2024-12-11 16:00:03] [INFO] Traitement de la Policy 'Important' (KeepFull=2, Ret=21 j, RetExt=60 j).
[2024-12-11 16:00:04] [INFO] Traitement de la Policy 'Standard' (KeepFull=1, Ret=14 j, RetExt=45 j).
[2024-12-11 16:00:05] [INFO] Récapitulatif :
[2024-12-11 16:00:05] [INFO]   Backups totales : 45
[2024-12-11 16:00:05] [INFO]   À conserver      : 32
[2024-12-11 16:00:05] [INFO]   À supprimer      : 13
[2024-12-11 16:00:06] [INFO] [DRY-RUN] Suppression de 'C:\Backups\Local\Standard\Standard_inc_20241110_080000_ABC123' (Policy=Standard, Type=inc, Age=31 j, Externalisé=False) → Raison : inc âgée de 31 j >= rétention (14 j)
...
[2024-12-11 16:00:10] [INFO] Purge simulée (DryRun=ON), aucune suppression réelle.
[2024-12-11 16:00:10] [INFO] === Fin purge ===
```

### Exemple 4 : Purge avec âge RGPD personnalisé

Définit un âge maximal de 180 jours (6 mois) au lieu de 150.

```powershell
.\purge_backups.ps1 -MaxAgeDays 180
```

**Résultat** : Les backups de plus de 180 jours sont supprimés, même s'ils sont les dernières full

### Exemple 5 : Purge combinée avec DryRun et âge personnalisé

```powershell
.\purge_backups.ps1 -MaxAgeDays 365 -DryRun
```

**Résultat** : Simule une purge avec une rétention RGPD d'un an

### Exemple 6 : Vérification des backups à conserver

Utilise DryRun pour auditer les backups avant purge réelle.

```powershell
.\purge_backups.ps1 -DryRun | Select-String "À conserver"
```

**Résultat** : Affiche le nombre total de backups qui seront conservés

## Fonctionnement détaillé

### Architecture du script

Le script est organisé en plusieurs régions fonctionnelles :

#### 1. **PARAMETERS** - Gestion des paramètres
Définit et valide les paramètres d'entrée :
- `BackupRoot` : Racine des backups
- `RetentionConfigPath` : Chemin du fichier JSON de rétention
- `MaxAgeDays` : Âge maximal RGPD
- `DryRun` : Switch pour le mode simulation

#### 2. **GLOBALS / LOGGING** - Initialisation et journalisation
- Crée le dossier `Logs` si nécessaire
- Fonction `Write-PurgeLog` pour journaliser toutes les opérations
- Initialise la date courante pour les calculs d'âge

#### 3. **VERIFICATIONS PREALABLES** - Validation
Trois vérifications critiques :
1. **Existence de BackupRoot** : Vérifie que le dossier existe
2. **Existence du fichier de rétention** : Vérifie `retention.json`
3. **Chargement du JSON** : Parse les règles de rétention

#### 4. **FONCTIONS UTILITAIRES** - Analyse des noms
- `Convert-BackupFolderName` : Parse le nom des dossiers de backup
  - Format : `{Policy}_{Type}_YYYYMMDD_HHMMSS_{ID}`
  - Extrait : Policy, Type, Date, Heure, ID
  - Calcule la date du backup
  - Retourne un objet structuré ou `$null` si format invalide

#### 5. **ENUMERATION DES SAUVEGARDES** - Scan et inventaire
- Parcourt `Local` et `External` dans `BackupRoot`
- Liste tous les dossiers de Policy (Critical, Important, Standard)
- Parse chaque dossier de backup avec `Convert-BackupFolderName`
- Calcule l'âge en jours de chaque backup
- Détermine si le backup est externalisé (emplacement)
- Construit une liste complète de tous les backups avec métadonnées

#### 6. **APPLICATION DES REGLES PAR POLICY** - Logique de rétention
Pour chaque Policy (Critical, Important, Standard) :

**Étape 1** : Récupérer les règles de rétention du JSON

**Étape 2** : **Règle RGPD** (priorité absolue)
- Marquer tous les backups > MaxAgeDays comme `ToDelete = $true`
- Marquer `ForcedRGPD = $true` (ne peut pas être annulé)

**Étape 3** : **Purge des dif/inc obsolètes**
- Identifier la dernière sauvegarde full
- Marquer tous les dif/inc antérieurs à cette full pour suppression

**Étape 4** : **Application des rétentions**
- Pour chaque backup non encore marqué :
  - Déterminer la rétention applicable (local vs externe)
  - Si âge >= rétention :
    - dif/inc : Suppression directe
    - full : Marqué pour suppression (peut être annulé par KeepFull)

**Étape 5** : **Respect de KeepFull et conservation minimale**
- Garantir au moins 1 full par Policy (sauf si RGPD)
- Conserver les N full les plus récentes (KeepFull)
- Démarquer les full protégées par ces règles

#### 7. **EXECUTION DE LA PURGE** - Suppression
- Sépare les backups à conserver et à supprimer
- Affiche un récapitulatif détaillé
- Pour chaque backup à supprimer :
  - En mode DryRun : Log simulation
  - En mode réel : Suppression avec `Remove-Item -Recurse`
  - Gestion des erreurs individuelles

### Algorithme de purge

```
1. Valider les paramètres et charger la configuration
2. Vérifier l'existence de BackupRoot et retention.json
3. Charger et parser le JSON de rétention
4. Énumérer tous les backups dans Local et External :
   a. Parser le nom de chaque dossier
   b. Calculer l'âge en jours
   c. Déterminer si externalisé
5. Grouper les backups par Policy
6. Pour chaque Policy :
   a. Appliquer la règle RGPD (suppression forcée > MaxAgeDays)
   b. Identifier la dernière full
   c. Marquer les dif/inc antérieurs à la dernière full
   d. Appliquer les rétentions selon l'emplacement
   e. Garantir KeepFull + au moins 1 full
7. Générer le récapitulatif (total, conservés, supprimés)
8. Exécuter la suppression :
   a. Si DryRun : Simuler et logger
   b. Sinon : Supprimer avec gestion d'erreur
9. Logger la fin de la purge
```

### Gestion des erreurs

Le script gère plusieurs types d'erreurs :

| Erreur | Message | Action | Code sortie |
|--------|---------|--------|-------------|
| BackupRoot introuvable | `Répertoire de sauvegarde introuvable` | Arrêt immédiat | 1 |
| retention.json introuvable | `Fichier de configuration de rétention introuvable` | Arrêt immédiat | 1 |
| Erreur parsing JSON | `Erreur lors du chargement du JSON de rétention` | Arrêt immédiat | 1 |
| Nom de dossier invalide | `Nom de dossier ignoré (format non reconnu)` | Ignore le dossier (WARN) | Continue |
| Policy sans règle | `Aucune règle de rétention pour la Policy` | Ignore la policy (WARN) | Continue |
| Emplacement absent | `Répertoire Local/External introuvable` | Ignore l'emplacement (WARN) | Continue |
| Erreur suppression | `Erreur lors de la suppression` | Continue les autres (ERROR) | Continue |
| Aucun backup trouvé | `Aucune sauvegarde trouvée` | Sortie propre | 0 |

**Principe** : Le script continue le plus loin possible malgré les erreurs de suppression individuelles.

## Journalisation

### Fichier de log

```
$BackupRoot\Logs\Purge.log
```

Exemple : `C:\Backups\Logs\Purge.log`

### Format des entrées

```
[YYYY-MM-DD HH:mm:ss] [LEVEL] Message
```

**Exemple de log complet** :
```
[2024-12-11 16:00:00] [INFO] === Démarrage purge (BackupRoot=C:\Backups, DryRun=False) ===
[2024-12-11 16:00:01] [INFO] Configuration de rétention chargée depuis C:\Backups\retention.json
[2024-12-11 16:00:02] [INFO] Traitement de la Policy 'Critical' (KeepFull=3, Ret=30 j, RetExt=90 j).
[2024-12-11 16:00:03] [INFO] Traitement de la Policy 'Important' (KeepFull=2, Ret=21 j, RetExt=60 j).
[2024-12-11 16:00:04] [INFO] Traitement de la Policy 'Standard' (KeepFull=1, Ret=14 j, RetExt=45 j).
[2024-12-11 16:00:05] [INFO] Récapitulatif :
[2024-12-11 16:00:05] [INFO]   Backups totales : 45
[2024-12-11 16:00:05] [INFO]   À conserver      : 32
[2024-12-11 16:00:05] [INFO]   À supprimer      : 13
[2024-12-11 16:00:06] [INFO] Supprimé : 'C:\Backups\Local\Standard\Standard_inc_20241110_080000_ABC123' (Policy=Standard, Type=inc, Age=31 j, Externalisé=False) → Raison : inc âgée de 31 j >= rétention (14 j)
[2024-12-11 16:00:07] [INFO] Supprimé : 'C:\Backups\Local\Important\Important_dif_20241115_020000_DEF456' (Policy=Important, Type=dif, Age=26 j, Externalisé=False) → Raison : dif âgée de 26 j >= rétention (21 j)
[2024-12-11 16:00:08] [INFO] Supprimé : 'C:\Backups\External\Critical\Critical_full_20240501_143022_GHI789' (Policy=Critical, Type=full, Age=224 j, Externalisé=True) → Raison : RGPD: âge >= 150 jours
[2024-12-11 16:00:09] [ERROR] Erreur lors de la suppression de 'C:\Backups\Local\Standard\Standard_dif_20241120_020000_JKL012' : Le processus ne peut pas accéder au fichier car il est utilisé par un autre processus
[2024-12-11 16:00:10] [INFO] === Fin purge ===
```

### Niveaux de gravité

- **INFO** : Opération normale (démarrage, règles appliquées, suppression réussie, fin)
- **WARN** : Avertissement (dossier ignoré, emplacement absent, policy sans règle)
- **ERROR** : Erreur (échec de suppression, erreur de chargement JSON)

## Sécurité et bonnes pratiques

### Garanties

**Protection des données critiques** : KeepFull garantit un minimum de full par Policy  
**Conformité RGPD** : Suppression forcée après MaxAgeDays  
**Traçabilité complète** : Toutes les opérations sont journalisées  
**Mode simulation** : DryRun permet de valider avant suppression réelle  
**Gestion d'erreur robuste** : Une erreur n'arrête pas la purge complète  
**Purge intelligente** : Suppression des dif/inc obsolètes (sans full de référence)  

### Recommandations

#### 1. **Toujours tester avec DryRun**
⚠️ **Critique** : Avant la première exécution en production.

```powershell
# Test complet
.\purge_backups.ps1 -DryRun

# Vérifier le log
Get-Content "C:\Backups\Logs\Purge.log" | Select-String "DRY-RUN"
```

#### 2. **Ajuster les règles de rétention progressivement**
- Commencer avec des rétentions longues
- Réduire progressivement selon l'espace disponible
- Surveiller les métriques de restauration
- Adapter selon la fréquence de backup

#### 3. **Surveillance régulière**
- Vérifier `Purge.log` après chaque exécution
- Monitorer l'espace disque libéré
- Alerter en cas d'erreurs de suppression
- Valider qu'il reste bien des full disponibles

#### 4. **Planification automatique**
Exécuter la purge régulièrement (quotidienne ou hebdomadaire) :

```powershell
# Exemple : purge quotidienne à 5h00 du matin
.\scheduler_backup.ps1 -Cron "0 5 * * *" `
    -Type "full" `
    -Includes "C:\Scripts\purge.txt" `
    -TaskName "purge_daily"
```

#### 5. **Versionner le fichier retention.json**
- Sauvegarder le fichier dans un système de gestion de versions (Git)
- Documenter chaque modification des règles
- Tester les changements avec DryRun avant application

#### 6. **Coordination avec l'externalisation**
- Purger **après** l'externalisation
- Vérifier que les backups critiques sont bien externalisés avant purge locale
- Appliquer des rétentions locales plus courtes si externalisation fréquente

**Exemple de séquence recommandée** :
```
1. Backup (toutes les 4h)
2. Externalisation (quotidienne à 4h00)
3. Purge (quotidienne à 5h00)
```

#### 7. **Protection contre les suppressions accidentelles**
- Utiliser des sauvegardes de snapshots/volumes si possible
- Tester la restauration régulièrement
- Conserver des archives critiques hors système de purge
- Documenter les procédures de récupération

#### 8. **Audit des règles de rétention**
- Réviser les règles trimestriellement
- Adapter selon l'évolution des besoins métier
- Vérifier la conformité réglementaire (RGPD, normes sectorielles)
- Consulter les responsables métier pour valider les durées

### Limitations connues

- Pas de restauration automatique en cas de suppression accidentelle
- Pas de vérification d'intégrité avant suppression
- Pas de compression/archivage automatique des anciens backups
- Pas de notification automatique en cas d'erreur
- Suppression définitive (pas de corbeille)
- Pas de parallélisation (traitement séquentiel)
- Format de nom de dossier strict (pattern regex)

## Compatibilité

### Versions PowerShell

- **PowerShell 5.1** (Windows PowerShell) : ✅ Compatible
- **PowerShell 7+** (PowerShell Core) : ✅ Compatible

### Systèmes d'exploitation

- Windows 10/11
- Windows Server 2016+
- Windows Server 2019/2022
- Linux/macOS : Compatible avec adaptation des chemins

## Notes importantes

### Ordre de priorité des règles

Les règles sont appliquées dans cet ordre :

1. **Règle RGPD** (priorité absolue) : Suppression > MaxAgeDays
2. **Purge dif/inc obsolètes** : Suppression si antérieurs à la dernière full
3. **Rétention par emplacement** : Suppression selon RetentionDays/RetentionExternalDays
4. **Conservation KeepFull** : Protection des N full les plus récentes
5. **Conservation minimale** : Garantie d'au moins 1 full (sauf RGPD)

### Cas particuliers

#### Toutes les full dépassent MaxAgeDays
Si toutes les sauvegardes complètes d'une Policy sont au-delà de l'âge maximal RGPD :
- **Toutes sont supprimées** (conformité RGPD prioritaire)
- Message d'avertissement dans le log
- Aucune restauration possible pour cette Policy après purge
- **Recommandation** : Créer un nouveau backup full immédiatement

#### Aucune full trouvée pour une Policy
Si une Policy ne contient que des dif/inc (pas de full) :
- Les dif/inc sont traités selon leur rétention
- Aucune garantie de conservation minimale
- Message d'avertissement dans le log

#### Backup en cours de création pendant la purge
Le script ne détecte pas les backups en cours de création :
- **Recommandation** : Planifier la purge en dehors des fenêtres de backup
- Ou ajouter un décalage temporel (ex: purger uniquement backups > 1 jour)

### Impact de la purge

**Espace disque libéré** :
- Variable selon le nombre et la taille des backups supprimés
- Plus important sur les backups full
- Monitorer l'évolution dans le temps

**Capacité de restauration** :
- Après purge, seuls les backups conservés sont restaurables
- Vérifier régulièrement qu'une full récente existe
- Tester périodiquement la restauration

## Fichiers associés

- **Script principal** : `purge_backups.ps1`
- **Documentation** : `docs/purge_backups.md`
- **Configuration de rétention** : `C:\Backups\retention.json`
- **Log de purge** : `C:\Backups\Logs\Purge.log`
- **Script de backup** : `backup_file.ps1`
- **Script d'externalisation** : `externalize_backups.ps1`

## Codes de sortie

| Code | Signification |
|------|---------------|
| 0 | Purge réussie (avec ou sans suppressions, ou DryRun) |
| 1 | Erreur de configuration (BackupRoot ou retention.json introuvable, erreur parsing) |

**Note** : Le script retourne toujours 0 après exécution complète, même si des erreurs de suppression individuelle se produisent. Ces erreurs sont loggées mais n'arrêtent pas le script.

## Dépannage

### Problème : "Fichier de configuration de rétention introuvable"

**Cause** : Le fichier `retention.json` n'existe pas à l'emplacement spécifié.

**Solution** :
1. Créer le fichier avec la structure correcte
2. Vérifier le chemin spécifié
3. Utiliser un chemin absolu

```powershell
# Créer un fichier de base
$baseConfig = @{
    Critical  = @{ KeepFull = 3; RetentionDays = 30; RetentionExternalDays = 90 }
    Important = @{ KeepFull = 2; RetentionDays = 21; RetentionExternalDays = 60 }
    Standard  = @{ KeepFull = 1; RetentionDays = 14; RetentionExternalDays = 45 }
}

$baseConfig | ConvertTo-Json | Set-Content "C:\Backups\retention.json"
```

### Problème : Aucun backup supprimé alors qu'ils devraient l'être

**Causes possibles** :
- Règle KeepFull trop élevée
- RetentionDays trop longue
- Tous les backups sont récents

**Diagnostic** :
```powershell
# Vérifier l'âge des backups
Get-ChildItem "C:\Backups\Local\*\*" -Directory | ForEach-Object {
    if ($_.Name -match "(\d{8})_(\d{6})") {
        $date = [datetime]::ParseExact($matches[1] + $matches[2], "yyyyMMddHHmmss", $null)
        $age = (Get-Date) - $date
        [PSCustomObject]@{
            Name = $_.Name
            Age = [math]::Floor($age.TotalDays)
        }
    }
} | Sort-Object Age -Descending | Format-Table -AutoSize
```

### Problème : "Erreur lors de la suppression" (fichier verrouillé)

**Cause** : Un processus utilise les fichiers du backup (antivirus, indexation, backup en cours).

**Solutions** :
1. Arrêter temporairement l'antivirus
2. Exclure les dossiers de backup de l'indexation Windows
3. Réexécuter la purge plus tard
4. Vérifier qu'aucun backup n'est en cours

### Problème : Toutes les full supprimées par erreur

**Cause** : MaxAgeDays trop court ou mauvaise configuration de KeepFull.

**Prévention** :
- Toujours tester avec DryRun
- Vérifier la configuration avant exécution
- Mettre en place des alertes

**Récupération** :
- Si backups externalisés : Restaurer depuis External
- Si pas de backup : Créer un nouveau full immédiatement
- Restaurer depuis une sauvegarde de snapshot si disponible

### Problème : Purge trop lente

**Causes** :
- Grand nombre de backups
- Disques lents
- Antivirus qui scan chaque suppression

**Solutions** :
- Exécuter pendant les heures creuses
- Exclure les dossiers de backup de l'antivirus
- Purger par Policy (exécutions séparées)

---

**Auteur** : Projet XANADU  
**Version** : 1.0  
**Dernière mise à jour** : 11 décembre 2025
