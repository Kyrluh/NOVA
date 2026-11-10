# Vérifications de la version 0.1.0 — 9 novembre 2026

Journal historique de la première livraison. Pour la version actuelle avec sources IPTV, voir `VALIDATION-0.2.0.md`.

## Environnement et compilation

- Flutter 3.47.9 et Dart 3.13.7 préparés dans `.tools`, analyse SDK désactivée.
- Visual Studio Build Tools 2022 17.14.44, chaîne C++ x64 et SDK Windows installés. `flutter doctor` reconnaît la cible Windows ; aucun SDK Android n'est nécessaire.
- `flutter build windows --release --no-pub` : compilation Release x64 réussie, `NOVA_IPTV.exe` et DLL natives générés.
- Icône personnalisée produite depuis le widget `NovaMark`, ICO PNG 256×256.

## Analyse et tests

| Commande via les wrappers `scripts/flutter.ps1` / `scripts/dart.ps1` | Résultat |
| --- | --- |
| `flutter analyze --no-pub` | Aucune erreur, aucun avertissement, aucun signalement |
| `flutter test --no-pub --reporter expanded` | 12 tests réussis |
| `flutter test tool/preview_test.dart --no-pub` | 1 test réussi, captures Flutter de test et icône générées |
| `dart run tool/native_smoke.dart build/windows/x64/libmpv/libmpv-2.dll` | Réussi : décodage PCM local, 10 vitesses, volume, pause et déplacement temporel |

Les 12 tests couvrent les valeurs de vitesse et préférences invalides, la progression, la reprise d'un fichier de sauvegarde `.bak`, les favoris et réglages conservés entre contrôleurs, les erreurs de stockage, les épisodes vus individuellement, la navigation, les fiches sans faux bouton Lecture, la sélection de saisons, la recherche sans accents, les filtres TV et le rendu 1000×680 avec grandes affiches.

Le test libmpv utilise un fichier WAV silencieux de 15 secondes généré par le projet, sans réseau ni contenu tiers. Les dix valeurs de `setRate` sont acceptées. Sur un intervalle réel d'environ 1,1 seconde, la position avance de **1,09 s à 1×** et **2,112 s à 2×**. Ces mesures sont des observations ponctuelles, pas un banc de performance garanti. Le moteur rapporte `mpv v0.36.0-403-g652a1dd907` et FFmpeg `n6.0`.

## Lancement et dossier portable

La vérification par `scripts/smoke-launch.ps1` contrôle un vrai processus Windows, la présence de sa fenêtre principale, sa survie pendant trois secondes et sa fermeture normale avec code 0. L'état final du contrôle et du réglage système est consigné ci-dessous après son exécution.

- Contrôle du binaire final : réussi, fenêtre créée et fermeture normale avec code 0.
- Contrôle du dossier portable `dist/NOVA-IPTV-0.1.0-windows-x64` : réussi, fenêtre créée et fermeture normale avec code 0, après restauration du réglage système.
- Mode développeur Windows : état initial restauré. La valeur `AllowDevelopmentWithoutDevLicense`, absente au départ, est de nouveau absente ; le fichier temporaire de restauration a été supprimé. Le mode développeur n'est pas requis pour utiliser le programme.
- Archives portable et sources NOVA générées avec sommes SHA-256 dans `dist/SHA256SUMS.txt`. Les DLL CRT requises sont fournies localement à côté de l'exécutable. Les sources excluent `.tools`, les builds et les liens éphémères des plugins.

Le test de fermeture avait révélé une sortie anormale avec `windowManager.destroy()` : cette API quittait la boucle Windows avant la destruction normale de la fenêtre. Le code utilise désormais une fermeture Windows normale après sauvegarde, contrôlée par le même test sur le binaire et sur le dossier portable.

## Limites des preuves

Les captures `preview*.png` viennent du moteur Flutter de test, pas d'une capture de la fenêtre Windows. Le test PCM prouve le fonctionnement du moteur audio et de l'horloge de lecture ; il ne prouve pas le rendu vidéo GPU, les dix vitesses sur chaque codec, le fonctionnement d'une URL distante ni la compatibilité d'un fournisseur IPTV.

Aucun compte IPTV n'a été utilisé. Xtream, M3U, XMLTV, bibliothèques massives, reprise persistante des fichiers personnels, enchaînement des épisodes, HEVC/HLS/MPEG-TS, pistes de médias représentatifs, sous-titres externes, D3D11VA et HDR ne sont pas validés dans cette phase. L'installateur n'est pas livré. L'archive portable reste une version de développement pour usage personnel local ; voir les notices des bibliothèques natives avant redistribution publique.
