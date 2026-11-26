import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../state/app_controller.dart';
import '../../sync/drive_resume.dart';

class DriveResumePanel extends StatefulWidget {
  const DriveResumePanel({super.key, required this.controller});
  final AppController controller;

  @override
  State<DriveResumePanel> createState() => _DriveResumePanelState();
}

class _DriveResumePanelState extends State<DriveResumePanel> {
  final _clientId = TextEditingController();
  final _clientSecret = TextEditingController();
  final _profileCode = TextEditingController();
  String? _generatedCode;

  Future<void> _associate(AppController app, {String? existingCode}) async {
    final code = existingCode ?? _profileCode.text.trim().toLowerCase();
    if (!isDriveProfileCode(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saisissez le code de profil de 32 caractères.'),
        ),
      );
      return;
    }
    final bool? createLocal;
    if (existingCode == null && code == _generatedCode) {
      createLocal = false;
    } else {
      createLocal = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Associer le profil synchronisé'),
          content: const Text(
            'Remplace le profil actuel par celui du Drive ou crée un profil séparé. Les sources de cet appareil restent en place.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Remplacer le profil actuel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Créer un nouveau profil'),
            ),
          ],
        ),
      );
    }
    if (!mounted || createLocal == null) return;
    await app.associateDriveProfile(
      code,
      createLocal: createLocal,
      importExisting: code != _generatedCode,
    );
  }

  @override
  void dispose() {
    _clientId.dispose();
    _clientSecret.dispose();
    _profileCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.controller;
    final drive = app.driveResume;
    if (drive == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: drive,
      builder: (context, _) {
        final profile = app.activeProfileId;
        final link = drive.deviceConsent;
        final code = drive.codeFor(profile);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Synchronisation Google Drive (essai)'),
            const SizedBox(height: 8),
            const Text(
              'Synchronise la reprise et les épisodes vus pour les sources Xtream. Les identifiants IPTV restent sur cet appareil.',
            ),
            const SizedBox(height: 12),
            if (!drive.connected && drive.mobile) ...[
              const Text(
                'Choisissez sur Android le même compte Google que sur vos autres appareils.',
              ),
              FilledButton(
                onPressed: drive.busy ? null : drive.connectMobile,
                child: const Text('Connecter Google Drive'),
              ),
            ] else if (!drive.connected) ...[
              Text(
                drive.television
                    ? 'Utilisez le client OAuth « TV et périphériques à saisie limitée » de votre projet Google Cloud.'
                    : 'Utilisez le client OAuth « Application de bureau » de votre projet Google Cloud.',
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _clientId,
                enabled: !drive.busy,
                autocorrect: false,
                enableSuggestions: false,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'ID du client OAuth',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _clientSecret,
                enabled: !drive.busy,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                maxLength: 150,
                decoration: const InputDecoration(
                  labelText: 'Secret du client OAuth',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              if (drive.busy) ...[
                if (link != null) ...[
                  Text(
                    'Sur ton téléphone, ouvre ${link.$1} puis saisis ce code :',
                  ),
                  Text(
                    link.$2,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ] else
                  const Text('En attente de l’autorisation Google…'),
                OutlinedButton(
                  onPressed: drive.cancelConnect,
                  child: const Text('Annuler'),
                ),
              ] else
                FilledButton(
                  onPressed: () {
                    final id = _clientId.text.trim();
                    final secret = _clientSecret.text.trim();
                    _clientSecret.clear();
                    unawaited(drive.connect(id, secret));
                  },
                  child: const Text('Connecter Google Drive'),
                ),
            ] else ...[
              Text('Profil NOVA : ${app.activeProfile.displayName}'),
              if (code == null) ...[
                const Text(
                  'Copiez le même code de profil sur l’autre appareil, avec le même compte Google.',
                ),
                TextField(
                  controller: _profileCode,
                  enabled: !drive.busy,
                  autocorrect: false,
                  enableSuggestions: false,
                  maxLength: 32,
                  decoration: const InputDecoration(
                    labelText: 'Code de profil',
                  ),
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: drive.busy
                          ? null
                          : () {
                              _generatedCode = newDriveProfileCode();
                              _profileCode.text = _generatedCode!;
                            },
                      child: const Text('Générer un code'),
                    ),
                    FilledButton(
                      onPressed: drive.busy ? null : () => _associate(app),
                      child: const Text('Associer ce profil'),
                    ),
                  ],
                ),
              ] else ...[
                SelectableText(code),
                if (!app.driveProfileEnabled) ...[
                  const Text(
                    'Ce code synchronise déjà la reprise. Choisis quel profil doit servir de référence pour les réglages et les listes.',
                  ),
                  Wrap(
                    spacing: 10,
                    children: [
                      FilledButton(
                        onPressed: drive.busy
                            ? null
                            : () => app.associateDriveProfile(
                                code,
                                createLocal: false,
                                importExisting: false,
                              ),
                        child: const Text('Publier ce profil comme référence'),
                      ),
                      OutlinedButton(
                        onPressed: drive.busy
                            ? null
                            : () => _associate(app, existingCode: code),
                        child: const Text('Importer le profil associé'),
                      ),
                    ],
                  ),
                ],
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    if (!drive.television)
                      OutlinedButton(
                        onPressed: () =>
                            Clipboard.setData(ClipboardData(text: code)),
                        child: const Text('Copier le code du profil'),
                      ),
                    FilledButton(
                      onPressed: drive.busy
                          ? null
                          : () => app.syncDriveResume(force: true),
                      child: const Text('Synchroniser maintenant'),
                    ),
                  ],
                ),
                if (drive.lastSync case final last?)
                  Text(
                    'Dernière synchronisation à ${TimeOfDay.fromDateTime(last).format(context)}',
                  ),
              ],
              OutlinedButton(
                onPressed: drive.busy ? null : drive.disconnect,
                child: const Text('Déconnecter cet appareil'),
              ),
            ],
            if (drive.busy) const LinearProgressIndicator(),
            if (drive.problem case final problem?) Text(problem),
          ],
        );
      },
    );
  }
}
