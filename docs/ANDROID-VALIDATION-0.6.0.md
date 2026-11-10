# Validation NOVA IPTV Android 0.6.0+8

Validation locale du 9 novembre 2026. Les médias de test sont des créations originales : mire animée, pistes AAC FR/EN et sous-titres texte. Aucun compte IPTV personnel n'a été utilisé pour les tests.

## Environnement

Flutter 3.47.9, Dart 3.13.7, JDK 21, Android SDK/API36, NDK 28.2, AGP 9.1.0. Émulateur Android 15/API35 Google APIs x86_64, profil Pixel Fold, WHPX et SwiftShader. Écran interne 2208×1840, écran externe 1080×2092 ; les tests déclenchent les transitions natives de l'émulateur, puis des changements de fenêtre et d'orientation. Le système testé utilise des pages mémoire de 4 Ko.

## Vérifications exécutées

| Domaine | Résultat observé |
| --- | --- |
| Analyse Dart partagée | Analyse globale finale sans problème ; journal conservé avec les rapports |
| Suite unitaire et widgets | 155 tests réussis ; formulaires à 360 px avec clavier, TV adaptative, historique, tris, sources, stockage et lecteur Windows/Android |
| Épisodes précédent/suivant | Commandes compactes et larges, bornes désactivées, ordre saisons/numéros, même State et progression conservée ; commandes absentes des films et du direct |
| Passage TV vers autre lecture | Libération du lecteur et des flags Android attendue dans les deux sens ; délais supérieurs à 12 s testés, seconde ouverture bloquée tant que la fermeture n'est pas terminée |
| Ouverture lente et réseau en arrière-plan | Lecture différée si l'ouverture se termine hors écran ; retry réseau reporté jusqu'au retour, sans lecteur supplémentaire |
| Keystore réel | Chiffrement/déchiffrement Unicode et rejet de modification du texte chiffré |
| SQLite Android réel | Import, fermeture et réouverture d'un catalogue de 2500 entrées dépassant 2 Mo, sans dépassement CursorWindow |
| H.264 et HEVC | Décodage Android, dimensions 320×180, progression, deux pistes audio AAC et deux pistes texte ; sélection FR/EN et sous-titres décodés |
| HTTP MPEG-TS et HLS | HLS sur nouveau lecteur, MPEG-TS, puis HLS en réutilisant le lecteur : réussis avec serveur HTTP dans un isolate indépendant |
| Branche direct réelle | NovaPlayer live avec MPEG-TS HTTP : compact→large→compact, une seule ouverture et un seul backend, même texture et audio, seek de surface supprimé |
| Plié/déplié et orientation | Même identifiant d'activité, même Player et VideoController, une seule ouverture du média ; position et pistes conservées |
| Écran partagé Android réel | Deux applications visibles dans des tâches multi-window, NOVA hors PiP ; même activité et une seule ouverture, vidéo et progression présentes, retour plein écran réussi |
| PiP | Entrée et retour réussis, image visible, progression pendant le PiP, écran non maintenu éveillé |
| Verrouillage/reprise | Reprise de la même session ; pas de nouvelle ouverture du média |
| Vidéo réellement affichée | Sept captures dont écran partagé, PiP et retours ; contrôle ciblé réussi avec coordonnées transformées exactes : 96 à 100 % de pixels chromatiques, dont 225/225 dans le panneau partagé. Mire vérifiée visuellement |
| Essai continu | 180 secondes réelles après les transitions, 18 relevés à 10 secondes, une seule ouverture ; position 56,000→268,625 s à vitesse 1,25× |
| Images pendant cet essai | Deux captures vers 181,250 et 240,750 secondes de média, 220/225 et 222/225 échantillons colorés ; mire et timecode visibles |
| Pause et énergie | KEEP_SCREEN_ON désactivé en pause et en PiP ; aucun service de fond applicatif |
| APK de production | ARM64 et universelle signées par le même certificat NOVA, package app.nova.iptv, version 0.6.0/code8, minSDK24/cible36, non débogables ; installation de l'universelle et démarrage à froid réussis |
| Parcours complet dans l'APK Release | Source M3U ajoutée par l'interface, une chaîne et un film importés, vraie vidéo TV visible sur écran interne puis externe et après dépliage ; Home Android active le PiP avec image visible |
| Mise à jour réelle | Réinstallation de l'APK signée avec install -r puis relance : source, deux contenus et catégorie TV conservés ; preuves XML et captures dans release-ui-smoke.json et release-ui |
| Compatibilité d'alignement | ZIP des deux APK vérifié avec zipalign -P16 ; les six ELF ARM64 Release sont alignés sur 16 Ko ou 64 Ko. Aucun essai d'exécution sur système 16 Ko n'est revendiqué |
| Windows | Compilation Release, test natif import/cache/lecture HTTP/redémarrage hors ligne réussi ; nouvelle fenêtre ouverte et fermée normalement, processus Windows déjà ouvert conservé |

