# NOVA IPTV 0.10.2 — Mise à jour depuis les paramètres

Une nouvelle entrée **Paramètres → Mise à jour de l’application** recherche la dernière version stable compatible sur GitHub et choisit automatiquement le bon installable.

- TV et Fire TV : APK TV universelle dédiée.
- Téléphone ARM64 : APK ARM64, avec repli vers l'universelle si nécessaire.
- Autres téléphones compatibles : APK universelle.
- Windows : ZIP portable x64.

Les publications qui ne concernent qu'une plateforme sont prises en compte. Une version égale, plus ancienne, en brouillon ou en préversion n'est pas proposée comme mise à jour.

Sur Android, le téléchargement affiche sa progression et vérifie la taille et l'empreinte SHA-256 du fichier. Le package, la signature et le code de version sont contrôlés avant d'ouvrir l'installateur système. Android ou Fire OS peut demander d'autoriser NOVA à installer ses mises à jour ; revenir ensuite sur le bouton Installer. L'installation reste confirmée par l'utilisateur.

Sur Windows, le bouton ouvre le téléchargement du ZIP. Fermer NOVA, extraire tout le ZIP puis lancer la nouvelle version. Les profils et sources sont conservés. Aucun téléchargement ni contrôle réseau de mise à jour ne démarre automatiquement au lancement.

## Première installation

Installer **0.10.2+34 une première fois manuellement**, car les versions précédentes ne possèdent pas ce bouton. Sur Android, installer par-dessus la même application sans la désinstaller pour conserver ses données.

| Appareil | Fichier |
| --- | --- |
| Windows x64 | `NOVA-IPTV-0.10.2-windows-x64.zip` |
| Téléphone Android ARM64 | `NOVA-IPTV-0.10.2-arm64-v8a.apk` |
| Téléphone Android universel | `NOVA-IPTV-0.10.2-universal.apk` |
| Android TV / Google TV / Fire OS compatible | `NOVA-IPTV-TV-0.10.2-universal.apk` |
| Sources et licences | `NOVA-IPTV-0.10.2-source.zip` |
| Empreintes des téléchargements | `SHA256SUMS.txt` |

## Validation

Les quatre installables ont été compilés en Release lors du développement de 0.10.2. La signature Android existante et le code de version 34 sont conservés pour cette publication. Neuf contrôles ciblés ont réussi, sans suite complète, émulateur ou installation ADB. Les réglages et confirmations sur téléphone et Fire TV physiques restent à confirmer.

Cette publication reprend ces binaires vérifiés ; elle met à jour la documentation et les archives Windows/source sans nouvelle compilation. Les détails sont dans le [guide des mises à jour](MISES-A-JOUR-0.10.2.md).
