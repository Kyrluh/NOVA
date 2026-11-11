# NOVA IPTV TV 0.8.9 — Fiches, catalogues et sortie Fire TV

APK TV **0.8.9+27**. Les dernières distributions Windows et Android téléphone restent **0.8.8+26**. Le code partagé inclut des améliorations de cache, mais aucun nouveau ZIP Windows ni APK téléphone n'est annoncé pour cette livraison.

## Diagnostic réel

Sur la Fire TV AFTKRT, Android a enregistré une fermeture **ANR**, après plus de 5 secondes sans réponse à un KeyEvent. Le thread principal exécutait du code Flutter/Dart, avec une consommation CPU élevée ; la mémoire disponible ne signalait pas une condition de mémoire faible. Cette trace établit un blocage de l'interface, sans identifier à elle seule une fonction Dart précise, les adresses du binaire Release étant non symbolisées.

L'audit a identifié des charges évitables : chaque synopsis sauvegardait l'ensemble de la source de plus de 43 000 contenus ; la progression vidéo recréait en arrière-plan les listes de films/séries et provoquait leur réindexation/tri ; la normalisation des variantes recalculait plusieurs fois le même titre et créait des expressions régulières répétées.

## Corrections

- Sur Android, `writeDetails` chiffre et persiste uniquement la fiche modifiée dans une table dédiée. Les clés de fiches sont hachées ; titres, URLs, identifiants de compte et synopsis restent chiffrés. Les grandes fiches sont fragmentées et la transaction restaure la version précédente en cas d'échec. Au redémarrage, les fiches sont fusionnées avec le catalogue de base. Une actualisation complète incorpore les métadonnées conservées et retire les anciennes entrées séparées dans la même transaction.
- Le chemin Windows conserve le format et l'écriture existants. Les dépôts de test conservent un repli compatible.
- Quitter une fiche TV ou changer sa variante annule la requête de détails correspondante. Une fiche rouverte ne doit pas être annulée par l'ancienne requête.
- Les listes Films/Séries et le catalogue de la plateforme sélectionnée restent stables sur les notifications de progression. Les changements de catalogue, de tri, de préférence de plateforme ou de données Internet invalident les caches concernés.
- La recherche et les catégories filtrent une liste déjà triée. Les catégories et textes de recherche sont indexés une fois pour cette liste.
- La normalisation des variantes réutilise les expressions régulières et calcule titre/année une seule fois par identité. Les recommandations sans genre choisi et les reprises sans progression évitent des parcours inutiles.

## Couleurs vidéo

Le Stick utilisait Impeller/OpenGLES. Le [réglage officiel Flutter](https://docs.flutter.dev/perf/impeller) permet de sélectionner Skia dans le manifeste de l'APK TV. Des [artefacts de textures EGL sur certains appareils MediaTek](https://github.com/flutter/flutter/issues/187419) sont documentés, mais concernent un matériel différent et ne suffisent pas à diagnostiquer ce Stick MT8696. L'essai Skia seul n'a pas supprimé les lignes bleues/vertes signalées par le propriétaire.

Le spectacle testé utilisait le décodage HEVC matériel en 1920 × 1080 à 25 images/s. La correction retenue sélectionne ensuite **`vo=mediacodec_embed`, `hwdec=mediacodec`** sur les appareils Amazon dans l'APK TV, afin de contourner le transfert de textures du décodeur vers OpenGL. Les autres TV et téléphones conservent la configuration automatique ; le chemin direct des émulateurs existait déjà. Le [manuel mpv sur les sorties vidéo](https://mpv.io/manual/stable/#video-output-drivers) décrit les limites de cette sortie native : elle repose sur le décodage matériel et ne propose pas tous les filtres/rendus mpv. Les sous-titres texte sont affichés par Flutter.

Une capture ADB du même spectacle avec cette sortie directe montre une image normale et les sous-titres, contrairement à la capture noire de l'ancien chemin. Cela valide ce flux pendant l'essai ; cela ne garantit pas tous les codecs, les flux HDR ou tous les modèles Fire TV.

## Vérifications

Treize scénarios ciblés passent : deux tests de cache de fiches (écriture limitée à un élément, restauration et invalidation après actualisation ; grands fragments Unicode et rollback) ; compatibilité du cache Windows ; annulation/réouverture d'une fiche et déduplication des détails ; regroupement/progression/favoris et choix des variantes dans les fiches commune/TV ; réglage des colonnes sur Windows/Android/TV ; sélection du chemin vidéo selon Fire TV/émulateur/téléphone/autre TV ; conservation de la liste pendant la progression et invalidation sur changement du tri ; Retour ferme le panneau ou les contrôles puis quitte le lecteur direct.

Dans le test de 1 000 éléments, l'écriture complète demande plus de vingt opérations de chiffrement, contre une seule pour modifier un synopsis court. Ce résultat vérifie la quantité de travail évitée ; il ne constitue pas un gain de FPS mesuré sur la Fire TV. Analyse statique des fichiers modifiés sans anomalie. Pas de suite complète ni d'émulateur.

L'APK de production signée a été installée sur la Fire TV du propriétaire sans désinstallation. Lolo et le profil existant ont été conservés. Catalogue Films de 15 250 fiches visibles, synopsis d'Artus et lecture HEVC ont été essayés sur l'appareil ; la sortie vidéo directe a produit la capture décrite ci-dessus. Aucun nouvel ANR n'a été constaté pendant cet essai court. Un essai prolongé reste nécessaire : la disparition définitive de tous les blocages n'est pas démontrée.

Les traces ANR, captures, adresses ADB et données de compte restent locales et hors Git. Signature Android conservée et versionCode 27 ; seuls l'APK TV et ses empreintes sont publiés dans la release.

La commande Retour du direct utilise une requête distincte du plein écran : elle ferme les commandes visibles en priorité, puis arrête le lecteur et rend le focus à la liste lorsque seule la vidéo est affichée. Le dernier choix de chaîne reste sélectionné ; relancer une chaîne recrée le lecteur.
