import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../state/app_controller.dart';
import 'artwork.dart';

class MediaArtwork extends StatelessWidget {
  const MediaArtwork({
    super.key,
    required this.item,
    this.landscape = false,
    this.controller,
  });
  final MediaItem item;
  final bool landscape;
  final AppController? controller;
  @override
  Widget build(BuildContext context) {
    final fallback = NovaArtwork(
      color: item.palette,
      variant: item.art,
      landscape: landscape,
      title: landscape ? null : item.title,
    );
    final uri = Uri.tryParse(
      (controller == null ? item.posterUrl : controller!.posterFor(item)) ?? '',
    );
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      return fallback;
    }
    return Image.network(
      uri.toString(),
      key: ValueKey('${item.kind.name}/${item.id}/${uri.toString()}'),
      fit: BoxFit.cover,
      cacheWidth: landscape ? 1280 : 420,
      filterQuality: FilterQuality.low,
      errorBuilder: (context, error, stack) => fallback,
      // A progress builder repaints on every download chunk. We only need the
      // placeholder until the first decoded image frame is available.
      frameBuilder: (context, image, frame, synchronous) =>
          synchronous || frame != null ? image : fallback,
    );
  }
}
