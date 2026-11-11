# Mise à jour de NOVA depuis les paramètres — 0.10.2

Une entrée **Mise à jour de l’application** est disponible dans les paramètres Windows, Android mobile et TV. La version installée et l'édition réelle sont lues depuis l'application native, sans numéro de version recopié dans l'interface.

## Utilisation

1. Ouvrir **Paramètres → Mise à jour de l’application**.
2. Choisir **Vérifier les mises à jour**.
3. Si une nouvelle version compatible existe, sélectionner son bouton de téléchargement.

| Application installée | Fichier choisi |
| --- | --- |
| Windows x64 | `NOVA-IPTV-<version>-windows-x64.zip` |
| Android TV / Fire TV, package `app.nova.iptv.tv` | `NOVA-IPTV-TV-<version>-universal.apk` |
| Téléphone Android ARM64 | `NOVA-IPTV-<version>-arm64-v8a.apk`, ou l'universelle si absente |
| Autre téléphone Android compatible | `NOVA-IPTV-<version>-universal.apk` |

La recherche utilise l'API publique GitHub du dépôt `Kyrluh/NOVA`, sans clé ni compte utilisateur. La dernière release stable est consultée en premier. Si elle ne contient aucun fichier pour cette édition, NOVA recherche la dernière version stable compatible dans les publications précédentes (jusqu'à 60 releases). Les brouillons, préversions, sources et fichiers d'une autre édition sont écartés.

Les versions sont comparées numériquement : `0.10.0` est bien plus récent que `0.9.12`. Une version égale ou plus ancienne n'est pas proposée comme mise à jour. Une panne réseau ou une limite GitHub affiche un message et laisse le reste de NOVA utilisable.

## Installation Android et Fire TV

L'APK est téléchargée dans le cache privé de NOVA avec progression. Sa taille et son empreinte SHA-256 GitHub sont vérifiées. Un téléchargement incomplet ou différent n'est pas présenté à l'installateur ; un fichier déjà téléchargé et vérifié peut être réutilisé.

Le composant Android vérifie ensuite que l'APK vise le même package, porte la même signature que l'application installée et possède un code de version supérieur. Le fichier est partagé avec l'installateur par un `FileProvider` limité au dossier privé des mises à jour, avec un accès temporaire en lecture.

Android peut demander d'autoriser **NOVA** à installer des applications inconnues. Le bouton **Autoriser l’installation** ouvre les réglages système ; revenir ensuite dans NOVA et choisir **Installer la mise à jour**. Selon Fire OS, l'autorisation peut se trouver dans les options développeur de la Fire TV. L'installation reste confirmée par l'utilisateur dans l'installateur Android.

Ne pas désinstaller NOVA : une mise à jour du même package et de la même signature conserve les sources, profils et préférences. Les applications téléphone et TV restent distinctes. Les versions de débogage ne proposent pas ce parcours de mise à jour Release.

## Windows portable

Le bouton **Télécharger le ZIP Windows** ouvre le lien GitHub exact dans le navigateur. Fermer NOVA, extraire **tout** le nouveau ZIP, puis lancer la nouvelle version. Les données de l'application restent dans son dossier de données Windows. Cette étape ne remplace pas automatiquement les fichiers d'une application en cours d'utilisation.

## Déploiement initial

Les anciennes versions ne contiennent pas ce bouton. Installer **0.10.2+34** une première fois manuellement pour disposer du gestionnaire des mises à jour suivantes. Les signatures Android de production sont conservées. Aucun service ou téléchargement automatique au démarrage n'est ajouté.

Les sources de 0.10.2 sont poussées sur GitHub. Les installables sont préparés localement dans `dist/`, `dist/android/` et `dist/android-tv/` ; la dernière release publique reste 0.10.1 tant que la publication suivante n'est pas demandée.

## Vérification

Neuf contrôles courts ont réussi : six dédiés au gestionnaire (choix de l'édition et des architectures, releases partielles, limite GitHub, intégrité/cache, parcours TV simulé et retour de l'autorisation Android sans retéléchargement) et trois pour les paramètres adaptatifs. Aucun émulateur ni installation ADB n'est utilisé. Le parcours de confirmation et les réglages des applications inconnues restent à confirmer sur le téléphone et la Fire TV physiques.

Windows x64, Android téléphone ARM64/universel et Android TV universel ont été compilés en Release **0.10.2+34**. Le package, la signature de production existante, les architectures et l'alignement APK 16 KiB ont été vérifiés. Les archives Windows et source ont reçu leurs empreintes SHA-256 et le contrôle d'exclusion des fichiers privés. Le mode développeur Windows n'a pas été activé ; Gradle a été arrêté après compilation.

Références des API utilisées : [releases GitHub](https://docs.github.com/en/rest/releases/releases), [installation Android](https://developer.android.com/reference/android/content/pm/PackageManager#canRequestPackageInstalls()), [partage d'un fichier privé](https://developer.android.com/reference/androidx/core/content/FileProvider).
