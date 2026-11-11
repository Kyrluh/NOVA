# TV 0.10.3 — Programme en cours sous les chaînes

Dans le menu contextuel des chaînes ouvert depuis le lecteur plein écran, chaque nom est suivi d'une ligne plus petite indiquant son programme en cours. L'information est consultable avant de sélectionner et lancer la chaîne.

- Les programmes sont lus dans le guide XMLTV de la source de chaque chaîne, avec les associations EPG existantes.
- Les lignes construites dans le menu demandent le guide de leur source en arrière-plan ; les requêtes et le cache sont partagés par source avec le guide automatique existant.
- Les titres des programmes se mettent à jour à la réception du guide et chaque minute pendant l'ouverture du menu. Fermer le menu arrête son actualisation périodique.
- L'arrivée des informations conserve la chaîne parcourue et le focus ; elle ne lance aucune chaîne et ne quitte pas le plein écran.
- Haut/bas, gauche/droite, OK et Retour gardent leur fonctionnement. L'ordre de la source est conservé.
- Le nom et le programme sont limités en largeur avec points de suspension. La hauteur des lignes s'adapte au texte agrandi, y compris pour le défilement automatique vers la sélection.
- Sans programme courant associé, la ligne affiche **Programme indisponible**. La source doit fournir un guide ; NOVA n'invente pas les programmes absents.

## Livraison locale

APK TV **0.10.3+35** : `dist/android-tv/NOVA-IPTV-TV-0.10.3-universal.apk`, avec la signature de production existante et le package `app.nova.iptv.tv`. Installer par-dessus l'application TV existante sans la désinstaller pour conserver ses données.

Cette tâche prépare uniquement un nouveau binaire TV. Les APK téléphone et le portable Windows restent en 0.10.2. Aucune nouvelle release ni installation ADB n'est effectuée à cette étape.

## Contrôles ciblés

Quatre scénarios passent sans suite complète ni émulateur : programmes sous les noms avec sélection conservée lors d'une actualisation, consultation d'une catégorie avant lancement, noms longs/texte agrandi/défilement dans l'ordre de la source, et intégration au menu du lecteur sans sortie du plein écran ni réouverture du flux lors de la consultation.

Les contrôles utilisent un guide et un moteur vidéo de test ; ils ne remplacent pas l'essai sur la Fire Stick physique.

L'analyse ciblée des cinq fichiers ne signale aucun problème. La compilation TV Release et son packaging ont réussi : version 0.10.3+35, signature de production conservée, ARM32/ARM64/x86_64, API minimum 24, cible 36 et alignement APK 16 KiB vérifiés. Gradle a été arrêté après compilation.
