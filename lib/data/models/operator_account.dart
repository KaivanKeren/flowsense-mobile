/// The signed-in operator, as returned by `POST /v1/auth/login`.
///
/// Named `OperatorAccount` rather than `Operator` because `operator` is a Dart
/// keyword and a class called `Operator` reads badly next to `operator ==`.
class OperatorAccount {
  const OperatorAccount({
    required this.id,
    required this.nama,
    required this.email,
  });

  /// Tolerant in the same way [TrafficRecord] is: unknown keys are ignored and
  /// a missing field degrades to empty rather than throwing. The backend team
  /// can add fields without shipping a new APK.
  factory OperatorAccount.fromJson(Map<String, dynamic> json) =>
      OperatorAccount(
        id: '${json['id'] ?? ''}',
        nama: json['nama'] as String? ?? '',
        email: json['email'] as String? ?? '',
      );

  final String id;
  final String nama;
  final String email;

  Map<String, dynamic> toJson() => {'id': id, 'nama': nama, 'email': email};

  @override
  bool operator ==(Object other) =>
      other is OperatorAccount &&
      other.id == id &&
      other.nama == nama &&
      other.email == email;

  @override
  int get hashCode => Object.hash(id, nama, email);
}

/// A token plus the account it belongs to.
class AuthSession {
  const AuthSession({required this.token, required this.operator});

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        token: json['token'] as String? ?? '',
        operator: OperatorAccount.fromJson(
          (json['operator'] as Map<String, dynamic>?) ?? const {},
        ),
      );

  final String token;
  final OperatorAccount operator;

  Map<String, dynamic> toJson() =>
      {'token': token, 'operator': operator.toJson()};
}
