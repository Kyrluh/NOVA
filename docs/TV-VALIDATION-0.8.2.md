# NOVA IPTV TV 0.8.2 — Saisie des sources à la télécommande

**Windows, téléphone et TV : 0.8.2+20**. Le clavier natif concerne l'APK TV `app.nova.iptv.tv` ; la liste des serveurs Xtream est disponible sur les trois interfaces.

Le formulaire utilisait des champs Flutter dans une zone comportant des raccourcis haut/bas. Naviguer à la télécommande et saisir dans ces mêmes champs pouvait rendre l'édition difficile sur les claviers de TV. La saisie TV est désormais séparée de la navigation du formulaire :

1. Haut/bas sélectionne un champ, qui montre un cadre de focus et l'indication OK pour modifier.
2. OK ou Entrée ouvre une boîte de saisie Android native avec un vrai `EditText` et le clavier système. Les raccourcis du formulaire Flutter ne reçoivent pas les touches de cette fenêtre native.
3. L'URL utilise le type de clavier URI, sans correction automatique. Le texte initial est conservé et le curseur se place à la fin, sans sélection automatique de tout le contenu.
4. Valider ou l'action Terminé du clavier applique le texte ; Annuler, Retour ou la fermeture de l'activité abandonne la saisie. Le résultat n'est envoyé qu'une fois et la boîte native est fermée proprement.
5. Le focus revient au champ. Bas permet de continuer vers le suivant. Le nom, l'identifiant, le mot de passe personnalisé et XMLTV utilisent le même parcours. Un mot de passe personnalisé reste masqué.

Les champs Windows/téléphone gardent leur fonctionnement existant. Les adresses personnelles et identifiants ne sont ni journalisés ni ajoutés au dépôt. Le préréglage Kyrlu est conservé, avec sa configuration locale privée de compilation.

Pour Xtream uniquement, le formulaire propose les sept adresses demandées : `http://predb.click`, `http://smpj4.online`, `http://mo8q8.online`, `http://draap.online`, `http://liveprotv.com`, `http://4kib.xyz` et `http://usica.space`. Choisir une adresse évite de la retaper. **Saisir une autre URL** retrouve le texte personnalisé précédent ; sur TV, OK ouvre alors le clavier natif. Les sources M3U gardent leur propre champ et ne reçoivent pas cette liste. La disponibilité réseau de ces serveurs n'a pas été testée.

Validation courte : **cinq tests ciblés passent**. Le nouveau scénario ouvre l'URL d'une source existante par OK, vérifie le passage au pont natif, les caractères spéciaux de l'URL, la validation, l'annulation, le retour du focus, la navigation au champ suivant et l'enregistrement. Deux tests vérifient les sept serveurs et le retour à la saisie personnalisée sur les interfaces standard et TV. Les deux parcours existants M3U/Xtream à la télécommande passent également. Le pont natif est simulé dans le test de widgets ; ce test ne simule pas le clavier réel de Fire OS. Analyse statique des cinq fichiers Dart concernés sans anomalie.

Compilations Release Windows x64, Android ARM64, Android universelle et TV universelle, avec vérification des packages Android, du numéro de version, de la signature existante, des architectures ARM32/ARM64/x86_64, de l'alignement ZIP et des empreintes SHA-256. Aucun émulateur ni appareil physique utilisé pour ce correctif. L'ouverture et l'ergonomie du clavier système restent à confirmer sur la TV/Fire Stick de l'utilisateur.

Installer la nouvelle APK TV par-dessus l'ancienne, sans désinstaller ; les sources et profils sont conservés.
