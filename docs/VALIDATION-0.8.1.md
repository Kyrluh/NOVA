# NOVA IPTV 0.8.1 — Notification de reprise et formulaire Xtream

Windows et Android : **0.8.1+19**.

- Le bandeau Retiré de Continuer à regarder est explicitement temporaire : quatre secondes, bouton Annuler fonctionnel et croix de fermeture. Les anciens bandeaux sont effacés avant d'afficher le suivant pour éviter leur accumulation. Le SDK Flutter local rendait les notifications avec action persistantes par défaut.
- Xtream Codes est la première entrée du menu Type de source et le choix par défaut d'une nouvelle source. Les sources existantes gardent leur type lors de la modification.
- Fournisseur affiché **Kyrlu**, avec mode **MDP prédéfini** choisi automatiquement lors de sa sélection, ou **Autre · saisir un mot de passe**. Le préréglage n'est pas affiché dans un champ révélable. L'adresse du serveur et le nom d'utilisateur restent à renseigner.
- Le fournisseur et le mode du mot de passe sont conservés dans la configuration protégée de la source. Les anciennes configurations restent compatibles. Les sources M3U ne conservent pas de mot de passe ni d'identifiant Xtream.
- La navigation clavier/télécommande suit les seuls champs visibles, y compris le choix du fournisseur et du mode du mot de passe.

## Configuration de compilation

Le code public ne contient pas le mot de passe distribué. Le wrapper `scripts/flutter.ps1` ajoute, uniquement pour les compilations, le fichier facultatif `.signing/provider-presets.json` via `--dart-define-from-file`. Ce fichier contient localement la valeur de `NOVA_KYRLU_PASSWORD` et reste exclu de Git. Sans cette configuration, la saisie manuelle reste disponible et le choix prédéfini est désactivé. Un secret intégré à un installable reste extractible : le nom d'affichage ne constitue pas une protection du fournisseur.

## Vérification ciblée

Quatre tests passent : expiration/annulation du bandeau, préréglage Kyrlu avec faux mot de passe de test puis saisie personnalisée et passage M3U, saisie M3U à la télécommande, navigation Xtream avec les flèches. Le test vérifie également la conservation du mode lors de la sérialisation de la configuration. Analyse statique des six fichiers concernés sans anomalie. Les autres scénarios du formulaire ont été adaptés au nouveau type par défaut, sans relancer une suite complète.

Compilations Release Windows x64, Android ARM64, Android universelle et TV universelle. Contrôles de packaging Android (versions, packages, signatures, architectures, alignement ZIP et SHA-256). Aucun nouvel essai physique ni émulateur pour ce correctif. Les packages et signatures restent ceux des versions précédentes : installer les APK par-dessus sans désinstaller.
