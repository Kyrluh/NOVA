# NOVA IPTV TV 0.7.0+15

## Livraison

Première APK TV distincte : `app.nova.iptv.tv`, label **NOVA IPTV TV**, lanceurs standard et Leanback, bannière TV, paysage et absence d'exigence tactile. Signature de production NOVA conservée. APK universelle ARM32/ARM64/x86_64, minSdk24 et targetSdk36.

La version téléphone publiée reste **0.6.6+14** et Windows reste **0.6.5+13** ; aucune nouvelle compilation de ces deux applications n'est annoncée. L'application TV possède son propre stockage Android et peut cohabiter avec la version téléphone.

## Réutilisation

Le client M3U/Xtream, le regroupement séries/saisons, XMLTV, le stockage chiffré, les règles de tri/langues, les favoris, l'historique, la reprise et le moteur media_kit/libmpv sont partagés. Seule la présentation TV est distincte. Les chaînes conservent leur ordre et leur lecteur reste la même instance pendant les changements de média/plein écran. Les gestes tactiles et le PiP ne sont pas proposés dans cette interface.

## Vérifications ciblées

**Huit tests ciblés réussis** :

- Navigation D-pad/Select : TV, films, carte, fiche et accès à la lecture.
- Reprise d'une série : bonne saison et bon épisode en cours.
- Dispositions960×540,1280×720 et720×400 ; défilement du menu vers Sources et Plateformes, logos sans débordement.
- Lecture/pause par OK et touche multimédia, y compris avec le focus hors du lecteur.
- Navigation de la barre de commandes sans seek involontaire et accès aux menus.
- Direct : changement de chaîne sans seek.
- Formulaires M3U/Xtream accessibles par Suivant/Valider et flèches.
- Conservation du parcours du petit lecteur Android préexistant sélectionné par les tests ciblés.

Analyse statique limitée aux fichiers concernés ; remarques d'accolades corrigées. Compilation Release réelle et contrôles du manifeste, du package, des ABI, du certificat et de l'alignement APK. Le contrôle de package a rejeté une première compilation qui gardait le package téléphone ; la sélection Gradle utilise désormais le même `dart-define` que Flutter pour éviter cette divergence.

Pas de suite complète, test d'endurance ou émulateur TV pour cette livraison. **Aucune TV physique ni Fire TV Stick réel n'a été testé** : installation, saisie du clavier constructeur, codecs, décodage matériel et comportement exact de la télécommande restent à confirmer sur l'appareil de l'utilisateur. L'APK cible les appareils Android/Fire OS compatibles API24+, pas Vega OS.
