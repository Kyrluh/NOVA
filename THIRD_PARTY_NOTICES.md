# Composants et crédits

NOVA IPTV est un projet indépendant. Aucun code applicatif ni binaire de l'installation locale d'IPTVS n'a été repris. Le dépôt [GCHOfficial/iptvs](https://github.com/GCHOfficial/iptvs), GPLv3, a été étudié pour ses choix d'architecture et de protocoles.

Le code original de NOVA est proposé sous GPL-3.0-or-later ; voir `LICENSE`. Les composants tiers conservent leurs licences et leurs mentions de copyright.

Les sélections internet facultatives proviennent du service public [Streaming Catalogs](https://github.com/rleroi/Stremio-Streaming-Catalogs-Addon), qui utilise des données de [JustWatch](https://www.justwatch.com/), et les listes populaires du service [Cinemeta de Stremio](https://v3-cinemeta.strem.io/manifest.json). Le client NOVA implémente le [protocole public des catalogues](https://github.com/Stremio/stremio-addon-sdk/blob/master/docs/protocol.md) sans reprendre le code de ces projets ni installer de plugin de lecture. Les métadonnées et affiches distantes gardent leurs droits d'origine et leurs propriétaires. Les services ne sont pas des API officielles de Netflix ou des autres plateformes et leur disponibilité n'est pas garantie. Leur provenance est affichée dans la page Par PlateForme et sur les rangées de tendances. Aucune clé TMDB n'est intégrée ni requise.

| Composant | Origine | Licence / notices |
| --- | --- | --- |
| Flutter et hôte Windows généré | https://github.com/flutter/flutter | BSD-3-Clause, `licenses/Flutter-BSD-3-Clause.txt` |
| media_kit, media_kit_video et plugins | https://github.com/media-kit/media-kit | MIT pour les wrappers, `licenses/media_kit-MIT.txt` |
| Packages Dart résolus | `pubspec.lock` | Textes dans `licenses/dart-packages.txt`, également dans l'écran Licences |
| SQLite et sqflite_common_ffi | https://pub.dev/packages/sqflite_common_ffi et https://pub.dev/packages/sqlite3 | Versions verrouillées et notices des packages conservées dans `licenses/dart-packages.txt` ; bibliothèque native incluse par les hooks officiels du paquet |
| libmpv Windows | https://github.com/media-kit/libmpv-win32-video-build/releases/tag/2023-09-24 | Binaire fourni par media_kit_libs_windows_video 1.0.11 ; les licences natives ne se résument pas à la licence MIT du wrapper |
| libmpv Android | https://github.com/media-kit/libmpv-android-video-build/tree/v1.1.7 | Construction fournie par media_kit_libs_android_video 1.3.8 ; scripts et sources du fournisseur à conserver, avec les notices de mpv/FFmpeg et dépendances natives |
| SQLite Android / sqflite | https://github.com/tekartik/sqflite | Plugin BSD-2-Clause, versions verrouillées dans pubspec.lock ; SQLite du système Android |
| ANGLE et bibliothèques graphiques associées | https://github.com/alexmercerind/flutter-windows-ANGLE-OpenGL-ES/releases/tag/v1.0.1 | Notices natives du fournisseur à conserver lors d'une redistribution |
| Logos des plateformes, fichiers PNG inchangés | [Dashboard Icons, commit d767d7327db7f8ebd3715b552523f61889eea41c](https://github.com/homarr-labs/dashboard-icons/tree/d767d7327db7f8ebd3715b552523f61889eea41c) | Apache-2.0, copyright 2024 Bjorn Lammers, Meier Lukas, Thomas Camlong et Homarr Labs ; `licenses/Dashboard-Icons-Apache-2.0.txt` |

Sur Windows, le verrou de dépendances actuellement résolu utilise le libmpv `mpv v0.36.0-403-g652a1dd907` et FFmpeg `n6.0`. Le paquet natif télécharge `mpv-dev-x86_64-20230924-git-652a1dd.7z`, MD5 de contrôle fournisseur `a832ef24b3a6ff97cd2560b5b9d04cd8`. Ce moteur ancien est une base de démonstration, à remplacer par une construction libmpv maintenue et auditée avant une diffusion publique. Il ne correspond pas au moteur récent et au chemin HDR natif d'IPTVS. Android utilise une construction distincte, référencée ci-dessus ; les versions natives des deux plateformes ne doivent pas être confondues.

Sources de construction du moteur : https://github.com/media-kit/libmpv-win32-video-build/tree/2023-09-24 ; commit mpv correspondant : https://github.com/mpv-player/mpv/commit/652a1dd. FFmpeg : https://ffmpeg.org/legal.html et https://github.com/FFmpeg/FFmpeg/tree/n6.0. Le choix GPL-3.0-or-later du code NOVA ne remplace pas l'inventaire et les sources correspondantes de ces bibliothèques.

Les binaires ne sont pas versionnés dans le dépôt Git. Avant de redistribuer les binaires à des tiers, réunir les notices complètes, versions, sources correspondantes et scripts/options de construction de libmpv, FFmpeg, ANGLE et leurs dépendances ; les simples liens ci-dessus ne constituent pas un paquet de sources correspondant complet. La publication du code source NOVA ne comprend pas les clés privées ni les données IPTV personnelles.

Les titres, synopsis, chaînes, épisodes et visuels du catalogue de démonstration sont des créations fictives originales. Les affiches et l'icône NOVA sont dessinées par le code du projet. Les logos tiers servent à identifier les plateformes dans la bibliothèque personnelle ; leurs noms et marques restent la propriété de leurs titulaires, sans affiliation avec NOVA. Aucune image de film commercial, clé API, compte, playlist privée, publicité ou télémétrie n'est fournie.
