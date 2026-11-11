# NOVA IPTV 0.8.6 — Repère de reprise des épisodes

Version Windows, Android téléphone et TV : **0.8.6+24**.

## Comportement

- La fiche d'une série s'ouvre sur la saison du dernier épisode regardé encore en cours, avec défilement automatique jusqu'à cet épisode et surbrillance « À reprendre ».
- Un seul épisode est désigné par cette surbrillance. Les anciennes barres de progression restent visibles sans désigner leurs épisodes comme la reprise actuelle.
- Le repère suit les nouveaux enregistrements de progression du profil actif. Terminer le dernier épisode regardé retire le repère sans réactiver un ancien épisode inachevé. Aucun épisode suivant non commencé n'est désigné arbitrairement.
- Changer manuellement de saison reste possible ; le défilement ne revient pas continuellement sur l'épisode en cours.
- Sur TV, le défilement fonctionne même pour un épisode qui n'a pas encore été construit dans une longue liste. Le bouton de reprise conserve le focus initial de la télécommande. Au retour du lecteur, la cible est recalculée et l'ancien repère est retiré.
- Les fiches Windows et Android utilisent la même logique. Le lecteur et les données utilisateur restent conservés.

## Vérifications ciblées

Trois tests de widgets passent : fiche commune et fiche TV avec une saison de 80 épisodes, reprise au 61e épisode, déplacement au 3e puis fin d'épisode sans remise en évidence d'un ancien ; sélection de la saison 2 et conservation du focus du bouton de reprise TV. Analyse statique des quatre fichiers Dart concernés sans anomalie.

Compilations Release : Windows x64 portable, Android ARM64, Android universelle et TV universelle. Les APK conservent la signature de production, avec versionCode 24. Le packaging vérifie packages, architectures, versions, signatures, alignement ZIP et empreintes SHA-256.

Pas de suite complète, d'émulateur ni de nouveau test sur appareil physique ou sur un flux fournisseur. Sur téléphone et TV, vérifier visuellement la reprise après passage à l'épisode suivant et retour à la fiche avec une source personnelle.

Installer les APK par-dessus les anciennes sans désinstaller. Pour Windows, fermer l'ancienne application et extraire le ZIP entier.
