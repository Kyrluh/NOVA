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

/// Mounted by lazy catalogue grids for visible cards and their nearby rows.
class CataloguePreviewArtwork extends StatefulWidget {
  const CataloguePreviewArtwork({
    super.key,
    required this.item,
    required this.controller,
  });

  final MediaItem item;
  final AppController controller;

  @override
  State<CataloguePreviewArtwork> createState() =>
      _CataloguePreviewArtworkState();
}

class _CataloguePreviewArtworkState extends State<CataloguePreviewArtwork> {
  @override
  void initState() {
    super.initState();
    _requestPreview();
  }

  @override
  void didUpdateWidget(CataloguePreviewArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.id != oldWidget.item.id ||
        widget.controller != oldWidget.controller) {
      _requestPreview();
    }
  }

  void _requestPreview() {
    final id = widget.item.id;
    final controller = widget.controller;
    bool relevant() =>
        mounted && widget.item.id == id && widget.controller == controller;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (relevant()) {
        controller.prefetchDetails(widget.item, relevant: relevant);
      }
    });
  }

  @override
  Widget build(BuildContext context) =>
      MediaArtwork(item: widget.item, controller: widget.controller);
}
