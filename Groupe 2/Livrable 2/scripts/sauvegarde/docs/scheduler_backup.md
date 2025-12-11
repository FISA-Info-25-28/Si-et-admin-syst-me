# scheduler_backup.ps1

## Synopsis

Gestion des tâches planifiées Windows pour l'exécution automatique du script `backup_file.ps1` dans le contexte du système de sauvegarde XANADU.

## Description

Ce script PowerShell permet de créer, gérer, modifier et supprimer des tâches planifiées Windows pour automatiser l'exécution des sauvegardes XANADU. Il constitue la couche d'orchestration du système de sauvegarde, permettant de définir des calendriers d'exécution précis basés sur une syntaxe CRON simplifiée.

### Fonctionnalités principales

#### Création de tâches planifiées
- Création automatique de tâches planifiées Windows
- Appel du script `backup_file.ps1` avec les paramètres appropriés
- Support de la syntaxe CRON pour définir les planifications
- Gestion automatique du préfixe `XANADU_` pour toutes les tâches

#### Syntaxe CRON simplifiée
Le script utilise une expression CRON-like à 5 champs :
```
M H DOM MON DOW
```
- **M** : Minute (0-59 ou */X pour répétition)
- **H** : Heure (0-23)
- **DOM** : Jour du mois (1-31)
- **MON** : Mois (1-12, actuellement non utilisé)
- **DOW** : Jour de la semaine (0-6, où 0=Dimanche)

#### Mode interactif
Si aucun paramètre n'est fourni, le script passe en mode interactif et demande :
- Le type de sauvegarde (full/dif/inc)
- Le chemin du fichier includes
- L'expression CRON

#### Mode liste et gestion
Le paramètre `-List` permet de :
- Afficher toutes les tâches planifiées XANADU
- Visualiser les informations détaillées (prochaine exécution, dernière exécution, état)
- Supprimer une tâche sélectionnée
- Modifier l'expression CRON d'une tâche (via recréation)

#### Journalisation complète
Toutes les opérations sont enregistrées dans `Scheduler.log` avec :
- Horodatage précis
- Niveau de gravité (INFO, WARN, ERROR)
- Détails des actions effectuées

## Paramètres

### `-Cron` (Optionnel)
**Type** : `String`  
**Obligatoire** : Non (sauf si mode non-interactif)  
**Valeur par défaut** : `$null`

Expression CRON-like définissant la planification de la tâche.

**Format** : `"M H DOM MON DOW"`

**Exemples** :
```powershell
-Cron "*/30 * * * *"   # Toutes les 30 minutes
-Cron "0 1 * * *"      # Tous les jours à 01:00
-Cron "0 2 * * 0"      # Tous les dimanches à 02:00
-Cron "0 3 1 * *"      # Le 1er de chaque mois à 03:00
-Cron "0 22 * * 1-5"   # Du lundi au vendredi à 22:00
```

### `-Type` (Optionnel)
**Type** : `String`  
**Obligatoire** : Non (sauf si mode non-interactif)  
**Valeurs autorisées** : `"full"`, `"dif"`, `"inc"`  
**Valeur par défaut** : `$null`

Type de sauvegarde qui sera passé au script `backup_file.ps1`.

```powershell
-Type "full"   # Sauvegarde complète
-Type "dif"    # Sauvegarde différentielle
-Type "inc"    # Sauvegarde incrémentielle
```

### `-Includes` (Optionnel)
**Type** : `String`  
**Obligatoire** : Non (sauf si mode non-interactif)  
**Valeur par défaut** : `$null`

Chemin vers le fichier contenant la liste des sources à sauvegarder. Ce paramètre est transmis à `backup_file.ps1` via `-IncludesFile`.

```powershell
-Includes "C:\Scripts\includes.txt"
```

### `-Policy` (Optionnel)
**Type** : `String`  
**Obligatoire** : Non  
**Valeurs autorisées** : `"Critical"`, `"Important"`, `"Standard"`, `"Logs"`  
**Valeur par défaut** : `"Standard"`

Criticité de la sauvegarde qui détermine le dossier d'écriture et la politique de rétention. Ce paramètre est transmis au script `backup_file.ps1` via `-Policy`.

```powershell
-Policy "Critical"    # Criticité maximale
-Policy "Important"   # Importance élevée
-Policy "Standard"    # Par défaut
-Policy "Logs"        # Sauvegarde de logs
```

