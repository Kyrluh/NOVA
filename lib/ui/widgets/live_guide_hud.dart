import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../domain/source_models.dart';
import '../../state/app_controller.dart';

/// Lives inside the player's chrome: opacity, focus and PiP follow the HUD.
class LiveGuideHud extends StatefulWidget {
  const LiveGuideHud({
    super.key,
    required this.controller,
    required this.channel,
    this.compact = false,
  });
  final AppController controller;
  final MediaItem channel;
  final bool compact;
  @override
  State<LiveGuideHud> createState() => _LiveGuideHudState();
}

class _LiveGuideHudState extends State<LiveGuideHud> {
  Timer? _tick;
  bool _scheduled = false;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _tick = Timer.periodic(const Duration(minutes: 1), (_) => _changed());
    _schedule();
  }

  @override
  void didUpdateWidget(covariant LiveGuideHud oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
    _schedule();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    _schedule();
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      final id = widget.channel.sourceId;
      if (id != null) unawaited(widget.controller.sources?.ensureEpg(id));
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  String _time(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final programmes = widget.controller.guideFor(widget.channel);
    final current = programmes
        .where((p) => !p.start.isAfter(now) && p.end.isAfter(now))
        .firstOrNull;
    final next = programmes.where((p) => p.start.isAfter(now)).firstOrNull;
    final source = widget.controller.sources;
    final id = widget.channel.sourceId;
    final busy = id != null && (source?.epgLoading(id) ?? false);
    final configured = id == null ? null : source?.draftFor(id);
    final available =
        configured != null &&
        (configured.kind == SourceKind.xtream ||
            configured.epgUrl.trim().isNotEmpty);
    return IgnorePointer(
      child: Padding(
        key: const ValueKey('live-guide-hud'),
        padding: EdgeInsets.fromLTRB(14, widget.compact ? 4 : 8, 14, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (current != null) ...[
              Text(
                '${_time(current.start)} – ${_time(current.end)} · ${current.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: widget.compact ? 12 : 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (!widget.compact) ...[
                const SizedBox(height: 5),
                LinearProgressIndicator(
                  value: current.progressAt(now),
                  minHeight: 2,
                  backgroundColor: Colors.white24,
                ),
              ],
            ] else
              Text(
                busy
                    ? 'Chargement du guide TV…'
                    : !available
                    ? 'Aucun guide TV associé à cette source.'
                    : 'Programme en cours indisponible.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            if (next != null) ...[
              const SizedBox(height: 4),
              Text(
                'À suivre · ${_time(next.start)} · ${next.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
