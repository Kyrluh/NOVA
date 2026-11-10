import 'package:flutter/material.dart';

import '../../domain/platform_catalog.dart';

class PlatformLogo extends StatelessWidget {
  const PlatformLogo({
    super.key,
    required this.platform,
    this.width = 100,
    this.height = 54,
  });
  final CatalogPlatform platform;
  final double width;
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: platform.asset.isNotEmpty
        ? Image.asset(
            platform.assetPath,
            fit: BoxFit.contain,
            semanticLabel: 'Logo ${platform.label}',
          )
        : DecoratedBox(
            decoration: BoxDecoration(
              color: Color(platform.color).withAlpha(28),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(7),
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