### `-TaskName` (Optionnel)
**Type** : `String`  
**Obligatoire** : Non  
**Valeur par défaut** : `"backup_file"`

Nom logique de la tâche planifiée, sans le préfixe `XANADU_`. Le nom complet de la tâche sera automatiquement `XANADU_{TaskName}`.

```powershell
-TaskName "backup_file"          # Tâche: XANADU_backup_file
-TaskName "backup_hourly"        # Tâche: XANADU_backup_hourly
-TaskName "backup_weekly"        # Tâche: XANADU_backup_weekly
```

### `-List` (Optionnel)
**Type** : `Switch`  
**Obligatoire** : Non

Active le mode liste permettant de visualiser et gérer les tâches XANADU existantes.

```powershell
-List
```

## Exemples d'utilisation

### Exemple 1 : Sauvegarde incrémentielle toutes les 30 minutes

Crée une tâche qui exécute une sauvegarde incrémentielle toutes les 30 minutes.

```powershell
.\scheduler_backup.ps1 -Cron "*/30 * * * *" -Type "inc" -Includes "C:\Scripts\includes.txt" -TaskName "backup_inc_30min" -Policy "Standard"
```

**Résultat** :
- Tâche créée : `XANADU_backup_inc_30min`
- Exécution : Toutes les 30 minutes, 24h/24
- Type : Incrémentielle
- Policy : Standard
- Sources : Définies dans `C:\Scripts\includes.txt`

### Exemple 2 : Sauvegarde complète quotidienne à 2h00

Crée une tâche qui exécute une sauvegarde complète tous les jours à 2h00 du matin.

```powershell
.\scheduler_backup.ps1 -Cron "0 2 * * *" -Type "full" -Includes "C:\Scripts\includes.txt" -TaskName "backup_daily_full" -Policy "Critical"
```

**Résultat** :
- Tâche créée : `XANADU_backup_daily_full`
- Exécution : Chaque jour à 02:00
- Type : Complète
- Policy : Critical

### Exemple 3 : Sauvegarde différentielle du lundi au vendredi à 22h00

Crée une tâche qui exécute une sauvegarde différentielle en semaine.

```powershell
.\scheduler_backup.ps1 -Cron "0 22 * * 1-5" -Type "dif" -Includes "C:\Scripts\includes.txt" -TaskName "backup_weekday_dif"
```

**Résultat** :
- Tâche créée : `XANADU_backup_weekday_dif`
- Exécution : Lundi à vendredi à 22:00
- Type : Différentielle

### Exemple 4 : Sauvegarde complète hebdomadaire le dimanche à 1h00

Crée une tâche qui exécute une sauvegarde complète tous les dimanches.

```powershell
.\scheduler_backup.ps1 -Cron "0 1 * * 0" -Type "full" -Includes "C:\Scripts\includes.txt" -TaskName "backup_sunday_full"
```

**Résultat** :
- Tâche créée : `XANADU_backup_sunday_full`
- Exécution : Chaque dimanche à 01:00
- Type : Complète

### Exemple 5 : Sauvegarde mensuelle le 1er à 3h00

Crée une tâche qui exécute une sauvegarde le premier jour de chaque mois.

```powershell
.\scheduler_backup.ps1 -Cron "0 3 1 * *" -Type "full" -Includes "C:\Scripts\includes.txt" -TaskName "backup_monthly"
```

**Résultat** :
- Tâche créée : `XANADU_backup_monthly`
- Exécution : Le 1er de chaque mois à 03:00
- Type : Complète

### Exemple 6 : Mode interactif

Lance le script en mode interactif qui demande les paramètres à l'utilisateur.

```powershell
.\scheduler_backup.ps1
```

**Interaction** :
```
=== CONFIGURATION DE LA TÂCHE PLANIFIÉE ===

Type de sauvegarde (full/dif/inc) [default: full]: inc
Chemin fichier includes.txt [default: C:\Users\Administrateur\Documents\script\includes.txt]: C:\Scripts\includes.txt
Criticité (Critical/Important/Standard) [default: Standard]: Important
Nom complet de la tâche planifiée [default: XANADU_Important_inc]: 

Saisir une expression CRON-like (ex : */30 * * * *)
Expression CRON: 0 2 * * *
```

**Résultat** : Tâche créée avec les paramètres saisis interactivement.

### Exemple 7 : Lister et gérer les tâches XANADU

