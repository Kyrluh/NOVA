# NOVA IPTV

Lecteur IPTV natif pour **Windows et Android**, développé avec Flutter et libmpv. NOVA réunit la TV en direct, les films, les séries et la reprise de lecture dans une interface sombre adaptée à la souris comme au tactile.

**Android : 0.6.6+14** · **Windows x64 : 0.6.5+13** · **Android 7.0/API 24 minimum** · **GPL-3.0-or-later**

Le correctif **Android 0.6.6** améliore la saisie des sources à la télécommande : actions Suivant/Valider du clavier, navigation haut/bas entre les champs et sélection du bouton Ajouter. [Rapport du correctif](docs/ANDROID-VALIDATION-0.6.6.md).

NOVA lit les sources personnelles configurées par l'utilisateur. Aucun abonnement, compte IPTV, chaîne commerciale ou playlist n'est fourni. Il n'y a ni publicité, ni compte NOVA, ni télémétrie applicative.

![Accueil Windows — catalogue fictif de démonstration](docs/preview.png)

## Fonctionnalités

| Domaine | Prise en charge |
| --- | --- |
| Sources | M3U/M3U8 par URL ou fichier, Xtream Codes, plusieurs sources |
| TV | Direct, catégories, favoris, recherche et guide XMLTV |
| Films et séries | Fiches, saisons, épisodes, progression individuelle, épisodes précédent/suivant |
| Séries M3U | Regroupement par série et saison, y compris les noms comme `From S01 E08` |
| Bibliothèque | Accueil, recherche globale, historique, favoris et reprise de lecture |
| Tri | Ordre de la source, titres, années, catégories personnalisées, langues et groupes masquables |
| Plateformes | Classement local, associations manuelles et sélections publiques facultatives sans clé API |
| Actualisation | Mise à jour des sources au lancement, barre d'avancement et cache conservé en cas d'échec |
| Vidéo | Lecture/pause centrale, volume, luminosité, vitesse VOD, audio, sous-titres texte, format et plein écran |
| Windows | Raccourcis clavier, touches multimédias, molette pour le volume, plein écran sans bordures |
| Android | Navigation compacte/tablette, pliables, gestes configurables, Picture-in-Picture si disponible |

## Installer et mettre à jour

