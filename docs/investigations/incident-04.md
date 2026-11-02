# Investigation - Incident 04 : échecs de connexion répétés

## Fiche de l'incident

| Champ | Valeur |
|---|---|
| Incident | n° 4 |
| Règle de détection | `Echecs-connexion-repetes` |
| Source | Microsoft Sentinel (portail Defender) |
| Gravité | Moyenne |
| Tactique MITRE | Credential Access |
| Technique MITRE | T1110 (Brute Force), probablement T1110.001 (Password Guessing) |
| Entité | `lab.reader` (compte de test, rôle Reader) |
| Début de l'activité | 14h56 (heure affichée par le portail) |
| Nombre d'échecs | 6 |
| Nature | Test contrôlé, généré volontairement sur un compte de laboratoire |
| Verdict | **Vrai positif (test autorisé)** |

> Cette investigation est menée comme en production, sur un incident que j'ai généré moi-même.
> La règle a bien détecté l'activité : c'est le résultat attendu.

## 1. Résumé

Six échecs de connexion consécutifs sur le compte `lab.reader`, depuis une adresse IP géolocalisée à Singapour, ont dépassé le seuil de 5 échecs de la règle et créé l'incident. L'activité correspond à mon test volontaire. En contexte réel (utilisateur basé en France), elle aurait été traitée comme une tentative probable de devinette de mot de passe.

## 2. Chronologie

| Étape | Événement | Source |
|---|---|---|
| 14h56 | Premier échec de connexion sur `lab.reader` | `SigninLogs` |
| Quelques minutes plus tard | 6 échecs au total, seuil de 5 dépassé | `SigninLogs` |
| Cycle suivant de la règle | Alerte générée puis incident créé | Sentinel |

Délai de détection attendu : de l'ordre de quelques minutes (planification toutes les 5 minutes, plus le délai d'arrivée des journaux).

## 3. Analyse

| Indicateur | Observation | Poids pour le verdict |
|---|---|---|
| Nombre d'échecs | 6 échecs rapprochés sur un seul compte | Fort : compatible avec une devinette de mot de passe |
| Compte ciblé | `lab.reader`, rôle Reader, aucun droit d'écriture | Impact limité même en cas de succès |
| Adresse IP | Géolocalisée à Singapour, hors du pays attendu (France) | Moyen : à corroborer, ne suffit pas seul (VPN, déplacement) |
| Heure | 14h56, heures ouvrées en France | Non discriminant : une attaque peut survenir à toute heure |
| Succès après les échecs | À vérifier (requête 3 ci-dessous) | Déterminant : un succès après une série d'échecs signale une compromission possible |

**Pourquoi ce n'est pas légitime dans le scénario de production.** Une série d'échecs sur un compte depuis une zone géographique inhabituelle, sans explication, ne correspond pas au comportement attendu d'un utilisateur basé en France. La géolocalisation seule ne prouve rien (un VPN la fausse), c'est pourquoi on la corrobore avec d'autres éléments avant de conclure.

**Pourquoi c'est un test dans mon lab.** Les échecs correspondent à l'heure de mes tentatives volontaires, et la zone géographique est cohérente avec le poste que j'ai utilisé.

**Technique plus précise.** Six échecs sur un seul compte évoquent T1110.001 (Password Guessing). Si la même IP avait ciblé plusieurs comptes avec peu d'essais chacun, on parlerait plutôt de T1110.003 (Password Spraying). La requête 2 permet de trancher.

## 4. Requêtes d'investigation (KQL)

```kusto
// 1. Chronologie des connexions du compte
SigninLogs
| where UserPrincipalName startswith "lab.reader"
| project TimeGenerated, ResultType, ResultDescription, IPAddress, Location, AppDisplayName
| order by TimeGenerated asc
```

```kusto
// 2. Cette IP a-t-elle ciblé d'autres comptes ? (remplacer par l'IP de l'incident)
let ip = "<IP source de l'incident>";
SigninLogs
| where IPAddress == ip
| summarize Tentatives = count(),
            Comptes = dcount(UserPrincipalName),
            Echecs = countif(ResultType != "0")
  by IPAddress
```

```kusto
// 3. Une connexion a-t-elle réussi après les échecs ?
SigninLogs
| where UserPrincipalName startswith "lab.reader"
| where ResultType == "0"
| project TimeGenerated, IPAddress, Location, AppDisplayName
| order by TimeGenerated asc
```

## 5. Verdict

**Vrai positif (test autorisé).** La détection a fonctionné comme prévu. Dans un contexte réel, le verdict serait resté « vrai positif, à confirmer » tant que l'utilisateur n'a pas répondu.

## 6. Recommandations (comme en production)

**Vérification**
1. Chercher si cette adresse IP a déjà tenté de se connecter par le passé (requête 2, sur une période plus longue).
2. Si oui, bloquer l'adresse (lieu nommé ou politique d'accès conditionnel) et rechercher les autres comptes visés.
3. Si non, contacter l'utilisateur **par un autre canal que la messagerie du compte** pour savoir si c'est lui (un VPN peut expliquer la localisation). On ne conclut pas avant sa réponse.
4. Vérifier avec la requête 3 si une connexion a réussi après la série d'échecs.

**Confinement (dans tous les cas)**
5. Réinitialiser le mot de passe du compte.
6. Révoquer les sessions actives du compte.
7. Vérifier les méthodes MFA enregistrées sur le compte (en chercher une qui ne vient pas de l'utilisateur).

## 7. Améliorations de la détection

- Ajouter une règle de corrélation « échecs suivis d'un succès » pour le même compte et la même IP.
- Ajuster le seuil et la fenêtre pour limiter les faux positifs (utilisateur qui oublie son mot de passe).
- Enrichir l'alerte avec le pays et l'adresse IP pour accélérer le triage.