# Vérifications de NOVA IPTV 0.3.0 — 9 novembre 2026

## Résultats exécutés

| Commande / contrôle | Résultat |
| --- | --- |
| `flutter analyze --no-pub` | Aucun signalement |
| `flutter test --no-pub --reporter expanded` | **80 tests réussis** |
| `flutter test tool/subtitle_smoke_test.dart --no-pub --reporter expanded` | **2 tests réussis**, dont décodage natif et affichage Flutter séparés |

La suite couvre notamment les sources et la reprise existantes, les erreurs récupérables TV, les règles de tri indépendantes, la sauvegarde des règles et des favoris/progressions masqués, les interactions du lecteur, les clics sans attente, la molette et les commandes de luminosité. Les grandes listes de catégories ont été vérifiées avec 2 000 catégories et les fenêtres 1000×680 / 1200×680.

## Réactivité des commandes

Le double-clic du plein écran englobait les boutons, retardant leurs actions d'environ 300 ms. Il est désormais détecté uniquement sur l'image, derrière les commandes. Les menus n'ont plus d'animation d'ouverture et les infobulles ont un délai réduit.

Les tests tapent les boutons puis effectuent une frame sans avancer de délai artificiel : le menu vitesse apparaît et applique sa valeur. Les sous-titres, la luminosité et la remise à zéro sont également actionnables immédiatement. Un test de molette vérifie l'augmentation/diminution, les rafales et l'absence de défilement de la page parent. Le contrôleur de commandes regroupe les requêtes successives et ignore les anciens retours natifs pendant une modification en cours.

## Sous-titres et luminosité

Le test natif génère un MKV original : vidéo BGR 64×36, silence PCM et deux pistes UTF-8 FR/EN. Il vérifie le texte décodé aux bons instants, le changement de langue, la désactivation, une réplique suivante, un intervalle vide et un SRT externe accentué. La propriété native `brightness` est réglée puis relue à 10, -10 et 0.

Le test Flutter monte le vrai widget `Video` avec une texture simulée, confirme que `NoVideoControls` conserve les sous-titres, puis vérifie les textes affichés et leur disparition. Les tests des interactions montent aussi `NovaPlayer` avec un backend de test et vérifient la lisibilité du texte, son placement au-dessus des boutons et le signalement des pistes bitmap non prises en charge.

Le décodage natif et le rendu Flutter sont donc vérifiés séparément. Les pixels GPU dans une fenêtre Windows ne sont pas mesurés ; les styles ASS avancés ne sont pas validés. Les sous-titres images DVD/PGS/DVB ne sont pas pris en charge par le rendu texte actuel et sont désactivés dans le menu. Voir `SUBTITLE-VALIDATION.md` et `.tools/subtitle-smoke-results.json`.

## Tri et conservation des données

La visibilité et l'ordre sont configurables indépendamment pour TV, films et séries. Les langues sont déduites prudemment des groupes et préfixes explicites, avec correction manuelle par catégorie. Le filtrage ne remplace pas le catalogue brut : l'index des identifiants, les favoris et la progression utilisent toujours l'ensemble des contenus. Les tests vérifient qu'un contenu masqué conserve ces données après sauvegarde et rechargement.

L'ordre personnalisé des catégories est testé par vrai glisser-déposer puis vérification des boutons TV et films. Les catégories restent regroupées par leur nom dans les vues existantes. Le tri est sauvegardé localement, sans modification des identifiants IPTV ou de la base des sources.

## Livraison Windows

La compilation Release x64 a réussi. Le dossier `dist/NOVA-IPTV-0.3.0-windows-x64` a été lancé avec `scripts/smoke-launch.ps1` : fenêtre créée, processus stable et fermeture normale avec code 0. Ce contrôle a été exécuté après restauration du réglage temporaire du mode développeur à son état initial. Aucun fournisseur personnel n'a été utilisé dans les fixtures de test.
