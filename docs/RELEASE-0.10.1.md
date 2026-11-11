# NOVA IPTV 0.10.1 — Guide TV automatique dans le lecteur

Le guide se charge désormais automatiquement en arrière-plan lorsqu'une chaîne est ouverte, depuis la page TV ou un autre accès de la bibliothèque.

- Le programme en cours, ses horaires, sa progression et le programme suivant apparaissent dans l'image avec l'ATH du lecteur, au-dessus des commandes.
- Le guide suit le masquage des commandes, le plein écran, le verrouillage tactile et le Picture-in-Picture. Il ne prend pas le focus de la télécommande.
- L'affichage est compact dans un petit lecteur et plus détaillé en plein écran. Le lecteur vidéo conserve sa session.
- Un changement de chaîne réutilise le guide de la source et affiche les programmes de la nouvelle chaîne, même si le téléchargement précédent se termine après le changement.
- Un guide absent ou indisponible ne bloque pas la chaîne et ne produit pas d'erreur de lecture.

## Sources et cache

Xtream utilise automatiquement le guide XMLTV du fournisseur. Pour une M3U, l'adresse du guide doit être annoncée dans la playlist ou configurée dans les sources ; NOVA ne peut pas inventer des programmes absents du fournisseur.

Les requêtes sont partagées par source. Le cache de session limite les téléchargements : un guide réussi contenant des programmes à venir est conservé jusqu'à trois heures ; les nouvelles tentatives sont espacées d'au moins cinq minutes. L'actualisation manuelle reste disponible.

Le chargement automatique ne réécrit pas tout le catalogue IPTV chiffré pendant la lecture. Son résultat reste en mémoire pour la session ; le cache déjà enregistré est conservé en cas d'échec. L'actualisation manuelle garde sa sauvegarde locale existante. Aucun service en arrière-plan n'est ajouté.

## Livraison

Version **0.10.1+33**, avec la signature Android de production conservée :

| Appareil | Fichier |
| --- | --- |
| Windows x64 | `NOVA-IPTV-0.10.1-windows-x64.zip` |
| Téléphone Android ARM64 | `NOVA-IPTV-0.10.1-arm64-v8a.apk` |
| Téléphone Android universel | `NOVA-IPTV-0.10.1-universal.apk` |
| Android TV / Google TV / Fire OS compatible | `NOVA-IPTV-TV-0.10.1-universal.apk` |
| Sources et licences | `NOVA-IPTV-0.10.1-source.zip` |
| Empreintes des fichiers | `SHA256SUMS.txt` |

Installer l'APK adaptée par-dessus l'application existante, sans la désinstaller, pour conserver sources, profils, favoris et reprises. Sous Windows, extraire le ZIP complet et lancer `NOVA_IPTV.exe`. Les sous-titres restent désactivés à l'ouverture d'une vidéo.

## Vérification

Six scénarios ciblés couvrent le chargement partagé sans réécriture du catalogue, l'échec non bloquant et son délai de nouvelle tentative, l'actualisation manuelle et son cache, le changement de chaîne pendant le chargement, et le masquage/plein écran de l'ATH sur les contrôles Windows et TV. L'analyse ciblée de neuf fichiers ne signale aucun problème.

Les essais utilisent des sources fictives et un moteur de test. Ils ne constituent pas un essai sur la Fire TV ou le Fold physiques. Aucune installation ADB n'est effectuée pour cette publication.
