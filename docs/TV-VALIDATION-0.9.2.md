# NOVA IPTV TV 0.9.2

Version Android TV/Google TV et Fire OS, code Android **31**. La release fournit l'APK TV universelle et ses empreintes SHA-256. Windows et Android téléphone restent disponibles en **0.8.8+26** ; aucun nouveau binaire de ces plateformes n'est inclus.

## Changements

- Lecteur Media3 ExoPlayer 1.11.1 avec SurfaceView Android native, décodage matériel et repli de décodeur.
- Buffers vidéo plafonnés selon la mémoire disponible ; aucune boucle de progression en pause/arrêt ni service permanent ajouté.
- Cache de synopsis séparé, annulation des fiches quittées, réutilisation des listes et des résultats filtrés. La progression reste exacte en mémoire ; ses notifications et sauvegardes ordinaires sont regroupées sur cinq secondes sur TV.
- Sous-titres désactivés au lancement de chaque vidéo, chaîne ou épisode. Activation manuelle dans le lecteur ; conservation du choix manuel lors d'une reconnexion au même contenu.
- Retour ferme panneaux, informations et commandes avant de quitter la chaîne. Focus des catégories plus visible ; haut/bas change de chaîne et gauche/droite parcourt les commandes.
- Menu ouvre les commandes lorsqu'elles sont masquées, puis affiche/masque les informations du flux. Les informations montrent moteur, codecs, décodeurs et réception de la première image, sans URL ni identifiants.
- Récupération bornée de certains manifestes HLS/DASH sans extension, après une erreur d'identification du conteneur. Aucun sondage réseau supplémentaire ni changement automatique de moteur.
- Direct HLS/DASH à sa position de diffusion par défaut ; reprise VOD, vitesse, pistes audio, sous-titres externes et navigation entre épisodes conservés.

## Vérifications

- Compilation TV Release réussie et signée avec le certificat de production existant.
- Package `app.nova.iptv.tv`, version `0.9.2+31`, API minimum 24, cible 36, ARM32/ARM64/x86_64 et alignement ZIP 16 KiB vérifiés par le packager.
- Tests courts exécutés pendant les corrections : passerelle native, événements tardifs, profils/favoris/reprises, navigation et focus, Menu/Retour, diagnostics et sous-titres. Les deux derniers tests ciblés vérifient le lancement sans sous-titres et la conservation d'un choix manuel lors d'une reconnexion.
- Analyses ciblées sans erreur. Pas de relance systématique de la suite complète ni d'émulateur.
- Installation par-dessus la version existante sur la Fire TV AFTKRT du propriétaire, sans effacement des données ; Android confirme la version `0.9.2`, code `31`, puis l'application est ouverte.

## Installation et limites

Installer l'APK **NOVA-IPTV-TV-0.9.2-universal.apk** par-dessus la version TV existante, sans désinstaller, pour conserver sources, profils, favoris et reprises. Le package téléphone est distinct.

Les vérifications ci-dessus ne constituent pas une validation prolongée de chaque flux ni de tous les modèles de TV. Les codecs audio/vidéo dépendent des décodeurs de l'appareil ; certains formats audio avancés peuvent ne pas être pris en charge. La récupération de manifestes reste limitée aux formats effectivement reconnus.
