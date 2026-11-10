# NOVA IPTV 0.4.0 — Vérifications du 9 novembre 2026

## Contrôles exécutés

| Contrôle | Résultat |
| --- | --- |
| `flutter analyze --no-pub` | Aucun signalement |
| `flutter test --no-pub --reporter expanded` | 99 tests réussis |
| `flutter build windows --release --no-pub` | Release Windows x64, version `0.4.0+6` |
| `scripts/smoke-launch.ps1` | Fenêtre stable, fermeture normale avec code 0 |
| `scripts/smoke-fullscreen.ps1` | F11 sans bordures depuis fenêtre normale/maximisée, restauration par F11/Échap, fermeture avec code 0 |

## Plateformes

L'onglet est placé après Films et Séries dans la navigation. Neuf logos PNG sont embarqués localement, avec leurs références et licence dans `assets/platforms/README.md` et `THIRD_PARTY_NOTICES.md`. Aucun CDN n'est appelé lors de l'affichage des cartes.

Le classement automatique reconnaît les noms explicites dans les catégories des sources : Netflix, Amazon Prime / Prime Video, Disney+, Apple TV+, HBO / Max, Paramount+, Crunchyroll, Hulu et Peacock. Les signes « + », séparateurs et catégories mentionnant plusieurs plateformes sont couverts. Les titres ou synopsis de films ne servent pas à attribuer une plateforme. Les contenus sans correspondance restent consultables dans « À identifier ».

Un dialogue permet d'associer ou de retirer des catégories de films/séries. Ces choix complètent ou remplacent le classement automatique et sont enregistrés dans les préférences. Le rétablissement automatique d'une plateforme conserve les associations manuelles des autres plateformes. Les mises à jour sont regroupées en une seule modification, et la liste du dialogue est construite à la demande.

Les tests d'interface cliquent sur les cartes, affichent les catalogues correspondants, utilisent la recherche et les filtres Films/Séries, associent un groupe sans marque et retirent un groupe détecté automatiquement. Ils vérifient que le filtrage des langues continue de masquer les contenus concernés. Les cartes et le dialogue sont aussi montés à 1000 × 680 ; la navigation reste accessible à 1200 × 680 grâce à des lignes plus compactes.

Ce catalogue correspond exclusivement aux contenus importés par l'utilisateur. Il ne constitue pas une recherche sur les services de streaming et ne promet pas une identification lorsque la source ne fournit aucune catégorie pertinente. L'association manuelle permet de préciser ces cas.

## Reprise et menu contextuel

Une rangée « Reprendre » précède « À l'affiche » sur l'accueil lorsqu'il existe des lectures inachevées. Elle utilise la même sélection que l'onglet « Continuer à regarder », du plus récent au plus ancien, sans être limitée aux vingt identifiants récents. Les règles de visibilité existantes s'appliquent aux deux vues.

Une série est représentée une fois. Sa progression provient de l'épisode inachevé le plus récemment regardé, même si un autre épisode a ensuite été marqué comme terminé. Les lectures achevées et les chaînes en direct sont exclues de la reprise.

Le clic droit sur une affiche en cours ouvre « Supprimer de Continuer à regarder ». Un menu à trois points propose la même action. Le retrait masque le contenu dans les deux vues et persiste après rechargement ; il conserve les favoris et la progression du film ou des épisodes. La notification permet d'annuler. Une nouvelle progression enregistrée réaffiche le film ou la série.

Les tests couvrent l'ordre des sections et des lectures, le clic droit réel avec bouton secondaire, le retrait depuis l'accueil et depuis l'onglet, l'annulation, la sauvegarde/relecture des préférences, la conservation des favoris/progressions et le retour d'une série lors d'une nouvelle lecture.

## Livraison et limites

Les essais du catalogue utilisent des données originales de démonstration ou des fixtures en mémoire, sans accéder aux comptes ou fournisseurs personnels. Les vérifications Windows ouvrent uniquement leur propre instance et la ferment normalement. Aucun test ne lance une lecture personnelle.

Les données utilisateur gardent leur emplacement et leurs champs existants. Les nouveaux champs `platformPreferences` et `dismissedResumeIds` sont optionnels lors du chargement des anciennes préférences. Le mode développeur Windows a été rétabli à son état initial après compilation : propriété temporaire absente et fichier de restauration supprimé.

Les limites du moteur et des sous-titres documentées pour les versions précédentes restent applicables. Aucun service de catalogue externe, compte Netflix ou API de métadonnées n'a été ajouté.
