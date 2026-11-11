import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'profiles_page.dart';
import 'app_updates_page.dart';
import '../widgets/catalog_columns_setting.dart';

import '../../domain/models.dart';
import '../../state/app_controller.dart';
import '../theme.dart';
import '../widgets/page_widgets.dart';
import '../adaptive.dart';

enum _SettingsCategory {
  profile(
    'Profil et envies',
    'Nom du profil, genres préférés et profils disponibles.',
    Icons.person_outline_rounded,
  ),
  library(
    'Bibliothèque et apparence',
    'Affiches, couleurs, langues, catégories et ordre des contenus.',
    Icons.grid_view_rounded,
  ),
  playback(
    'Lecture',
    'Vitesse, volume, épisodes et options adaptées à votre appareil.',
    Icons.play_circle_outline_rounded,
  ),
  sources(
    'Sources et guide TV',
    'Gérer M3U, Xtream Codes et le programme XMLTV.',
    Icons.cloud_outlined,
  ),
  data(
    'Données locales',
    'Importer ou exporter les réglages, licences et réinitialisation.',
    Icons.folder_outlined,
  ),
  updates(
    'Mise à jour de l’application',
    'Vérifier et télécharger la dernière version compatible de NOVA.',
    Icons.system_update_alt_rounded,
  );

