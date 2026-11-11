# Préférences du propriétaire

- Répondre en français.
- À la fin d'une tâche demandée qui modifie le projet, créer un commit explicite et pousser automatiquement les changements liés à cette tâche vers `origin/main` (`https://github.com/Kyrluh/NOVA.git`). Le propriétaire a demandé ce comportement ; ne pas redemander la même autorisation à chaque tâche.
- Préserver les modifications étrangères à la tâche et l'historique distant. Ne pas forcer les pushes.
- Privilégier des tests courts et ciblés. Ne pas relancer systématiquement la suite complète ou un émulateur pour une petite correction.
- Ne jamais commiter les clés, identifiants, bases utilisateur, outils locaux ou installables. Les APK et ZIP à distribuer vont dans les releases GitHub, pas dans Git.
- Conserver la signature Android existante pour les mises à jour et augmenter le code de version des APK livrées.
- Lors d'une publication, distinguer les versions Windows et Android si une seule plateforme reçoit de nouveaux binaires ; ne pas annoncer une compilation inexistante.
