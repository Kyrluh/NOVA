# Phases et critères de livraison

État au 9 novembre 2026 : phases 1 et 2 livrées dans la version 0.2.0. Le lecteur de fichiers/URL, les flux importés, la vitesse, les favoris, la progression et le guide XMLTV sont déjà intégrés. Voir `VALIDATION-0.2.0.md` pour la preuve des vérifications ; les paragraphes ci-dessous conservent les objectifs de chaque phase, dont certaines optimisations restent à terminer.

Ce document fixe les limites de chaque phase et les validations attendues. Il ne constitue pas un journal de tests : seules les commandes réellement exécutées et leurs résultats, consignés lors de la livraison, peuvent établir qu'une validation a réussi.

## Phase 1 — application native et interface

Livrables : projet Flutter Windows, thème sombre, accent personnalisable, menu latéral réductible et navigation Accueil, TV en direct, Films, Séries, Favoris, Continuer à regarder, Recherche et Paramètres. Le catalogue de démonstration utilise des données fictives et des illustrations originales hors ligne.

L'interface doit permettre de parcourir les catalogues, filtrer/rechercher des éléments, consulter leurs fiches et gérer des favoris réels. Les réglages et données locales non sensibles sont conservés dans un fichier JSON, derrière l'abstraction `LocalStore`.

La préférence de vitesse propose une plage de 0,25× à 3×. Si un lecteur est livré en avance sur la phase 3, ses commandes doivent agir sur le moteur réel ; l'ouverture de fichiers personnels et le réglage de vitesse doivent être vérifiés séparément.

Validations attendues : analyse statique sans erreur, tests du domaine et de la persistance, tests de navigation et d'affichage si disponibles, compilation Windows puis lancement du binaire. Vérifier le comportement lorsque le stockage est indisponible ou corrompu. Un succès des tests de widgets ne prouve ni la lecture vidéo, ni le décodage matériel, ni une compilation Windows réussie.

Limites de la phase : aucun catalogue réel n'est fourni ; les chaînes fictives ne sont pas des chaînes en direct. L'EPG, Xtream, M3U et XMLTV restent dans les phases suivantes. Aucun bouton ne doit faire croire à une fonctionnalité absente.

## Phase 2 — sources et stockage de catalogue

Ajouter plusieurs sources personnelles Xtream Codes, l'import M3U local/distant, les catégories et les catalogues TV/films/séries. Installer SQLite pour le catalogue local, les requêtes paginées et la migration des données de la première phase.

Protéger les secrets par un mécanisme Windows adapté. Tester authentification invalide, délai dépassé, JSON/M3U incomplet, déconnexion pendant l'actualisation et changement rapide de source. Les tests réels nécessitent des sources que l'utilisateur est autorisé à consulter ; aucune source privée n'est intégrée par défaut.

## Phase 3 — moteur vidéo

Finaliser libmpv : lecture des médias distants, TV en direct, films et épisodes, plein écran, volume, muet, recherche temporelle VOD, audio et sous-titres, ratio et informations techniques disponibles. La vitesse VOD est reliée à `Player.setRate`, avec valeur normale de 1× pour le direct sans différé.

Tester la libération du moteur, l'ouverture successive des médias et les erreurs réseau. Utiliser des fichiers autorisés représentatifs pour H.264, HEVC, HLS, MPEG-TS, MKV, plusieurs pistes et sous-titres. Ne pas déduire la prise en charge effective d'un format de la seule présence de libmpv.

## Phase 4 — suivi et guide

Ajouter XMLTV et programme actuel/suivant, historique réel, reprise précise et progression par épisode. Compléter les saisons, le prochain épisode avec option de désactivation et la recherche sur l'ensemble des sources. Les métadonnées externes restent facultatives et respectent les conditions de leurs API.

Tester séparément changement d'heure, fuseaux du guide, identifiants sans correspondance, fichier XML partiel, reprise après redémarrage et lecture du dernier épisode d'une saison.

## Phase 5 — charge, stabilité et capacités matérielles

Mesurer mémoire, CPU, temps de démarrage et réactivité sur une grande bibliothèque. Ajouter cache d'images, concurrence réseau bornée, annulation des chargements, reconnexion configurable et diagnostics expurgés.

Étudier D3D11VA et le chemin HDR Windows. Le HDR nécessite la validation du pipeline natif, des formats, de Windows, du pilote et d'un écran compatible. En attendant cette validation, ne pas afficher une option « HDR actif » ou promettre le passthrough.

## Phase 6 — distribution Windows

Produire un build Release x64, une archive portable et, si retenu, un installateur. Vérifier un lancement en dehors du dossier de développement, la présence des DLL nécessaires, la conservation des données à la mise à jour et la désinstallation.

Livrer le journal des commandes de validation exécutées, les limites connues, les crédits/licences des dépendances natives et les éléments de source nécessaires à leur redistribution. La réussite d'une compilation ne remplace pas le test de lancement de l'exécutable empaqueté.