  const _SettingsCategory(this.label, this.description, this.icon);
  final String label;
  final String description;
  final IconData icon;
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.controller,
    this.onManageSources,
    this.onOrganize,
  }) : _category = null;

  const SettingsPage._category({
    required this.controller,
    required this._category,
    this.onManageSources,
    this.onOrganize,
  });

  final AppController controller;
  final VoidCallback? onManageSources;
  final VoidCallback? onOrganize;
  final _SettingsCategory? _category;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _maxImportBytes = 1024 * 1024;
  static const _fileTypes = [
    XTypeGroup(label: 'Réglages NOVA (JSON)', extensions: ['json']),
  ];
  bool _busy = false;
  late _SettingsCategory _selected =
      widget._category ?? _SettingsCategory.profile;

  void _openCategory(_SettingsCategory category) {
    final android = NovaAdaptiveScope.isAndroid(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NovaAdaptiveScope(
          android: android,
          child: Scaffold(
            appBar: AppBar(title: Text(category.label)),
            body: SettingsPage._category(
              controller: widget.controller,
              category: category,
              onManageSources: widget.onManageSources,
              onOrganize: widget.onOrganize,
            ),
          ),
        ),
      ),
    );
  }

  void _organizeCatalogue() {
    if (widget._category != null) Navigator.of(context).pop();
    widget.onOrganize?.call();
  }

  Widget _categoryTile(_SettingsCategory category, {required bool split}) =>
      ListTile(
        key: ValueKey('settings-category-${category.name}'),
        leading: Icon(category.icon),
        title: Text(category.label),
        subtitle: split ? null : Text(category.description),
        selected: split && _selected == category,
        selectedTileColor: Theme.of(context).colorScheme.primary
            .withValues(alpha: .12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        trailing: split ? null : const Icon(Icons.chevron_right_rounded),
        onTap: split
            ? () => setState(() => _selected = category)
            : () => _openCategory(category),
      );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      if (widget._category != null) return _content(context);
      if (bounds.maxWidth >= 850) {
        return Row(
          key: const ValueKey('settings-split-view'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 244,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 22, 8, 24),
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 12, 20),
                    child: Text(
                      'Paramètres',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  for (final category in _SettingsCategory.values)
                    _categoryTile(category, split: true),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _content(context)),
          ],
        );
      }
      return ListView(
        key: const ValueKey('settings-category-hub'),
        padding: EdgeInsets.fromLTRB(
          novaPageInset(context),
          20,
          novaPageInset(context),
          32,
        ),
        children: [
          const PageHeading(
            title: 'Paramètres',
            subtitle: 'Choisissez ce que vous souhaitez personnaliser.',
          ),
          const SizedBox(height: 22),
          for (final category in _SettingsCategory.values) ...[
            Material(
              color: novaSurface,
              borderRadius: BorderRadius.circular(12),
              child: _categoryTile(category, split: false),
            ),
            const SizedBox(height: 10),
          ],
        ],
      );
    },
  );

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _exportSettings() async {
    setState(() => _busy = true);
    try {
      final data = const JsonEncoder.withIndent('  ').convert({
        'version': 1,
        'settings': widget.controller.settings.toJson(),
      });
      if (Platform.isAndroid) {
        final saved = await const MethodChannel('nova/android')
            .invokeMethod<bool>('exportDocument', {
              'name': 'nova-iptv-reglages.json',
              'mime': 'application/json',
              'text': data,
            });
        if (saved == true) _message('Les réglages ont été exportés.');
        return;
      }
      final location = await getSaveLocation(
        suggestedName: 'nova-iptv-reglages.json',
        acceptedTypeGroups: _fileTypes,
      );
      if (location == null) return;
      final file = XFile.fromData(
        Uint8List.fromList(utf8.encode(data)),
        name: 'nova-iptv-reglages.json',
        mimeType: 'application/json',
      );
      await file.saveTo(location.path);
      _message('Les réglages ont été exportés.');
    } catch (_) {
      _message(
        'L’exportation a échoué. Vérifiez les droits d’écriture et réessayez.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importSettings() async {
    setState(() => _busy = true);
    try {
      final file = await openFile(acceptedTypeGroups: _fileTypes);
      if (file == null) return;
      if (await file.length() >= _maxImportBytes) {
        throw const FormatException();
      }
      final bytes = await file.readAsBytes();
      if (bytes.length >= _maxImportBytes) throw const FormatException();
      final data = jsonDecode(utf8.decode(bytes));
      if (data is! Map<String, dynamic> ||
          data['version'] is! int ||
          data['version'] != 1 ||
          data['settings'] is! Map<String, dynamic>) {
        throw const FormatException();
      }
      final settingsData = data['settings'] as Map<String, dynamic>;
      if (!_validSettings(settingsData)) throw const FormatException();
      final settings = AppSettings.fromJson({
        ...widget.controller.settings.toJson(),
        ...settingsData,
      });
      if (!mounted) return;
      widget.controller.updateSettings(settings);
      await widget.controller.flush();
      _message(
        widget.controller.storageError == null
            ? 'Les réglages ont été importés.'
            : 'Les réglages sont appliqués, mais leur sauvegarde a échoué.',
      );
    } on FormatException {
      _message(
        'Ce fichier de réglages est invalide ou incompatible. '
        'Choisissez un export NOVA de moins de 1 Mo.',
      );
    } catch (_) {
      _message(
        'L’importation a échoué. Vérifiez que le fichier est accessible.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _validSettings(Map<String, dynamic> data) {
    if (data.isEmpty) return false;
    final allowed = const AppSettings().toJson().keys.toSet();
    if (data.keys.any((key) => !allowed.contains(key))) return false;
    final accent = data['accent'];
    if (data.containsKey('accent') &&
        (accent is! int || accent < 0xff000000 || accent > 0xffffffff)) {
      return false;
    }
    for (final key in [
      'animations',
      'autoPreview',
      'autoNext',
      'touchGestures',
      'brightnessGestures',
      'volumeGestures',
      'seekGestures',
      'reconnectEnabled',
      'pictureInPicture',
      'landscapeFullscreen',
    ]) {
      if (data.containsKey(key) && data[key] is! bool) return false;
    }
    for (final entry in [
      (key: 'reconnectAttempts', min: 0, max: 10),
      (key: 'reconnectDelaySeconds', min: 1, max: 30),
      (key: 'catalogColumns', min: 0, max: 12),
    ]) {
      final value = data[entry.key];
      if (data.containsKey(entry.key) &&
          (value is! int || value < entry.min || value > entry.max)) {
        return false;
      }
    }
    if (data.containsKey('playbackRate') &&
        !playbackRates.contains(data['playbackRate'])) {
      return false;
    }
    for (final entry in [
      (key: 'posterScale', min: .75, max: 1.5),
      (key: 'volume', min: 0.0, max: 100.0),
    ]) {
      final value = data[entry.key];
      if (data.containsKey(entry.key) &&
          (value is! num ||
              !value.isFinite ||
              value < entry.min ||
              value > entry.max)) {
        return false;
      }
    }
    return true;
  }

  Future<void> _resetData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Réinitialiser les données locales ?'),
        content: const Text(
          'Les favoris, l’historique, les progressions et les '
          'réglages du profil actuel seront effacés. Les autres profils sont conservés. '
          'Cette action ne peut pas être annulée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB3445A),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    widget.controller.resetData();
    await widget.controller.flush();
    _message(
      widget.controller.storageError == null
          ? 'Les données locales ont été réinitialisées.'
          : 'Les données ont été réinitialisées en mémoire, mais leur sauvegarde a échoué.',
    );
    if (mounted) setState(() => _busy = false);
  }

  Widget _content(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      if (_selected == _SettingsCategory.updates) {
        return const AppUpdatesPanel();
      }
      final settings = widget.controller.settings;
      return ListView(
        key: PageStorageKey(('settings-panel', _selected)),
        padding: EdgeInsets.fromLTRB(
          novaPageInset(context),
          20,
          novaPageInset(context),
          40,
        ),
        children: [
          if (widget._category == null)
            PageHeading(title: _selected.label, subtitle: _selected.description)
          else
            Text(
              _selected.description,
              style: const TextStyle(color: novaMuted),
            ),
          const SizedBox(height: 22),
          if (_selected == _SettingsCategory.profile)
            ProfileSettingsTile(controller: widget.controller),
          if (_selected == _SettingsCategory.library) ...[
            _SettingsSection(
              icon: Icons.palette_outlined,
              title: 'Apparence',
              children: [
                _SettingRow(
                  title: 'Couleur d’accent',
                  subtitle: 'Une touche personnelle sur le thème sombre.',
                  control: Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      for (final accent in const [
                        (color: 0xff8b5cf6, name: 'Violet'),
                        (color: 0xff5294ef, name: 'Bleu'),
                        (color: 0xff38ada8, name: 'Turquoise'),
                        (color: 0xffd77da2, name: 'Rose'),
                      ])
                        Tooltip(
                          message: accent.name,
                          child: Semantics(
                            button: true,
                            selected: settings.accent == accent.color,
                            label: 'Accent ${accent.name}',
                            child: Material(
                              color: Color(accent.color),
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => widget.controller.updateSettings(
                                  settings.copyWith(accent: accent.color),
                                ),
                                child: SizedBox.square(
                                  dimension: 38,
                                  child: settings.accent == accent.color
                                      ? const Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                          size: 21,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                _SettingRow(
                  title: 'Taille des affiches',
                  subtitle:
                      'Taille en mode automatique et dans les carrousels.',
                  control: Row(
                    children: [
                      const Icon(
                        Icons.photo_size_select_small_rounded,
                        size: 17,
                        color: novaMuted,
                      ),
                      Expanded(
                        child: Slider(
                          value: settings.posterScale,
                          min: .75,
                          max: 1.5,
                          divisions: 3,
                          label: '${(settings.posterScale * 100).round()} %',
                          semanticFormatterCallback: (value) =>
                              '${(value * 100).round()} pour cent',
                          onChanged: (value) =>
                              widget.controller.updateSettings(
                                settings.copyWith(posterScale: value),
                              ),
                        ),
                      ),
                      Text(
                        '${(settings.posterScale * 100).round()} %',
                        style: const TextStyle(color: novaMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                CatalogColumnsSetting(controller: widget.controller),
                _SettingRow(
                  title: 'Animations',
                  subtitle: 'Transitions discrètes entre les écrans et sur les affiches.',
                  control: Align(
                    alignment: Alignment.centerRight,
                    child: Switch(
                      value: settings.animations,
                      onChanged: (value) => widget.controller.updateSettings(
                        settings.copyWith(animations: value),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (widget.onOrganize != null) ...[
              _SettingsSection(
                icon: Icons.sort_rounded,
                title: 'Tri et affichage',
                children: [
                  _SettingRow(
                    title: 'Langues et catégories visibles',
                    subtitle: 'Choisissez les contenus à afficher et leur ordre, séparément pour la TV, les films et les séries.',
                    control: OutlinedButton.icon(
                      key: const Key('configure-catalog'),
                      onPressed: _organizeCatalogue,
                      icon: const Icon(Icons.sort_rounded, size: 18),
                      label: const Text('Configurer le tri'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ],
          if (_selected == _SettingsCategory.playback) ...[
            _SettingsSection(
              icon: Icons.tune_rounded,
              title: 'Lecteur',
              children: [
                _SettingRow(
                  title: 'Vitesse de lecture par défaut',
                  subtitle:
                      'Appliquée à l’ouverture d’un film ou d’un fichier. '
                      'Le direct reste à 1× sans mode différé.',
                  control: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Vitesse'),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<double>(
                        key: const Key('playback-speed'),
                        value: settings.playbackRate,
                        isDense: true,
                        isExpanded: true,
                        menuMaxHeight: 320,
                        items: [
                          for (final rate in playbackRates)
                            DropdownMenuItem(
                              value: rate,
                              child: Text(
                                rate == 1
                                    ? '${rateLabel(rate)} · Normale'
                                    : rateLabel(rate),
                              ),
                            ),
                        ],
                        onChanged: (rate) {
                          if (rate != null) {
                            widget.controller.updateSettings(
                              settings.copyWith(playbackRate: rate),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ),
                _SettingRow(
                  title: 'Volume à l’ouverture',
                  subtitle:
                      'Le volume peut ensuite être ajusté dans le lecteur.',
                  control: Row(
                    children: [
                      Icon(
                        settings.volume == 0
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        size: 20,
                        color: novaMuted,
                      ),
                      Expanded(
                        child: Slider(
                          value: settings.volume,
                          max: 100,
                          divisions: 20,
                          label: '${settings.volume.round()} %',
                          semanticFormatterCallback: (value) =>
                              '${value.round()} pour cent',
                          onChanged: (value) => widget.controller
                              .updateSettings(settings.copyWith(volume: value)),
                        ),
                      ),
                      Text(
                        '${settings.volume.round()} %',
                        style: const TextStyle(color: novaMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (!NovaAdaptiveScope.isAndroid(context))
                  const _SettingRow(
                    title: 'Raccourcis du lecteur',
                    subtitle: 'Disponibles lorsque le lecteur est ouvert.',
                    control: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _KeyHint(keyName: 'Espace', action: 'Pause'),
                        _KeyHint(keyName: 'F', action: 'Plein écran'),
                        _KeyHint(keyName: 'Échap', action: 'Retour'),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (NovaAdaptiveScope.isAndroid(context)) ...[
              _SettingsSection(
                icon: Icons.touch_app_outlined,
                title: 'Lecture tactile et Android',
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Gestes tactiles'),
                    subtitle: const Text(
                      'Glisser pour régler la luminosité ou le son, double appui pour ±10 s en VOD.',
                    ),
                    value: settings.touchGestures,
                    onChanged: (value) => widget.controller.updateSettings(
                      settings.copyWith(touchGestures: value),
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Geste de luminosité à gauche'),
                    value: settings.brightnessGestures,
                    onChanged: settings.touchGestures
                        ? (value) => widget.controller.updateSettings(
                            settings.copyWith(brightnessGestures: value),
                          )
                        : null,
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Geste de volume à droite'),
                    value: settings.volumeGestures,
                    onChanged: settings.touchGestures
                        ? (value) => widget.controller.updateSettings(
                            settings.copyWith(volumeGestures: value),
                          )
                        : null,
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Double appui pour avancer/reculer'),
                    subtitle: const Text(
                      'Uniquement pour les films et épisodes, sans saut sur le direct.',
                    ),
                    value: settings.seekGestures,
                    onChanged: settings.touchGestures
                        ? (value) => widget.controller.updateSettings(
                            settings.copyWith(seekGestures: value),
                          )
                        : null,
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Reconnexion automatique'),
                    value: settings.reconnectEnabled,
                    onChanged: (value) => widget.controller.updateSettings(
                      settings.copyWith(reconnectEnabled: value),
                    ),
                  ),
                  _SettingRow(
                    title: 'Tentatives de reconnexion',
                    subtitle:
                        'Un échec n’efface ni la source ni la progression.',
                    control: DropdownButtonFormField<int>(
                      initialValue: settings.reconnectAttempts,
                      isExpanded: true,
                      menuMaxHeight: 300,
                      items: [
                        for (var count = 0; count <= 10; count++)
                          DropdownMenuItem(
                            value: count,
                            child: Text('$count tentatives'),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          widget.controller.updateSettings(
                            settings.copyWith(reconnectAttempts: value),
                          );
                        }
                      },
                    ),
                  ),
                  _SettingRow(
                    title: 'Délai entre les tentatives',
                    subtitle: 'Évite les demandes en rafale lorsque le réseau est instable.',
                    control: DropdownButtonFormField<int>(
                      initialValue: settings.reconnectDelaySeconds,
                      isExpanded: true,
                      menuMaxHeight: 300,
                      items: [
                        for (var seconds = 1; seconds <= 30; seconds++)
                          DropdownMenuItem(
                            value: seconds,
                            child: Text('$seconds secondes'),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          widget.controller.updateSettings(
                            settings.copyWith(reconnectDelaySeconds: value),
                          );
                        }
                      },
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Picture-in-Picture'),
                    subtitle: const Text(
                      'La disponibilité dépend du téléphone et des autorisations Android.',
                    ),
                    value: settings.pictureInPicture,
                    onChanged: (value) => widget.controller.updateSettings(
                      settings.copyWith(pictureInPicture: value),
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Plein écran en paysage'),
                    value: settings.landscapeFullscreen,
                    onChanged: (value) => widget.controller.updateSettings(
                      settings.copyWith(landscapeFullscreen: value),
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Épisode suivant automatiquement'),
                    value: settings.autoNext,
                    onChanged: (value) => widget.controller.updateSettings(
                      settings.copyWith(autoNext: value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],

            if (!NovaAdaptiveScope.isAndroid(context))
              _desktopContinuity(settings),
          ],
          if (_selected == _SettingsCategory.sources) ...[
            if (widget.onManageSources != null) ...[
              _SettingsSection(
                icon: Icons.playlist_add_rounded,
                title: 'Sources IPTV',
                children: [
                  _SettingRow(
                    title: 'Mes sources et mon guide TV',
                    subtitle: 'Ajoutez une playlist M3U, un compte Xtream Codes et un guide XMLTV.',
                    control: FilledButton.icon(
                      key: const Key('manage-sources'),
                      onPressed: widget.onManageSources,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Gérer les sources'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],

            if (widget.onManageSources == null)
              const NovaNotice(
                icon: Icons.info_outline,
                text: 'La gestion des sources est indisponible dans cet environnement.',
              ),
          ],
          if (_selected == _SettingsCategory.data) ...[
            _SettingsSection(
              icon: Icons.folder_outlined,
              title: 'Données locales',
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 18),
                  child: Text(
                    'L’export contient uniquement vos réglages d’apparence et de lecture. '
                    'Les favoris et progressions restent conservés sur cet appareil.',
                    style: TextStyle(
                      color: novaMuted,
                      fontSize: 12,
                      height: 1.6,
                    ),
                  ),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _exportSettings,
                      icon: const Icon(Icons.file_upload_outlined, size: 18),
                      label: const Text('Exporter les réglages'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _importSettings,
                      icon: const Icon(Icons.file_download_outlined, size: 18),
                      label: const Text('Importer les réglages'),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Divider(height: 1),
                ),
                _SettingRow(
                  title: 'Repartir de zéro',
                  subtitle: 'Efface les réglages, favoris, historique et progressions.',
                  control: OutlinedButton.icon(
                    onPressed: _busy ? null : _resetData,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF095A9),
                    ),
                    icon: const Icon(Icons.restart_alt_rounded, size: 18),
                    label: const Text('Réinitialiser les données'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            NovaNotice(
              icon: Icons.info_outline_rounded,
              text:
                  'NOVA IPTV · Sources personnelles M3U, Xtream Codes et XMLTV. '
                  '${NovaAdaptiveScope.isAndroid(context) ? 'Le stockage des sources est protégé par Android Keystore. ' : 'Les identifiants et catalogues sont protégés pour votre compte Windows. '}'
                  'Aucun compte, abonnement ou serveur IPTV fourni.',
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: 'NOVA IPTV',
                  applicationLegalese:
                      'Licences des composants de cette application.',
                ),
                icon: const Icon(Icons.description_outlined, size: 17),
                label: const Text('Licences des composants'),
              ),
            ),
          ],
        ],
      );
    },
  );

  Widget _desktopContinuity(AppSettings settings) => _SettingsSection(
    icon: Icons.autorenew_rounded,
    title: 'Continuité de lecture',
    children: [
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Épisode suivant automatiquement'),
        value: settings.autoNext,
        onChanged: (value) => widget.controller.updateSettings(
          settings.copyWith(autoNext: value),
        ),
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Reconnexion automatique'),
        value: settings.reconnectEnabled,
        onChanged: (value) => widget.controller.updateSettings(
          settings.copyWith(reconnectEnabled: value),
        ),
      ),
      _SettingRow(
        title: 'Tentatives de reconnexion',
        subtitle: 'Un échec n’efface ni la source ni la progression.',
        control: DropdownButtonFormField<int>(
          key: ValueKey(('reconnect-attempts', settings.reconnectAttempts)),
          initialValue: settings.reconnectAttempts,
          isExpanded: true,
          items: [
            for (var count = 0; count <= 10; count++)
              DropdownMenuItem(value: count, child: Text('$count tentatives')),
          ],
          onChanged: (value) {
            if (value != null) {
              widget.controller.updateSettings(
                settings.copyWith(reconnectAttempts: value),
              );
            }
          },
        ),
      ),
      _SettingRow(
        title: 'Délai entre les tentatives',
        subtitle:
            'Évite les demandes en rafale lorsque le réseau est instable.',
        control: DropdownButtonFormField<int>(
          key: ValueKey(('reconnect-delay', settings.reconnectDelaySeconds)),
          initialValue: settings.reconnectDelaySeconds,
          isExpanded: true,
          items: [
            for (var seconds = 1; seconds <= 30; seconds++)
              DropdownMenuItem(
                value: seconds,
                child: Text('$seconds secondes'),
              ),
          ],
          onChanged: (value) {
            if (value != null) {
              widget.controller.updateSettings(
                settings.copyWith(reconnectDelaySeconds: value),
              );
            }
          },
        ),
      ),
    ],
  );
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: novaSurface,
      border: Border.all(color: const Color(0xFF242936)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1) const SizedBox(height: 20),
          ],
        ],
      ),
    ),
  );
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    required this.subtitle,
    required this.control,
  });

  final String title;
  final String subtitle;
  final Widget control;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final label = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: novaMuted, fontSize: 12, height: 1.5),
          ),
        ],
      );
      if (constraints.maxWidth < 580) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            label,
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: control,
            ),
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: label),
          const SizedBox(width: 32),
          SizedBox(width: 280, child: control),
        ],
      );
    },
  );
}

class _KeyHint extends StatelessWidget {
  const _KeyHint({required this.keyName, required this.action});

  final String keyName;
  final String action;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFF202533),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: keyName,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFFE1E5EE),
            ),
          ),
          TextSpan(
            text: '  $action',
            style: const TextStyle(color: novaMuted),
          ),
        ],
      ),
      style: const TextStyle(fontSize: 11),
    ),
  );
}
