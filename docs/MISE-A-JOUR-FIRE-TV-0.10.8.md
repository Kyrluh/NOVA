# TV 0.10.8 — Vérification des mises à jour

Ce correctif, d’abord préparé localement, est maintenant intégré à la [release 0.11.1](RELEASE-0.11.1.md) pour Android mobile et TV. Utiliser l’APK de cette release pour l’installation manuelle.

Le contrôle natif demande les certificats via les informations Android modernes et historiques. Si les informations modernes sont absentes, il essaie la lecture historique du package installé et de l’archive APK. L’égalité des certificats, l’identifiant de package, la version croissante et le confinement au cache privé restent obligatoires. Aucune installation non signée ni de signature différente n’est autorisée.

Les erreurs distinguent maintenant un fichier inaccessible, une archive illisible, une mauvaise édition, une version trop ancienne, des certificats illisibles et une véritable différence de signature. Les erreurs système ne dévoilent ni chemins ni détails internes.

Les APK TV 0.10.6 et 0.10.7 ont été vérifiées avec apksigner : elles sont valides et utilisent le même certificat SHA-256 `62fafe6de54629f3d7485d2dcebc81664709ac9ec7c67456822c7614e36b4dd0`. Le fichier TV 0.10.7 publié correspond à l’empreinte locale vérifiée. Le contrôle exact qui échoue sur la Fire Stick concernée n’a pas été observé sur l’appareil : la compatibilité doit encore y être confirmée.

L’APK TV locale 0.10.8+40 conserve la signature existante. La correction étant dans le code de l’application installée, un ancien gestionnaire qui bloque nécessite une installation manuelle initiale de l’APK officielle, par-dessus NOVA, sans désinstallation. Les données sont ainsi conservées si l’installation réussit.

La préparation locale 0.10.8 recompilait uniquement l’édition TV. La release 0.11.1 intègre ensuite ce correctif dans les APK mobile et TV. Aucune installation ADB n’est effectuée.
