/// The version shown on the Tentang screen.
///
/// A plain constant rather than `package_info_plus`: reading the real bundle
/// version needs a platform channel, which would drag `flutter test` onto one
/// for a string. `test/core/app_version_test.dart` asserts this matches
/// `pubspec.yaml`, so it cannot drift silently.
const String kAppVersion = '0.1.0';
