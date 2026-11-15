# NOVA IPTV 0.11.1 — Profils, guide TV et nouvelle identité cinéma

Cette release regroupe les améliorations préparées depuis la version publique 0.10.7.

## Navigation et personnalisation

- Programme en cours affiché sous les chaînes dans les listes TV, en complément du guide du lecteur et du menu contextuel. Les chargements sont partagés et ne bloquent pas la lecture.
- Trente avatars illustrés hors connexion, à choisir dans Paramètres → Profil et envies : super-héros, Poudlard, Star Wars, Retour vers le futur, One Piece, Goku et Naruto. L’avatar est enregistré par profil et apparaît sur les boutons de changement de profil.
- Clic droit dans l’image TV sur Windows pour ouvrir le menu des chaînes et catégories, avec logos et programme en cours, sans redémarrer la vidéo.
- Prise en charge de la touche Lecture/Pause Windows même avec une autre fenêtre au premier plan, pendant qu’un lecteur est ouvert. La touche est libérée à la fermeture du lecteur. Une réservation préalable par une autre application ou une macro clavier peut limiter cette fonction.
- Nouveau logo validé : N composé de filaments lumineux verticaux et popcorn rouge/blanc agrandi au premier plan. Il est utilisé dans l’interface, les icônes et la bannière TV.
- Version installée affichée près de la marque et guide utilisateur HTML imprimable actualisé.

## Vérification des mises à jour Android

La lecture des certificats essaie les informations Android modernes et historiques, sans désactiver le contrôle de signature. Les erreurs distinguent maintenant une archive illisible, une mauvaise édition, une version déjà installée, un certificat illisible et une signature différente.

Si une ancienne version de NOVA bloque encore avant d’ouvrir l’installateur en signalant une APK non signée, installer une première fois l’APK officielle manuellement, **par-dessus l’application, sans désinstallation**. Le correctif du gestionnaire ne peut prendre effet qu’une fois cette nouvelle version installée. Son fonctionnement doit encore être confirmé sur la Fire Stick où le blocage a été signalé.

## Fichiers

- `NOVA-IPTV-0.11.1-windows-x64.zip` : portable Windows.
- `NOVA-IPTV-0.11.1-arm64-v8a.apk` : téléphone Android ARM64.
- `NOVA-IPTV-0.11.1-universal.apk` : téléphone Android universel.
- `NOVA-IPTV-TV-0.11.1-universal.apk` : Android TV / Fire TV.
- `NOVA-IPTV-0.11.1-source.zip` : archive du code du projet.
- `SHA256SUMS.txt` : empreintes des fichiers distribués.

Les APK conservent le certificat de production et utilisent le code 42. Pour Windows, fermer NOVA avant d’extraire le dossier complet du portable.

## Validation

Les fonctionnalités de la préparation 0.11.0 ont passé sept tests ciblés : guide partagé, isolation et persistance des profils, clic droit sans réouverture vidéo, commandes Windows et réservation/libération de la touche multimédia sans double bascule. L’analyse statique n’a signalé aucun problème. L’aperçu des portraits et du logo a été vérifié ; le logo final a été validé par le propriétaire.

La révision 0.11.1 remplace uniquement les illustrations de marque et augmente la version. Les compilations et le packaging vérifient les versions Android, packages, signatures et l’alignement ZIP 16 KiB. Aucun déploiement ADB n’est effectué. Le clavier Corsair en situation réelle et le correctif de mise à jour sur la Fire Stick concernée restent à tester sur ces appareils.
