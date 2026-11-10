# NOVA IPTV 0.5.0 — Vérifications du 9 novembre 2026

## Vérifications

| Contrôle exécuté | Résultat |
| --- | --- |
| `flutter analyze --no-pub` | Aucun signalement |
| `flutter test --no-pub --reporter expanded` | 115 tests réussis |
| `flutter test tool/public_catalog_smoke_test.dart --no-pub --reporter expanded` | 1 test réel des services publics réussi |
| `flutter build windows --release --no-pub` | Compilation x64 réussie, version `0.5.0+7` |
| `scripts/smoke-launch.ps1 -Executable dist\NOVA-IPTV-0.5.0-windows-x64\NOVA_IPTV.exe` | Fenêtre stable et fermeture normale, code 0 |

Le dossier portable, son archive ZIP et les sources sont livrés sous `dist`. Le binaire portable est identique au résultat de compilation. Le mode développeur temporaire a été restauré avant le contrôle de lancement : propriété Windows temporaire absente et fichier de restauration supprimé.

## API sans clé

La solution finale utilise uniquement des listes publiques Streaming Catalogs et Cinemeta, sans TMDB direct, clé API ou compte. Les services ont été vérifiés avant l'intégration et avec le client Dart. Le contrat lu est celui des catalogues de métadonnées du protocole Stremio, pas celui des ressources de lecture.

Le test réel a reçu les vingt sélections attendues : neuf plateformes × films/séries, plus deux listes de popularité. Le contrôleur a retenu 20 films et 20 séries pour l'accueil. Les sélections par plateforme contenaient entre 187 et 200 fiches au total, après validation et dédoublonnage. Le rapport est écrit localement dans `.tools/public-catalog-smoke-results.json` ; ces nombres décrivent l'essai et ne promettent ni une taille fixe ni un catalogue commercial complet.

La redirection HTTPS officielle de `v3-cinemeta.strem.io` vers `cinemeta-catalogs.strem.io` est prise en charge. Les destinations imprévues sont rejetées, avec au plus deux redirections. Les requêtes ont un délai global de huit secondes et sont annulables ; les réponses sont limitées à 3 Mio. Trois tâches au maximum sont utilisées pour une actualisation. La mise à jour manuelle comprend un indicateur de progression et un bouton d'arrêt ; le reste de l'application continue à fonctionner.

## Conservation des données

Chaque sélection possède son propre instantané. Un échec HTTP, un délai dépassé, un JSON invalide, une réponse vide ambiguë ou une sélection mal formée conserve les anciennes données de cette sélection. Les autres réponses valides peuvent être enregistrées. Une erreur de sauvegarde laisse les données reçues utilisables en mémoire avec une information discrète. Aucune erreur brute, URL privée ou fenêtre bloquante n'est affichée.

Le cache internet est séparé des préférences et de la base des sources. Il contient exclusivement les fiches publiques reçues et leurs dates. Le démarrage lit ce cache sans lancer de mise à jour. Les données IPTV, comptes et URL de lecture ne sont pas envoyés : les requêtes visent uniquement vingt adresses de listes fixes.

## Correspondances et accueil

La correspondance est prudente : type film/série, titre normalisé exact ou alias fourni, année compatible. Les homonymes ambigus sont ignorés. Les suggestions internet complètent les indications locales ; une association manuelle, y compris une exclusion, garde toujours la priorité. Les filtres de langue et de catégorie des sources continuent de s'appliquer.

Après une mise à jour réussie, deux rangées de tendances apparaissent sur l'accueil en conservant la reprise et les sections existantes. Les cartes distinguent les titres retrouvés dans les sources visibles des fiches de découverte. Ces dernières ne proposent pas de lecture fictive. La sélection internet de chaque plateforme reste consultable séparément des sources.

Les services fournissent des sélections partielles, avec des différences de pays et de langue. Le client ne déduit pas une indisponibilité commerciale de l'absence d'un film dans une liste de popularité. Les métadonnées peuvent être en anglais. Les affiches distantes ont un rendu de remplacement local en cas d'échec.

## Couverture

Les tests déterministes couvrent les requêtes sans authentification et sans données IPTV, le cache après redémarrage, les réponses invalides/vides, les échecs partiels, les délais, l'annulation et la reprise, les erreurs d'écriture, les redirections et les réponses trop volumineuses. Les tests d'interface cliquent sur le bouton en haut à droite, vérifient les deux rangées de tendances, la navigation en cas de panne et les fiches sans lecture. Les petites fenêtres et les catalogues vides restent défilables sans débordement.

Références : [Streaming Catalogs](https://github.com/rleroi/Stremio-Streaming-Catalogs-Addon), [Cinemeta](https://v3-cinemeta.strem.io/manifest.json), [protocole Stremio](https://github.com/Stremio/stremio-addon-sdk/blob/master/docs/protocol.md). Les validations des versions précédentes restent applicables au lecteur et aux sources.
