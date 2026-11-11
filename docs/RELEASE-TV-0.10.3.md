# NOVA IPTV TV 0.10.3 — Programmes dans le menu des chaînes

Le programme en cours s'affiche désormais en petit sous chaque chaîne du menu contextuel du lecteur. Il est consultable avant de lancer la chaîne.

- Le guide se charge en arrière-plan pour les chaînes affichées, avec le cache partagé de leur source.
- Les programmes se mettent à jour sans perdre la sélection ni quitter le plein écran.
- Le texte agrandi, le défilement et l'ordre de la source sont conservés.
- Sans information du fournisseur, la ligne indique **Programme indisponible**.

## Mettre à jour depuis NOVA TV 0.10.2

Ouvrir **Paramètres → Mise à jour de l’application → Vérifier les mises à jour**, puis **Télécharger et installer la mise à jour**. Si Android ou Fire OS le demande, autoriser NOVA à installer ses mises à jour, revenir dans NOVA et sélectionner **Installer la mise à jour**. Confirmer dans l'installateur système.

Le bouton ne détecte que les versions publiées dans les releases GitHub. La publication de 0.10.3 rend donc cette APK disponible au gestionnaire de mise à jour.

## Fichiers et compatibilité

- `NOVA-IPTV-TV-0.10.3-universal.apk` : Android TV, Google TV et Fire OS compatible, ARM32/ARM64/x86_64.
- `SHA256SUMS.txt` : empreinte de l'APK.

Version **0.10.3+35**, package `app.nova.iptv.tv`, signature de production conservée. Installer par-dessus l'application TV existante sans la désinstaller pour conserver sources, profils et préférences. Android 7.0/API 24 minimum. Les appareils Vega OS ne peuvent pas installer cette APK Android.

**Cette release concerne uniquement l'application TV.** Windows et Android téléphone restent en 0.10.2, disponibles dans la release précédente.

## Validation

L'APK a déjà été compilée et vérifiée pendant le développement : quatre scénarios ciblés réussis, analyse sans problème, signature/version/architectures et alignement APK vérifiés. Cette publication reprend ce binaire sans nouvelle compilation ni installation ADB. Le menu et le guide doivent encore être confirmés sur la Fire Stick physique avec les sources réelles.
