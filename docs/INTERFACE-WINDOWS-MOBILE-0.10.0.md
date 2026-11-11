# Interface Windows et Android mobile 0.10.0

Adaptation **0.10.0+32** de l'interface Windows et Android téléphone/tablette. Les compilations Release Windows et Android mobile ont réussi. Les installables sont distribués dans la [release 0.10.0](https://github.com/Kyrluh/NOVA/releases/tag/v0.10.0) ; les sources sont poussées sur `origin/main`. Aucune installation ADB n'est effectuée.

L'APK TV `dist/android-tv/NOVA-IPTV-TV-0.10.0-universal.apk` a déjà été construite localement lors de l'étape TV précédente. Cette adaptation concerne Windows et Android mobile ; elle n'annonce pas de nouveau binaire TV. Voir la [note TV 0.10.0](INTERFACE-TV-0.10.0.md) pour son périmètre et ses contrôles.

## Navigation adaptée à l'appareil

### Windows

- Le menu latéral conserve les rubriques de la bibliothèque et peut être réduit.
- La barre supérieure donne accès à la recherche globale, aux sources IPTV, au changement de profil et aux paramètres. Le menu **Ouvrir** regroupe l'ajout d'une source, l'ouverture d'un fichier et celle d'une URL vidéo.
- **Ctrl+F** et **Ctrl+K** ouvrent la recherche globale et sélectionnent son texte. Une croix efface la recherche.
- Ces raccourcis ne changent pas de rubrique lorsqu'un lecteur occupe le plein écran.
- Les accès utilitaires, notamment les réglages et le tri, mémorisent la rubrique précédente pour y revenir.

### Android téléphone, tablette et pliable

- Sur une largeur compacte, la navigation inférieure conserve **Accueil, TV, Films, Séries et Plus**. Sur une grande largeur, le menu latéral devient disponible.
- **Plus** regroupe les accès sous **Bibliothèque**, **Découvrir**, **Personnaliser** et **Sources et fichiers**. Reprise, favoris, historique, plateformes et tendances restent accessibles sans charger l'en-tête.
- L'en-tête propose recherche, changement de profil et paramètres. L'ouverture des sources et des fichiers est également disponible dans le menu d'ouverture de média.
- Un bouton Retour et le retour Android permettent de quitter les pages utilitaires et de retrouver la rubrique précédente. La lecture conserve sa propre gestion du retour.
- Les actions des fiches ont des cibles tactiles d'au moins 48 dp. Le choix de catégories mobile n'ouvre pas le clavier automatiquement.

## Accueil et catalogues

Les six raccourcis **Reprendre, Favoris, TV, Films, Séries et Par plateforme** restent placés avant la suggestion. Leur nombre de colonnes s'adapte à l'espace disponible. La suggestion selon les genres préférés, **Autre suggestion**, **Reprendre** puis **Récemment ajoutés** sont conservés.

Dans **Films** et **Séries** :

- Les catégories restent dans une seule bande horizontale, même lorsqu'un fournisseur en propose beaucoup. Le bouton **Catégories** indique le choix courant et ouvre la liste complète avec recherche : dialogue sur Windows, panneau inférieur sur Android.
- **Récemment ajoutés** reste la première catégorie et le choix initial. Les autres catégories conservent le tri par ajouts récents par défaut et les choix de tri existants.
- La recherche, la catégorie et le tri sont retrouvés pendant la session, séparément pour chaque profil et chaque type de catalogue. Cette conservation de navigation n'ajoute pas de sauvegarde sur disque.
- Une recherche sans résultat et un catalogue vide ont des explications distinctes. L'action **Effacer la recherche** ou **Réinitialiser les filtres** est proposée lorsqu'un filtre peut masquer les contenus.

La densité des grilles et le réglage **Affiches par ligne** restent pris en compte. Les favoris et le menu de retrait de **Continuer à regarder** sont conservés.

## Fiches, versions et épisodes

