# NOVA IPTV 0.8.3 — Densité des grilles et contrôle TV

Windows, téléphone et TV : **0.8.3+21**.

## Réglage d'affichage

- Paramètres → **Affiches par ligne · Films et Séries**, sur les trois interfaces.
- **Automatique** conserve le comportement adaptatif existant. Les valeurs **1 à 12** demandent une densité précise pour les grilles de catalogue.
- En largeur insuffisante, le nombre effectif est réduit pour conserver des cartes lisibles. Le choix reste mémorisé et s'applique à nouveau lorsque l'écran s'élargit, notamment après dépliage ou redimensionnement.
- Sur TV, la hauteur des grandes cartes manuelles est plafonnée à la hauteur de la grille : une seule affiche par ligne ne bloque pas l'accès au film suivant avec la télécommande.
- Le réglage reste local à l'appareil et séparé par profil. Il survit au redémarrage et accompagne l'export/import des réglages. Les anciennes préférences utilisent Automatique par défaut.
- Le réglage Taille des affiches reste utile au mode automatique et aux carrousels horizontaux. Les listes de chaînes et le moteur vidéo ne sont pas modifiés.

## Contrôle TV demandé

Le contrôle a révélé un cas de données contenant plusieurs fois le même identifiant de média, qui produisait des entrées répétées dans le sélecteur de versions. La construction du catalogue de présentation élimine désormais ces identifiants répétés, en conservant la dernière valeur pour rester cohérente avec l'index des sources. Le scénario de reprise d'une série dans la bonne saison passe après cette correction.

**Treize tests ciblés passent** :

- Quatre scénarios d'affichage : sauvegarde et isolation du réglage par profil ; grilles Windows, Android et TV, nombres de colonnes et largeur réduite. Les vérifications couvrent notamment 1, 5 et 8 affiches, et la navigation TV vers le film suivant avec une seule colonne.
- Trois scénarios d'interface TV : reprise dans la bonne saison, navigation D-pad/OK vers les films et fiches, affichage et accès aux sources/plateformes aux formats 960×540, 1280×720 et 720×400.
- Trois scénarios du lecteur avec moteur simulé : lecture/pause à la télécommande et touches multimédias, changement de chaîne sans seek, contrôles/plein écran et conservation d'une seule session.
- Trois scénarios des sources : saisie URL TV par OK, validation/annulation et caractères spéciaux via un pont natif simulé ; navigation des formulaires M3U et Xtream.

Analyse statique des fichiers modifiés sans anomalie. Aucune TV ni aucun autre appareil Android n'était connecté à ADB. Pas de suite complète, d'émulateur, de test réseau des fournisseurs ou d'essai prolongé sur matériel. Le clavier réel de Fire OS/Android TV, les décodeurs matériels et la lecture des sources réelles restent à confirmer sur appareil ; ces tests ne démontrent pas l'absence de tout bug.

## Livraison

Compilations Release Windows x64, Android ARM64, Android universelle et TV universelle. Packages et signature Android conservés, code de version 21, contrôles de packaging et empreintes SHA-256. Installer les APK par-dessus sans désinstaller. Windows : fermer l'ancienne version et extraire le nouveau ZIP entier.

La version inclut les choix de serveurs Xtream et la saisie native TV de la 0.8.2, ainsi que le préréglage Kyrlu provenant de la configuration locale privée de compilation.
