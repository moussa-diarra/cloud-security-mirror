# Cadrage et modèle de menaces

Ce document décrit ce que le projet protège, contre quoi, et comment chaque contrôle est prouvé. Il sert de fil rouge : chaque ressource créée doit répondre à une ligne de ce tableau.

## 1. Entreprise fictive

Petite entreprise qui héberge :
- une **application web** exposée à Internet (zone publique) ;
- une **base de données PostgreSQL** (zone privée, accessible uniquement depuis l'application) ;
- une **équipe d'administration** et un **compte de développeur** (lecture seule).

## 2. Principes de conception

1. **Segmentation** : zone publique et zone privée, un seul flux autorisé de la première vers la seconde (TCP 5432).
2. **Moindre privilège** : droits minimaux, périmètre minimal, attribués à des groupes ou à des rôles temporaires.
3. **Traçabilité** : toute action d'administration est journalisée et certaines déclenchent une alerte.
4. **Maîtrise des coûts** : budget à 0 €, aucune ressource payante inutile, nettoyage planifié.
5. **Reproductibilité** : l'infrastructure est décrite en code (Terraform) et supprimable en une commande.

## 3. Hors périmètre

- Aucune technique offensive : le projet est purement défensif.
- Aucune charge de production, aucune donnée réelle.

## 4. Plan d'adressage

| Environnement | Réseau | Sous-réseau public | Sous-réseau privé |
|---|---|---|---|
| Azure (construction manuelle) | 10.10.0.0/16 | 10.10.1.0/24 | 10.10.2.0/24 |
| Azure (Terraform) | 10.10.0.0/16 | 10.10.1.0/24 | 10.10.2.0/24 |
| AWS (construction manuelle) | 10.20.0.0/16 | 10.20.1.0/24 | 10.20.2.0/24 |
| AWS (Terraform) | 10.30.0.0/16 | 10.30.1.0/24 | 10.30.2.0/24 |

Les environnements manuel et Terraform sont des déploiements indépendants : le second prouve que le premier est reproductible.

## 5. Modèle de menaces

| Menace | Contrôle Azure | Contrôle AWS | Preuve prévue | Statut réel |
|---|---|---|---|---|
| Vol d'identifiants d'un administrateur | MFA, accès conditionnel (CA01), PIM, compte admin séparé, compte d'urgence | MFA, utilisateur sans droit direct, rôle temporaire avec MFA (STS) | Connexion sans MFA bloquée, droits temporaires tracés | CA01 appliquée, activation PIM tracée ; refus de création de VPC sans rôle, session AWS avec `mfaAuthenticated: true` |
| Ressource privée exposée sur Internet | NSG sans règle entrante depuis Internet sur la zone privée | Sous-réseau privé sans route vers la passerelle Internet, security groups sans `0.0.0.0/0` sur la base | Test depuis l'extérieur : connexion refusée | Configuration prouvée (règles NSG, tables de routage) ; pas de test réel, aucune machine créée |
| Mouvement latéral de la zone publique vers la zone privée | NSG : seul le sous-réseau applicatif est autorisé, règle de refus explicite | Security group de la base : source = security group applicatif | Connexion bloquée + journal de flux | Configuration prouvée ; pas de test de trafic réel |
| Action privilégiée non détectée | Journal d'activité + règles Sentinel | CloudTrail + alarmes CloudWatch | Alerte déclenchée par une action d'administration de test | Incidents Sentinel n° 4 et 5, alarmes AWS testées |
| Consommation abusive de ressources | Budget Azure + crédit étudiant | AWS Budgets + plafond du Free Plan | Alerte de seuil déclenchée | Budgets configurés ; déclenchement d'un seuil non testé |

## 6. Limites du modèle

Ce modèle couvre cinq menaces représentatives, pas l'ensemble des risques d'une architecture cloud. Il ne traite pas, par exemple, la protection des données au repos, la sécurité des applications ou la gestion des secrets.
