import 'android_playback_test.dart' as playback;
import 'android_storage_test.dart' as storage;

/// One APK/Gradle build executes native storage, codecs, HTTP and resizing tests.
void main() {
  storage.main();
  playback.main();
}
