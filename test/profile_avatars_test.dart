import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/data/local_store.dart';
import 'package:nova_iptv/state/app_controller.dart';

void main() {
  test(
    'Avatar, genres and favourites remain isolated and persist across profiles',
    () async {
      final store = MemoryLocalStore();
      final app = AppController(store: store);
      await app.init();
      final first = app.activeProfileId;
      final item = app.items.first.id;
      app.updateProfile('Premier', {'Action'}, avatar: 'zoro');
      app.toggleFavorite(item);
      final other = app.createProfile('Autre');
      app.selectProfile(other);
      app.updateProfile('Autre', {'Animation'}, avatar: 'harry');
      expect(app.favorites, isNot(contains(item)));
      app.selectProfile(first);
      expect(app.activeProfile.avatar, 'zoro');
      expect(app.activeProfile.genres, {'Action'});
      expect(app.favorites, contains(item));
      await app.shutdown();
      app.dispose();
      final restored = AppController(store: store);
      await restored.init();
      restored.selectProfile(first);
      expect(restored.activeProfile.avatar, 'zoro');
      expect(restored.favorites, contains(item));
      restored.selectProfile(other);
      expect(restored.activeProfile.avatar, 'harry');
      expect(restored.activeProfile.genres, {'Animation'});
      expect(restored.favorites, isNot(contains(item)));
      await restored.shutdown();
      restored.dispose();
    },
  );
}