Affiche toutes les tâches XANADU et permet de les supprimer ou modifier.

```powershell
.\scheduler_backup.ps1 -List
```

**Interaction** :
```
=== TÂCHES PLANIFIÉES XANADU ===

[1] XANADU_backup_file
    Next Run : 08/12/2024 14:00:00
    Last Run : 08/12/2024 13:30:00
    State    : Ready
--------------------------------
[2] XANADU_backup_hourly
    Next Run : 08/12/2024 15:00:00
    Last Run : 08/12/2024 14:00:00
    State    : Ready
--------------------------------

Choisir une action : D = Delete une tâche, M = Modify CRON, Q = Quitter
Action: D
Numéro de la tâche à supprimer: 2
Suppression de : XANADU_backup_hourly...
Tâche supprimée.
```

### Exemple 8 : Stratégie complète de sauvegarde

Configuration d'une stratégie de sauvegarde complète (Full + Dif + Inc).

```powershell
# Sauvegarde complète hebdomadaire (dimanche 2h00)
.\scheduler_backup.ps1 -Cron "0 2 * * 0" -Type "full" -Includes "C:\Scripts\includes.txt" -TaskName "weekly_full" -Policy "Critical"

# Sauvegarde différentielle quotidienne (lundi-samedi 2h00)
.\scheduler_backup.ps1 -Cron "0 2 * * 1-6" -Type "dif" -Includes "C:\Scripts\includes.txt" -TaskName "daily_dif" -Policy "Important"

# Sauvegarde incrémentielle toutes les 4 heures (8h, 12h, 16h, 20h)
.\scheduler_backup.ps1 -Cron "0 8,12,16,20 * * *" -Type "inc" -Includes "C:\Scripts\includes.txt" -TaskName "4hourly_inc" -Policy "Standard"
```

**Résultat** : Trois tâches créées pour une couverture optimale.

## Fonctionnement détaillé

### Architecture du script

Le script est organisé en plusieurs régions fonctionnelles :

#### 1. PARAMETERS - Gestion des paramètres
Définit les paramètres d'entrée du script avec validation.

#### 2. VARIABLES GLOBALES - Configuration
Définit les variables de configuration :
- `$BackupScriptPath` : Chemin vers `backup_file.ps1`
- `$DefaultBackupType` : Type par défaut ("full")
- `$DefaultIncludesFile` : Chemin par défaut du fichier includes
- `$Prefix` : Préfixe des tâches ("XANADU_")
- `$SchedulerLog` : Chemin du fichier de log

#### 3. LOGGING - Journalisation
Fonction `Write-Log` pour enregistrer toutes les opérations.

#### 4. FONCTIONS UTILITAIRES
- `Get-FullTaskName` : Ajoute le préfixe XANADU_ au nom logique
- `Test-BackupScriptPath` : Vérifie l'existence du script de backup
- `Test-IncludesPath` : Vérifie l'existence du fichier includes

#### 5. FONCTIONS CRON
Ensemble de fonctions pour parser et convertir les expressions CRON :

**Fonctions de test** :
- `Test-IsNumericCronField` : Vérifie si une valeur est numérique
- `Test-IsWildcard` : Vérifie si c'est un wildcard (*)
- `Test-IsRange` : Vérifie si c'est une plage (ex: 1-5)
- `Test-IsStep` : Vérifie si c'est une répétition (ex: */30)

**Fonctions de création de triggers** :
- `New-DailyTriggerFromHourMinute` : Crée un trigger quotidien
- `New-WeeklyTrigger` : Crée un trigger hebdomadaire
- `New-MonthlyTrigger` : Crée un trigger mensuel

**Fonctions de conversion** :
- `Convert-CronExpression` : Parse l'expression CRON en objet structuré
- `Convert-CronToTrigger` : Convertit les champs CRON en trigger Windows

#### 6. FONCTIONS DE TÂCHES PLANIFIÉES
- `New-BackupAction` : Crée l'action PowerShell à exécuter
- `Register-BackupTask` : Enregistre la tâche dans Windows
- `Get-XanaduTasks` : Récupère toutes les tâches XANADU
- `Show-XanaduTasksAndManage` : Affiche et gère les tâches en mode interactif

#### 7. MAIN - Logique principale
- Détection du mode (List, Interactif, ou Paramètres)
- Validation des entrées
- Conversion CRON → Trigger
- Création de la tâche planifiée

