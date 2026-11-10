/// Supplied by the local release configuration, never by tracked source files.
abstract final class ProviderPresets {
  static const xtreamServers = <String>[
    'http://predb.click',
    'http://smpj4.online',
    'http://mo8q8.online',
    'http://draap.online',
    'http://liveprotv.com',
    'http://4kib.xyz',
    'http://usica.space',
  ];
  static const kyrluPassword = String.fromEnvironment('NOVA_KYRLU_PASSWORD');
  static bool get kyrluAvailable => kyrluPassword.isNotEmpty;
}
