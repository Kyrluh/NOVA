# Audit et adaptation Android de NOVA IPTV — 9 novembre 2026

La base est le lecteur Windows NOVA 0.5.0, pas un nouveau projet. La branche partagée devient 0.6.0+8, avec application Android `app.nova.iptv` (Android 7/API24 minimum, cible API36). Les dispositions dépendent de la fenêtre disponible et des caractéristiques de pliage, jamais d'une résolution du Galaxy Z Fold codée dans l'application.

## Réutilisation et adaptations

| Domaine | Réutilisé | Adaptation Android |
| --- | --- | --- |
| M3U/M3U8, Xtream, XMLTV | Clients, parsers, modèles, associations EPG | Même logique HTTP, calculs de parsing hors UI ; parcours des lignes M3U sans seconde liste complète |
| Catalogue, favoris, historique, reprise | Contrôleurs et préférences existants | Historique visible, résolutions des épisodes vers leurs séries, navigation tactile |
| SQLite | Repository et chiffrement avant écriture | Factory `sqflite` Android, fragments chiffrés bornés pour éviter `CursorWindow` ; Windows reste en schéma1 compatible avec les anciens EXE |
| Protection des sources | Interface SecretStore | Android Keystore AES-256-GCM sur worker natif ; DPAPI réservé à Windows |
| Vidéo | media_kit/libmpv, pistes, progression, santé de lecture | Hôte Android, MediaCodec, gestes, PiP, lifecycle, reconnexion bornée, épisodes suivants |
| Affiches/catalogues/tri/plateformes | Composants et logique existants | Paddings, grilles, formulaires et dialogues adaptatifs |
| Fenêtre | Navigation et routes Flutter | `window_manager`/plein écran Win32 uniquement sous Windows ; Android utilise activité, insets, orientation et PiP |
| Documents | file_selector | Sélection Android SAF, export des réglages via ACTION_CREATE_DOCUMENT |

## Choix du moteur

Media3 ExoPlayer est une option Android pertinente pour MediaCodec, HLS et l'intégration système. Son adoption immédiate exigerait cependant une seconde abstraction des pistes et des états, un moteur Windows distinct et une nouvelle validation de toutes les sources.

Cette version conserve libmpv via `media_kit` pour réutiliser la session et la compatibilité des sources existantes. Sur appareil physique, la configuration permet l'accélération matérielle et garde les choix automatiques sûrs de la bibliothèque. Un chemin spécifique aux émulateurs évite un défaut EGL connu : rendu direct `mediacodec_embed` avec décodeur MediaCodec, sans modifier la politique des appareils physiques. Il ne prouve pas l'accélération du téléphone Samsung.

La reconnexion limite les tentatives et le délai, conserve la position VOD et les pistes, et n'est pas une boucle infinie. En direct sans timeshift, les gestes de seek sont désactivés ; le lecteur Android empêche aussi le composant vidéo d'envoyer un seek de restauration au flux live lors d'un rattachement de surface.

## Continuité et interface

La vidéo possède une session et une texture conservées. Le changement de disposition réutilise leur état ; une clé stable protège la vidéo lorsque la liste TV passe au-dessous ou à côté. Les informations de charnière fournies par Flutter/Android sont prises en compte dans la disposition TV. Les changements de taille, densité, orientation et écran sont gérés par `configChanges`, sans réinitialiser le moteur.

Écran compact : navigation inférieure, accès aux rubriques supplémentaires par « Plus », commandes tactiles et formulaires utilisables avec clavier. Grand écran : rail rétractable, grilles plus denses, liste et vidéo TV simultanées lorsque la place le permet, EPG latéral ou dialogue compact.

Les gestes sont désactivables globalement et par fonction : luminosité à gauche, son à droite, doubles appuis VOD ±10s, tap de visibilité et verrouillage tactile. Le ratio, les pistes et les sous-titres texte sont disponibles. Les commandes d'épisode précédent/suivant traversent les saisons dans la même page et le même état de lecteur, conservent la progression et sont désactivées aux extrémités. Le passage TV vers une autre vidéo attend la libération complète du précédent lecteur et de ses flags Android avant d'ouvrir le suivant.

## Énergie et cycle de vie

Il n'y a pas de service permanent en arrière-plan. Le maintien de l'écran dépend d'une lecture active et du retour au premier plan, puis est désactivé en pause, PiP ou fermeture. Le lecteur conserve sa session pour la reprise après une pause Android. Le PiP se limite aux appareils compatibles et à une lecture active. Les changements de focus audio et le retrait d'écouteurs peuvent mettre en pause ; le volume système est synchronisé avec les commandes.

## Limites à vérifier sur téléphone

Le catalogue final reste représenté en mémoire ; le découpage du cache et le parsing hors UI réduisent les pics mais ne constituent pas une pagination serveur de Xtream. Les grilles sont paresseuses et les détails de séries sont chargés à la demande. La validation ne permet pas de promettre un catalogue illimité sur un téléphone à faible mémoire.

Les sous-titres texte sont pris en charge. Les pistes images DVD/PGS/DVB conservent la limite du rendu texte antérieur ; les styles ASS avancés, le HDR, les codecs audio propriétaires et tous les profils HEVC doivent être testés séparément. Les anciennes dépendances natives de Windows ne sont pas remplacées par le port Android.

Il faut encore confirmer sur le Galaxy physique : décodage matériel et HDR, comportement One UI lors de transitions rapides, réseau du fournisseur, batterie/température et sessions longues. Un émulateur et des tests de redimensionnement ne certifient pas ces points.

## Références techniques

- [Flutter : grands écrans et pliables](https://docs.flutter.dev/ui/adaptive-responsive/large-screens), [DisplayFeature](https://api.flutter.dev/flutter/dart-ui/DisplayFeature-class.html).
- [Android : écrans pliables](https://developer.android.com/develop/adaptive-apps/guides/foldables/learn-about-foldables), [Picture-in-Picture](https://developer.android.com/develop/ui/views/picture-in-picture).
- [media_kit : moteur multiplateforme](https://pub.dev/packages/media_kit), [Media3 : formats](https://developer.android.com/media/media3/exoplayer/supported-formats).
- [Rendu noir des émulateurs : problème upstream et chemin MediaCodec](https://github.com/media-kit/media-kit/issues/1343).
