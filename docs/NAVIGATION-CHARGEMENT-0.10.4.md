# NOVA IPTV 0.10.4+36

## Navigation et visibilité

- Changer d’onglet efface la recherche et replace son contenu en haut, sur Windows, téléphone et TV. Le redimensionnement d’un écran pliable conserve la page et son lecteur.
- Dans l’édition TV, entrer dans TV en direct place le focus sur la première chaîne disponible, dans l’ordre de la source.
- Les contours de focus des cartes TV, boutons, champs de saisie et épisodes sont jaunes. Les favoris actifs affichent un cœur jaune.
- Retour depuis l’accueil Android/TV propose Réduire, Fermer ou Annuler. Fermer la fenêtre Windows offre les mêmes choix. Réduire conserve la session en mémoire sans relancer volontairement les sources ; Android peut néanmoins supprimer le processus pour récupérer de la mémoire.

## Chargement des sources

La première importation reste complète pour découvrir toutes les catégories et permettre de les cocher plus tard. Avec un catalogue déjà en cache, Xtream demande uniquement les catégories autorisées par les filtres du profil actif, pour la TV, les films et les séries. Les catégories nouvelles sont examinées avec les mêmes règles.

Les catégories masquées restent dans le cache ; les recocher déclenche une actualisation des contenus sélectionnés, avec regroupement des changements rapprochés. L’ordre connu des chaînes est conservé lorsque plusieurs requêtes par catégorie sont nécessaires. Les programmes et les détails ne sont pas téléchargés à nouveau à cette occasion.

Une M3U est un fichier unique : le serveur ne propose généralement pas de téléchargement par catégorie. NOVA doit donc la télécharger entièrement puis appliquer les préférences. Une langue impossible à déterminer à partir du nom de catégorie nécessite également de recevoir ses titres avant de les filtrer. Si le fournisseur ne renvoie pas ses catégories, le chargement complet reste le recours disponible.

Les paramètres Sources et guide TV et la gestion des sources proposent **Recharger manuellement les sources**, avec progression et conservation du cache en cas d’échec.

## Fichiers de mise à jour

Au démarrage Android, NOVA supprime dans son propre cache de mises à jour les APK de son édition dont la version est déjà installée, sans appel réseau. Une APK plus récente non installée et les fichiers extérieurs à ce cache sont conservés. Un fichier verrouillé ne bloque pas l’ouverture.

## Livraison et vérifications

Cette version est compilée localement pour Windows, Android téléphone et Android TV/Fire TV. Les installables ne sont pas committés. Aucun déploiement ADB ni aucune nouvelle release GitHub ne fait partie de cette modification.

- Windows : `dist/NOVA-IPTV-0.10.4-windows-x64.zip`.
- Téléphone ARM64 : `dist/android/NOVA-IPTV-0.10.4-arm64-v8a.apk`.
- Téléphone universel : `dist/android/NOVA-IPTV-0.10.4-universal.apk`.
- Android TV / Fire TV : `dist/android-tv/NOVA-IPTV-TV-0.10.4-universal.apk`.

Compilation Release des trois éditions réussie, code Android 36 et signature de production conservée. Le packaging vérifie les identifiants de package, les versions, l’alignement ZIP 16 KiB et les empreintes SHA-256. L’analyse statique ne signale aucun problème. Sept tests ciblés ont réussi, sans suite complète ni émulateur.

Les vérifications ciblent le premier import puis le rafraîchissement filtré, la conservation du cache masqué, le retour dans les onglets TV, le focus de première chaîne, les choix de fermeture et la suppression sélective des APK. Les transitions et la reprise après réduction restent à vérifier sur les appareils physiques, notamment si Fire OS décide de libérer l’application.
