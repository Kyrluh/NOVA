# NOVA IPTV 0.11.0+41

## Guide dans les listes de chaînes

Le programme en cours apparaît en petit sous chaque chaîne dans les listes TV, sur Windows, Android mobile et l’édition TV. Les informations utilisent le même guide que le lecteur et le menu contextuel. Les lignes visibles demandent le guide en arrière-plan ; les requêtes d’une même origine sont partagées et le passage au programme suivant est réévalué chaque minute. « Programme indisponible » reste affiché lorsqu’aucune information n’est connue, sans bloquer la lecture.

## Avatars de profils

Créer un profil puis choisir son personnage à l’étape de personnalisation, ou ouvrir Paramètres → Profil et envies → Modifier le profil → Choisir mon personnage. Les choix sont classés par univers. Trente portraits géométriques originaux sont intégrés hors connexion : Superman, Spider-Man, Iron Man, Batman, Wonder Woman, Black Panther ; Harry, Ron, Hermione et Dumbledore ; Dark Vador, Luke, Leia, Yoda et Grogu ; Marty et Doc ; Luffy, Zoro, Nami, Usopp, Sanji, Chopper, Robin, Franky, Brook, Jinbe et Law ; Goku et Naruto.

L’avatar est enregistré avec le profil et réapparaît au prochain lancement. Les genres, favoris et reprises restent associés à chaque profil. Aucun compte ni téléchargement d’images n’est nécessaire.

## Clic droit sur PC

Un clic droit dans l’image TV ouvre le panneau des chaînes, avec catégories, logos et programme en cours, en plein écran ou dans le lecteur intégré. Cliquer une chaîne la lance ; cliquer à l’extérieur ou de nouveau avec le bouton droit ferme le panneau. Consulter le panneau ne rouvre pas le flux. Dans une vidéo à la demande, le clic droit affiche les informations du lecteur.

## Touches multimédias Windows en arrière-plan

NOVA réserve la touche Lecture/Pause standard pendant qu’un lecteur est présent, puis la libère lorsque le dernier lecteur est fermé ou que l’application quitte. Windows peut alors transmettre cette touche même si une autre fenêtre a le focus. Le maintien de la touche n’entraîne pas de répétition et les deux voies d’événements Windows ne provoquent pas deux bascules.

Si une autre application a déjà réservé cette touche, le contrôle habituel dans NOVA reste disponible. Les réglages de macro du clavier peuvent aussi intervenir. Le fonctionnement physique du clavier Corsair et la coexistence avec d’autres lecteurs restent à confirmer sur le matériel de l’utilisateur. Référence : [RegisterHotKey](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-registerhotkey), [WM_HOTKEY](https://learn.microsoft.com/en-us/windows/win32/inputdev/wm-hotkey).

## Logo et version

Le nouveau N violet intègre un pot de popcorn de cinéma. Il est utilisé dans l’interface et les icônes Windows / Android. Son fichier original et le prompt de création sont conservés dans `assets/branding/` ; les icônes sont exportées par `scripts/update-branding.ps1`.

La version affichée près de la marque est lue dans les métadonnées de l’application installée ; aucune requête internet n’est effectuée. Elle est visible dans le menu latéral Windows / grand écran, l’en-tête mobile et le menu TV.

## Livraison locale et vérifications

Versions Windows, Android mobile et TV compilées en Release 0.11.0+41, signature Android conservée. Le packaging vérifie les packages Android, le code 41 et l’alignement APK 16 KiB. Le correctif natif de vérification des mises à jour 0.10.8 est conservé dans ces builds. Aucun push, aucune release ni installation ADB : le travail reste local à la demande du propriétaire.

Sept tests ciblés passent : partage et affichage du guide entre lecteur et liste, persistance et isolation des avatars et favoris, clic droit sans réouverture vidéo, commandes Windows de pause et de recadrage, commandes multimédias sans focus du lecteur, réservation et libération de la touche globale sans double bascule. L’analyse statique ne signale aucun problème. Un aperçu des portraits et du logo est exporté pour vérification visuelle. Les tests utilisent un moteur vidéo simulé et ne remplacent pas les essais sur Fire Stick et clavier physique.
