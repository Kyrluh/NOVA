import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/source_models.dart';
import '../../state/source_controller.dart';
import '../theme.dart';
import '../widgets/page_widgets.dart';
import '../adaptive.dart';

/// Personal source management. Provider addresses and credentials are only
/// displayed inside the edit form, never in source cards or error details.
class SourcesPage extends StatelessWidget {
  const SourcesPage({super.key, required this.controller});

  final SourceController controller;

  Future<void> _edit(BuildContext context, [SourceSummary? source]) async {
    final initial = source == null ? null : controller.draftFor(source.id);
    if (source != null && initial == null) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SourceForm(
        controller: controller,
        sourceId: source?.id,
        initial: initial,
      ),
    );
    if (saved != true || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          source == null
              ? 'Source ajoutée. Votre catalogue est prêt.'
              : 'Source mise à jour.',
        ),
      ),
    );
  }

  Future<void> _remove(BuildContext context, SourceSummary source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette source ?'),
        content: Text(
          '« ${source.name} » et son catalogue local seront retirés de NOVA. Votre accès auprès du fournisseur reste inchangé.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _perform(
      context,
      () => controller.remove(source.id),
      'Source supprimée.',
    );
  }

  Future<void> _perform(
    BuildContext context,
    Future<void> Function() action,
    String success,
  ) async {
    String message;
    try {
      await action();
      message = success;
    } on SourceCancelled {
      return;
    } on SourceException catch (error) {
      message = error.message;
    } catch (_) {
      message = 'Cette opération a échoué. Vérifiez la source et réessayez.';
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, child) {
      final sources = controller.sources;
      return ListView(
        padding: EdgeInsets.fromLTRB(
          novaPageInset(context),
          20,
          novaPageInset(context),
          36,
        ),
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              const heading = PageHeading(
                title: 'Votre bibliothèque commence ici.',
                subtitle: 'Ajoutez vos playlists et vos accès personnels, puis retrouvez leurs contenus dans NOVA.',
              );
              final add = FilledButton.icon(
                key: const Key('add-source'),
                onPressed: controller.isInitializing
                    ? null
                    : () => _edit(context),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Ajouter une source'),
              );
              if (constraints.maxWidth < 820) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [heading, const SizedBox(height: 20), add],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(child: heading),
                  const SizedBox(width: 28),
                  add,
                ],
              );
            },
          ),
          const SizedBox(height: 26),
          if (controller.isInitializing) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 20),
          ],
          if (controller.error != null) ...[
            NovaNotice(
              icon: Icons.info_outline_rounded,
              text: controller.error!,
            ),
            const SizedBox(height: 16),
          ],
          for (final warning in controller.warnings) ...[
            NovaNotice(icon: Icons.info_outline_rounded, text: warning),
            const SizedBox(height: 12),
          ],
          if (sources.isEmpty && !controller.isInitializing)
            _emptyState(context)
          else
            for (final source in sources) ...[
              _sourceCard(context, source),
              const SizedBox(height: 14),
            ],
          const SizedBox(height: 20),
          const NovaNotice(
            icon: Icons.lock_outline_rounded,
            text: 'Vos sources et vos accès sont protégés sur cet ordinateur. NOVA ne fournit ni abonnement, ni chaîne, ni compte. Utilisez uniquement des sources que vous êtes autorisé à consulter.',
          ),
        ],
      );
    },
  );

  Widget _emptyState(BuildContext context) => Container(
    padding: const EdgeInsets.all(30),
    decoration: BoxDecoration(
      color: novaSurface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF252A37)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.video_library_outlined,
          size: 36,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 18),
        const Text(
          'Aucune source ajoutée',
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        const Text(
          'Choisissez le format fourni par votre service. Un test de connexion est disponible avant l’importation.',
          style: TextStyle(color: novaMuted, height: 1.7),
        ),
        const SizedBox(height: 25),
        const _FormatHint(
          icon: Icons.playlist_play_rounded,
          title: 'Playlist M3U',
          text: 'Collez l’URL de votre playlist ou sélectionnez un fichier M3U / M3U8.',
        ),
        const SizedBox(height: 18),
        const _FormatHint(
          icon: Icons.dns_outlined,
          title: 'Xtream Codes',
          text: 'Saisissez l’adresse du serveur, votre nom d’utilisateur et votre mot de passe.',
        ),
        const SizedBox(height: 18),
        const _FormatHint(
          icon: Icons.calendar_today_outlined,
          title: 'Guide TV XMLTV',
          text: 'Ajoutez une adresse XMLTV à votre source. Le guide peut ensuite être actualisé séparément.',
        ),
      ],
    ),
  );

  Widget _sourceCard(BuildContext context, SourceSummary source) {
    final busy = controller.busyIds.contains(source.id);
    final draft = controller.draftFor(source.id);
    final hasGuide =
        source.kind == SourceKind.xtream ||
        (draft?.epgUrl.trim().isNotEmpty ?? false);
    final updated = source.updatedAt.toLocal();
    final stamp =
        '${updated.day.toString().padLeft(2, '0')}/${updated.month.toString().padLeft(2, '0')}/${updated.year} à ${updated.hour.toString().padLeft(2, '0')}:${updated.minute.toString().padLeft(2, '0')}';
    return Container(
      key: ValueKey('source-${source.id}'),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: novaSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF252A37)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary
                      .withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  source.kind == SourceKind.xtream
                      ? Icons.dns_outlined
                      : Icons.playlist_play_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _kindLabel(source.kind),
                      style: const TextStyle(fontSize: 12, color: novaMuted),
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${source.itemCount} contenus  •  Actualisé le $stamp',
            style: const TextStyle(color: novaMuted, fontSize: 12),
          ),
          if (source.error != null) ...[
            const SizedBox(height: 12),
            Text(
              source.error!,
              style: const TextStyle(color: Color(0xFFFFC3A3), fontSize: 12),
            ),
          ],
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => _perform(
                        context,
                        () => controller.refresh(source.id),
                        'Catalogue actualisé.',
                      ),
                icon: const Icon(Icons.sync_rounded, size: 18),
                label: const Text('Actualiser'),
              ),
              Tooltip(
                message: hasGuide ? 'Actualiser le guide TV de cette source' : 'Ajoutez une adresse XMLTV dans les réglages de cette source.',
                child: OutlinedButton.icon(
                  onPressed: busy || !hasGuide
                      ? null
                      : () => _perform(
                          context,
                          () => controller.refreshEpg(source.id),
                          'Guide TV actualisé.',
                        ),
                  icon: const Icon(Icons.calendar_today_outlined, size: 17),
                  label: const Text('Guide TV'),
                ),
              ),
              TextButton.icon(
                onPressed: busy ? null : () => _edit(context, source),
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: const Text('Modifier'),
              ),
              if (busy)
                TextButton(
                  onPressed: () => controller.cancel(source.id),
                  child: const Text('Annuler le chargement'),
                )
              else
                TextButton.icon(
                  onPressed: () => _remove(context, source),
                  icon: const Icon(Icons.delete_outline_rounded, size: 17),
                  label: const Text('Supprimer'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFCA5A5),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _kindLabel(SourceKind kind) => switch (kind) {
  SourceKind.m3uUrl => 'Playlist M3U • URL',
  SourceKind.m3uFile => 'Playlist M3U • Fichier local',
  SourceKind.xtream => 'Xtream Codes',
};

class _FormatHint extends StatelessWidget {
  const _FormatHint({
    required this.icon,
    required this.title,
    required this.text,
  });
  final IconData icon;
  final String title;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 21, color: novaMuted),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: novaMuted,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _SourceForm extends StatefulWidget {
  const _SourceForm({required this.controller, this.sourceId, this.initial});
  final SourceController controller;
  final String? sourceId;
  final SourceDraft? initial;
  @override
  State<_SourceForm> createState() => _SourceFormState();
}

class _SourceFormState extends State<_SourceForm> {
  final _form = GlobalKey<FormState>();
  final _kindFocus = FocusNode(debugLabel: 'Source type');
  final _nameFocus = FocusNode(debugLabel: 'Source name');
  final _addressFocus = FocusNode(debugLabel: 'Source address');
  final _usernameFocus = FocusNode(debugLabel: 'Source username');
  final _passwordFocus = FocusNode(debugLabel: 'Source password');
  final _epgFocus = FocusNode(debugLabel: 'Source EPG');
  final _testFocus = FocusNode(debugLabel: 'Test source');
  final _saveFocus = FocusNode(debugLabel: 'Save source');
  final _cancelFocus = FocusNode(debugLabel: 'Cancel source');
  final _closeFocus = FocusNode(debugLabel: 'Close source');

  List<FocusNode> get _focusOrder => [
    if (!_busy) ...[
      _kindFocus,
      _nameFocus,
      _addressFocus,
      if (_kind == SourceKind.xtream) ...[_usernameFocus, _passwordFocus],
      _epgFocus,
      _testFocus,
      _saveFocus,
    ],
    _cancelFocus,
    _closeFocus,
  ];

  void _focusField(FocusNode target) {
    target.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final fieldContext = target.context;
      if (mounted && fieldContext != null) {
        Scrollable.ensureVisible(fieldContext, alignment: .4);
      }
    });
  }

  void _moveFocus(int direction) {
    final order = _focusOrder;
    final index = order.indexWhere((node) => node.hasFocus);
    if (index < 0) {
      _focusField(direction > 0 ? order.first : order.last);
      return;
    }
    _focusField(order[(index + direction).clamp(0, order.length - 1)]);
  }

  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _epg;
  late SourceKind _kind;
  bool _showPassword = false;
  bool _busy = false;
  bool _saving = false;
  String? _error;
  String? _testResult;
  CancellationToken? _operation;

  @override
  void initState() {
    super.initState();
    final draft = widget.initial;
    _kind = draft?.kind ?? SourceKind.m3uUrl;
    _name = TextEditingController(text: draft?.name ?? '');
    _address = TextEditingController(text: draft?.address ?? '');
    _username = TextEditingController(text: draft?.username ?? '');
    _password = TextEditingController(text: draft?.password ?? '');
    _epg = TextEditingController(text: draft?.epgUrl ?? '');
  }

  @override
  void dispose() {
    _operation?.cancel();
    _name.dispose();
    _address.dispose();
    _username.dispose();
    _password.dispose();
    _epg.dispose();
    for (final node in [
      _kindFocus,
      _nameFocus,
      _addressFocus,
      _usernameFocus,
      _passwordFocus,
      _epgFocus,
      _testFocus,
      _saveFocus,
      _cancelFocus,
      _closeFocus,
    ]) {
      node.dispose();
    }
    super.dispose();
  }

  SourceDraft _draft() => SourceDraft(
    name: _name.text.trim(),
    kind: _kind,
    address: _address.text.trim(),
    username: _kind == SourceKind.xtream ? _username.text.trim() : '',
    password: _kind == SourceKind.xtream ? _password.text : '',
    epgUrl: _epg.text.trim(),
  );

  String? _httpUrl(String? text, {bool optional = false}) {
    final value = text?.trim() ?? '';
    if (optional && value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    return uri == null ||
            !['http', 'https'].contains(uri.scheme) ||
            uri.host.isEmpty
        ? 'Saisissez une adresse HTTP ou HTTPS valide.'
        : null;
  }

  Future<void> _browse() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Playlists M3U', extensions: ['m3u', 'm3u8']),
        ],
      );
      if (file == null || !mounted) return;
      setState(() {
        _address.text = file.path;
        _error = null;
        _testResult = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'La sélection du fichier a échoué. Réessayez.');
      }
    }
  }

  Future<void> _submit({required bool save}) async {
    if (_busy || !_form.currentState!.validate()) return;
    final token = CancellationToken();
    _operation = token;
    final draft = _draft();
    setState(() {
      _busy = true;
      _saving = save;
      _error = null;
      _testResult = null;
    });
    try {
      if (save) {
        if (widget.sourceId == null) {
          await widget.controller.add(draft, cancel: token);
        } else {
          await widget.controller.update(
            widget.sourceId!,
            draft,
            cancel: token,
          );
        }
        if (mounted && !token.isCancelled) Navigator.pop(context, true);
      } else {
        final message = await widget.controller.test(draft, cancel: token);
        if (mounted && !token.isCancelled) {
          setState(() => _testResult = message);
        }
      }
    } on SourceCancelled {
      // Closing the form cancels its request without showing a failure.
    } on SourceException catch (error) {
      if (mounted && !token.isCancelled) setState(() => _error = error.message);
    } catch (_) {
      if (mounted && !token.isCancelled) {
        setState(
          () => _error = 'La connexion ou l’importation a échoué. Vérifiez les informations et réessayez.',
        );
      }
    } finally {
      if (_operation == token) _operation = null;
      if (mounted) {
        setState(() {
          _busy = false;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<bool>(
    onPopInvokedWithResult: (didPop, result) {
      if (didPop) _operation?.cancel();
    },
    child: CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            _moveFocus(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _moveFocus(-1),
      },
      child: FocusTraversalGroup(
        policy: WidgetOrderTraversalPolicy(),
        child: Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: MediaQuery.sizeOf(context).width < 600 ? 12 : 40,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 620,
              maxHeight: MediaQuery.sizeOf(context).height - 64,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 20, 14, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.sourceId == null
                              ? 'Ajouter une source'
                              : 'Modifier la source',
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Fermer',
                        focusNode: _closeFocus,
                        onPressed: () {
                          _operation?.cancel();
                          Navigator.pop(context, false);
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(26, 20, 26, 10),
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<SourceKind>(
                            focusNode: _kindFocus,
                            autofocus: true,
                            key: ValueKey('source-kind-${_kind.name}'),
                            initialValue: _kind,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Type de source',
                            ),
                            items: [
                              for (final kind in SourceKind.values)
                                DropdownMenuItem(
                                  value: kind,
                                  child: Text(_kindLabel(kind)),
                                ),
                            ],
                            onChanged: _busy
                                ? null
                                : (value) {
                                    setState(() {
                                      _kind = value!;
                                      _error = null;
                                      _testResult = null;
                                    });
                                    _focusField(_nameFocus);
                                  },
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            key: const Key('source-name'),
                            controller: _name,
                            focusNode: _nameFocus,
                            textInputAction: TextInputAction.next,
                            onEditingComplete: () {},
                            onFieldSubmitted: (_) => _focusField(_addressFocus),
                            enabled: !_busy,
                            maxLength: 80,
                            decoration: const InputDecoration(
                              labelText: 'Nom de la source',
                              hintText: 'Ma bibliothèque',
                              counterText: '',
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Donnez un nom à cette source.'
                                : null,
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            key: const Key('source-address'),
                            controller: _address,
                            focusNode: _addressFocus,
                            textInputAction: TextInputAction.next,
                            onEditingComplete: () {},
                            onFieldSubmitted: (_) => _focusField(
                              _kind == SourceKind.xtream
                                  ? _usernameFocus
                                  : _epgFocus,
                            ),
                            enabled: !_busy,
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: InputDecoration(
                              labelText: switch (_kind) {
                                SourceKind.m3uUrl => 'URL de la playlist',
                                SourceKind.m3uFile => 'Fichier de la playlist',
                                SourceKind.xtream => 'URL du serveur',
                              },
                              hintText: _kind == SourceKind.m3uFile
                                  ? 'Sélectionnez votre fichier M3U'
                                  : 'https://serveur.example',
                              suffixIcon: _kind == SourceKind.m3uFile
                                  ? IconButton(
                                      tooltip: 'Choisir un fichier M3U',
                                      onPressed: _busy ? null : _browse,
                                      icon: const Icon(
                                        Icons.folder_open_rounded,
                                      ),
                                    )
                                  : null,
                            ),
                            validator: (value) => _kind == SourceKind.m3uFile
                                ? value == null || value.trim().isEmpty
                                      ? 'Choisissez un fichier M3U ou M3U8.'
                                      : null
                                : _httpUrl(value),
                          ),
                          if (_kind == SourceKind.xtream) ...[
                            const SizedBox(height: 18),
                            TextFormField(
                              key: const Key('source-username'),
                              controller: _username,
                              focusNode: _usernameFocus,
                              textInputAction: TextInputAction.next,
                              onEditingComplete: () {},
                              onFieldSubmitted: (_) =>
                                  _focusField(_passwordFocus),
                              enabled: !_busy,
                              autocorrect: false,
                              enableSuggestions: false,
                              decoration: const InputDecoration(
                                labelText: 'Nom d’utilisateur',
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? 'Saisissez votre nom d’utilisateur.'
                                  : null,
                            ),
                            const SizedBox(height: 18),
                            TextFormField(
                              key: const Key('source-password'),
                              controller: _password,
                              focusNode: _passwordFocus,
                              textInputAction: TextInputAction.next,
                              onEditingComplete: () {},
                              onFieldSubmitted: (_) => _focusField(_epgFocus),
                              enabled: !_busy,
                              obscureText: !_showPassword,
                              autocorrect: false,
                              enableSuggestions: false,
                              decoration: InputDecoration(
                                labelText: 'Mot de passe',
                                suffixIcon: IconButton(
                                  tooltip: _showPassword
                                      ? 'Masquer le mot de passe'
                                      : 'Afficher le mot de passe',
                                  onPressed: _busy
                                      ? null
                                      : () => setState(
                                          () => _showPassword = !_showPassword,
                                        ),
                                  icon: Icon(
                                    _showPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                  ? 'Saisissez votre mot de passe.'
                                  : null,
                            ),
                          ],
                          const SizedBox(height: 24),
                          const Text(
                            'Guide TV',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            key: const Key('source-epg'),
                            controller: _epg,
                            focusNode: _epgFocus,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _focusField(_saveFocus),
                            enabled: !_busy,
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: const InputDecoration(
                              labelText: 'URL XMLTV (facultatif)',
                              hintText: 'https://…',
                            ),
                            validator: (value) =>
                                _httpUrl(value, optional: true),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _kind == SourceKind.xtream
                                ? 'Sans adresse personnalisée, NOVA utilise le guide proposé par votre serveur. Actualisez-le avec « Guide TV » après l’ajout.'
                                : 'L’adresse du guide indiquée dans la playlist est utilisée si elle est disponible. Vous pouvez la remplacer ici.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: novaMuted,
                              height: 1.6,
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 18),
                            NovaNotice(
                              icon: Icons.error_outline_rounded,
                              text: _error!,
                            ),
                          ],
                          if (_testResult != null) ...[
                            const SizedBox(height: 18),
                            NovaNotice(
                              icon: Icons.check_circle_outline_rounded,
                              text: _testResult!,
                            ),
                          ],
                          if (_busy) ...[
                            const SizedBox(height: 20),
                            const LinearProgressIndicator(),
                            const SizedBox(height: 10),
                            Text(
                              _saving
                                  ? 'Importation du catalogue…'
                                  : 'Test de la connexion…',
                              style: const TextStyle(
                                color: novaMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        focusNode: _cancelFocus,
                        onPressed: () {
                          _operation?.cancel();
                          Navigator.pop(context, false);
                        },
                        child: Text(
                          _busy ? 'Annuler le chargement' : 'Annuler',
                        ),
                      ),
                      OutlinedButton(
                        focusNode: _testFocus,
                        onPressed: _busy ? null : () => _submit(save: false),
                        child: const Text('Tester la connexion'),
                      ),
                      FilledButton(
                        focusNode: _saveFocus,
                        key: const Key('save-source'),
                        onPressed: _busy ? null : () => _submit(save: true),
                        child: Text(
                          widget.sourceId == null ? 'Ajouter' : 'Enregistrer',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
