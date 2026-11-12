# NOVA IPTV 0.10.6 — Logos TV et boutons lisibles

Les listes de chaînes affichent les petits logos déjà visibles dans les favoris, à côté du nom. Sur Android TV et Fire TV, ils apparaissent aussi dans le menu contextuel du lecteur, avec le programme en cours.

- Images affichées sans recadrage et décodées en petite taille pour limiter la consommation mémoire.
- Initiale de remplacement si le logo est absent ou indisponible.
- Boutons sélectionnés à la télécommande avec fond jaune et texte sombre : Annuler et les autres actions des fenêtres de dialogue restent lisibles.
- Boutons textuels ordinaires avec une couleur claire indépendante de la couleur d’accent.
- Conservation du focus sur la chaîne ouverte depuis les favoris ou la recherche, introduite dans la version TV 0.10.5.

## Installables

- `NOVA-IPTV-0.10.6-windows-x64.zip` : portable Windows.
- `NOVA-IPTV-0.10.6-arm64-v8a.apk` : téléphone Android ARM64.
- `NOVA-IPTV-0.10.6-universal.apk` : téléphone Android universel.
- `NOVA-IPTV-TV-0.10.6-universal.apk` : Android TV / Fire TV.
- `NOVA-IPTV-0.10.6-source.zip` : code du projet.
- `SHA256SUMS.txt` : empreintes des fichiers.

Les APK utilisent le code de version 38 et conservent la signature existante. Installer par-dessus NOVA sans la désinstaller pour garder les données. Sur Windows, fermer l’application avant d’extraire le dossier complet de la nouvelle version.

Trois tests ciblés du menu TV passent : guide actualisé sans perte de sélection, navigation entre catégories et défilement avec noms longs et texte agrandi. L’analyse des fichiers modifiés ne signale aucun problème. Aucun déploiement ADB n’est effectué.
