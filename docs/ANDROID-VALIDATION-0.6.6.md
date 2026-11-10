# Correctif Android 0.6.6+14 — formulaire de source à la télécommande

Le formulaire possède maintenant des nœuds de focus explicites et un ordre adapté au type de source. Les touches haut/bas passent d'un contrôle au suivant sans être interprétées comme des déplacements du curseur dans un champ sur une seule ligne. Les flèches gauche/droite restent disponibles pour l'édition du texte. Le menu du type de source conserve sa navigation propre.

Les actions Suivant/Valider du clavier passent explicitement au champ suivant. En M3U, les champs utilisateur/mot de passe absents sont ignorés. En Xtream, le parcours passe par ces deux champs. Depuis le dernier champ XMLTV facultatif, Valider masque le clavier et sélectionne le bouton Ajouter/Enregistrer ; le bouton OK de la télécommande l'active. Le champ recevant le focus est ramené dans la zone visible. Les contrôles sont libérés à la fermeture du formulaire.

Vérification volontairement limitée : **deux tests ciblés réussis**, parcours M3U avec actions du clavier et activation par Select, parcours Xtream par les flèches avec clavier masqué. Analyse statique limitée au formulaire et à ces tests. Aucun essai poussé, aucune suite complète ni émulateur TV. Le comportement reste à confirmer sur la TV et son clavier système.

APK ARM64 et universelle produites avec le package `app.nova.iptv`, le code de version14 et la signature de production conservée. Installer la mise à jour sans désinstaller la version précédente. Les versions publiées précédemment sur GitHub restent inchangées.
