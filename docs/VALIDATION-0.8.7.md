# NOVA IPTV 0.8.7 — Télécommande et déplacements VOD

Version Windows, Android téléphone et TV : **0.8.7+25**.

## Changements TV

- Les recherches du direct, des catalogues (films, séries, favoris, historique, reprise, plateformes, recherche globale) et du tri de catégories utilisent le même éditeur natif que les sources, avec ouverture sur OK uniquement. Les flèches restent des commandes de navigation, sans champ éditable Flutter actif. Le clavier de recherche intercepte Retour pour rendre la main au formulaire et conserve le texte ; Annuler conserve la recherche précédente. Les champs de sources conservent leur logique de validation/annulation.
- Haut/bas zappe dans le lecteur du direct. Gauche/droite accède aux boutons et navigue entre eux. La barre du direct comporte réactualisation, pause/lecture, rapport d'image et plein écran ; audio et sous-titres restent disponibles en VOD.
- OK en plein écran direct quand les commandes sont masquées ouvre le panneau de chaînes à gauche, sans quitter le plein écran. Les catégories sont en haut : gauche/droite change de catégorie et haut/bas parcourt les chaînes. OK choisit la chaîne et ferme le panneau. Retour ferme le panneau sans quitter le plein écran. Le panneau utilise les chaînes visibles du profil, dans l'ordre du catalogue.
- Le focus revient à l'image lorsque les commandes disparaissent, afin que le prochain OK ouvre le panneau. Les contrôles/panneau reçoivent explicitement le focus lorsqu'ils apparaissent.

## Déplacements et synchronisation

La file de déplacement est partagée entre Windows, Android téléphone et TV. Elle regroupe les sollicitations rapprochées et n'envoie qu'un déplacement natif à la fois. Les répétitions partent de la cible en cours plutôt que d'une ancienne position du moteur. Maintenir gauche/droite sur l'image VOD ou les touches avance/retour rapide accélère après six répétitions (pas de 30 s), puis dix-huit (60 s) ; relâcher applique la dernière cible. Aucune commande temporelle n'est envoyée au direct.

Sur Android VOD, `video-sync=audio`, `framedrop=vo` et `hr-seek-framedrop=yes` permettent de rattraper le retard vidéo après un déplacement. media_kit 1.2.6 désactive par défaut le dernier réglage. Le [manuel officiel mpv](https://mpv.io/manual/stable/) décrit la synchronisation sur l'audio et l'abandon des images précédant la cible lors d'une recherche précise. Aucun décalage audio arbitraire n'est appliqué. Un réglage optionnel non pris en charge ne bloque pas la lecture.

Ces changements traitent l'accumulation de commandes et le rattrapage vidéo ; ils ne démontrent pas la disparition du décalage constaté sur le téléviseur. Un essai avec le même épisode, le même point de déplacement et le même matériel audio reste nécessaire.

## Vérification ciblée

Sept scénarios de widgets passent : recherche ouverte uniquement sur OK et navigation après retour/validation ; file native occupée et annulation des demandes en attente ; lecture/pause TV et navigation dans les options sans déplacement ; zapping haut/bas et recadrage depuis les boutons ; appuis répétés avant/arrière avec accélération et regroupement ; panneau en plein écran, catégories/chaînes et fermeture sans sortie ; contrôles sur petite surface et conservation de la session plein écran. Analyse statique des fichiers concernés sans anomalie.

Compilations Release Windows x64, Android ARM64, Android universelle et TV universelle. Les APK gardent la signature de production et passent au versionCode 25 ; le packaging vérifie packages, architectures, versions, signatures et alignement ZIP. Les installables sont accompagnés des empreintes SHA-256 dans la release GitHub.

Pas de suite complète ni d'émulateur. Les tests utilisent un moteur et un pont clavier simulés ; le clavier Fire OS réel et la synchronisation audio après déplacement restent à confirmer sur appareil physique. Installer les APK par-dessus les précédentes sans désinstaller. Sur Windows, fermer l'ancienne application et extraire le ZIP entier.
