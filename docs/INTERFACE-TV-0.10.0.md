# Interface NOVA IPTV TV 0.10.0

APK locale **0.10.0+32 compilée en Release**, non publiée et non installée sur la TV. Fichier : `dist/android-tv/NOVA-IPTV-TV-0.10.0-universal.apk`. Les sources de cette interface sont regroupées avec les adaptations Windows/mobile dans le commit 0.10.0 ; aucune nouvelle release n'est publiée. Les téléchargements publics restent en TV 0.9.2 et Windows/téléphone 0.8.8.

## Accès plus directs

- Les six raccourcis **Reprendre, Favoris, TV, Films, Séries et Par plateforme** précèdent la bannière à l'accueil. Sur TV, ils occupent une ligne lorsque la largeur le permet, sinon deux lignes de trois ; leur focus déclenche le défilement nécessaire pour garder la sélection visible.
- La bannière de suggestion TV est réduite à environ 170 dp. Elle conserve les propositions selon les genres préférés et **Autre suggestion**.
- L'en-tête TV garde quatre accès disponibles : **Recherche, Sources, Changer de profil et Paramètres**. Le profil courant apparaît dans l'accueil et les actions ne sont pas dupliquées dans son contenu.
- **Reprendre** reste suivi de **Récemment ajoutés**. Le menu latéral conserve les rubriques demandées, notamment **Tendances** après **Plateformes**.

## Navigation et réglages

- Les paramètres sont regroupés en quatre entrées : **Profil et envies**, **Bibliothèque et affichage**, **Lecture**, **Sources et guide TV**.
- Retour depuis le catalogue d'une plateforme ramène d'abord à la grille des plateformes, avec restauration du focus. Retour depuis un accès utilitaire ramène à la rubrique précédente.
- Recherche, catégorie et position de défilement des catalogues sont conservées par profil et par rubrique lors des déplacements dans l'application pendant la session. La navigation évite de maintenir des catalogues ou un lecteur cachés actifs.
- Une recherche sans résultat se distingue d'une bibliothèque vide ; les actions pour effacer la recherche ou réinitialiser le filtre sont proposées lorsque pertinentes.

## Fiches et épisodes

- L'action principale **Lire/Reprendre** et le choix de version sont mis en évidence avant les informations secondaires.
- Le synopsis peut être développé ou replié. Le favori indique son état : **Ajouter aux favoris** ou **Dans les favoris**.
- Les affiches des fiches conservent leur proportion 2:3, sans étirement.
- Les lignes d'épisodes TV passent à environ 96 dp, avec adaptation au texte agrandi. Le repère unique **À reprendre**, le choix de saison et le défilement jusqu'à l'épisode en cours sont conservés.

## Préférences et périmètre

Les sources, profils, favoris, reprises, historique, variantes, genres préférés et filtres existants sont conservés. Cette modification d'interface ne change pas le moteur vidéo, le lancement sans sous-titres, les choix de langues ni l'ordre des chaînes fourni par la source.

Cette note décrit l'étape TV et son APK locale. Les adaptations et les binaires Windows/téléphone préparés ensuite sont détaillés dans la [note Windows et Android mobile](INTERFACE-WINDOWS-MOBILE-0.10.0.md).

## Contrôles réalisés

- Analyse ciblée de neuf fichiers : aucune erreur.
- Quinze scénarios uniques réussis lors de contrôles courts : onze pour l'accueil, les fiches et la navigation générale, quatre pour les catalogues.
- Quatre captures de démonstration de l'accueil, des paramètres et des fiches film/série inspectées, sans installation ni commande ADB sur la TV.
- Compilation TV Release et packager réussis : signature de production existante, trois architectures ARM32/ARM64/x86_64, API minimum 24, cible 36 et alignement ZIP 16 KiB vérifiés.

Ces contrôles couvrent les parcours et la disposition de l'interface. Ils ne remplacent pas l'essai de cette version avec les sources du propriétaire sur sa télécommande et son appareil.
