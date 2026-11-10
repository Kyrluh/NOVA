import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';

abstract interface class SecretStore {
  Future<Uint8List> protect(String value);
  Future<String> unprotect(Uint8List value);
}

class SecretStoreException implements Exception {
  const SecretStoreException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// AES-GCM protection with a non-exportable Android Keystore key. Channel work
/// runs on the main isolate; native cryptography is dispatched off the UI thread.
class AndroidKeystoreSecretStore implements SecretStore {
  const AndroidKeystoreSecretStore();
  static const _channel = MethodChannel('nova/android');

  @override
  Future<Uint8List> protect(String value) async {
    try {
      final protected = await _channel.invokeMethod<Uint8List>(
        'protect',
        value,
      );
      if (protected == null || protected.isEmpty) throw const FormatException();
      return protected;
    } catch (_) {
      throw const SecretStoreException(
        'Android n’a pas pu protéger les données de cette source.',
      );
    }
  }

  @override
  Future<String> unprotect(Uint8List value) async {
    try {
      final plaintext = await _channel.invokeMethod<String>('unprotect', value);
      if (plaintext == null) throw const FormatException();
      return plaintext;
    } catch (_) {
      throw const SecretStoreException(
        'Android ne peut pas déverrouiller cette source. Réimportez-la sur cet appareil.',
      );
    }
  }
}

/// Windows DPAPI protection bound to the current Windows user, never to all
/// users of the computer. Catalogues also contain private stream URLs, so this
/// protects the complete source record rather than only its password.
class DpapiSecretStore implements SecretStore {
  const DpapiSecretStore();

  @override
  Future<Uint8List> protect(String value) => Isolate.run(
    () => _transform(Uint8List.fromList(utf8.encode(value)), true),
  );

  @override
  Future<String> unprotect(Uint8List value) =>
      Isolate.run(() => utf8.decode(_transform(value, false)));
}

final class _DataBlob extends Struct {
  @Uint32()
  external int length;
  external Pointer<Uint8> data;
}

typedef _CryptNative = Int32 Function(
  Pointer<_DataBlob>,
  Pointer<Void>,
  Pointer<_DataBlob>,
  Pointer<Void>,
  Pointer<Void>,
  Uint32,
  Pointer<_DataBlob>,
);
typedef _CryptDart = int Function(
  Pointer<_DataBlob>,
  Pointer<Void>,
  Pointer<_DataBlob>,
  Pointer<Void>,
  Pointer<Void>,
  int,
  Pointer<_DataBlob>,
);
typedef _FreeNative = Pointer<Void> Function(Pointer<Void>);
typedef _FreeDart = Pointer<Void> Function(Pointer<Void>);

Uint8List _transform(Uint8List bytes, bool encrypt) {
  const maxBytes = 256 * 1024 * 1024;
  if (!Platform.isWindows || bytes.length > maxBytes) {
    throw const SecretStoreException(
      'Le stockage protégé Windows est indisponible.',
    );
  }
  final crypt32 = DynamicLibrary.open('crypt32.dll');
  final kernel32 = DynamicLibrary.open('kernel32.dll');
  final operation = crypt32.lookupFunction<_CryptNative, _CryptDart>(
    encrypt ? 'CryptProtectData' : 'CryptUnprotectData',
  );
  final localFree = kernel32.lookupFunction<_FreeNative, _FreeDart>(
    'LocalFree',
  );
  final input = calloc<_DataBlob>();
  final output = calloc<_DataBlob>();
  final buffer = calloc<Uint8>(bytes.isEmpty ? 1 : bytes.length);
  try {
    buffer.asTypedList(bytes.length).setAll(0, bytes);
    input.ref.length = bytes.length;
    input.ref.data = buffer;
    // CRYPTPROTECT_UI_FORBIDDEN. No machine-wide protection or interactive UI.
    final result = operation(
      input,
      nullptr,
      nullptr,
      nullptr,
      nullptr,
      1,
      output,
    );
    if (result == 0 || output.ref.length > maxBytes) {
      throw SecretStoreException(
        encrypt ? 'Windows n’a pas pu protéger les données de cette source.' : 'Windows ne peut pas déverrouiller cette source. Réimportez-la avec ce compte Windows.',
      );
    }
    return Uint8List.fromList(output.ref.data.asTypedList(output.ref.length));
  } finally {
    // Native plaintext buffers are cleared before release. Managed Dart strings
    // remain under the VM's memory management, not under our explicit control.
    buffer.asTypedList(bytes.length).fillRange(0, bytes.length, 0);
    if (output.ref.data != nullptr) {
      output.ref.data
          .asTypedList(output.ref.length)
          .fillRange(0, output.ref.length, 0);
      localFree(output.ref.data.cast<Void>());
    }
    calloc.free(buffer);
    calloc.free(input);
    calloc.free(output);
  }
}
