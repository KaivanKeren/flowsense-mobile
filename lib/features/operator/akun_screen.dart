import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/app_version.dart';
import '../../core/max_width.dart';
import '../../state/auth_providers.dart';
import '../tentang/tentang_screen.dart';

/// Who is signed in, and how to stop being signed in.
///
/// The only place the operator console has anything resembling a profile, and
/// that is reasonable here because there genuinely is an account. There is no
/// avatar: the layout spec rules a profile photo out, and a name plus an email
/// is the whole of what the console knows about a person anyway.
class AkunScreen extends ConsumerWidget {
  const AkunScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaces = FlowSurfaces.of(context);
    final text = Theme.of(context).textTheme;
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: surfaces.page,
      appBar: AppBar(title: const Text('Akun')),
      body: MaxWidth448(
        child: ListView(
          key: const ValueKey('akun-body'),
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    auth is AuthSignedIn ? auth.operator.nama : '—',
                    style: text.titleLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    auth is AuthSignedIn ? auth.operator.email : '',
                    style: text.bodyMedium
                        ?.copyWith(color: surfaces.textSecondary),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: surfaces.roadLine),
            _Row(
              label: 'Tentang dan sumber data',
              onTap: () => unawaited(Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const TentangScreen(),
                ),
              )),
            ),
            const _Row(label: 'Versi aplikasi', trailing: kAppVersion),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton(
                key: const ValueKey('sign-out'),
                onPressed: auth is AuthSignedIn
                    ? () => unawaited(_confirmSignOut(context, ref))
                    : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: surfaces.errorInk,
                  side: BorderSide(color: surfaces.errorInk),
                ),
                child: const Text('Keluar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Signing out drops the token and sends the operator back to the login
  /// screen, so it is worth one confirmation — an accidental tap in the field
  /// costs a re-authentication with a password nobody carries around.
  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari konsol?'),
        content: const Text('Anda perlu memasukkan sandi lagi untuk masuk.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await ref.read(authProvider.notifier).signOut();
    }
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, this.trailing, this.onTap});

  final String label;

  /// A value shown instead of a chevron — a row that states something rather
  /// than leading somewhere.
  final String? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = FlowSurfaces.of(context);
    final text = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: surfaces.roadLine)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(child: Text(label, style: text.titleMedium)),
              if (trailing != null)
                Text(
                  trailing!,
                  style: text.bodyMedium
                      ?.copyWith(color: surfaces.textSecondary),
                )
              else if (onTap != null)
                Icon(Icons.chevron_right, size: 20, color: surfaces.faintInk),
            ],
          ),
        ),
      ),
    );
  }
}
