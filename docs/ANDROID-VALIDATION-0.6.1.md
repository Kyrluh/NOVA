# Correctif Android NOVA IPTV 0.6.1+9

Cette mise à jour corrige les dispositions Android après les premiers essais sur téléphone. Elle réutilise la même signature et le même package `app.nova.iptv` : installer l'APK par-dessus 0.6.0 pour conserver les sources, favoris et progressions.

## Changements

- TV : davantage de place pour la liste, lignes plus compactes, défilement tactile explicite et lecteur conservé pendant le redimensionnement. Lorsque le clavier laisse moins de 300 points de hauteur, la vidéo reste montée hors écran et la liste occupe la zone disponible.
- TV : commandes du lecteur sur une seule ligne, plein écran maintenu à droite ; les réglages secondaires peuvent défiler horizontalement dans un petit lecteur. Un second bouton plein écran reste visible sous l'image, indépendamment du masquage de l'ATH.
- Écran interne : cinq affiches par ligne à densité standard dès que la fenêtre et le contenu offrent assez de place. La hauteur des cartes conserve les proportions de l'affiche. Les en-têtes du catalogue ne répètent plus inutilement ceux de la navigation.
- Catégories Android : bandeau horizontal construit à la demande au lieu de dizaines de lignes de filtres au-dessus des films.
- Fiches sur grand écran : affiche entière à gauche, titre à droite, bannière et typographie réduites, dialogue plus large.
- Accueil : bannière et affiches plus compactes, premières sélections limitées à 24 films/séries/favoris avec accès au catalogue complet ; la rangée Reprendre conserve tous les contenus en cours. Les images utilisent leur première image décodée plutôt qu'une reconstruction à chaque fragment réseau ; la bannière possède sa propre zone de peinture.

## Vérifications

La suite complète de 160 tests passe. Les nouveaux tests reproduisent un catalogue de 1500 films, le geste vertical sur les carrousels, une liste TV de 80 chaînes à différentes tailles dont 360×260, cinq affiches sur une ligne et de nombreuses catégories sans repousser la grille hors écran. Le plein écran est testé dans un lecteur large de seulement 180 points ; le lecteur et ses pistes sont conservés.

L'APK signée est également vérifiée sur l'émulateur Pixel Fold API35, avec une densité interne de 560 pour reproduire une fenêtre logique plus étroite : playlist originale locale de 80 chaînes et 30 films, défilement pendant la lecture, écran externe et interne, bouton plein écran et grille. Les captures sont conservées dans `validation/android-0.6.1`.

Les tests d'interface ne mesurent pas les FPS ni la consommation sur le Samsung physique. Le gain de fluidité de l'accueil reste à confirmer avec le catalogue et le réseau du téléphone. Les sources personnelles n'ont pas été utilisées pour ces vérifications.
