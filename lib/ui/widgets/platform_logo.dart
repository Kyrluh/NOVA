import 'package:flutter/material.dart';

import '../../domain/platform_catalog.dart';
import 'profile_avatar.dart';

/// Same category markers on the poster and on its opened detail sheet.
class PlatformCategoryLine extends StatelessWidget {
  const PlatformCategoryLine({
    super.key,
    required this.platforms,
    required this.label,
    required this.style,
    this.details = false,
  });

  final Set<CatalogPlatform> platforms;
  final String label;
  final TextStyle style;
  final bool details;

  @override
  Widget build(BuildContext context) {
    final kids = platforms.contains(CatalogPlatform.kids);
    final height = details ? 30.0 : 23.0;
    return Row(
      children: [
        if (kids)
          Padding(
            padding: const EdgeInsets.only(right: 5),
            child: ProfileAvatar(avatar: 'luffy', size: height),
          ),
        for (final platform
            in platforms
                .where((platform) => platform != CatalogPlatform.kids)
                .take(details && !kids ? 2 : 1))
          Padding(
            padding: const EdgeInsets.only(right: 5),
            child: PlatformLogo(
              platform: platform,
              width: switch (platform) {
                CatalogPlatform.netflix => details ? 38 : 30,
                CatalogPlatform.frenchTv => details ? 75 : 60,
                _ => details ? 64 : 49,
              },
              height: height,
              categoryBadge: true,
            ),
          ),
        Flexible(
          child: Text(
            label,
            maxLines: details ? null : 1,
            overflow: details ? null : TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}

class PlatformLogo extends StatelessWidget {
  const PlatformLogo({
    super.key,
    required this.platform,
    this.width = 100,
    this.height = 54,
    this.categoryBadge = false,
  });
  final CatalogPlatform platform;
  final double width;
  final double height;
  final bool categoryBadge;
  @override
  Widget build(BuildContext context) {
    if (categoryBadge && platform == CatalogPlatform.frenchTv) {
      return Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF224A9E),
          borderRadius: BorderRadius.circular(4),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'TF1+ · M6+\nFrance TV',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: height > 23 ? 12 : 10,
              height: 1.05,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }
    final path = switch (platform) {
      CatalogPlatform.canalPlus when categoryBadge =>
        'assets/platforms/canal-plus.png',
      CatalogPlatform.disneyPlus when categoryBadge =>
        'assets/platforms/disney-plus-wordmark.png',
      _ => platform.asset.isNotEmpty ? platform.assetPath : null,
    };
    if (!categoryBadge || path == null) return _logo(path);
    final background = switch (platform) {
      CatalogPlatform.disneyPlus => const Color(0xFF315ACC),
      CatalogPlatform.paramountPlus => const Color(0xFFD6EBFF),
      CatalogPlatform.netflix => const Color(0xFFFFE8E9),
      CatalogPlatform.primeVideo => const Color(0xFF142A40),
      _ => const Color(0xFF29364D),
    };
    final logo = Image.asset(
      path,
      fit: BoxFit.contain,
      semanticLabel: 'Logo ${platform.label}',
    );
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: logo,
    );
  }

  Widget _logo(String? path) => SizedBox(
    width: width,
    height: height,
    child: path != null
        ? Image.asset(
            path,
            fit: BoxFit.contain,
            semanticLabel: 'Logo ${platform.label}',
          )
        : DecoratedBox(
            decoration: BoxDecoration(
              color: Color(platform.color).withAlpha(28),
              borderRadius: BorderRadius.circular(width < 50 ? 4 : 10),
            ),
            child: Padding(
              padding: EdgeInsets.all(width < 50 ? 2 : 7),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  switch (platform) {
                    CatalogPlatform.frenchTv => 'TF1+\nM6+ · FTV',
                    CatalogPlatform.documentaries => 'DOCU',
                    CatalogPlatform.reality => 'REALITY\nTV',
                    _ => platform.label,
                  },
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(platform.color),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    fontStyle: platform == CatalogPlatform.canalPlus
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
              ),
            ),
          ),
  );
}
