# Architecture de NOVA IPTV

Mise à jour 0.3.0 : sources M3U/Xtream/XMLTV, cache SQLite protégé, tri personnel et commandes du lecteur sont implémentés. Les résultats actuels figurent dans `VALIDATION-0.3.0.md` ; les journaux précédents conservent les preuves des imports et du correctif TV.

## Choix technique

NOVA IPTV est une application Flutter Desktop native pour Windows x64. Son interface est dessinée par Flutter : elle n'utilise ni WebView, ni Electron, ni serveur web local.

Le projet de référence [GCHOfficial/iptvs](https://github.com/GCHOfficial/iptvs) confirme la pertinence de Flutter avec `media_kit` et libmpv pour la vidéo sur Windows. NOVA possède son propre code, sa navigation et son identité graphique. Aucun code applicatif d'IPTVS n'a été copié.

Le premier relevé de l'environnement, le 9 novembre 2026, a trouvé un dossier projet vide, sans Flutter, Dart, Git ni chaîne de compilation C++ Windows accessibles. Le runtime .NET installé n'est pas un SDK et ne permet pas de compiler cette application. Les scripts du dépôt préparent les outils nécessaires ; la présence de ces scripts ne prouve pas à elle seule leur installation ni la réussite d'une compilation.

## Découpage

| Emplacement | Responsabilité |
| --- | --- |
| `lib/main.dart` | Initialisation Flutter, stockage local, fenêtre et lancement |
| `lib/domain/models.dart` | Médias, saisons, épisodes, réglages et progression validés |
| `lib/domain/catalog_preferences.dart` | Visibilité par langue/catégorie et ordre indépendant par type de média |
| `lib/data/demo_catalog.dart` | Catalogue de démonstration clairement identifié |
| `lib/data/local_store.dart` | Persistance asynchrone des données locales non sensibles |
| `lib/data/source_repository.dart` | Cache SQLite des sources et catalogues chiffrés |
| `lib/data/secret_store.dart` | Protection DPAPI Windows liée à l'utilisateur |
| `lib/sources/` | Client HTTP, M3U, Xtream et XMLTV |
| `lib/state/source_controller.dart` | Import, annulation, cache, détails et actualisation des sources |
| `lib/state/app_controller.dart` | État observable, favoris, historique, réglages et sauvegarde |
| `lib/ui/` | Navigation, écrans et composants |
| `lib/player/nova_player.dart` | Session libmpv, commandes réelles, pistes, vitesse et plein écran |
| `lib/player/player_adjustments.dart` | Commandes rapides de volume/luminosité et regroupement des requêtes |
| `lib/player/playback_health.dart` | Échec confirmé et reprise, sans bloquer les diagnostics récupérables |
| `lib/ui/theme.dart` | Thème sombre et accent personnalisable |
| `lib/ui/widgets/artwork.dart` | Affiches, bannières et logo originaux dessinés par code |
| `windows/` | Hôte natif Windows et configuration CMake |
| `test/` | Vérifications automatisées ciblées |
| `scripts/` | Préparation, commandes Flutter et compilation |

Le domaine ne dépend pas d'un fournisseur IPTV. Un catalogue distant pourra alimenter les mêmes écrans sans imposer son format JSON à l'interface. Le contrôleur coordonne les mutations et la persistance ; les widgets ne réécrivent pas eux-mêmes les fichiers de préférences.

## Données de la première phase

Les chaînes et les créations du catalogue sont fictives. Leurs illustrations sont générées hors ligne par `CustomPainter`, sans service d'affiches, clé API ou abonnement. Une fiche fictive sans média ne représente pas un flux réellement disponible.

La persistance JSON est limitée aux réglages, favoris, historique et positions de lecture. `LocalStore` fournit une interface remplaçable et une implémentation mémoire pour les tests. `FileLocalStore` écrit un fichier temporaire puis conserve une sauvegarde de la version précédente avant le remplacement, en tenant compte du comportement de renommage Windows.

Ce stockage JSON reste limité aux préférences, favoris et progressions. SQLite conserve désormais un bloc DPAPI par source comprenant configuration, catalogue et programmes ; aucun identifiant ni URL privée n'est écrit en clair dans SQLite ou ses journaux. Le décodage des gros documents et le chiffrement sortent du thread de rendu. Des index SQL séparés pour les titres et la pagination constituent une évolution ultérieure ; le cache actuel est déchiffré en mémoire au démarrage.

Les identifiants sont saisis dans l'écran Sources IPTV et protégés par DPAPI avec les URL et contenus du catalogue. Les paramètres d'interface exportés n'incluent pas les sources. Les messages d'erreur sont neutres et n'exposent ni URL privée ni secret. Un autre compte Windows ne peut pas déverrouiller ce cache ; les sources doivent alors être configurées à nouveau.

## Lecteur et vitesse

Le moteur sélectionné est libmpv, via `media_kit` et `media_kit_video`. Le lecteur doit posséder un cycle de vie explicite : ouvrir un média, suivre les événements, enregistrer la progression, annuler les abonnements et libérer le moteur à la fermeture.

La préférence de vitesse accepte **0,25×, 0,5×, 0,75×, 1×, 1,25×, 1,5×, 1,75×, 2×, 2,5× et 3×**. Dans le lecteur, elle doit être appliquée par l'API réelle [`Player.setRate`](https://pub.dev/documentation/media_kit/latest/media_kit/Player/setRate.html). Une sélection enregistrée dans les préférences ne constitue pas, à elle seule, une preuve de changement de vitesse du média.

Les flux en direct restent à 1×, sans déplacement temporel. La vitesse variable est destinée aux films, épisodes et fichiers à la demande.

Les codecs, pistes et capacités de décodage dépendent du binaire libmpv réellement livré et du matériel. L'intégration standard de la surface vidéo Flutter ne garantit pas le HDR natif. Le projet IPTVS possède du code Windows/D3D11 dédié pour ce chemin ; une transmission HDR équivalente exigera une étude séparée, du code natif et des essais sur écran/GPU compatibles. Aucune garantie HDR ne doit apparaître dans l'interface avant cette validation.

## Évolution vers les sources IPTV

La version 0.2.0 utilise des adaptateurs distincts :

- **Xtream Codes** : authentification, catégories, catalogue TV/VOD/séries, puis détails chargés à la demande.
- **M3U/M3U8** : analyse de fichier ou URL, groupes, logos et identifiants de chaînes.
- **XMLTV** : import du guide, correspondance par identifiant, heures avec fuseau explicite et conservation du dernier guide valide.

Le contrôleur initialise le cache indépendamment du réseau. Depuis0.6.5, le point d'entrée de production active ensuite une actualisation des sources, une fois par lancement, après chargement des préférences et affichage du catalogue. Les sources sont parcourues séquentiellement et utilisent les mêmes opérations transactionnelles que l'actualisation manuelle. La progression associe les octets reçus lorsque leur total est connu et les phases de parsing/enregistrement ; sans taille réseau connue, le bandeau est indéterminé. Les délais d'expiration, limites de taille, annulations et commits sérialisés restent appliqués. Les générations empêchent une réponse annulée de ressusciter une source supprimée. Les anciennes rubriques sont conservées lors d'une actualisation Xtream partiellement échouée ; les saisons connues restent en cache jusqu'au rechargement des détails. Le guide XMLTV et les catalogues publics de tendances restent séparés de cette actualisation automatique.

Les listes et grilles doivent rester construites à la demande. Le cache d'images, la pagination SQL et les index de recherche seront mesurés sur de grands jeux de données ; la présence d'une liste défilante n'est pas une preuve de performance sur une bibliothèque réelle.

## Dépendances et redistribution

Les versions résolues sont consignées dans `pubspec.lock`. La [documentation de media_kit](https://pub.dev/packages/media_kit) décrit l'assemblage des packages Dart, surface vidéo et bibliothèques natives.

[IPTVS est publié sous GPLv3](https://github.com/GCHOfficial/iptvs/blob/main/LICENSE). Ses [notices tierces](https://github.com/GCHOfficial/iptvs/blob/main/THIRD_PARTY_NOTICES.md) indiquent un assemblage libmpv/FFmpeg avec composants GPL. Le fait d'écrire un code d'interface indépendant ne dispense pas de vérifier les licences des bibliothèques effectivement distribuées avec NOVA. Avant redistribution, inventorier les binaires, conserver les licences/notices et préparer les sources correspondantes et informations de construction requises par leurs licences.

NOVA ne fournit aucun compte IPTV, serveur privé, télémétrie ou publicité. Les contenus de démonstration externes éventuels doivent être identifiés avec leur source et leurs crédits.
