# NOVA IPTV TV

Application dédiée aux téléviseurs et boîtiers Android, conçue pour les flèches, OK, Retour et les touches multimédias. Elle partage les modèles, sources, cache chiffré, logique de reprise et moteur libmpv de NOVA ; son interface et son package sont distincts.

## APK et compatibilité

- Fichier : **NOVA-IPTV-TV-0.8.6-universal.apk**.
- Package de production : **`app.nova.iptv.tv`** ; application téléphone : `app.nova.iptv`.
- Android **API24/7.0 minimum**, cible API36 ; architectures ARM32, ARM64 et x86_64.
- Android TV / Google TV et Fire TV sous **Fire OS basé sur Android**, sous réserve de respecter l'API minimum et les capacités vidéo de l'appareil.
- **Vega OS n'est pas une cible APK Android**. Le modèle exact du Fire TV Stick doit être vérifié : Amazon distingue les appareils Fire OS et Vega dans son [inventaire officiel](https://developer.amazon.com/docs/fire-tv/fire-os-overview.html).

Le manifeste déclare le lanceur Leanback, une bannière TV, le paysage et l'absence d'exigence tactile, conformément aux [éléments de configuration Android TV](https://developer.android.com/training/tv/get-started/create). Aucune dépendance Google Play Services n'est introduite par l'interface TV.

## Installation

1. Télécharger l'APK TV depuis la release GitHub, puis la transférer ou l'installer avec les outils autorisés de l'appareil.
2. Sur les appareils Fire OS compatibles, l'installation via ADB suit la [procédure Amazon](https://developer.amazon.com/docs/fire-tv/installing-and-running-your-app.html).
3. Ouvrir **NOVA IPTV TV** depuis le lanceur.
4. Aller dans **Sources**, puis ajouter la playlist M3U ou l'accès Xtream.

L'application TV peut être installée à côté de NOVA téléphone. **Elle ne lit pas les données privées de l'autre package** : les accès sont à renseigner dans la version TV. Ce choix permet de garder l'ancienne installation sans mélanger ses préférences et ses bases. Installer ensuite les mises à jour TV par-dessus la première version, sans la désinstaller.

## Navigation

| Télécommande | Action |
| --- | --- |
| Flèches | Déplacer le cadre de sélection entre les menus, cartes et contrôles |
| OK / Select | Ouvrir ou activer la cible sélectionnée |
| Menu sur l'écran principal | Revenir au menu latéral |
| Retour | Fermer le menu/la page ; revenir à l'accueil depuis une rubrique |
| Retour depuis l'accueil | Demander confirmation avant de quitter |

Les listes et carrousels suivent automatiquement le focus. Les grilles sont construites à la demande. Les catalogues gardent les règles de langues et catégories et l'ordre fourni par la source. Le menu **Paramètres → Tri, langues et catégories** permet de les modifier.

### Direct

La liste des chaînes est à gauche et le lecteur à droite. **Le simple focus ne change pas de chaîne** : OK choisit la chaîne ; un second OK sur la même chaîne, ou **Regarder**, développe le lecteur existant. La recherche et le choix de catégorie restent accessibles.

Dans le lecteur, les touches chaîne suivante/précédente ou gauche/droite changent de chaîne. Le direct ne reçoit pas de commande de déplacement temporel. Le guide actuellement chargé apparaît sous le lecteur ; le chargement XMLTV reste dans **Sources → Guide TV**.

### Films et séries

Ouvrir une fiche puis lancer le film ou choisir une saison et un épisode. Une série en cours propose **Reprendre l'épisode** et sélectionne sa saison. Les épisodes sont construits en liste à la demande. Favoris, historique et retrait de Reprendre restent accessibles.

## Lecteur à la télécommande

- **OK sur l'image** : lecture/pause.
- **Play/Pause** : contrôle du lecteur visible, même si le focus est dans la liste des chaînes.
- **Bas/Haut ou Menu depuis l'image** : accéder aux contrôles.
- **Gauche/droite sur l'image VOD** : ±10 secondes ; sur les contrôles : naviguer entre eux sans chercher dans la vidéo.
- **Avance/retour rapide** : ±10 secondes en VOD.
- **Retour** : fermer les contrôles/le plein écran avant de revenir au catalogue.

La barre TV propose lecture/pause, épisode précédent/suivant, vitesse, pistes audio, sous-titres texte et format. Elle ne propose pas les gestes de luminosité/volume ni le verrouillage tactile du téléphone. Le PiP est désactivé dans cette interface TV ; l'activité n'ajoute pas de service permanent en arrière-plan. Les touches système Home et volume gardent leur rôle système.

Les réglages audio/vidéo et les reconnections restent ceux du moteur partagé. Les codecs et le décodage matériel dépendent du téléviseur ou du Stick. Les [conventions Amazon pour les contrôleurs](https://developer.amazon.com/docs/fire-tv/controller-behavior-guidelines.html) servent de référence pour OK, Retour et Play/Pause.

## Sources et mises à jour

Depuis la version TV 0.8.2, les flèches haut/bas déplacent le focus entre les champs du formulaire sans ouvrir le clavier. Sur le champ URL, appuyer sur **OK** ouvre un éditeur **Android natif** avec le clavier système de la TV. **Valider** enregistre le texte ; **Annuler** ou Retour conserve la valeur précédente. Le focus revient au champ modifié, puis la flèche bas passe au suivant. La même saisie est utilisée pour le nom, l'identifiant, le mot de passe personnalisé et XMLTV. Les caractères de l'URL, notamment `:`, `/`, `?`, `&`, `%` et `=`, sont conservés.

Les catalogues sont actualisés au lancement avec la progression partagée. Les sources restent chiffrées dans le stockage de ce package. Aucun transfert automatique de mots de passe depuis une autre application ou un téléphone n'est effectué.

## Compilation

`scripts/build-android-tv.ps1` utilise le même fichier de signature privé que les autres livraisons NOVA et passe `--dart-define=NOVA_TV=true`. Gradle lit ce même paramètre pour sélectionner `src/tv/AndroidManifest.xml` et le package TV. Un seul paramètre pilote donc le natif et Flutter. Sans ce paramètre, le manifeste et le package téléphone restent utilisés.

Le packager `scripts/package-android.ps1 -Television` vérifie les identifiants, la version du pubspec, le lanceur Leanback, le tactile facultatif, les trois ABI, la signature et l'alignement ZIP16KiB avant de copier vers `dist/android-tv`.
