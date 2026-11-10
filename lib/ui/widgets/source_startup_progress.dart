import 'dart:async';

import 'package:flutter/material.dart';

import '../../state/source_controller.dart';
import '../theme.dart';

class SourceStartupProgress extends StatefulWidget {
  const SourceStartupProgress({super.key, required this.controller});
  final SourceController controller;
  @override
  State<SourceStartupProgress> createState() => _SourceStartupProgressState();
}

class _SourceStartupProgressState extends State<SourceStartupProgress> {
  Timer? _dismissTimer;
  bool _dismissed = false;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _scheduleDismiss();
  }

  @override
  void didUpdateWidget(covariant SourceStartupProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
      _dismissTimer?.cancel();
      _dismissTimer = null;
      _dismissed = false;
      _scheduleDismiss();
    }
  }

  void _scheduleDismiss() {
    if (widget.controller.startupFinished &&
        widget.controller.startupFailures == 0 &&
        _dismissTimer == null) {
      _dismissTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _dismissed = true);
      });
    }
  }

  void _changed() {
    _scheduleDismiss();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.controller;
    if (_dismissed || (!source.startupRefreshing && !source.startupFinished)) {
      return const SizedBox.shrink();
    }
    final running = source.startupRefreshing;
    final failed = source.startupFailures > 0;
    final progress = source.startupProgress;
    return Padding(
      key: const ValueKey('source-startup-progress'),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: novaSurface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      running
                          ? 'Actualisation des sources · ${source.startupCompleted + 1}/${source.startupTotal}'
                          : failed
                          ? 'Actualisation incomplète · cache conservé pour les sources indisponibles'
                          : 'Sources à jour',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  if (running && progress != null)
                    Text(
                      '${(progress * 100).floor()} %',
                      style: const TextStyle(fontSize: 11, color: novaMuted),
                    ),
                  if (!running)
                    IconButton(
                      tooltip: 'Masquer le résultat',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => _dismissed = true),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                ],
              ),
              if (running) ...[
                const SizedBox(height: 4),
                Text(
                  '${source.startupSourceName ?? ''} · ${source.startupPhase}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: novaMuted),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: progress, minHeight: 3),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
