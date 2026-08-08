import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the operator's bearer token lives.
///
/// **`flutter_secure_storage`, not `shared_preferences`** — the layout spec
/// names this explicitly and it is a done-criterion. A session token is a
/// credential: on Android it belongs in the Keystore-backed store, not in a
/// world-readable XML file that any backup tool will happily copy off the
/// device.
abstract class TokenStore {
  Future<String?> read();

  Future<void> write(String token);

  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  /// The default constructor already encrypts with AES-GCM under a
  /// Keystore-wrapped RSA key, so there is nothing to opt into here. Do not
  /// "improve" this by reaching for `encryptedSharedPreferences` — see the
  /// version pin in `pubspec.yaml` before touching this dependency at all.
  const SecureTokenStore({
    this._storage = const FlutterSecureStorage(),
  });

  static const String key = 'flowsense.operator.token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: key);
    } on Object {
      // A store that cannot be decrypted — a restored backup, a reinstalled
      // keystore — reads as "no session" rather than crashing on launch. The
      // worst case is one extra sign-in.
      return null;
    }
  }

  @override
  Future<void> write(String token) => _storage.write(key: key, value: token);

  @override
  Future<void> clear() => _storage.delete(key: key);
}

/// In-memory stand-in. Tests never touch the platform channel.
class FakeTokenStore implements TokenStore {
  FakeTokenStore([this._token]);

  String? _token;

  int writes = 0;
  int clears = 0;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async {
    writes++;
    _token = token;
  }

  @override
  Future<void> clear() async {
    clears++;
    _token = null;
  }
}
