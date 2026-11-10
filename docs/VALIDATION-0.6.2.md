# NOVA IPTV 0.6.2+10 — Android et Windows

## Corrections

- Une playlist M3U peut maintenant produire une fiche par série avec des saisons et des épisodes, au lieu d'une affiche répétée pour chaque vidéo. Les noms S01E02, Saison 1 Episode 2, 1x02, Episode/Ep et les attributs de la playlist sont pris en compte. Les entrées déclarées séries/animés avec un titre identique sont réunies ; sans numérotation, l'ordre du fournisseur est conservé dans une seule saison.
- Le cache M3U existant est regroupé au démarrage sans appel au fournisseur ; les gros travaux sont effectués dans un isolate. Les identifiants des vidéos restent identiques pour conserver progression, historique et reprise. Les favoris et retraits de la liste de reprise sont transférés à la fiche parente. Les groupes/langues et les sources restent séparés.
- Les tendances de l'accueil et les sélections internet des plateformes affichent uniquement les correspondances à des vidéos des sources visibles. Les titres absents, les fiches sans vidéo et les correspondances ambiguës sont masqués. Les en-têtes de rangées vides disparaissent. Cela s'applique également aux anciens résultats API mis en cache.
- La correspondance reste conservatrice : titre ou alias exact après normalisation, même type, année compatible. Aucune recherche approximative entre titres différents. Les différentes qualités d'un même titre daté produisent une seule carte internet.
- Les affiches des sources restent prioritaires. Une affiche publique sert de remplacement après identification du contenu local ; un identifiant IMDb contradictoire dans l'URL de l'affiche ou une même affiche attribuée à plusieurs œuvres publiques est ignoré. Les cellules d'image sont identifiées par contenu et URL pour éviter une réutilisation visuelle incorrecte.
- Un identifiant fournisseur réattribué à une autre œuvre n'hérite plus des anciennes saisons ou de l'ancienne affiche lors d'un rafraîchissement.

## Vérifications

- `flutter analyze --no-pub` : aucune anomalie.
- `flutter test --no-pub` : **176 tests réussis**. Cas couverts : formats M3U, classement saisons/épisodes, titres répétés, attributs, films et direct conservés, migration hors ligne avec favoris/progression, navigation série/saison/épisode, API sans correspondance, titres homonymes/années, affiches publiques incohérentes et identifiants fournisseur recyclés.
- APK ARM64 et universelle Release compilées. Package `app.nova.iptv`, version `0.6.2`, code `10`, minSdk24, targetSdk36. Même certificat de production que 0.6.0/0.6.1. Vérifications de signature, architectures et alignement ZIP16KiB effectuées par `scripts/package-android.ps1`.
- Mise à jour réelle de 0.6.1 vers 0.6.2 sur l'émulateur local Pixel Fold API35, sans désinstallation. Une source de validation locale a été actualisée avec trois vidéos originales réparties sur deux saisons : une seule carte de série dans le catalogue, deux épisodes en saison1, un en saison2. Le changement de saison et la lecture réelle ont été vérifiés. Les boutons précédent et suivant passent bien de S02E01 à S01E02 puis de S01E02 à S02E01, en retrouvant la progression déjà enregistrée. Captures conservées dans `validation/0.6.2`.
- Windows x64 Release compilée ; la fenêtre s'ouvre et se ferme normalement avec un code de sortie0 (`scripts/smoke-launch.ps1`). La logique M3U/API est partagée avec Android.

Les sources et identifiants personnels n'ont pas été utilisés pour ces essais. Les noms non structurés ne permettent pas de deviner des saisons absentes de la playlist. Les tests de cette livraison ne remplacent pas un essai du catalogue réel et du décodage matériel sur le Samsung physique. Les précédentes validations vidéo/pliage sont documentées dans les rapports0.6.0 et0.6.1 ; elles n'ont pas toutes été répétées pour ce correctif de catalogue.

Après réception d'un exemple exact de nom, un test supplémentaire confirme `From S01 E08` : une fiche `From`, saison1, épisode8. Les noms espacés et non espacés se regroupent ensemble et les épisodes7,8,9,10 restent dans l'ordre numérique. Les dix tests M3U passent ; le code déjà livré dans les APK0.6.2 reconnaissait ce format et n'a pas nécessité de modification.

## Installation

Installer l'APK0.6.2 par-dessus la version existante, sans désinstaller. Sur Windows, extraire tout le dossier portable et ouvrir `NOVA_IPTV.exe` après avoir fermé l'ancienne version. Les sources et préférences restent dans leur stockage habituel. Le regroupement du cache M3U s'applique au redémarrage ; actualiser la source permet aussi de relire ses attributs complets.

La signature reste dans `.signing`, exclue de Git et de l'archive de sources. Le mode développeur Windows est resté désactivé : les liens Flutter existants ont suffi aux compilations.
