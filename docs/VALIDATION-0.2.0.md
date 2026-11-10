# Vérifications de NOVA IPTV 0.2.0 — 9 novembre 2026

## Tests exécutés

| Vérification | Résultat |
| --- | --- |
| `flutter analyze --no-pub` | Aucun signalement |
| `flutter test --no-pub --reporter expanded` | 42 tests réussis |
| `flutter test tool/source_smoke_test.dart --no-pub --reporter expanded` | 1 test natif complet réussi |
| `flutter build windows --release --no-pub` | Release x64 compilée |
| `scripts/smoke-launch.ps1` sur le binaire Release et le dossier portable | Fenêtre créée, processus stable, fermeture normale code 0 pour les deux |

La suite de 42 tests couvre les anciens écrans/préférences, les parseurs M3U/XMLTV, les API Xtream, les erreurs et l'annulation, le stockage SQLite et DPAPI réel, les actualisations partielles, la conservation des épisodes connus, le formulaire d'ajout, puis le parcours complet Paramètres → import → catalogue → guide → épisodes et restauration hors ligne.

## Test natif complet

`tool/source_smoke_test.dart` utilise un vrai serveur HTTP local, le vrai client IPTV, SQLite et Windows DPAPI, puis libmpv. Aucun faux repository, faux chiffrement ou compte fournisseur réel n'intervient dans ce contrôle.

Observations enregistrées dans `.tools/source-smoke-results.json` :

- Deux sources importées : M3U URL et Xtream ; quatre contenus restaurés.
- Guide XMLTV avec programme actuel/suivant, isolé pour chaque source.
- Détails film et série, saison et URL d'épisode générée avec les identifiants encodés.
- libmpv atteint réellement cette URL HTTP : média PCM original silencieux de 15 secondes, vitesse 1,5× et progression observée de 450 ms.
- Après arrêt du serveur, un nouveau contrôleur restaure les sources, catalogues, guides, favoris, progression, saisons et préférence de vitesse depuis le stockage local. La fabrique de client réseau hors ligne n'est jamais appelée.
- Le secret fictif du test n'apparaît pas en clair dans SQLite, ses journaux ou les préférences.

Ce test valide le circuit source → cache protégé → lecture HTTP → redémarrage. Il ne valide pas la surface vidéo GPU, tous les codecs, le HDR ou le comportement d'un fournisseur personnel.

## Livraison

- Dossier portable : `dist/NOVA-IPTV-0.2.0-windows-x64` ; lancement et fermeture contrôlés avec code 0, après restauration du réglage Windows.
- Archive portable et archive des sources NOVA, avec SHA-256, produites par `scripts/package.ps1`.
- SQLite et les DLL CRT requises sont incluses avec les bibliothèques du lecteur.
- Le mode développeur a été activé temporairement avec l'autorisation de l'utilisateur, puis son réglage initial restauré après compilation.

## Limites connues

Pas de fournisseur réel utilisé. Pas d'import Stalker, d'en-têtes VLC personnalisés, de regroupement automatique des séries M3U, d'actualisation programmée, de prochain épisode automatique ni d'installateur. Les guides et documents sont bornés à 64 Mo ; une grande bibliothèque représentative reste à mesurer. Le cache contient un bloc chiffré par source et est déchiffré en mémoire au démarrage ; il n'utilise pas encore d'index SQL par titre. Les posters réseau sont chargés à la demande, sans cache disque dédié.

Le détail des capacités et limites du moteur natif figure dans les notices tierces. Aucun compte, source de contenu ou télémétrie n'est livré par défaut. Le catalogue fictif sert uniquement lorsque l'utilisateur n'a encore enregistré aucune source.