### Algorithme de conversion CRON

Le script analyse l'expression CRON et génère le trigger Windows approprié :

```
1. Parser l'expression CRON en 5 champs (M H DOM MON DOW)
2. Analyser les champs dans l'ordre de priorité :

   a. Si Minute contient */X (ex: */30)
      → Trigger répétitif toutes les X minutes
      
   b. Sinon, si DOW ≠ * (ex: 0-6)
      → Trigger hebdomadaire
      → Convertir 0-6 en Sunday-Saturday
      
   c. Sinon, si DOM ≠ * (ex: 1-31)
      → Trigger mensuel
      → Utiliser les jours du mois spécifiés
      
   d. Sinon (fallback)
      → Trigger quotidien à l'heure spécifiée

3. Créer le trigger Windows correspondant
4. Associer l'action PowerShell
5. Enregistrer la tâche planifiée
```

### Correspondance CRON → Trigger Windows

| Expression CRON | Type de trigger | Description |
|-----------------|-----------------|-------------|
| `*/30 * * * *` | Répétitif | Toutes les 30 minutes |
| `0 2 * * *` | Quotidien | Chaque jour à 02:00 |
| `0 3 * * 0` | Hebdomadaire | Chaque dimanche à 03:00 |
| `0 22 * * 1-5` | Hebdomadaire | Lundi-vendredi à 22:00 |
| `0 1 1 * *` | Mensuel | Le 1er du mois à 01:00 |
| `0 4 1,15 * *` | Mensuel | Les 1er et 15 à 04:00 |

### Gestion des erreurs

Le script gère plusieurs types d'erreurs :

| Erreur | Message | Action | Code sortie |
|--------|---------|--------|-------------|
| Script backup introuvable | `Script de sauvegarde introuvable` | Arrêt (ERROR) | 1 |
| Fichier includes introuvable | `Fichier includes introuvable` | Arrêt (ERROR) | 1 |
| Expression CRON invalide | `Expression CRON invalide` | Arrêt (ERROR) | 1 |
| Jour de semaine invalide | `Jour de semaine non valide` | Arrêt (Exception) | 1 |
| Jour du mois invalide | `Jour du mois non valide` | Arrêt (Exception) | 1 |
| Erreur création tâche | `Erreur lors de la création de la tâche` | Arrêt (ERROR) | 1 |
| Erreur suppression tâche | `Impossible de vérifier/supprimer l'ancienne tâche` | Continue (WARN) | 0 |

## Format de l'expression CRON

### Structure

```
M H DOM MON DOW
│ │  │   │   └─ Jour de la semaine (0-6, 0=Dimanche)
│ │  │   └───── Mois (1-12) [non utilisé actuellement]
│ │  └───────── Jour du mois (1-31)
│ └──────────── Heure (0-23)
└────────────── Minute (0-59)
```

### Opérateurs supportés

#### Wildcard (*)
Correspond à "toutes les valeurs".

```
* * * * *   # Toutes les minutes (non recommandé)
0 * * * *   # Toutes les heures à la minute 0
```

#### Valeur spécifique
Un nombre exact.

```
30 14 * * *   # 14:30 chaque jour
0 0 1 * *     # Minuit le 1er de chaque mois
```

#### Liste de valeurs (,)
Plusieurs valeurs séparées par des virgules.

```
0 8,12,16 * * *   # À 8h, 12h et 16h
0 9 * * 1,3,5     # 9h les lundis, mercredis et vendredis
```

#### Plage (-)
Une plage de valeurs consécutives.

```
0 9 * * 1-5    # 9h du lundi au vendredi
0 8 1-7 * *    # 8h les 7 premiers jours du mois
```

#### Intervalle (*/X)
Répétition toutes les X unités (uniquement pour les minutes).

```
*/15 * * * *   # Toutes les 15 minutes
*/5 * * * *    # Toutes les 5 minutes
*/60 * * * *   # Toutes les 60 minutes (équivalent à 0 * * * *)
```

### Correspondance jour de la semaine

| Valeur | Jour | Windows |
|--------|------|---------|
| 0 | Dimanche | Sunday |
| 1 | Lundi | Monday |
| 2 | Mardi | Tuesday |
| 3 | Mercredi | Wednesday |
| 4 | Jeudi | Thursday |
| 5 | Vendredi | Friday |
| 6 | Samedi | Saturday |

### Exemples d'expressions CRON