- **Lecture/Reprendre** est visible avant le synopsis. Sur une série, **Reprendre l'épisode** ou **Lire l'épisode** accompagne le choix de saison.
- Le choix **Version · langue / qualité** reste disponible avant le lancement lorsque plusieurs variantes existent.
- Le bouton de favori exprime son état : **Ajouter aux favoris** ou **Dans mes favoris**.
- Le synopsis est limité à trois lignes lorsqu'il est long ; **Lire la suite** et **Voir moins** permettent de développer ou replier le texte.
- Sur téléphone, les marges et la hauteur de l'en-tête sont réduites pour laisser davantage de place aux actions et aux épisodes. Sur une grande surface mobile, la fiche utilise une présentation plus compacte avec affiche et titre côte à côte.
- Le repère unique **À reprendre**, la sélection de la bonne saison et le défilement jusqu'à l'épisode en cours restent conservés.

## Paramètres par groupes

Les réglages sont répartis en cinq groupes :

| Groupe | Contenu principal |
| --- | --- |
| Profil et envies | Profil courant, genres préférés, profils disponibles |
| Bibliothèque et apparence | Affiches, couleurs, langues, catégories et ordre |
| Lecture | Vitesse, volume, épisodes et options propres à l'appareil |
| Sources et guide TV | Sources M3U/Xtream Codes et guide XMLTV |
| Données locales | Import/export des réglages, licences et réinitialisation |

Sur une grande largeur, les groupes et leur contenu sont affichés côte à côte. Sur téléphone ou fenêtre étroite, une liste de groupes ouvre une page dédiée avec retour. Les options Android et Windows continuent d'être présentées selon leur plateforme.

## Périmètre et validation

Les profils, sources, favoris, reprises, historique, genres, filtres et variantes existants sont réutilisés. L'ordre des chaînes fourni par la source n'est pas modifié. Le lancement sans sous-titres et l'activation manuelle des sous-titres sont conservés.

Cette étape adapte la disposition à la largeur disponible, y compris sur Fold fermé/déplié, sans changer le moteur vidéo ni ajouter de rechargement du catalogue lors d'un changement de dimensions. Elle ne constitue pas une validation de lecture ou de performance sur un appareil physique.

Vingt-six scénarios ciblés ont réussi, sans suite complète ni émulateur : 19 pour les catégories, paramètres, accès Windows/mobile et dispositions adaptatives, trois pour les fiches, deux pour l'accueil et deux pour les raccourcis Windows. Les contrôles de redimensionnement vérifient la conservation du même état de lecteur à travers les tailles simulées. Dix aperçus des vrais widgets avec catalogue fictif ont été générés dans `dist/previews` (Windows, téléphone et Fold) ; les écrans principaux ont été inspectés visuellement.

L'analyse ciblée finale de 12 fichiers ne signale aucun problème. La compilation Windows x64 Release et les compilations Android Release par architecture et universelle ont réussi. Le packager Android a vérifié le package `app.nova.iptv`, la version `0.10.0+32`, les architectures attendues, l'API minimum 24, la cible 36 et l'alignement ZIP 16 KiB. Le certificat est celui de production existant : `62fafe6de54629f3d7485d2dcebc81664709ac9ec7c67456822c7614e36b4dd0`.

La transition physique plié/déplié pendant une lecture, la fluidité sur appareil et l'usage prolongé restent à confirmer sur le téléphone. Le mode développeur Windows n'a pas été activé pour ces compilations. Les processus Gradle ont été arrêtés après le packaging.

## Installables locaux

Les archives sont locales, hors Git :

| Plateforme | Chemin local |
| --- | --- |
| Windows x64 portable | `dist/NOVA-IPTV-0.10.0-windows-x64/NOVA_IPTV.exe` |
| Archive Windows portable | `dist/NOVA-IPTV-0.10.0-windows-x64.zip` |
| Android téléphone ARM64 | `dist/android/NOVA-IPTV-0.10.0-arm64-v8a.apk` |
| Android téléphone universelle | `dist/android/NOVA-IPTV-0.10.0-universal.apk` |

Les APK mobiles conservent le package `app.nova.iptv` et la signature de production existante. Les installables, clés de signature et données personnelles restent hors Git. Les APK et archives sont disponibles séparément dans la release GitHub 0.10.0.
