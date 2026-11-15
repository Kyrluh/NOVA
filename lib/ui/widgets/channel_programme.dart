import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../state/app_controller.dart';

class ChannelProgramme extends StatefulWidget {
  const ChannelProgramme({
    super.key,
    required this.controller,
    required this.channel,
  });
  final AppController controller;
  final MediaItem channel;
  @override
  State<ChannelProgramme> createState() => _ChannelProgrammeState();
}

class _ChannelProgrammeState extends State<ChannelProgramme> {
  Timer? _timer;
  int? _revision;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
        _request();
      }
    });
    _request();
  }

  void _request() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    final id = widget.channel.sourceId;
    if (id != null) unawaited(widget.controller.sources?.ensureEpg(id));
  });
  void _changed() {
    final revision = widget.controller.sources?.epgRevision;
    if (mounted && revision != _revision) {
      _revision = revision;
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant ChannelProgramme oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
    if (oldWidget.channel.id != widget.channel.id ||
        oldWidget.controller != widget.controller) {
      _request();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final programme = widget.controller
        .guideFor(widget.channel)
        .where((p) => !p.start.isAfter(now) && p.end.isAfter(now))
        .firstOrNull;
    return Text(
      programme?.title ?? 'Programme indisponible',
      key: ValueKey('channel-programme-${widget.channel.id}'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 11,
        height: 1.2,
        color: Color(0xFFBAC2D3),
      ),
    );
  }
}
