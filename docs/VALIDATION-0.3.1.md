# NOVA IPTV 0.3.1 — Vérification du 9 novembre 2026

## Résultats

| Contrôle exécuté | Résultat |
| --- | --- |
| `flutter analyze --no-pub` | Aucun signalement |
| `flutter test --no-pub --reporter expanded` | 90 tests réussis |
| `flutter build windows --release --no-pub` | Compilation x64 réussie |
| `scripts/smoke-fullscreen.ps1` | F11 / Échap, plein écran et restauration réussis, fermeture avec code 0 |

## Plein écran

La bascule est partagée entre le raccourci global F11 et le lecteur (F, bouton, double-clic). Le lecteur conserve son moteur, sa lecture et ses réglages pendant son agrandissement. Échap quitte le plein écran avant de fermer une lecture VOD. Les tests couvrent les cycles successifs, la priorité au lecteur agrandi, le retrait d'un lecteur, le maintien de la lecture et le traitement d'un échec natif. F11 est aussi testé avec le champ de recherche focalisé.

Le passage natif sauvegarde le placement et les styles Win32, enlève la légende et les bordures, puis applique le rectangle du moniteur courant. Il restaure ensuite le placement initial, y compris son état maximisé. Cette voie évite le comportement de `window_manager` 0.5.2 observé lors du passage d'une fenêtre maximisée au plein écran. Les fichiers du cache des dépendances restent intacts.

Le contrôle natif lance uniquement son propre processus, envoie F11 à sa vue Flutter et mesure les styles, le rectangle de fenêtre et celui de la zone cliente. Il vérifie que les deux surfaces remplissent le moniteur, sans légende ni bordures. Il mesure ensuite le retour aux coordonnées initiales, répète le passage depuis une fenêtre maximisée et vérifie qu'Échap rétablit la maximisation. Le processus de test se ferme avec le code 0. Les autres instances ne sont pas manipulées. Aucun flux fournisseur n'est ouvert.

Références Win32 : [GetWindowPlacement](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getwindowplacement), [SetWindowLongPtrW](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setwindowlongptrw), [SetWindowPos](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setwindowpos).

## ATH et souris

Le titre, les informations et la barre de progression/commandes partagent un état de visibilité. Une minuterie de trois secondes est relancée par les mouvements du pointeur et les interactions clavier/tactiles. La sortie du pointeur et la perte de focus Windows les masquent. Le retour du focus seul ne réaffiche pas l'ATH lorsque la souris est restée ailleurs. Les commandes invisibles ignorent les clics et sont retirées de la sémantique. Le curseur est masqué au repos au-dessus de l'image.

Les menus épinglent temporairement la visibilité ; la fermeture ou l'annulation relance le délai. La disparition de l'ATH laisse les sous-titres, la mise en mémoire tampon et les erreurs indépendants. Les tests vérifient la minuterie, le mouvement, la sortie de souris, la perte/reprise de focus, les menus et leur libération ; des tests de widgets mesurent l'opacité effective du titre et des commandes et les cycles du lecteur agrandi.

La suite utilise un moteur média simulé pour ces interactions. Le test Windows mesure les vraies bordures et positions sur l'écran disponible ; il ne reproduit pas physiquement un changement de moniteur, tous les DPI possibles ou tous les pilotes graphiques. Les validations précédentes des sous-titres et du catalogue sont conservées dans `VALIDATION-0.3.0.md` et `SUBTITLE-VALIDATION.md`.

## Livraison

Version `0.3.1+5`, dossier portable et archives sous `dist`. Le mode développeur utilisé temporairement pour compiler a été restauré à son état initial avant les contrôles du programme. Les fichiers de données utilisateur et les règles de tri existantes sont conservés.
