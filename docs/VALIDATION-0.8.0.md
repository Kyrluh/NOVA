# NOVA IPTV 0.8.0 — Profils, accueil et versions des œuvres

Version commune Windows et Android : **0.8.0+18**.

## Profils

- Sélection ou création à chaque lancement de l'application distribuée, jusqu'à vingt profils locaux.
- Migration des favoris, réglages et progressions existants dans **Mon profil**, renommable depuis les paramètres.
- Favoris, reprises, historique, éléments retirés de Reprendre, réglages vidéo, tri, langues/catégories masquées, associations de plateformes et genres préférés séparés par profil.
- Les sources et le cache IPTV restent communs. Le changement de profil ferme l'ancienne interface et ses lecteurs ; une ancienne route de lecture ne peut pas écrire sa progression dans un nouveau profil.
- Proposition des genres à la première entrée, continuation possible sans préférence, modification ultérieure dans **Paramètres → Profil**.
- La fermeture Windows est gérée au-dessus du sélecteur de profils, afin de conserver la sauvegarde et la fermeture normale pendant le choix d'un profil.

## Accueil et tendances

- Nouvel accueil commun, adapté au téléphone, à Windows et à la télécommande : bannière aléatoire parmi les films compatibles avec les genres préférés, bouton Autre suggestion, accès Reprendre/Favoris/TV/Films/Séries/Par plateforme, paramètres en haut à droite et changement de profil.
- Évite la même première suggestion consécutive lorsqu'au moins deux films du groupe correspondent ; choix mémorisé par profil.
- Si aucun genre ne correspond aux métadonnées disponibles, choix parmi les autres films visibles. Aucun film extérieur aux sources n'est inventé. La source doit fournir des catégories ou informations de genre pour une sélection précise.
- Accueil précédent conservé dans Tendances, après Par plateforme. Pas de sections Reprendre/Favoris ni raccourcis TV/vitesse dans Tendances.
- Récemment ajoutés reste sous Reprendre dans le nouvel accueil ; le tri récent reste celui des catégories Films/Séries.

## Plateformes et variantes

- CANAL+, STARZ, OCS, VARIETY, TF1+ | M6+ | FTV, DOCUMENTAIRES, ÉMISSION / REALITY TV et KIDS ajoutés. Les catégories accentuées Animés/Animées/Animation sont reconnues pour KIDS.
- Les nouvelles rubriques reposent sur les catégories de la source et les associations manuelles. Les logos historiques sont conservés ; les nouvelles rubriques ont des badges graphiques locaux. Aucun service Internet fictif n'est ajouté ; la mise à jour facultative des plateformes déjà prises en charge reste non bloquante.
- Une fiche par œuvre identifiée avec confiance : même source, type, titre nettoyé des marqueurs de langue/qualité et année connue. Les titres numériques significatifs restent distincts. Les remakes et titres ambigus restent séparés ; les traductions de titres ne sont pas rapprochées arbitrairement.
- Sélecteur de version avant lecture dans les fiches partagées et TV. Chaque version garde ses vrais identifiants, épisodes, flux et progression. Les catégories et plateformes de toutes les variantes visibles restent accessibles. Favoris, historique et Reprendre montrent la fiche regroupée, avec choix par défaut de la version regardée le plus récemment.
- Les filtres de visibilité sont appliqués avant regroupement. Aucun catalogue ni identifiant fournisseur n'est réécrit.

## Validation ciblée

Seize scénarios distincts ont passé les contrôles ciblés au cours de la modification : huit nouveaux tests (migration/isolation/persistance des profils, identité prudente des œuvres, favoris/reprises des versions, rotation par genre, plateformes, premier démarrage, sélection du flux partagé/TV et Tendances), quatre tests existants de sauvegarde, deux de tri récent et deux d'affichage compact/TV. Les contrôles de tailles couvrent notamment le téléphone compact et les fenêtres TV 960×540, 1280×720 et 720×400. Des attentes de navigation existantes ont été adaptées au nouvel accueil et à Tendances. Pas de suite complète ni d'émulateur.

Analyse statique des fichiers concernés sans anomalie après correction. Compilations Release Windows x64, téléphone ARM64, téléphone universelle et TV universelle ; contrôles de packaging Android (packages, version/code, architectures, signature de production, SHA-256 et alignement ZIP). Aucun nouvel essai physique sur un téléphone pliable, Android TV ou Fire Stick pendant cette modification. Ces essais restent à effectuer sur appareil, notamment pour la navigation de chaque télécommande et les sources réelles.

Les packages et la signature Android sont conservés. Installer les APK par-dessus, sans désinstaller. Windows : extraire tout le ZIP et fermer l'ancienne application avant de lancer la nouvelle. Les profils et leurs préférences sont enregistrés localement sur chaque appareil, sans synchronisation entre appareils.
