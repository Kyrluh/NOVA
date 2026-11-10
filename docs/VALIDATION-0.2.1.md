# Correctif TV 0.2.1 — 9 novembre 2026

## Défaut corrigé

Le flux `Player.stream.error` de media_kit transmet aussi des messages natifs de décodage récupérables. NOVA les transformait immédiatement en écran d'erreur et ne retirait jamais cet écran lors de la reprise effective. Une chaîne pouvait donc continuer à diffuser derrière l'icône Wi-Fi et les commandes se retrouver désactivées.

La politique `PlaybackHealth` observe désormais la progression du temps de lecture. Les diagnostics seuls ne produisent pas d'alerte immédiate ; le premier chargement dispose de 25 secondes pour démarrer, et un diagnostic après démarrage nécessite huit secondes sans progression pour confirmer un échec. Les messages répétés ne repoussent pas indéfiniment ces délais. Une reprise du compteur efface l'erreur automatiquement. Les pauses volontaires suspendent les délais ; changement de chaîne et fermeture annulent les anciens timers.

Le drapeau natif `playing=true`, émis avant un démarrage réussi, ne suffit pas à prouver la lecture. Les erreurs explicites des appels d'ouverture restent signalées. L'icône est maintenant une erreur de lecture générique, sans déduire une panne Wi-Fi. Les flux en direct sont ouverts sans position de départ, afin de ne pas demander une recherche à zéro sur un flux non navigable.

## Vérifications exécutées

- `flutter analyze --no-pub` : aucun signalement.
- `flutter test --no-pub --reporter expanded` : **52 tests réussis**, dont dix nouveaux tests de diagnostics récupérables, panne confirmée, reprise, pause, changement de chaîne, remise à zéro des timestamps et libération des ressources.
- `flutter test tool/live_error_smoke_test.dart --no-pub --reporter expanded` : **un test natif réussi** avec vrai libmpv et serveur HTTP local.

Le test natif sert un WAV silencieux original de 20 secondes. Il injecte un diagnostic récupérable dans le vrai flux `Player.stream.error` : après 1 359 ms d'observation, la lecture a avancé de 1 370 ms sans passer en erreur. Une véritable réponse HTTP 404 est ensuite détectée après 3 064 ms, avec un délai de démarrage réduit à trois secondes pour le test. Enfin, une URL valide reprend sans réinitialiser l'observateur et efface l'échec à la progression suivante, observée à 180 ms. Résultats conservés dans `.tools/live-error-smoke-results.json`.

L'injection du diagnostic est volontaire et explicitement limitée au test ; aucun message de fournisseur personnel, identifiant privé ou source de l'utilisateur n'a été lu. Le média est du PCM, donc ce contrôle ne valide pas le rendu GPU ni chaque codec IPTV.

## Compilation et livraison

La version Release x64 a été compilée avec succès. Le dossier portable `dist/NOVA-IPTV-0.2.1-windows-x64` a été lancé et fermé normalement avec code 0 par `scripts/smoke-launch.ps1`, après restauration du mode développeur. La valeur Windows `AllowDevelopmentWithoutDevLicense`, absente avant la compilation, est de nouveau absente. Les données utilisateur et les sources restent dans le même dossier de support Windows qu'en version 0.2.0.
