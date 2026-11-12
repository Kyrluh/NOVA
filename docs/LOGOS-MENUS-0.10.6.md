# NOVA IPTV 0.10.6 — Logos des chaînes et boutons lisibles

La liste TV affiche désormais une petite version du logo déjà utilisé dans les favoris. L’édition TV / Fire TV présente aussi ces images dans le menu contextuel des chaînes, à côté du nom et du programme en cours.

Les images existantes sont réutilisées sans recherche externe ni modification du catalogue. Elles conservent leurs proportions ; une initiale les remplace si leur adresse manque ou si leur chargement échoue. Leur décodage est limité à 96 pixels pour limiter la consommation mémoire des listes.

Les boutons sélectionnés à la télécommande utilisent un fond jaune et un texte sombre, notamment Annuler dans les fenêtres de dialogue. Les boutons textuels ordinaires utilisent une couleur claire indépendante de la couleur d’accent.

Les vérifications ciblées du menu couvrent les informations du guide, la sélection, les titres longs, le texte agrandi et le défilement dans l’ordre des chaînes. Les éditions Windows, Android mobile et TV sont distribuées en 0.10.6+38 ; la signature Android est conservée. Aucun déploiement ADB n’est effectué. [Notes de release](RELEASE-0.10.6.md).
