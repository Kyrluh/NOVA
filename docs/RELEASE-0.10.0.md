# NOVA IPTV 0.10.0 — Windows, Android et TV

Cette version réorganise la navigation et les fiches selon l'appareil. Les profils, sources, favoris, reprises, genres préférés et filtres existants sont conservés.

## Nouveautés

- Accueil : les six raccourcis Reprendre, Favoris, TV, Films, Séries et Par plateforme précèdent la suggestion personnalisée ; Reprendre reste suivi des ajouts récents.
- Windows : accès fixes aux sources, au profil et aux paramètres ; recherche globale avec Ctrl+F/Ctrl+K. Ces raccourcis préservent le lecteur plein écran.
- Android téléphone et Fold : accueil compact, menu Plus organisé, retour Android adapté et grilles selon la place disponible.
- TV : accès directs à la recherche, aux sources, au profil et aux paramètres ; retour vers la rubrique précédente et fiches plus compactes pour la télécommande.
- Catalogues : catégories recherchables, filtres conservés pendant la session et explications adaptées lorsqu'aucun résultat n'est disponible.
- Fiches : lecture/reprise, versions et favoris avant le synopsis repliable ; repère unique et défilement vers l'épisode à reprendre.
- Paramètres regroupés par usage. Le tri par ajouts récents, l'ordre des chaînes de la source et le lancement sans sous-titres restent conservés.

## Fichiers à télécharger

| Appareil | Fichier |
| --- | --- |
| Windows x64 | `NOVA-IPTV-0.10.0-windows-x64.zip` |
| Téléphone Android ARM64, dont Galaxy Z Fold | `NOVA-IPTV-0.10.0-arm64-v8a.apk` |
| Autres téléphones Android compatibles | `NOVA-IPTV-0.10.0-universal.apk` |
| Android TV, Google TV et Fire OS compatible | `NOVA-IPTV-TV-0.10.0-universal.apk` |
| Sources du projet et licences | `NOVA-IPTV-0.10.0-source.zip` |
| Vérification des téléchargements | `SHA256SUMS.txt` |

Sous Windows, extraire tout le ZIP puis lancer `NOVA_IPTV.exe`. Sur Android, installer l'APK correspondant à l'application existante sans la désinstaller pour conserver ses données. La signature de production est conservée ; les APK portent le code de version 32, avec Android 7.0/API 24 minimum. L'application TV (`app.nova.iptv.tv`) et l'application téléphone (`app.nova.iptv`) restent distinctes. Une Fire TV sous Vega OS ne peut pas installer ces APK Android.

## Validation

Les binaires Windows et téléphone ont été compilés en Release lors de l'adaptation Windows/mobile. L'APK TV est la Release 0.10.0 déjà construite à l'étape TV précédente. Cette publication ne prétend pas ajouter de nouvelle compilation ni de nouveaux essais physiques.

Les contrôles précédents comprennent 26 scénarios ciblés Windows/mobile et 15 scénarios TV, ainsi que les analyses et aperçus des interfaces. Les signatures, versions, architectures, alignements Android et empreintes des fichiers publiés sont vérifiés. Les essais prolongés et le pliage/dépliage en lecture sur téléphone physique restent à confirmer. Aucun appareil n'est installé ou modifié à l'occasion de cette publication.

Les installables ne contiennent aucun compte ou abonnement IPTV fourni avec NOVA. Les sources personnelles configurées par l'utilisateur restent nécessaires.
