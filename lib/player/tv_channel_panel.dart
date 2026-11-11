import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

@immutable
class TvChannelOption {
  const TvChannelOption({
    required this.id,
    required this.title,
    required this.category,
  });
  final String id;
  final String title;
  final String category;
}

/// Stays inside the video surface: switching channels never leaves fullscreen.
class TvChannelPanel extends StatefulWidget {
  const TvChannelPanel({
    super.key,
    required this.channels,
    required this.selectedId,
    required this.onSelected,
    required this.onClose,
  });
  final List<TvChannelOption> channels;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final VoidCallback onClose;
  @override
  State<TvChannelPanel> createState() => _TvChannelPanelState();
}

class _TvChannelPanelState extends State<TvChannelPanel> {
  final _focus = FocusNode(debugLabel: 'TV fullscreen channel panel');
  final _rows = ScrollController();
  final _tabs = ScrollController();
  String? _category;
  int _index = 0;
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
    final selected = widget.channels
        .where((c) => c.id == widget.selectedId)
        .firstOrNull;
    _category = selected?.category;
    _selectCurrent();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _selectCurrent() {
    final index = _channels.indexWhere((c) => c.id == widget.selectedId);
    _index = index < 0 ? 0 : index;
    _reveal();
  }

  void _reveal() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    if (_rows.hasClients) {
      _rows.jumpTo((_index * 64.0).clamp(0.0, _rows.position.maxScrollExtent));
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
                                  ? Colors.white
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
                        itemExtent: 64,
                        itemCount: channels.length,
                        itemBuilder: (context, index) {
                          final channel = channels[index];
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
                                        ? Colors.white
                                        : Colors.transparent,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    if (channel.id == widget.selectedId)
                                      const Icon(Icons.play_arrow, size: 20),
                                    Expanded(
                                      child: Text(
                                        channel.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: index == _index
                                              ? FontWeight.w800
                                              : FontWeight.normal,
                                        ),
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
