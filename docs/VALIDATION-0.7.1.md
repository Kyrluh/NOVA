# NOVA IPTV 0.7.1 — Récemment ajoutés

Version commune Windows, Android téléphone et Android TV : **0.7.1+16**.

- Accueil : rangée Récemment ajoutés immédiatement après Reprendre, avant les tendances et À l'affiche. Sans reprise en cours, la rangée reste affichée.
- Films et Séries : Récemment ajoutés en première catégorie, sélectionnée par défaut ; les catégories du fournisseur et Tout explorer restent disponibles.
- Dates Xtream : champ `added` valide, secondes ou millisecondes Unix. Les dates de sortie et les modifications de métadonnées ne servent pas de dates d'ajout.
- M3U : première observation conservée dans le cache, y compris après redémarrage. Les catalogues antérieurs sont initialisés avec leur date d'actualisation ; leur historique d'ajout réel ne peut pas être reconstruit sans données fournisseur.
- Les épisodes restent regroupés sous leur série et leur saison. Les filtres de langues et de catégories restent appliqués ; aucune carte Internet sans vidéo associée n'est ajoutée.
- Le classement de l'accueil est mis en cache jusqu'à modification du catalogue visible.

Validation courte : quatre tests ciblés passent (lecture des dates, persistance M3U/épisodes, ordre et exclusion du direct, migration du cache puis actualisation et redémarrage). Analyse statique des onze fichiers concernés sans anomalie. Compilations Release Windows, Android ARM64, Android universelle et TV universelle ; les contrôles de packaging vérifient les identifiants, versions, architectures et signatures Android. Aucun émulateur ni essai physique supplémentaire sur téléphone/TV pour cette modification.

La signature Android et les packages restent ceux des versions précédentes. Installer les APK par-dessus sans désinstaller. Windows : extraire le ZIP complet dans un nouveau dossier et fermer l'ancienne application avant d'ouvrir la nouvelle.