Les sept tests natifs complets passent. Un test ciblé supplémentaire de 40 secondes passe après affinage du recadrage des captures en écran partagé. Les rapports des transitions, des contrôles visuels et le parcours dans l'APK signée sont conservés dans [validation/android-0.6.0](validation/android-0.6.0). Le défaut d'image noire de l'émulateur avec le rendu EGL par défaut a été reproduit puis corrigé par un choix MediaCodec réservé aux émulateurs. Les appareils physiques gardent la politique matérielle automatique de media_kit.

## Reproduire

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\flutter.ps1 analyze --no-pub
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\flutter.ps1 test test --no-pub
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\flutter.ps1 test integration_test/android_full_test.dart -d emulator-5556 --dart-define=NOVA_FOLD_HANDSHAKE=true --dart-define=NOVA_SOAK_SECONDS=180 --reporter expanded
```

Pendant la compilation puis l'exécution de cette dernière commande, lancer dans deux autres terminaux :

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\android-native-transitions.ps1 -Device emulator-5556
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\android-soak-pixels.ps1 -Device emulator-5556
```

Ces scripts sont limités aux émulateurs jetables. Ils ne doivent pas être lancés sur un téléphone personnel. Le premier restaure taille, densité et rotation initiales. Les ports de contrôle HTTP appartiennent uniquement au banc de test, absent des APK Release.

Compiler et tester séquentiellement : Flutter partage les fichiers générés de plugins entre plateformes. Avec cette version du SDK, `--no-pub` saute aussi la régénération de ces fichiers ; passer d'un test natif à une Release exige de laisser cette régénération active. Le script `build-android.ps1` le fait automatiquement. Il n'ajoute pas le plugin `integration_test` aux APK de production. Références : [défaut de génération avec --no-pub](https://github.com/flutter/flutter/issues/169336), [course entre commandes Flutter](https://github.com/flutter/flutter/issues/193430).

## À vérifier sur le Samsung et les téléphones des amis

Aucun appareil Samsung physique n'était connecté. La validation ne certifie pas le Galaxy demandé, ses codecs matériels, les interactions One UI, le HDR, les réseaux des fournisseurs, l'autonomie ou la température. Une endurance de trois minutes sur émulateur ne constitue pas une validation sur plusieurs heures.

Sur le téléphone : configurer une source autorisée ; tester TV, films, séries, changements rapides plié/déplié, rotation, écran partagé, PiP, verrouillage, casque Bluetooth, pistes audio et sous-titres, Wi-Fi/mobile et reconnexion ; poursuivre une lecture d'au moins une heure et contrôler la batterie et la chauffe. Tester aussi une mise à jour de l'APK sans désinstallation.

Le cache est fragmenté et chiffré, le parsing s'effectue hors UI et les grilles se construisent à la demande. Le catalogue final reste cependant en mémoire : aucun catalogue illimité ni pagination serveur Xtream n'est promis. Les sous-titres images DVD/PGS/DVB ne sont pas rendus par le composant texte actuel. Les entrées M3U non regroupées ne créent pas automatiquement une structure de saisons.
