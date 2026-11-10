# NOVA IPTV Android 0.6.3+11

- TV : la première ouverture rétablit une fois l'ordre exact du catalogue fournisseur sur Android. Les filtres de langues/catégories, favoris, historique et progressions restent enregistrés. Les choix de tri ultérieurs restent respectés. Un menu **Ordre des chaînes** est accessible directement dans l'en-tête de la liste TV. L'ordre des éléments est celui de la source, sans reclassement TNT imposé.
- Lecteur : bouton lecture/pause au centre de l'image, visible avec l'ATH et masqué avec lui. Le verrouillage tactile et le PiP le masquent également. Le bouton reste indépendant des doubles appuis latéraux.
- Lecteur : écarter deux doigts choisit **Remplir**, les rapprocher choisit **Image entière**. Le geste modifie le cadrage Flutter sans rouvrir le flux. Aucun ajustement de luminosité/volume n'est déclenché lorsqu'un doigt est relevé après le pincement. Le réglage général des gestes et le cadenas désactivent le pincement.

Vérifications limitées à la demande de l'utilisateur : **13 tests ciblés réussis** (`android_player_test.dart` et `android_tv_order_test.dart`) et analyse statique sans anomalie. Ces tests vérifient les nouveaux gestes, le bouton central, le masquage, les gestes existants, la conservation du lecteur et la migration des préférences sans perte des favoris/progressions. Aucun lancement de la suite complète ni de l'émulateur pour cette livraison.

Livraison ARM64 et universelle signée avec la clé de production existante, package `app.nova.iptv`, version0.6.3/code11. Installer par-dessus la version précédente sans désinstallation. Les binaires Windows0.6.2 restent la livraison Windows disponible. Le mode développeur Windows n'a pas été activé pour cette mise à jour.
