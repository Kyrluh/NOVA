import 'package:flutter/material.dart';

/// Small, bounded channel artwork; an unavailable image never blocks the list.
class ChannelLogo extends StatelessWidget {
  const ChannelLogo({super.key, required this.title, this.url, this.size = 32});
  final String title;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final name = title.trim();
    final fallback = Center(
      child: Text(
        name.isEmpty ? 'TV' : name.characters.first,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
    final uri = Uri.tryParse(url ?? '');
    return SizedBox.square(
      dimension: size,
      child: ExcludeSemantics(
        child:
            uri != null &&
                const ['https', 'http'].contains(uri.scheme) &&
                uri.host.isNotEmpty
            ? Image.network(
                uri.toString(),
                fit: BoxFit.contain,
                cacheWidth: 96,
                cacheHeight: 96,
                filterQuality: FilterQuality.low,
                errorBuilder: (_, _, _) => fallback,
                frameBuilder: (_, image, frame, synchronous) =>
                    synchronous || frame != null ? image : fallback,
              )
            : fallback,
      ),
    );
  }
}
