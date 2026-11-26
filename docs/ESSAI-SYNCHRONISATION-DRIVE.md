# Essai NOVA IPTV 0.11.10 — reprise avec Google Drive

## Profil complet à partir de la 0.11.17

Sur l’appareil qui contient le bon profil, ouvrez **Profil et envies**. Si un code est déjà associé, choisissez **Publier ce profil comme référence**. Sur l’autre appareil, saisissez le même code ou choisissez **Importer le profil associé**. Vous pouvez remplacer le profil actif ou créer un profil séparé. Les profils associés portent la mention **(Sync.)**.

Le nom, l’avatar, les goûts, les réglages, les favoris films et séries, « Ma liste » et la progression sont associés au profil Drive. Les sources, leurs identifiants, les liens de lecture et les favoris des chaînes en direct restent locaux. Pour afficher une liste ou reprendre une vidéo sur une autre source, NOVA doit retrouver le titre dans le catalogue de cet appareil. Les films et séries sont rapprochés par titre normalisé et année. Les épisodes sont rapprochés par numéro de saison et d’épisode. Gardez la même version de NOVA sur les appareils associés.

Cet essai couvre Windows, les téléphones Android avec les services Google Play, et Android TV / Fire TV. La reprise et les épisodes vus sont synchronisés pour les sources Xtream. Les favoris et « Ma liste » restent locaux.

## Essayer sur un téléphone Android

Dans **Clients** du même projet Google Cloud, créez un client OAuth de type **Android**. Utilisez le paquet `app.nova.iptv` et l’empreinte SHA-1 du certificat des APK de cette release :

```text
33:DD:CF:F8:C3:D7:F2:37:E5:66:F8:11:B6:EC:4D:F8:CC:91:A9:2E
```

Installez l’APK mobile. Dans **Paramètres → Profil et envies**, choisissez **Connecter Google Drive**, sélectionnez le même compte Google que sur le PC, puis associez le même code de profil NOVA. La connexion Android utilise l’autorisation native de Google. Aucun secret de client n’est à saisir sur le téléphone.

## Configurer l’accès Google

1. Dans la [console Google Cloud](https://console.cloud.google.com/), créez un projet dédié et activez **Google Drive API**.
2. Dans Google Auth Platform, configurez l’écran de consentement. Si le projet est en mode **Testing**, ajoutez votre compte Google aux utilisateurs de test.
3. Créez deux clients OAuth dans **le même projet** : **Application de bureau** pour le PC et **TV et périphériques à saisie limitée** pour la Fire TV. Gardez les identifiants de ces clients sur vos appareils. Saisissez-les directement dans NOVA.
4. Ouvrez **Paramètres → Profil et envies → Synchronisation Google Drive (essai)** sur le PC. Choisissez **Connecter Google Drive** et confirmez dans le navigateur.
5. Sur la Fire TV, ouvrez le même réglage, utilisez le client TV, puis validez sur votre téléphone le code affiché à l’écran. Utilisez le même compte Google sur les deux appareils.
6. Sur le PC, choisissez **Générer un code**, puis **Associer ce profil**. Saisissez le même code dans le profil Fire TV que vous souhaitez associer. Configurez la même adresse de serveur Xtream et le même nom d’utilisateur sur les deux appareils.

En mode Testing, les jetons d’actualisation Google expirent généralement après sept jours pour l’accès Drive. [Documentation Google OAuth](https://developers.google.com/identity/protocols/oauth2#expiration)

## Faire un essai

1. Lancez un film ou un épisode sur le PC, puis quittez la lecture.
2. Sur la TV, ouvrez **Synchroniser maintenant**. Vérifiez **Reprendre** et relancez la vidéo.
3. Refaites l’essai dans l’autre sens. Vérifiez qu’un autre profil NOVA sans association conserve sa propre progression.

La synchronisation se lance après une lecture, une fois par minute avec un profil associé et à la demande. Le dernier changement gagne pour un même film ou épisode. Les sources M3U et le direct restent locaux durant cet essai.

À partir de la 0.11.11, **Retirer de Continuer à regarder** efface la progression du titre sur le profil actif, y compris celle des épisodes pour une série. Pour synchroniser ce retrait, installez la 0.11.11 ou une version ultérieure sur les appareils associés.

NOVA demande l’autorisation Drive limitée à son dossier privé `appDataFolder`. Le fichier envoyé contient des clés pseudonymes, des positions, des durées et des dates, ainsi que l’état « vu ». Les mots de passe IPTV, noms d’utilisateur et URLs de lecture ne sont pas transmis. Sur le PC, la connexion utilise le navigateur système, un retour sur une adresse locale aléatoire et PKCE. Les jetons sont protégés par DPAPI sur Windows et par Android Keystore sur TV. **Déconnecter cet appareil** efface la connexion locale. Les autres appareils gardent la leur.

Liens Google : [Stockage privé Drive](https://developers.google.com/workspace/drive/api/guides/appdata), [connexion sur TV](https://developers.google.com/identity/protocols/oauth2/limited-input-device) et [connexion sur ordinateur](https://developers.google.com/identity/protocols/oauth2/native-app).
