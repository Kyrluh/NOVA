# NOVA IPTV 0.10.7 — Catalogue complet au démarrage

L’actualisation au démarrage récupère de nouveau toutes les chaînes, tous les films et toutes les séries, y compris les langues et catégories décochées. Xtream utilise ses listes complètes plutôt qu’une succession de requêtes pour les catégories sélectionnées.

Les préférences du profil restent appliquées à l’affichage : les contenus masqués ne réapparaissent pas dans les listes. L’écran de chargement et sa progression sont conservés. En cas d’échec, le cache reste disponible.

Ce changement concerne le démarrage sur Windows, Android mobile et Android TV / Fire TV. Les actualisations manuelles et celles déclenchées en recochant une préférence conservent leur fonctionnement actuel.

Un test ciblé vérifie que les trois listes complètes sont demandées au démarrage malgré une langue décochée, et que cette langue reste masquée dans le catalogue affiché. Les installables locaux utilisent la version 0.10.7+39 et la signature Android existante. Aucune publication de release ni installation ADB n’est incluse.