```powershell
# Toutes les 10 minutes
"*/10 * * * *"

# Tous les jours à minuit
"0 0 * * *"

# Tous les lundis à 8h30
"30 8 * * 1"

# Du lundi au vendredi à 18h
"0 18 * * 1-5"

# Le 1er et le 15 de chaque mois à 2h
"0 2 1,15 * *"

# Toutes les 6 heures (minuit, 6h, 12h, 18h)
"0 0,6,12,18 * * *"

# Weekend uniquement à 10h
"0 10 * * 0,6"

# Dernier jour du mois (approximatif : jour 28)
"0 23 28 * *"
```

## Journalisation

### Fichier de log

```
C:\Backups\Local\Logs\Scheduler.log
```

### Format des entrées

```
[YYYY-MM-DD HH:mm:ss] [LEVEL] Message
```

**Exemple** :
```
[2024-12-08 14:30:22] [INFO] ---- Exécution Scheduler.ps1 ----
[2024-12-08 14:30:23] [INFO] Création trigger quotidien : 2:0
[2024-12-08 14:30:24] [INFO] Action générée : C:\Scripts\backup_file.ps1 avec Type=full et Includes=C:\Scripts\includes.txt et Policy=Standard
[2024-12-08 14:30:25] [INFO] Tâche existante trouvée : XANADU_backup_file, suppression en cours.
[2024-12-08 14:30:26] [INFO] Tâche existante supprimée.
[2024-12-08 14:30:27] [INFO] Tâche planifiée créée avec succès : XANADU_backup_file
```

### Niveaux de gravité

