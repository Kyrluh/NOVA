# NOVA Web pour iPhone

1. Ouvrez [NOVA Web](https://kyrluh.github.io/NOVA/pwa/) dans Safari.
2. Dans **Partager**, choisissez **Sur l’écran d’accueil**. Activez **Ouvrir comme app web** si l’option apparaît, puis touchez **Ajouter**.
3. Lancez l’application depuis son icône et ajoutez une source personnelle dans **Mes sources**.

L’interface adapte le nombre de colonnes à l’espace disponible et suit les changements de taille et d’orientation. Les sources, favoris et positions de lecture sont enregistrés dans le stockage Web de l’appareil. Installez l’application avant de saisir vos sources pour les retrouver au prochain lancement depuis l’icône. Les données peuvent être effacées depuis les réglages de Safari ou lors de la suppression de l’application.

## Compatibilité des sources

- **Xtream Codes** et **playlist M3U par URL** requièrent HTTPS et l’autorisation CORS du fournisseur pour la lecture du catalogue par le navigateur. Une importation M3U depuis un fichier permet de charger le catalogue localement.
- Les flux vidéo doivent eux-mêmes être en HTTPS et compatibles avec Safari. Pour le direct, privilégiez HLS (`.m3u8`). La lecture dépend aussi des codecs employés pour le film ou l’épisode.
- La PWA contacte directement le fournisseur. GitHub Pages sert uniquement les fichiers de l’application. Les données de source et de lecture ne sont pas synchronisées avec les versions natives.
