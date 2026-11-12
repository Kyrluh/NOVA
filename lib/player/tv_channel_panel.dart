import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui/theme.dart';
import '../ui/widgets/channel_logo.dart';

@immutable
class TvChannelOption {
  const TvChannelOption({
    required this.id,
    required this.title,
    required this.category,
    this.logoUrl,
  });
  final String id;
  final String title;
  final String category;
  final String? logoUrl;
}

/// Stays inside the video surface: switching channels never leaves fullscreen.
class TvChannelPanel extends StatefulWidget {
  const TvChannelPanel({
    super.key,
    required this.channels,
    required this.selectedId,
    required this.onSelected,
    required this.onClose,
    this.programmeFor,
    this.guideChanges,
    this.onGuideRequested,
  });
  final List<TvChannelOption> channels;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final VoidCallback onClose;
  final String? Function(String channelId)? programmeFor;
  final Listenable? guideChanges;
  final ValueChanged<String>? onGuideRequested;
  @override
  State<TvChannelPanel> createState() => _TvChannelPanelState();
}

class _TvChannelPanelState extends State<TvChannelPanel> {
  final _focus = FocusNode(debugLabel: 'TV fullscreen channel panel');
  final _rows = ScrollController();
  final _tabs = ScrollController();
  String? _category;
  int _index = 0;
  Timer? _guideTick;
  final _requestedGuides = <String>{};
  double get _rowHeight =>
      64 +
      (MediaQuery.textScalerOf(context).scale(14) - 14).clamp(
            0,
            double.infinity,
          ) *
          2.3;

  void _guideChanged() {
    if (!mounted) return;
    setState(_requestedGuides.clear);
  }

  void _requestGuide(String id) {
    if (widget.onGuideRequested == null || !_requestedGuides.add(id)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onGuideRequested?.call(id);
    });
  }

  List<String?> get _categories => [
    null,
    ...widget.channels.map((c) => c.category).toSet(),
  ];
  List<TvChannelOption> get _channels => widget.channels
      .where((c) => _category == null || c.category == _category)
      .toList();
  @override
  void initState() {
    super.initState();
    widget.guideChanges?.addListener(_guideChanged);
    if (widget.programmeFor != null) {
      _guideTick = Timer.periodic(
        const Duration(minutes: 1),
        (_) => _guideChanged(),
      );
    }
    final selected = widget.channels
        .where((c) => c.id == widget.selectedId)
        .firstOrNull;
    _category = selected?.category;
    _selectCurrent();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant TvChannelPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.guideChanges != widget.guideChanges) {
      oldWidget.guideChanges?.removeListener(_guideChanged);
      widget.guideChanges?.addListener(_guideChanged);
      _requestedGuides.clear();
    }
    if (!identical(oldWidget.channels, widget.channels)) {
      _requestedGuides.clear();
    }
  }

  void _selectCurrent() {
    final index = _channels.indexWhere((c) => c.id == widget.selectedId);
    _index = index < 0 ? 0 : index;
    _reveal();
  }

  void _reveal() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    if (_rows.hasClients) {
      _rows.jumpTo(
        (_index * _rowHeight).clamp(0.0, _rows.position.maxScrollExtent),
      );
    }
    if (_tabs.hasClients) {
      _tabs.jumpTo(
        (_categories.indexOf(_category) * 160.0).clamp(
          0.0,
          _tabs.position.maxScrollExtent,
        ),
      );
    }
  });
  void _changeCategory(String? category) {
    setState(() {
      _category = category;
      _selectCurrent();
    });
  }

  KeyEventResult _key(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      widget.onClose();
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      final categories = _categories;
      final next =
          (categories.indexOf(_category) +
                  (key == LogicalKeyboardKey.arrowRight ? 1 : -1))
              .clamp(0, categories.length - 1);
      _changeCategory(categories[next]);
    } else if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      if (_channels.isNotEmpty) {
        setState(() {
          _index = (_index + (key == LogicalKeyboardKey.arrowDown ? 1 : -1))
              .clamp(0, _channels.length - 1);
          _reveal();
        });
      }
    } else if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (event is KeyDownEvent && _channels.isNotEmpty) {
        widget.onSelected(_channels[_index].id);
      }
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    widget.guideChanges?.removeListener(_guideChanged);
    _guideTick?.cancel();
    _focus.dispose();
    _rows.dispose();
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final channels = _channels;
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _key,
      child: Material(
        color: const Color(0xf0181922),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Chaînes',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ExcludeFocus(
                    child: IconButton(
                      tooltip: 'Fermer les chaînes',
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 48,
                child: ListView.builder(
                  controller: _tabs,
                  scrollDirection: Axis.horizontal,
                  itemExtent: 160,
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    return Semantics(
                      button: true,
                      selected: category == _category,
                      child: GestureDetector(
                        onTap: () => _changeCategory(category),
                        child: Container(
                          margin: const EdgeInsets.all(3),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: category == _category
                                ? Theme.of(context).colorScheme.primary
                                : Colors.white10,
                            border: Border.all(
                              color: category == _category
                                  ? novaHighlight
                                  : Colors.transparent,
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${category == _category ? '✓ ' : ''}${category ?? 'Toutes'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: category == _category
                                    ? FontWeight.w800
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: channels.isEmpty
                    ? const Center(child: Text('Aucune chaîne'))
                    : ListView.builder(
                        controller: _rows,
                        itemExtent: _rowHeight,
                        itemCount: channels.length,
                        itemBuilder: (context, index) {
                          final channel = channels[index];
                          _requestGuide(channel.id);
                          final programme = widget.programmeFor
                              ?.call(channel.id)
                              ?.trim();
                          return Semantics(
                            button: true,
                            selected: index == _index,
                            child: GestureDetector(
                              onTap: () => widget.onSelected(channel.id),
                              child: Container(
                                key: ValueKey('panel-channel-${channel.id}'),
                                margin: const EdgeInsets.symmetric(vertical: 3),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: index == _index
                                      ? Theme.of(context).colorScheme.primary
                                            .withValues(alpha: .3)
                                      : Colors.transparent,
                                  border: Border.all(
                                    width: 3,
                                    color: index == _index
                                        ? novaHighlight
                                        : Colors.transparent,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    if (channel.id == widget.selectedId)
                                      const Icon(Icons.play_arrow, size: 20),
                                    ChannelLogo(
                                      title: channel.title,
                                      url: channel.logoUrl,
                                      size: 28,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            channel.title,
                                            maxLines:
                                                widget.programmeFor == null
                                                ? 2
                                                : 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 14,
                                              height: 1.1,
                                              fontWeight: index == _index
                                                  ? FontWeight.w800
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                          if (widget.programmeFor != null) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              programme == null ||
                                                      programme.isEmpty
                                                  ? 'Programme indisponible'
                                                  : programme,
                                              key: ValueKey(
                                                'panel-programme-${channel.id}',
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                height: 1.1,
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const Text(
                '← → Catégories · ↑ ↓ Chaînes · OK Regarder',
                style: TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
