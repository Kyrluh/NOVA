# NOVA IPTV 0.8.8 — Chargement et mémoire Fire TV

Version commune Windows, Android téléphone et TV : **0.8.8+26**.

## Écran de chargement

Le démarrage affiche une page NOVA légère pendant l'ouverture du cache et l'actualisation des sources. Le choix du profil et les catalogues sont construits après cette phase. La page affiche le nom de la source, l'étape et une progression lorsque la taille est connue ; sinon la barre reste indéterminée. Une source indisponible rend ensuite la main au cache existant, sans bloquer indéfiniment l'accueil.

L'ajout et l'actualisation manuelle d'un catalogue affichent aussi cette page au-dessus du formulaire. Le navigateur et le brouillon restent conservés. L'état « aucune source au premier démarrage » est terminé explicitement pour que l'ajout ultérieur de la première source ne laisse pas l'application bloquée sur le chargement.

## Mémoire

- Sur Android, la sauvegarde génère le JSON élément par élément, puis chiffre des fragments de 48 K caractères maximum. Elle évite la copie du catalogue vers un isolate et la création d'une chaîne JSON complète supplémentaire pour l'écriture. Une fiche individuelle reste encodée d'un seul tenant ; la lecture du cache reste celle du format existant.
- Les fragments sont toujours chiffrés avant insertion et écrits dans une transaction. Une erreur au milieu de la sauvegarde conserve la version précédente. Le format Android existant reste lisible ; le format Windows version 1 et sa protection restent conservés.
- Les éléments déjà datés par le fournisseur sont réutilisés lors du classement des ajouts, sans copie inutile de chaque objet.
- L'APK TV limite le cache Flutter d'affiches à 32 Mio et 96 entrées. Cela borne le cache réutilisable, sans prétendre limiter toute la mémoire vidéo ou les images actuellement affichées.
- Les champs TV vides rendent leur texte d'attente sans chevauchement du libellé, défaut constaté lors de l'essai sur appareil.

## Vérification ciblée

Dix scénarios passent : écran avant les profils sur interfaces commune et TV, réussite et échec de chargement avec cache ; premier import avec formulaire conservé ; actualisation unique préservant favoris et progression ; poursuite après source indisponible ; compatibilité du cache Windows version 1 ; grand catalogue chiffré, Unicode, comparaison des données restaurées ; rollback après échec d'un fragment ; dates et ordre des ajouts. Analyse statique des fichiers concernés sans anomalie. Pas de suite complète ni d'émulateur.

## Essai sur Fire TV physique

Une Fire TV **AFTKRT / Android API 30**, disposant d'environ 1,7 Gio de RAM et d'un tas Java normal limité à 192 Mio, a été connectée avec l'autorisation du propriétaire. L'APK TV de production a été installée puis mise à jour sans désinstallation. Une source personnelle a été configurée dans l'éditeur natif, avec le préréglage de mot de passe existant : **43 111 contenus** ont été importés.

Le chargement initial, le rechargement au démarrage et l'affichage de l'écran d'attente suivi des profils ont été observés sur l'appareil. La recherche de chaînes a ouvert le clavier natif ; Retour a conservé « TF1 » et filtré la liste ; la flèche bas a ensuite placé le focus sur Catégorie. L'ordre affiché commence par TF1, France 2, France 3 et France 4.

Une tentative de lecture TF1 HD a activé le décodeur matériel H.264 avec une sortie déclarée 1280 × 720 à 25 images/s dans les traces du Stick. Une capture ADB présentait la zone vidéo noire : ces traces ne suffisent pas à garantir l'image et le son réellement perçus sur le téléviseur. Cette confirmation reste nécessaire, ainsi qu'un essai prolongé et les autres codecs/flux.

La fermeture spontanée signalée n'a pas été reproduite avec cette source pendant la session. Les arrêts d'installation et de redémarrage commandés via ADB sont distingués des plantages. Les changements réduisent des pics de mémoire évitables ; ils ne démontrent pas à eux seuls la cause de la fermeture initiale. Aucune mesure comparative de fluidité ou garantie d'absence de crash prolongé n'est annoncée.

Les adresses de connexion ADB, identifiants, bases utilisateur et traces brutes restent hors Git. Aucun compte personnel n'est inclus dans les installables distribués. Les compilations Release Windows x64, Android ARM64, Android universelle et TV universelle conservent les signatures existantes ; les APK passent au versionCode 26. Les APK se mettent à jour par-dessus les précédentes sans désinstallation.
