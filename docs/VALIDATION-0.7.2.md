# NOVA IPTV 0.7.2 — Tri des catégories par ajout

Windows et les trois APK : **0.7.2+17**.

Dans Films et Séries, le classement par date d'ajout décroissante est désormais appliqué par défaut à toutes les catégories du fournisseur et à Tout explorer, sur Windows, téléphone et TV. Par exemple, Horreur montre d'abord les titres ajoutés le plus récemment. La catégorie Récemment ajoutés reste en première position. Le menu Trier par de l'interface Windows/téléphone indique correctement ce tri et permet de choisir un autre ordre dans les catégories habituelles.

Les dates restent celles introduites en 0.7.1 : champ `added` du fournisseur Xtream lorsqu'il est disponible et valide ; première apparition mémorisée pour les M3U sans dates. Aucun historique fournisseur n'est inventé. Les filtres personnels et le regroupement série/saison/épisode sont conservés. Les listes TV en direct et l'historique ne changent pas de tri.

Validation courte : **deux tests de widgets passent**, un pour les films, un pour les séries. Ils sélectionnent Horreur dans l'interface partagée et dans l'interface TV, vérifient l'ordre récent → ancien et l'exclusion des autres genres. Analyse statique des trois fichiers concernés sans anomalie. Compilations Release Windows x64, téléphone ARM64 et universelle, TV universelle ; contrôles de packaging Android pour versions, packages, architectures, signatures et alignement ZIP. Aucun émulateur ni essai physique supplémentaire.

Installer les APK par-dessus les anciennes sans désinstaller. Les packages et la signature Android sont conservés. Windows : extraire le ZIP entier et fermer l'ancienne version avant d'ouvrir le nouveau dossier portable.
