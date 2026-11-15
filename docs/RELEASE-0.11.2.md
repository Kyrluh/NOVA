# NOVA IPTV 0.11.2

Disponible pour Windows, Android mobile et Android TV / Fire TV sous Fire OS.

- Nouveau logo validé : N lumineux et popcorn rouge/blanc occupent davantage le carré de l’icône.
- Logo agrandi dans les en-têtes Windows, mobile et TV ; numéro de version plus lisible, également visible dans le menu réduit.
- Sur Windows, barres de défilement visibles et élargies dans le menu des chaînes : 18 pixels à droite, 12 pixels sous les catégories, curseur d’au moins 48 pixels et espace réservé à la souris. Faire glisser le curseur ne lance aucune chaîne.

## Téléchargements

- Windows : `NOVA-IPTV-0.11.2-windows-x64.zip` — décompresser puis lancer `NOVA_IPTV.exe`.
- Android mobile ARM64 : `NOVA-IPTV-0.11.2-arm64-v8a.apk`.
- Android mobile universelle : `NOVA-IPTV-0.11.2-universal.apk`.
- Android TV / Fire TV : `NOVA-IPTV-TV-0.11.2-universal.apk`.
- Code source : `NOVA-IPTV-0.11.2-source.zip` ; empreintes : `SHA256SUMS.txt`.

Les APK portent le code de version 43 et conservent la signature de production existante. Installer l’APK adaptée par-dessus l’application existante pour conserver les données. Si une ancienne version Fire TV refuse la mise à jour depuis NOVA, télécharger et installer manuellement l’APK TV officielle, sans désinstaller NOVA.

## Validation

Analyse statique ciblée des fichiers modifiés, test de déplacement du curseur à la souris et aperçus des en-têtes Windows, mobile et TV sans débordement. Compilations Release et vérification des signatures lors du packaging. Les changements visuels restent à apprécier sur les appareils réels ; aucune installation ADB n’est réalisée pour cette livraison.