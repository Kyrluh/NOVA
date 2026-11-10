# NOVA IPTV Windows et Android0.6.5+13

## Comportement

Au lancement, l'application ouvre le cache puis lance une actualisation unique des catalogues de toutes les sources configurées, l'une après l'autre. L'interface reste accessible. La progression indique la source et les étapes connexion/téléchargement/classement/enregistrement. Les octets alimentent le pourcentage quand le serveur indique leur total ; sinon la barre est indéterminée pendant le téléchargement. Le pourcentage combine ces étapes et le nombre de sources ; il ne s'agit pas d'une estimation de temps restant.

Le succès est indiqué brièvement puis le bandeau disparaît. En cas de source indisponible, un résultat non bloquant reste affiché, son cache est conservé et les autres sources continuent. Les favoris et progressions restent associés aux identifiants existants. Les actualisations concurrentes de la même source sont évitées et les annulations/commits transactionnels existants restent utilisés. Aucun service Android permanent n'est ajouté. Il n'y a pas de rafraîchissement à chaque retour au premier plan : uniquement au nouveau lancement du processus. Le guide XMLTV et les sélections publiques restent actualisés séparément.

## Vérifications limitées

**Cinq tests ciblés réussis** dans `source_startup_refresh_test.dart` : affichage du cache avant la fin du réseau, une seule actualisation par lancement, conservation favoris/progression, échec d'une source sans arrêter la suivante, barre responsive320/1000 et mode indéterminé, progression du vrai import M3U à partir des octets avec/sans Content-Length. Analyse statique des fichiers modifiés ; les remarques de style sur des accolades ont été corrigées. La suite complète et l'émulateur n'ont pas été relancés.

Compilation Release Android ARM64/universelle avec signature de production conservée, package `app.nova.iptv`, code13 ; compilation Release Windows x64. Installer l'APK par-dessus la version précédente sans désinstallation. Sur Windows, extraire tout le dossier portable et lancer son exécutable après fermeture de l'ancienne version. Les sources personnelles n'ont pas servi aux tests ciblés. La qualité de la connexion du fournisseur reste à vérifier avec le catalogue de l'utilisateur.

Le mode développeur Windows n'a pas été activé et les clés privées restent exclues des archives de sources.
