import 'package:media_kit/media_kit.dart';

/// A live source without timeshift must never be sought. This also protects
/// against media_kit's internal seek when its Android Surface is reattached.
class AndroidSessionPlayer extends Player {
  AndroidSessionPlayer({
    this.isLive = false,
    super.configuration,
    super.platformPlayer,
  });

  bool isLive;

  @override
  Future<void> seek(Duration duration) =>
      isLive ? Future<void>.value() : super.seek(duration);
}
