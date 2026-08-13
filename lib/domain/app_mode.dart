/// The two audiences, from one app.
///
/// This used to be a build-time flavor — two entry points, two APKs. It is a
/// runtime choice now: one install, one icon, and a button in each direction.
/// The operator side is still gated by a login, so "runtime" costs nothing in
/// access control: switching mode only chooses which shell is on screen, and
/// the console still refuses to render without a session.
enum AppMode {
  warga,
  operator;

  String get appTitle => switch (this) {
        AppMode.warga => 'FlowSense',
        AppMode.operator => 'FlowSense Operator',
      };

  /// How the mode is named to the person switching into it.
  String get label => switch (this) {
        AppMode.warga => 'Tampilan warga',
        AppMode.operator => 'Konsol operator',
      };

  AppMode get other =>
      this == AppMode.warga ? AppMode.operator : AppMode.warga;

  /// Parses the persisted form. Unknown values read as null rather than
  /// throwing: a mode written by a newer build must not stop an older one from
  /// starting.
  static AppMode? tryParse(String? name) => switch (name) {
        'warga' => AppMode.warga,
        'operator' => AppMode.operator,
        _ => null,
      };
}
