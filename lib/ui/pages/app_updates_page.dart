import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../updates/app_updates.dart';
import '../theme.dart';
import '../tv/tv_widgets.dart';

class AppUpdatesPanel extends StatefulWidget {
  const AppUpdatesPanel({super.key, this.television = false, this.service});
  final bool television;
  final AppUpdateService? service;
  @override
  State<AppUpdatesPanel> createState() => _AppUpdatesPanelState();
}

class _AppUpdatesPanelState extends State<AppUpdatesPanel>
    with WidgetsBindingObserver {
  late final _service = widget.service ?? AppUpdateService();
  InstalledApp? _installed;
  AppRelease? _release;
  bool _busy = false;
  bool _checked = false;
  bool _permission = false;
  bool _settingsOpened = false;
  int _received = 0;
  int _total = 0;
  String? _path;
  String? _message;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final app = await _service.installed();
      if (mounted) setState(() => _installed = app);
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Impossible de lire la version installée.');
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.service == null) _service.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _settingsOpened && mounted) {
      setState(() {
        _settingsOpened = false;
        _permission = false;
      });
    }
  }

  Future<void> _check() async {
    setState(() {
      _busy = true;
      _received = 0;
      _total = 0;
      _message = 'Recherche sur GitHub…';
    });
    try {
      final app = _installed ?? await _service.installed();
      final release = await _service.latest(app);
      if (!mounted) return;
      setState(() {
        _installed = app;
        _release = release;
        _checked = true;
        _path = null;
        _permission = false;
        _message = release == null
            ? 'Aucun installable trouvé pour cette édition.'
            : compareAppVersions(release.version, app.version) > 0
            ? 'La version ${release.version} est disponible.'
            : 'Votre application est à jour.';
      });
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _error(Object error) {
    if (mounted) {
      setState(
        () => _message = error is UpdateException
            ? error.message
            : error is PlatformException &&
                  const {
                    'invalid_update',
                    'installer_unavailable',
                    'settings_unavailable',
                  }.contains(error.code)
            ? error.message
            : 'La mise à jour est indisponible. Réessayez plus tard.',
      );
    }
  }

  Future<void> _update() async {
    final release = _release;
    if (release == null || _installed == null) return;
    setState(() => _busy = true);
    try {
      if (_installed!.windows) {
        await _service.openWindowsDownload(release);
        if (mounted) {
          setState(
            () => _message = 'Téléchargement ouvert. Fermez NOVA, extrayez tout le ZIP puis lancez la nouvelle version. Vos profils et sources sont conservés.',
          );
        }
      } else if (_permission) {
        _settingsOpened = true;
        await _service.openPermissionSettings();
      } else {
        if (_path == null) {
          setState(() {
            _message = 'Téléchargement et vérification de l’APK…';
            _total = release.bytes;
            _received = 0;
          });
          _path = await _service.download(release, (received, total) {
            if (mounted) {
              setState(() {
                _received = received;
                _total = total;
              });
            }
          });
        }
        if (!mounted) return;
        final status = await _service.install(_path!);
        if (status != 'permission' && status != 'installer') {
          throw const UpdateException(
            'Impossible d’ouvrir l’installateur Android.',
          );
        }
        if (!mounted) return;
        setState(() {
          _permission = status == 'permission';
          _message = _permission
              ? 'Autorisez NOVA à installer ses mises à jour, puis revenez ici pour installer l’APK.'
              : 'Confirmez la mise à jour dans l’installateur Android. Ne désinstallez pas NOVA.';
        });
      }
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _action(
    String label,
    VoidCallback? onPressed, {
    bool autofocus = false,
  }) => widget.television && onPressed != null
      ? TvTile(
          label: label,
          autofocus: autofocus,
          onPressed: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(label, textAlign: TextAlign.center),
          ),
        )
      : FilledButton(onPressed: onPressed, child: Text(label));

  @override
  Widget build(BuildContext context) {
    final newer =
        _installed != null &&
        _release != null &&
        compareAppVersions(_release!.version, _installed!.version) > 0;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Icon(Icons.system_update_alt_rounded, size: 38),
        const SizedBox(height: 16),
        Text(
          'Mise à jour de l’application',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(
          _installed == null
              ? 'Lecture de la version installée…'
              : '${_installed!.edition} · Version ${_installed!.version}',
        ),
        const SizedBox(height: 12),
        const Text(
          'NOVA recherche la dernière version stable compatible sur le dépôt GitHub officiel Kyrluh/NOVA.',
          style: TextStyle(color: novaMuted),
        ),
        const SizedBox(height: 22),
        _action(
          _busy ? 'Opération en cours…' : 'Vérifier les mises à jour',
          _busy ? null : _check,
          autofocus: true,
        ),
        if (_message != null) ...[
          const SizedBox(height: 18),
          Text(_message!, key: const ValueKey('app-update-status')),
        ],
        if (_busy) ...[
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: _total > 0 ? (_received / _total).clamp(0, 1) : null,
          ),
          if (_total > 0)
            Text(
              '${(_received / (1024 * 1024)).toStringAsFixed(1)} / ${(_total / (1024 * 1024)).toStringAsFixed(1)} Mo',
            ),
        ],
        if (newer && _checked) ...[
          const SizedBox(height: 18),
          Text(
            _release!.filename,
            style: const TextStyle(color: novaMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          _action(
            _installed!.windows
                ? 'Télécharger le ZIP Windows'
                : _permission
                ? 'Autoriser l’installation'
                : _path == null
                ? 'Télécharger et installer la mise à jour'
                : 'Installer la mise à jour',
            _busy ? null : _update,
          ),
        ],
        const SizedBox(height: 22),
        const Text(
          'La vérification est manuelle. Aucun téléchargement ne démarre au lancement de NOVA.',
          style: TextStyle(color: novaMuted, fontSize: 12),
        ),
      ],
    );
  }
}