- **INFO** : Opération normale (création de trigger, enregistrement de tâche)
- **WARN** : Avertissement (erreur de suppression d'ancienne tâche)
- **ERROR** : Erreur bloquante (script introuvable, CRON invalide, échec création)

## Mode liste (-List)

Le mode liste offre une interface interactive pour gérer les tâches XANADU.

### Affichage des tâches

```
=== TÂCHES PLANIFIÉES XANADU ===

[1] XANADU_backup_file
    Next Run : 08/12/2024 14:00:00
    Last Run : 08/12/2024 13:30:00
    State    : Ready
--------------------------------
[2] XANADU_backup_hourly
    Next Run : 08/12/2024 15:00:00
    Last Run : 08/12/2024 14:00:00
    State    : Ready
--------------------------------
```

### Actions disponibles

#### D - Delete (Supprimer)
Supprime une tâche sélectionnée par son numéro.

**Processus** :
1. Saisir "D"
2. Entrer le numéro de la tâche
3. La tâche est supprimée de Windows Task Scheduler
4. Confirmation affichée et journalisée

#### M - Modify (Modifier)
Modifie l'expression CRON d'une tâche (en la recréant).

**Processus** :
1. Saisir "M"
2. Entrer le numéro de la tâche
3. Saisir la nouvelle expression CRON
4. Le script se relance automatiquement pour recréer la tâche avec le nouveau CRON
5. Le Type et Includes utilisent les valeurs par défaut

**Note** : La modification recrée entièrement la tâche avec les paramètres par défaut pour Type et Includes.

#### Q - Quit (Quitter)
Quitte le mode liste sans effectuer d'action.

## Configuration

### Variables à adapter

Dans la section **VARIABLES GLOBALES**, ajustez ces chemins selon votre environnement :

```powershell
# Chemin vers le script de backup
$BackupScriptPath = "C:\Users\Administrateur\Documents\script\backup_file.ps1"

# Type de sauvegarde par défaut
$DefaultBackupType = "full"

# Fichier includes par défaut
$DefaultIncludesFile = "C:\Users\Administrateur\Documents\script\includes.txt"

# Préfixe des tâches (ne pas modifier sans raison)
$Prefix = "XANADU_"

# Emplacement du log
$SchedulerLog = "C:\Backups\Local\Logs\Scheduler.log"
```

### Préfixe XANADU_

Toutes les tâches créées par ce script portent le préfixe `XANADU_` pour :
- Faciliter l'identification dans Windows Task Scheduler
- Permettre le filtrage dans le mode `-List`
- Éviter les conflits avec d'autres tâches système
- Garantir une gestion centralisée

**Ne modifiez pas ce préfixe** sauf si vous comprenez les implications sur la gestion des tâches existantes.

## Sécurité et bonnes pratiques

### Garanties

- **Pas de tâches orphelines** : Les tâches existantes sont supprimées avant recréation
- **Validation stricte** : Vérification de l'existence des chemins requis
- **Traçabilité complète** : Toutes les opérations sont journalisées
- **Isolation** : Préfixe XANADU_ pour éviter les conflits
- **Exécution privilégiée** : Les tâches s'exécutent avec `-RunLevel Highest`

### Recommandations

#### 1. Planification intelligente
Évitez les planifications trop fréquentes qui pourraient :
- Saturer les disques
- Consommer trop de ressources
- Créer des chevauchements d'exécution

**Recommandation** :
- Full : Hebdomadaire (dimanche 2h)
- Dif : Quotidienne (lundi-samedi 2h)
- Inc : Toutes les 4-6 heures

#### 2. Surveillance des tâches
- Vérifier régulièrement l'état des tâches avec `-List`
- Consulter les logs du scheduler
- Vérifier les logs des backups eux-mêmes
- Monitorer les codes de retour des tâches planifiées

#### 3. Test des planifications
Avant de déployer en production :
- Tester avec une tâche qui s'exécute dans quelques minutes
- Vérifier que le backup s'exécute correctement
- Consulter les logs pour validation

#### 4. Gestion des chemins
- Utiliser des chemins absolus
- Vérifier l'existence des fichiers avant création de tâche
- Documenter les chemins utilisés

#### 5. Droits d'accès
- Exécuter le script avec des privilèges administrateur
- Les tâches créées s'exécutent avec le compte SYSTEM (RunLevel Highest)
- S'assurer que le compte a accès aux sources de backup

#### 6. Maintenance
- Réviser périodiquement les tâches planifiées
- Supprimer les tâches obsolètes
- Adapter les planifications selon l'évolution des besoins

### Limitations connues

- Le champ MON (mois) n'est pas utilisé
- Pas de support des plages complexes (ex: */5 8-18 * * *)
- Les intervalles (*/X) ne fonctionnent que pour les minutes
- Pas de validation avancée des conflits de planification
- La modification d'une tâche utilise les valeurs par défaut (Type et Includes)
- Pas de gestion de la priorité des tâches
- Pas de notification en cas d'échec d'exécution

## Compatibilité

### Versions PowerShell

- **PowerShell 5.1** (Windows PowerShell) : Requis (module ScheduledTasks)
- **PowerShell 7+** (PowerShell Core) : Compatible avec Windows uniquement

### Module requis

```powershell
# Le module ScheduledTasks doit être disponible
Import-Module ScheduledTasks
```

Ce module est inclus par défaut dans :
- Windows 10/11
- Windows Server 2012 R2+
- Windows Server 2016/2019/2022

### Systèmes d'exploitation

- Windows 10/11 (tous)
- Windows Server 2012 R2+
- Windows Server 2016/2019/2022
- Non compatible Linux/macOS (utilise Windows Task Scheduler)

## Notes importantes

### Ordre de priorité CRON

Le script évalue les champs CRON dans cet ordre de priorité :
1. Minute avec intervalle (*/X) → Trigger répétitif
2. Jour de la semaine (DOW) → Trigger hebdomadaire
3. Jour du mois (DOM) → Trigger mensuel
4. Fallback → Trigger quotidien

Cela signifie qu'une expression comme `0 2 1 * 0` sera interprétée comme "dimanche à 2h" (hebdomadaire) et non "le 1er du mois à 2h si c'est un dimanche".

### Recréation des tâches

Lorsqu'une tâche avec le même nom existe déjà :
1. Elle est automatiquement supprimée
2. Une nouvelle tâche est créée avec les nouveaux paramètres
3. L'historique d'exécution est perdu

### Trigger de répétition

Les triggers répétitifs (*/X minutes) sont configurés avec :
- Point de départ : Minuit du jour courant
- Durée de répétition : 30 jours
- Après 30 jours, la tâche doit être recréée (ou continue selon la configuration Windows)

### Exécution avec privilèges

Toutes les tâches sont créées avec `-RunLevel Highest`, ce qui signifie :
- Exécution avec droits administrateur
- Pas d'UAC prompt lors de l'exécution automatique
- Accès complet aux ressources système

## Codes de sortie

| Code | Signification |
|------|---------------|
| 0 | Opération réussie (création ou liste) |
| 1 | Erreur (script introuvable, CRON invalide, échec création) |

## Cas d'usage avancés

### Déploiement via GPO

Pour déployer sur plusieurs serveurs :

```powershell
# Script de déploiement centralisé
$servers = @("SRV01", "SRV02", "SRV03")

foreach ($server in $servers) {
    Invoke-Command -ComputerName $server -ScriptBlock {
        & "C:\Scripts\scheduler_backup.ps1" `
            -Cron "0 2 * * *" `
            -Type "full" `
            -Includes "C:\Scripts\includes.txt" `
            -TaskName "backup_file" `
            -Policy "Standard"
    }
}
```

### Script de vérification des tâches

Vérifier que toutes les tâches sont bien planifiées :

```powershell
$expectedTasks = @("XANADU_weekly_full", "XANADU_daily_dif", "XANADU_4hourly_inc")

