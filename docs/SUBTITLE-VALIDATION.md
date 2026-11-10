# Vérification des sous-titres

Commande depuis la racine du projet, après compilation Windows Release :

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\flutter.ps1 test tool/subtitle_smoke_test.dart --reporter expanded --no-pub
```

Deux tests passent sous Windows avec la DLL `libmpv-2.dll` du build NOVA.
Le détail daté de la dernière exécution est enregistré dans
`.tools/subtitle-smoke-results.json`.

Le premier test utilise le vrai moteur natif. Il génère lui-même un fichier
Matroska de douze secondes : vidéo BGR 64 × 36, silence PCM, pistes françaises
et anglaises UTF-8, et un fichier SRT externe original. Aucun abonnement,
serveur IPTV, contenu téléchargé ni outil de multiplexage externe n'est requis.

Il vérifie les données décodées, pas seulement l'identifiant de la piste :

- la vidéo est décodée avec les dimensions attendues ;
- le premier texte français accentué arrive après son horodatage ;
- le choix anglais produit réellement le texte anglais et retire le français ;
- la désactivation reste effective pendant une réplique ;
- une seconde réplique française et un intervalle sans texte sont respectés ;
- un SRT externe UTF-8 produit son texte dans `player.stream.subtitle` ainsi
  que dans la propriété native `sub-text` ;
- la propriété native `brightness` accepte et restitue `10`, `-10`, puis `0`.

Le second test monte le vrai widget `Video` avec `NoVideoControls`. Il vérifie
que `SubtitleView` reste présent, affiche les textes FR puis EN et les efface
quand le flux devient vide. Son contrôleur de texture est simulé et son flux
texte est injecté : ce test couvre l'affichage Flutter, séparément du décodage
natif prouvé par le premier test.

## Limites

Le lecteur conserve `PlayerConfiguration.libass: false`, donc l'affichage
Flutter des sous-titres texte. `NoVideoControls` supprime seulement les commandes
intégrées du paquet ; le widget des sous-titres en est indépendant. Les sous-titres
bitmap DVD/PGS/DVB ne sont pas pris en charge par le rendu textuel actuel ; ils
sont signalés dans le menu et leurs pistes ne sont pas proposées à la sélection.
Les pistes texte et le chargement d'un fichier SRT restent accessibles. Les
styles avancés ASS, une source fournisseur particulière et le rendu GPU dans
une fenêtre Windows ne sont pas validés par ces tests.
La lecture native utilise `vo: null` ; la propriété de luminosité est vérifiée
par relecture API, sans mesure des pixels.

Une source doit effectivement contenir une piste exploitable, ou l'utilisateur
doit charger un fichier externe. La présence d'un bouton n'implique pas qu'une
chaîne en direct fournisse des sous-titres.

## Références primaires

- [API officielle media_kit et sélection des pistes](https://github.com/media-kit/media-kit/blob/main/README.md).
- [Code du widget Video et overlay SubtitleView](https://github.com/media-kit/media-kit/blob/main/media_kit_video/lib/src/video/video_texture.dart).
- [Implémentation Flutter de SubtitleView](https://github.com/media-kit/media-kit/blob/main/media_kit_video/lib/src/subtitle/subtitle_view.dart).
- [Spécification des éléments Matroska](https://www.matroska.org/technical/elements.html)
  et [correspondance des codecs](https://www.matroska.org/technical/codec_specs.html),
  utilisées pour générer les médias de test originaux.
- [Documentation mpv : sous-titres et formats bitmap](https://mpv.io/manual/master/#subtitles).

Le comportement a aussi été vérifié dans les sources des versions réellement
installées : `media_kit 1.2.6` et `media_kit_video 2.0.1`.
