# Chasse aux menaces - fiches de requêtes

Données : espace Log Analytics `law-secure-mirror-dev`, alimenté depuis le 15/10/2026. Volume très faible : beaucoup de requêtes renvoient peu ou rien. Chaque fiche indique ce qui serait attendu sur de vraies données.

---

## Chasse 1 - Connexion depuis un pays jamais utilisé par le compte

**Question.** Un compte se connecte-t-il avec succès depuis un pays qu'il n'avait jamais utilisé ?

**Hypothèse.** Une connexion réussie depuis un nouveau pays peut signaler un identifiant volé et utilisé par un tiers.

**Table.** `SigninLogs`

```kusto
let historique = SigninLogs
    | where TimeGenerated between (ago(14d) .. ago(1d))
    | where ResultType == "0"
    | distinct UserPrincipalName, Location;
SigninLogs
| where TimeGenerated > ago(1d)
| where ResultType == "0"
| join kind=leftanti historique on UserPrincipalName, Location
| project TimeGenerated, UserPrincipalName, Location, IPAddress, AppDisplayName
```

Logique : on dresse la liste des couples (compte, pays) vus dans le passé, puis on garde les connexions récentes qui n'y figurent pas (`leftanti`).

**Résultat dans mon lab.** Aucune ligne : tous les comptes se connectent depuis la même zone géographique.

**Validation de la requête.** Un résultat vide peut cacher une requête cassée. Test avec une base de référence fictive (`datatable` contenant un compte inexistant) : la requête renvoie alors toutes les connexions réussies récentes, ce qui confirme que la logique fonctionne et que le résultat vide sur les vraies données est légitime.

**Limites et faux positifs.** Voyage légitime, usage d'un VPN, première connexion d'un nouvel utilisateur (aucun historique), historique trop court (ici, une semaine de données).

**Règle candidate ?** Oui, avec réglages : ignorer les comptes sans historique suffisant, croiser avec une liste de déplacements connus, alerter à partir du pays plutôt que de l'IP seule.

---

## Chasse 2 - Opérations PIM en dehors des heures de bureau

**Question.** Un rôle privilégié est-il attribué, retiré ou activé via PIM en dehors des heures de travail habituelles ?

**Hypothèse.** Un attaquant qui contrôle un compte éligible peut activer un rôle la nuit, quand personne ne surveille. Un changement d'attribution hors horaires mérite aussi vérification.

**Table.** `AuditLogs`

**Choix de la plage normale.** 8h à 19h, heure de Paris (entreprise fictive basée en France). `TimeGenerated` est en UTC : l'heure locale est calculée en ajoutant le décalage (2 h jusqu'au 25/10/2026, 1 h ensuite).

**Noms d'opérations PIM observés dans mon annuaire :**
- `Add member to role requested (PIM activation)` et `Add member to role completed (PIM activation)` : activation d'un rôle (deux lignes par activation, demande puis réalisation)
- `Add eligible member to role in PIM requested/completed (timebound)` : attribution d'un rôle éligible
- `Add member to role in PIM requested/completed (permanent)` : attribution permanente
- `Remove member from role in PIM completed (permanent)` : retrait d'une attribution permanente
- `Remove eligible member from role in PIM requested/completed (timebound)`
- `Update role setting in PIM` : modification des paramètres du rôle

```kusto
let decalage = 2h;   // France : 2h jusqu'au 25/10, puis 1h
AuditLogs
| where OperationName has "PIM" and OperationName has "completed"
| where Result == "success"
| extend HeureLocale = hourofday(TimeGenerated + decalage)
| where HeureLocale < 8 or HeureLocale >= 19
| project TimeGenerated, HeureLocale, OperationName, InitiatedBy, TargetResources
```

La requête filtre sur `completed` pour éviter les doublons (demande puis réalisation).

**Résultat dans mon lab.** Une ligne : `Remove member from role in PIM completed (permanent)` à 07h58 (heure locale calculée : 7). Une activation PIM réalisée à 08h03 n'est pas remontée : elle tombe dans la plage normale (8h), ce qui montre que le filtre horaire fonctionne dans les deux sens.

**Analyse de la ligne remontée.**
- C'est une action sensible : retirer une attribution permanente modifie les droits d'un compte d'administration.
- L'initiateur est un compte différent de `adm.cloud` (nom d'affichage visible dans le champ `InitiatedBy`).
- Pour qualifier l'événement, un analyste ouvre `TargetResources` pour identifier le compte et le rôle concernés, puis confirme auprès de l'initiateur que l'action était attendue.

```kusto
AuditLogs
| where OperationName has "Remove member from role in PIM completed"
| mv-expand TargetResources
| project TimeGenerated, InitiatedBy,
          Cible = tostring(TargetResources.displayName),
          Type = tostring(TargetResources.type)
```

**Problème de fuseau horaire observé.** L'heure affichée par le portail et l'heure UTC ne sont pas la même : l'heure affichée (07h58) correspond à l'heure de Paris, ce qui est cohérent avec le calcul. Une règle basée sur l'heure doit connaître le fuseau de chaque utilisateur : un administrateur qui travaille dans un autre fuseau déclenche des faux positifs. Un changement d'heure (25/10) casse aussi un décalage fixe. Piste à tester : la fonction `datetime_utc_to_local(TimeGenerated, "Europe/Paris")`, qui gère l'heure d'été automatiquement.

**Limites et faux positifs.** Administrateurs dans d'autres fuseaux, astreintes de nuit légitimes, opérations planifiées, changement d'heure.

**Règle candidate ?** Oui. Priorité haute pour les rôles très privilégiés (Administrateur général), plus basse pour les autres. À associer à une liste d'exceptions (fenêtres de maintenance approuvées).
