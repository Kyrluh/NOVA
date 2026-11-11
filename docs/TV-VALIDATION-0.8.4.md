# NOVA IPTV TV 0.8.4 — Ordre des chaînes fourni par la source

**APK TV uniquement : 0.8.4+22**, package `app.nova.iptv.tv`. Téléphone et Windows restent distribués en **0.8.3+21**.

La liste TV utilisait les préférences du profil, qui pouvaient conserver un ancien tri alphabétique. La page dédiée TV ne présentait pas de choix d'ordre direct, contrairement au lecteur des interfaces téléphone/Windows.

- L'application TV applique une migration unique par profil vers **Ordre de la source**, au chargement puis lors de l'ouverture des autres profils concernés.
- Seul l'ordre des chaînes est changé. Les langues/catégories masquées, favoris, progressions, préférences des films/séries et sources restent conservés.
- **TV en direct → Ordre des chaînes** propose Ordre de la source, titres et catégories. Les choix explicites effectués après cette migration sont conservés au redémarrage.
- L'ordre de la source conserve celui du catalogue importé, y compris pendant une recherche ou un filtrage de catégorie. Il ne s'agit pas d'une numérotation TNT inventée : le fournisseur doit transmettre l'ordre désiré.
- Windows et téléphone gardent leur comportement et leurs choix précédents.

Validation courte : **quatre tests ciblés passent** (migration des anciens profils TV et persistance des nouveaux choix ; ordre réel des cartes TV TF1 → France 2 → Arte, recherche puis changements explicites ; migration Android existante ; préférences Windows conservées). La liste a également été vérifiée dans une surface réduite de 480×300 pour le nouveau contrôle. Analyse statique des quatre fichiers concernés sans anomalie. Pas de suite complète, d'émulateur ou de TV physique pour ce correctif.

Compilation Release de l'APK TV universelle, vérification du package, version/code, signature de production conservée, architectures ARM32/ARM64/x86_64, alignement ZIP et SHA-256. Aucune compilation Windows ni téléphone annoncée pour cette livraison.

Installer la nouvelle APK **NOVA-IPTV-TV** par-dessus l'ancienne, sans désinstaller. Ouvrir chaque profil concerné, puis TV en direct ; l'ordre par défaut doit être **Ordre de la source**.
