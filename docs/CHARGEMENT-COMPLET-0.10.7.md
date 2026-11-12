# NOVA IPTV 0.10.7 — Catalogue complet au démarrage

L’actualisation au démarrage récupère de nouveau toutes les chaînes, tous les films et toutes les séries, y compris les langues et catégories décochées. Xtream utilise ses listes complètes plutôt qu’une succession de requêtes pour les catégories sélectionnées.

Les préférences du profil restent appliquées à l’affichage : les contenus masqués ne réapparaissent pas dans les listes. L’écran de chargement et sa progression sont conservés. En cas d’échec, le cache reste disponible.

Ce changement concerne le démarrage sur Windows, Android mobile et Android TV / Fire TV. Les actualisations manuelles et celles déclenchées en recochant une préférence conservent leur fonctionnement actuel.

Un test ciblé vérifie que les trois listes complètes sont demandées au démarrage malgré une langue décochée, et que cette langue reste masquée dans le catalogue affiché. Les installables utilisent la version 0.10.7+39 et la signature Android existante. Les compilations Windows, Android mobile et TV ont réussi. Aucune installation ADB n’est effectuée.

La [release 0.10.7](https://github.com/Kyrluh/NOVA/releases/tag/v0.10.7) contient le ZIP portable Windows, les APK mobile ARM64 et universelle, l’APK TV universelle, une archive du code et les empreintes SHA-256. Elle est proposée depuis les paramètres de mise à jour de NOVA. La publication réutilise les binaires déjà compilés.
