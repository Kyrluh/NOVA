# NOVA IPTV Windows 0.6.4+12

- Bouton lecture/pause au centre de l'ATH, masqué avec les autres commandes.
- Pincement à deux doigts : écarter pour remplir, rapprocher pour retrouver l'image entière, sans rouvrir le flux. Le geste fonctionne sur une surface tactile ou un périphérique transmettant les gestes de pincement à Flutter/Windows. Les menus de format restent accessibles à la souris.
- Touches multimédias standard Play/Pause, Play et Pause : les événements clavier Flutter et les messages natifs Windows `WM_APPCOMMAND` sont reliés au lecteur visible. L'action reste disponible quand un autre contrôle de NOVA a le focus. Le lecteur masqué d'une autre page ne reçoit pas la commande. Play et Pause sont idempotents ; le maintien d'une touche Flutter ne bascule pas la lecture à répétition.

La fenêtre NOVA doit être active pour ces commandes ; aucune touche globale n'est réservée au détriment des autres applications. Le bouton Corsair doit émettre la commande multimédia Windows standard. Aucun clavier Corsair physique ni profil iCUE personnel n'a été utilisé pendant les vérifications.

Vérifications limitées : **trois tests ciblés réussis** pour le bouton central/masquage, le pincement sans réouverture et les événements multimédias clavier/natifs sans focus sur le lecteur. Les fichiers modifiés ont été analysés statiquement ; une remarque de style sur des accolades a été corrigée. Compilation Windows Release et test d'ouverture/fermeture du programme. La suite complète n'a pas été relancée.

Livraison Windows portable et archive de sources. Android reste à la version installable0.6.3. Les données utilisateur Windows gardent leur emplacement et l'ordre des chaînes n'est pas réinitialisé. Le mode développeur Windows n'a pas été activé.
