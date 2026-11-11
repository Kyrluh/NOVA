# NOVA IPTV 0.8.5 — Préréglage de langues et catégories

Version commune Windows, Android téléphone et TV : **0.8.5+23**.

## Données reprises

Le préréglage est extrait des préférences du profil Windows actif du propriétaire. Il reprend uniquement les langues et noms de catégories explicitement masqués :

| Catalogue | Langues masquées | Catégories masquées |
| --- | ---: | ---: |
| TV | 18 | 52 |
| Films | 4 | 8 |
| Séries | 3 | 12 |

Les listes sont stockées dans `lib/domain/catalog_defaults_data.dart`. Les identifiants de source propres au PC sont retirés ; aucune adresse personnelle, clé, information de compte, préférence de lecture, identité de profil, progression ou liste de favoris n'est copiée. Le préréglage ne revient pas à imposer uniquement le français : il conserve exactement les langues masquées dans les réglages repris.

## Application et personnalisation

- Une installation/profil sans préférences de catalogue reçoit les langues du préréglage. Un catalogue de démonstration ne reçoit pas de masquages de catégories associés à une source réelle.
- Au premier catalogue de chaque source/type, les catégories sont retrouvées par nom, sans dépendre de l'identifiant de source du PC d'origine. La comparaison ignore la casse et les espaces superflus.
- Le fonctionnement couvre les sources déjà importées lors de la création d'un profil, ainsi que l'ajout de la première source après le démarrage.
- Chaque source/type est initialisé une seule fois. Recocher une langue ou une catégorie reste possible dans Tri et affichage ; une actualisation ne remet pas automatiquement les cases dans leur état initial.
- Les groupes absents d'un catalogue n'entraînent pas d'erreur. Une catégorie portant un nom différent n'est pas rapprochée arbitrairement.
- Les profils qui possèdent déjà des préférences, même entièrement ouvertes, les conservent. Aucun fichier de l'installation Windows du propriétaire n'est modifié.
- Une nouvelle source ajoutée à un profil utilisant le préréglage reçoit les catégories initiales correspondantes. Les choix restent propres à chaque profil et appareil.

## Vérification ciblée

**Huit tests passent** : quatre nouveaux scénarios (nouvelle installation avec d'autres identifiants de source ; import après démarrage ; cases recochées conservées après actualisation et redémarrage ; ancien profil conservé et nouveau profil initialisé), ainsi que quatre scénarios existants d'ordre des chaînes et profils TV/Android/Windows. Analyse statique des quatre fichiers de la modification sans anomalie. Pas de suite complète ni d'émulateur.

Compilations Release Windows x64, Android ARM64, Android universelle et TV universelle, contrôles des packages, versions, architectures, signatures de production, alignement ZIP et empreintes SHA-256. Pas de nouveau test sur appareil physique ou sur les flux du fournisseur.

Installer les APK par-dessus les anciennes sans désinstaller ; les profils existants gardent leurs choix. Pour constater le préréglage sur une installation déjà personnalisée, créer un nouveau profil plutôt que supprimer ses données. Sur Windows, extraire le ZIP entier et fermer l'ancienne application avant d'ouvrir la nouvelle.
