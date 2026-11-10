# Installer et mettre à jour NOVA IPTV sur Android

## APK à choisir

- **ARM64** : adaptée aux Galaxy Z Fold et aux téléphones Android récents.
- **Universelle** : inclut ARM64, ARM32 et x86_64 pour davantage d'appareils.

Android 7.0/API24 minimum. Le package de production est `app.nova.iptv`. Les versions de test utilisent un package distinct, `app.nova.iptv.debug`.

1. Copier l'APK sur le téléphone par USB, un espace de fichiers personnel ou un autre moyen choisi.
2. Ouvrir l'APK depuis **Mes fichiers** et autoriser cette application à installer des applications inconnues lorsque le système le demande.
3. Si les protections d'installation Samsung ou de l'entreprise refusent le fichier, vérifier leurs réglages et leur message. L'application ne modifie aucune protection du téléphone.
4. Ouvrir **NOVA IPTV**, puis **Plus → Paramètres → Gérer les sources**, ou l'accès d'ajout de source sur l'accueil.
5. Ajouter ses propres sources M3U ou Xtream et, si nécessaire, le guide XMLTV. Aucun abonnement ou serveur IPTV n'est fourni.

Les sources chiffrées Windows ne peuvent pas être déchiffrées par le téléphone : leurs protections sont propres à chaque système. Renseigner les mêmes paramètres autorisés dans l'application Android. Aucune copie automatique de mots de passe n'est effectuée.

## Utilisation

L'écran compact possède une navigation inférieure ; **Plus** donne accès aux favoris, historique, reprise, plateformes, tri et paramètres. Sur grand écran, le menu latéral est disponible. La liste TV et la vidéo se partagent l'espace lorsque la fenêtre le permet.

Depuis0.6.5, les catalogues des sources configurées sont actualisés automatiquement à chaque lancement. Le catalogue enregistré reste accessible pendant le chargement. Le bandeau en haut indique la source, l'étape et la progression ; sans connexion ou si le fournisseur refuse la demande, le dernier catalogue reste disponible. Le guide XMLTV et les tendances internet ont toujours leurs boutons d'actualisation distincts.

Dans le lecteur : tap pour les commandes, glissement gauche pour la luminosité, glissement droit pour le volume, doubles appuis gauche/droite pour ±10 secondes en VOD. Le cadenas empêche les gestes involontaires. Les gestes, le PiP, la reconnexion et le paysage automatique sont réglables. Les pistes et le ratio restent accessibles dans les commandes du lecteur. Le direct n'effectue pas de seek sans timeshift.

Depuis 0.6.3, l'ATH propose aussi un bouton lecture/pause au centre de l'image. Écarter deux doigts remplit l'écran en recadrant l'image ; les rapprocher réaffiche l'image entière. Le pincement suit le réglage général des gestes et le verrouillage tactile. Il conserve le lecteur et la position en cours. Dans la liste TV, le bouton **Ordre des chaînes** permet de choisir **Ordre de la source** ou un autre tri. La première ouverture de cette mise à jour rétablit l'ordre de la source en conservant les filtres, favoris et progressions ; les choix de tri effectués ensuite sont conservés.

Pour les séries et animés, **Épisode précédent** et **Épisode suivant** parcourent les saisons dans l'ordre. Un bouton grisé indique une extrémité ou un épisode indisponible. Le changement manuel conserve la progression ; l'enchaînement automatique se règle dans les paramètres. Depuis 0.6.2, les épisodes M3U sont réunis sous une fiche de série à partir des noms S01E02/1x02/Episode, des attributs de saison/épisode ou des entrées déclarées séries/animés. Sans numéros fournis, ils restent dans l'ordre de la playlist dans une seule saison. Les films et chaînes ne sont pas regroupés en collections arbitraires.

Le PiP nécessite la prise en charge et l'autorisation Android. Une lecture active peut être placée en PiP puis ramenée au premier plan. La page de lecture conserve sa session lors du redimensionnement ; changer volontairement de chaîne ou quitter la page reste une action de lecture distincte.

## Mise à jour

Installer la nouvelle APK par-dessus l'ancienne, sans désinstaller l'application. Les versions ARM64 et universelle utilisent la même signature et le même `versionCode`, ce qui permet de changer de variante. Une nouvelle livraison doit augmenter le code de version dans `pubspec.yaml`.

## Signature conservée

La clé de production et son mot de passe protégé sont conservés dans le dossier **`.signing` du projet**, exclu de Git et de toutes les archives de sources. La clé privée n'est pas incluse dans l'APK. La protection automatique du mot de passe est liée au compte Windows de compilation.

Avant un changement de PC ou une réinstallation de Windows, créer une sauvegarde portable chiffrée de la même clé avec un mot de passe connu de son propriétaire :

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\backup-android-signing.ps1 -Mode Export
```

Le script demande le mot de passe localement et crée `.signing/nova-android-portable-backup.p12`. Conserver ce fichier en lieu privé. Sur un nouveau poste dépourvu de signature de production :

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\backup-android-signing.ps1 -Mode Restore -BackupPath 'D:\Ma sauvegarde privee\nova-android-portable-backup.p12'
```

Le script refuse de remplacer une clé de production existante. Perdre la clé empêche de signer des mises à jour compatibles ; ne pas distribuer `.signing` avec les APK destinées aux amis.

## Compiler à nouveau sous Windows

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\bootstrap.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\bootstrap-android.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\flutter.ps1 pub get
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-android.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\package-android.ps1
```

`initialize-android-signing.ps1` sert uniquement au premier poste sans signature, ou après restauration appropriée. Il conserve une clé existante ; les mises à jour doivent réutiliser celle de la première livraison. Le JDK, le SDK et le cache Gradle restent locaux dans `.tools`, sans installation d'un service de fond pour l'application.

Lancer les commandes Flutter les unes après les autres. Le script de compilation conserve la régénération des plugins de production ; il faut la laisser active après les tests Android pour ne pas réutiliser le registre des plugins de test.

Les liens de plugins Flutter peuvent nécessiter le mode développeur Windows pendant la compilation. Le réglage temporaire doit être restauré avec `scripts/enable-developer-mode.ps1 -Mode Restore` après les travaux. Il n'est pas nécessaire pour utiliser l'APK.