Les installables sont disponibles dans les releases [**Android 0.6.6**](https://github.com/Kyrluh/NOVA/releases/tag/v0.6.6) et [**Windows 0.6.5**](https://github.com/Kyrluh/NOVA/releases/tag/v0.6.5). Le dépôt Git contient le **code source et la documentation** ; les binaires sont distribués séparément dans les releases. Les clés privées et les outils locaux restent hors Git.

| Plateforme | Téléchargement |
| --- | --- |
| Windows x64 portable | [ZIP Windows](https://github.com/Kyrluh/NOVA/releases/download/v0.6.5/NOVA-IPTV-0.6.5-windows-x64.zip) |
| Android ARM64, notamment Galaxy Z Fold | [APK ARM64](https://github.com/Kyrluh/NOVA/releases/download/v0.6.6/NOVA-IPTV-0.6.6-arm64-v8a.apk) |
| Android universelle : ARM64, ARM32, x86_64 | [APK universelle](https://github.com/Kyrluh/NOVA/releases/download/v0.6.6/NOVA-IPTV-0.6.6-universal.apk) |

Les empreintes SHA-256 sont disponibles pour [Windows 0.6.5](https://github.com/Kyrluh/NOVA/releases/download/v0.6.5/SHA256SUMS.txt) et [Android 0.6.6](https://github.com/Kyrluh/NOVA/releases/download/v0.6.6/SHA256SUMS.txt). Les commandes de [compilation](#compiler-le-projet) produisent les installables de la version du code local dans `dist/` et `dist/android/`.

### Windows

1. Extraire **tout** le ZIP dans un dossier accessible en écriture.
2. Conserver `data` et toutes les DLL à côté de `NOVA_IPTV.exe`.
3. Lancer `NOVA_IPTV.exe`.

Flutter, Visual Studio et le mode développeur ne sont pas nécessaires pour utiliser le programme compilé. Pour une mise à jour, fermer l'ancienne version puis ouvrir celle du nouveau dossier portable. Les données utilisateur restent dans le même emplacement de support Windows.

### Android

1. Copier l'APK adaptée au téléphone et l'ouvrir depuis le gestionnaire de fichiers.
2. Autoriser ce gestionnaire à installer l'APK lorsque Android le demande.
3. Ouvrir NOVA et ajouter ses sources.

Pour mettre à jour, **installer par-dessus la version précédente, sans désinstaller**. La nouvelle APK doit conserver le package `app.nova.iptv` et la même signature. Les variantes ARM64 et universelle partagent la même signature et le même code de version.

Les comptes chiffrés Windows ne sont pas transférés automatiquement sur Android : renseigner les sources sur chaque appareil. Voir [l'installation Android et la sauvegarde de la signature](docs/ANDROID-INSTALLATION.md).

## Ajouter une source

1. Ouvrir **Paramètres → Gérer les sources → Ajouter une source**. Sur Android compact : **Plus → Paramètres**.
2. Choisir **Playlist M3U · URL**, **Playlist M3U · Fichier local** ou **Xtream Codes**.
3. Donner un nom à la source et renseigner son adresse. Pour Xtream, ajouter les identifiants du fournisseur.
4. Ajouter une URL XMLTV dans la partie guide TV si nécessaire.
5. Choisir **Ajouter** pour importer et enregistrer. **Tester la connexion** vérifie l'accès sans sauvegarder la source.

Le premier import remplace la démonstration par la bibliothèque personnelle. Les sources peuvent ensuite être modifiées, actualisées ou supprimées depuis leur fiche.

### Séries M3U

Les noms comme `From S01 E08`, `S01E08`, `1x08` ou `Saison 1 Episode 8`, ainsi que les attributs de la playlist, permettent le parcours **série → saison → épisode**. Les entrées déclarées séries/animés avec un titre identique sont réunies ; sans numérotation fournie, l'ordre de la playlist est conservé dans une seule saison.

NOVA ne peut pas déduire des saisons absentes des noms et métadonnées. Les langues, catégories et sources distinctes restent séparées. Le regroupement du cache existant conserve les identifiants des vidéos pour retrouver progressions et favoris.

## Actualisation au démarrage

À chaque **nouveau lancement de l'application**, NOVA :

1. Ouvre le catalogue enregistré pour permettre de naviguer avant la fin du réseau.
2. Actualise les sources configurées, l'une après l'autre.
3. Affiche la source et les étapes **connexion → téléchargement → classement → enregistrement**.

La barre tient compte des octets reçus lorsque le serveur annonce leur total, puis des étapes de traitement et du nombre de sources. Quand la taille est inconnue, elle reste animée pendant la réception. Le pourcentage ne représente pas un temps restant.

En cas d'échec, le dernier catalogue valide reste disponible et les autres sources continuent. Un résultat non bloquant indique les sources indisponibles. L'actualisation manuelle reste accessible via **Gérer les sources → Actualiser**.

Le guide **XMLTV** et les sélections **internet des plateformes/tendances** gardent leurs boutons dédiés. Le simple retour d'Android au premier plan ne relance pas tous les imports.

## Lecteur et commandes

Le moteur est **libmpv**, intégré via `media_kit` et `media_kit_video`. La compatibilité dépend du codec, du flux, du matériel et de la construction native du moteur.

- **Lecture/pause** au centre de l'image lorsque l'ATH est affiché, et dans la barre inférieure.
- **Vitesse VOD de 0,25× à 3×**, également réglable par défaut dans les paramètres.
- **Épisode précédent / suivant**, y compris entre saisons ; enchaînement automatique configurable.
- **Volume, muet et sélection des pistes audio** disponibles.
- **Sous-titres texte intégrés** et fichiers externes SRT, VTT, ASS ou SSA.
- **Image entière, remplissage avec recadrage ou étirement** ; pincement à deux doigts sur les périphériques compatibles.
- **Reconnexion** avec tentatives et délais configurables.

Le direct reste à vitesse normale et ne reçoit pas les commandes d'avance/retour VOD sans prise en charge du timeshift.

### Windows

| Commande | Action |
| --- | --- |
| `Espace` | Lecture/pause lorsque le lecteur a le focus |
| Touche multimédia Play/Pause | Lecture/pause du lecteur visible quand NOVA est la fenêtre active |
| Touches multimédias Play / Pause | Lecture ou pause explicite |
| `F`, bouton plein écran, double-clic sur l'image | Plein écran du lecteur |
| `F11` | Plein écran depuis l'application ; développe le lecteur actif |
| `Échap` | Sortie du plein écran avant fermeture du lecteur |
| Flèches gauche / droite | Reculer / avancer de 10 secondes en VOD |
| Molette au-dessus de la vidéo | Volume |

Les commandes multimédias Windows standard, notamment celles d'un clavier Corsair configuré pour les envoyer, fonctionnent même si un autre contrôle de NOVA a le focus. Aucune touche globale n'est réservée pour contrôler NOVA lorsqu'une autre application est active.

Le titre, les commandes et la progression se masquent après trois secondes sans interaction, quand la souris quitte la vidéo ou quand NOVA perd le focus. Les sous-titres et erreurs restent visibles. Les menus vitesse/audio/sous-titres/format s'ouvrent sans animation de menu prolongée.

### Android et écrans pliables

- Appui simple : afficher ou masquer les commandes.
- Glissement vertical à gauche : luminosité de la fenêtre ; à droite : volume système.
- Double appui sur un côté : ±10 secondes en VOD.
- Écarter deux doigts : remplir l'écran ; les rapprocher : image entière.
- Cadenas : verrouiller les commandes tactiles. Les gestes sont désactivables.

L'écran compact utilise une navigation inférieure. Sur grand écran : menu latéral, davantage d'affiches et, si l'espace le permet, chaînes et vidéo côte à côte. La session vidéo est conservée pendant les changements de taille et d'orientation. Le PiP dépend de la disponibilité et de l'autorisation Android.

## Bibliothèque, tri et plateformes

### Reprise de lecture

La rangée **Reprendre** apparaît sur l'accueil avant **À l'affiche**. L'onglet **Continuer à regarder** reste disponible. Une série utilise la progression de son épisode en cours.

Le clic droit ou le menu à trois points d'une affiche permet de choisir **Supprimer de Continuer à regarder**. Cela retire la fiche des deux vues sans effacer ses favoris ni sa progression ; une nouvelle lecture la réaffiche.

### Tri et langues

Dans **Tri et affichage**, les règles sont indépendantes pour la TV, les films et les séries. On peut masquer des langues ou catégories, corriger la langue d'un groupe et choisir un ordre personnalisé. La langue est déduite des noms fournis par la source, pas d'une analyse des pistes de chaque vidéo. **Non renseignée** désigne une langue non identifiée.

Sur Android, **Ordre des chaînes** dans la liste TV donne un accès direct au tri, notamment **Ordre de la source**. Les contenus masqués restent dans le cache avec favoris et progressions.

### Par PlateForme et tendances

L'onglet **Par PlateForme** classe les contenus des sources à partir des catégories, des associations manuelles et, facultativement, de métadonnées publiques.

**Mettre a jour par internet** récupère des sélections **Streaming Catalogs / JustWatch** et des tendances **Cinemeta**, sans clé API ni compte supplémentaire. Ce sont des sélections non exhaustives, variables selon les pays, et non les API officielles des plateformes.

**Seuls les titres retrouvés dans les sources visibles et associés à une vidéo sont affichés.** Les correspondances absentes ou ambiguës sont masquées et les rangées vides disparaissent. Les affiches des sources sont prioritaires. Un échec des services publics conserve leur dernier cache sans bloquer la bibliothèque.

Les requêtes consultent des listes publiques fixes : elles n'envoient ni identifiants IPTV, ni URL de lecture, ni titres privés aux services de métadonnées. Les associations manuelles gardent la priorité.

## Protection des données

- Configurations, URL privées, catalogues et programmes chiffrés **avant** écriture dans SQLite : **DPAPI Windows** ou **Android Keystore AES-256-GCM**.
- Favoris, progressions et préférences enregistrés localement ; l'export JSON des paramètres n'exporte pas les comptes IPTV.
- Protection liée à l'environnement d'origine : copier une base ne transfère pas automatiquement les accès entre appareils.
- Erreurs d'interface conçues pour ne pas exposer les mots de passe et URL privées.
- Clés Android, mots de passe protégés, bases locales, outils et fichiers de compilation exclus du dépôt.

Les communications avec le fournisseur utilisent l'adresse configurée : le chiffrement local ne transforme pas une source HTTP en source HTTPS.

## Compiler le projet

Les scripts préparent un environnement **Windows** local. Versions utilisées : **Flutter 3.47.9 / Dart 3.13.7** ; dépendances verrouillées dans [pubspec.lock](pubspec.lock).

```powershell
git clone https://github.com/Kyrluh/NOVA.git
cd NOVA
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\bootstrap.ps1 -Precache
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\flutter.ps1 pub get
```

### Compiler Windows x64

Installer Visual Studio Build Tools 2022 avec C++, CMake et un SDK Windows. Le script [setup-windows-build.ps1](scripts/setup-windows-build.ps1) prépare ces composants Microsoft et peut demander des droits administrateur.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\flutter.ps1 build windows --release
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\package.ps1
```

Le packaging produit le dossier portable, son ZIP et une archive des sources dans `dist/`, avec empreintes SHA-256.

Les plugins nécessitent des liens symboliques pour la compilation Windows. Si le système les refuse, `enable-developer-mode.ps1 -Mode Enable` sauvegarde le réglage puis active temporairement le mode développeur ; **exécuter `-Mode Restore` après la compilation**. Ce réglage n'est pas nécessaire à l'exécution de NOVA.

### Compiler Android

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\bootstrap-android.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\flutter.ps1 build apk --debug
```

Le package de développement, `app.nova.iptv.debug`, est distinct de la production.

Pour une **nouvelle signature de production personnelle**, puis les APK Release :

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\initialize-android-signing.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-android.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\package-android.ps1
```

**Une nouvelle clé ne peut pas mettre à jour une APK signée avec une autre clé.** Pour poursuivre une distribution existante, conserver sa signature d'origine hors Git. Les scripts protègent le mot de passe avec le compte Windows et ne remplacent pas silencieusement une clé existante. Voir la [sauvegarde/restauration](docs/ANDROID-INSTALLATION.md#signature-conservée).

`pubspec.yaml` porte la version et le code Android ; une nouvelle livraison doit les augmenter. Les constantes attendues de `package-android.ps1` doivent correspondre à la version à livrer.

### Vérifier une modification

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\flutter.ps1 analyze --no-pub
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\flutter.ps1 test --no-pub
```

Les tests peuvent être limités aux fichiers concernés. Les essais natifs et d'intégration restent séparés ; les rapports précisent les validations sur émulateur et les essais restant à faire sur appareil réel.

## Architecture et documentation

| Emplacement | Rôle |
| --- | --- |
| `lib/domain/` | Modèles, tri, préférences et correspondances |
| `lib/sources/` | Clients IPTV, parsers M3U/XMLTV et métadonnées publiques |
| `lib/state/` | Catalogue, imports, préférences et progression des actualisations |
| `lib/data/` | Stockage local, chiffrement et démonstration |
| `lib/player/` | Session libmpv, commandes, reconnexion et intégration système |
| `lib/ui/` | Pages, composants et dispositions adaptatives |
| `windows/`, `android/` | Hôtes et intégrations natives |
| `test/`, `integration_test/`, `tool/` | Tests ciblés, intégration et outils de validation |
| `scripts/` | Installation des outils, compilation et packaging |
| `docs/`, `licenses/` | Documentation, rapports et licences tierces |

- [Architecture](docs/ARCHITECTURE.md)
- [Installation Android et signature](docs/ANDROID-INSTALLATION.md)
- [0.6.6 — saisie des sources à la télécommande](docs/ANDROID-VALIDATION-0.6.6.md)
- [Audit et adaptation Android](docs/ANDROID-AUDIT.md)
- [0.6.5 — actualisation au démarrage](docs/VALIDATION-0.6.5.md)
- [0.6.4 — lecteur et clavier Windows](docs/WINDOWS-VALIDATION-0.6.4.md)
- [0.6.3 — gestes et ordre TV Android](docs/ANDROID-VALIDATION-0.6.3.md)
- [0.6.2 — séries M3U et correspondances internet](docs/VALIDATION-0.6.2.md)
- [Sous-titres : vérifications et limites](docs/SUBTITLE-VALIDATION.md)

## Tests et limites

La version 0.6.5 a reçu **cinq tests ciblés** sur l'actualisation et la progression, ainsi que les compilations Release Windows et Android. Les rapports historiques distinguent tests unitaires, essais natifs et émulateur pliable. Les sources personnelles ne sont pas incluses dans les fixtures.

Limites connues :

- Les sous-titres **images DVD/PGS/DVB** ne sont pas pris en charge par le rendu texte actuel ; les styles ASS avancés ont leurs propres limites.
- Pas de prise en charge Stalker ni des en-têtes VLC/User-Agent personnalisés des playlists.
- Pas d'actualisation périodique en service de fond : lancement de l'application ou actualisation manuelle.
- Le catalogue final reste en mémoire, sans pagination serveur Xtream ; les très gros catalogues nécessitent des essais spécifiques.
- Décodage matériel, HDR, codecs et comportements One UI à vérifier sur le matériel concerné. Un émulateur ne valide pas le téléphone physique.
- Le pincement dépend des événements transmis par le périphérique et le système.
- Le moteur natif Windows actuellement verrouillé est ancien ; ses versions et limites sont détaillées dans les [notices tierces](THIRD_PARTY_NOTICES.md).

## Licence et crédits

Le code original de NOVA IPTV est distribué sous **GPL-3.0-or-later** : [LICENSE](LICENSE). Les composants tiers conservent leurs propres licences et droits, détaillés dans [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) et [licenses/](licenses/).

La publication de ce code source ne constitue pas un paquet complet des sources correspondantes de libmpv, FFmpeg, ANGLE et de toutes leurs dépendances natives. Consulter les notices avant de redistribuer des binaires.

Les noms et logos des plateformes restent la propriété de leurs titulaires. NOVA n'est affilié à aucune plateforme ni à aucun fournisseur IPTV. Les titres et visuels du catalogue de démonstration sont fictifs et originaux.