$actualTasks = Get-ScheduledTask | Where-Object { $_.TaskName -like "XANADU_*" }

foreach ($expected in $expectedTasks) {
    if ($actualTasks.TaskName -notcontains $expected) {
        Write-Warning "Tâche manquante : $expected"
    } else {
        Write-Host "OK : $expected" -ForegroundColor Green
    }
}
```

### Notification par email après création

```powershell
.\scheduler_backup.ps1 -Cron "0 2 * * *" -Type "full" -Includes "C:\Scripts\includes.txt" -Policy "Standard"

if ($LASTEXITCODE -eq 0) {
    Send-MailMessage -To "admin@company.com" `
                     -From "scheduler@server.local" `
                     -Subject "Tâche de backup créée" `
                     -Body "La tâche a été créée avec succès." `
                     -SmtpServer "smtp.company.com"
}
```

### Création de plusieurs tâches en batch

```powershell
# Définition des tâches à créer
$tasks = @(
    @{ Name = "weekly_full";    Cron = "0 2 * * 0";       Type = "full"; Policy = "Critical"; },
    @{ Name = "daily_dif";      Cron = "0 2 * * 1-6";     Type = "dif"; Policy = "Important"; },
    @{ Name = "hourly_inc";     Cron = "0 8,12,16,20 * * *"; Type = "inc"; Policy = "Standard"; }
)

$includesFile = "C:\Scripts\includes.txt"

foreach ($task in $tasks) {
    Write-Host "Création de la tâche : $($task.Name)"
    
    & "C:\Scripts\scheduler_backup.ps1" `
        -Cron $task.Cron `
        -Type $task.Type `
        -Includes $includesFile `
        -TaskName $task.Name `
        -Policy $task.Policy
        
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] $($task.Name)" -ForegroundColor Green
    } else {
        Write-Host "  [ERREUR] $($task.Name)" -ForegroundColor Red
    }
}
```

## Dépannage

### Problème : "Module ScheduledTasks introuvable"

**Solution** :
```powershell
Import-Module ScheduledTasks -Force
```

Si le module n'existe pas, vous êtes probablement sur une version trop ancienne de Windows.

### Problème : "Accès refusé" lors de la création de tâche

**Solution** : Exécuter PowerShell en tant qu'administrateur.

```powershell
# Vérifier les privilèges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Error "Ce script nécessite des privilèges administrateur."
}
```

### Problème : La tâche ne s'exécute pas

**Vérifications** :
1. Ouvrir Task Scheduler et localiser la tâche `XANADU_*`
2. Vérifier l'historique de la tâche
3. Vérifier que le chemin vers `backup_file.ps1` est correct
4. Tester manuellement l'exécution : `Start-ScheduledTask -TaskName "XANADU_backup_file"`
5. Consulter les logs du scheduler et du backup

### Problème : Expression CRON invalide

**Solution** : Vérifier le format exact :
- 5 champs séparés par des espaces
- Pas de caractères spéciaux non supportés
- Utiliser des guillemets autour de l'expression

```powershell
# Bon
-Cron "0 2 * * *"

# Mauvais
-Cron 0 2 * * *
-Cron "0 2 * *"
```

## Fichiers associés

- **Script principal** : `scheduler_backup.ps1`
- **Documentation** : `docs/scheduler_backup.md`
- **Script appelé** : `backup_file.ps1`
- **Configuration** : Fichier includes (chemin variable)
- **Logs** : `C:\Backups\Local\Logs\Scheduler.log`

## Auteur

Projet XANADU
Version : 1.1
Dernière mise à jour : 11 décembre 2025
