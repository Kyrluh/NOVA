/// Supplied by the local release configuration, never by tracked source files.
abstract final class ProviderPresets {
  static const kyrluPassword = String.fromEnvironment('NOVA_KYRLU_PASSWORD');
  static bool get kyrluAvailable => kyrluPassword.isNotEmpty;
}
