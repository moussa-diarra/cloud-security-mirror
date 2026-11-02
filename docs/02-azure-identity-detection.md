# Phase 2 - Azure : identité avancée et détection

## Contexte et contraintes
- Annuaire personnel, édition Entra ID Free, paramètres de sécurité par défaut ACTIVÉS.
- Essai Entra P2 : 30 jours. Essai Sentinel : 31 jours, 10 Go/jour max.
- Budget : 0 euro. Crédit Azure for Students en garde-fou.
- Sentinel est géré dans le portail Defender (fin du portail Azure en mars 2027).

## Politiques d'accès conditionnel

### Politique 1 : MFA obligatoire pour les administrateurs
- Menace : vol d'identifiants admin
- Qui : tous les rôles d'administrateur. Exclusion : compte d'urgence
- Quoi : toutes les applications cloud
- Alors : exiger la MFA
- Test : rapport seul, lecture des journaux de connexion, puis activation
- Risque : MFA non enregistrée sur mon compte, vérifiée avant activation

### Politique 2 : blocage de l'authentification héritée
- Menace : contournement de la MFA par de vieux protocoles (IMAP, POP, SMTP)
  qui ne gèrent pas la MFA, avec des identifiants volés
- Qui : tous les utilisateurs. Exclusion : compte d'urgence
- Conditions : applications clientes "héritées"
- Alors : bloquer
- Test : rapport seul d'abord

### Politique 3 : MFA sur connexion à risque (nécessite P2)
- Menace : connexion depuis un contexte inhabituel avec identifiants valides
- Qui : tous les utilisateurs. Exclusion : compte d'urgence
- Conditions : risque de connexion moyen ou élevé
- Alors : exiger la MFA
- Test : rapport seul. Si indisponible dans mon annuaire, politique reportée

## Événements à détecter dans Sentinel

### Événement 1 : attribution d'un rôle ou ajout à un groupe
- Menace : élévation de privilèges, action privilégiée non détectée
- Où : journaux d'audit Entra
- Déclenchement sans danger : ajouter puis retirer lab.reader d'un groupe de test

### Événement 2 : échecs de connexion répétés
- Menace : vol d'identifiants (tentatives par force brute)
- Où : journaux de connexion Entra
- Déclenchement : 5 mauvais mots de passe sur MON compte de test lab.reader

### Événement 3 : modification d'une règle NSG
- Menace : affaiblissement de la segmentation
- Où : journal d'activité Azure
- Déclenchement : modifier puis rétablir une règle du NSG de test

## Ordre des opérations
1. Préparation gratuite, sans essai : compte d'urgence, 2e méthode MFA.
2. Activation de l'essai P2 : début du compteur (J0).
3. Désactivation des paramètres par défaut + création immédiate des politiques
   (politique 1 activée, politiques 2 et 3 en rapport seul).
4. Espace Log Analytics (région autorisée par l'abonnement).
5. Envoi des journaux Entra et Azure vers l'espace.
6. Activation de Sentinel via le portail Defender.
7. Règles de détection et tests des 3 événements.
8. PIM : droits admin à la demande.
9. Defender for Cloud : voir ce qui est gratuit avant d'activer.
10. Avant J25 : captures, export du code, suppression de l'espace de travail.

## Points à vérifier avant d'agir (non confirmés)
- Licence requise pour envoyer les journaux de connexion vers Log Analytics
- Coût de l'espace Log Analytics après l'essai
- Comportement des essais si je supprime l'espace
- Politiques gérées automatiquement par Microsoft après désactivation des défauts

## Plan de retour arrière
Désactiver toutes les politiques d'accès conditionnel, puis réactiver les
paramètres de sécurité par défaut. Compte d'urgence pour garder l'accès.