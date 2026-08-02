import 'package:flutter/material.dart';

/// Plain Indonesian relative time: `baru saja`, `2 menit lalu`, `1 jam lalu`.
///
/// Rounds down, so it never claims data is fresher than it is.
String relativeIndonesian(Duration age) {
  if (age.isNegative || age.inSeconds < 10) return 'baru saja';
  if (age.inMinutes < 1) return '${age.inSeconds} detik lalu';
  if (age.inHours < 1) return '${age.inMinutes} menit lalu';
  if (age.inDays < 1) return '${age.inHours} jam lalu';
  return '${age.inDays} hari lalu';
}

/// Says, without alarm, that what is on screen is not current.
///
/// Shown whenever the feed is behind or a poll failed — the map underneath
/// keeps rendering the last good data rather than blanking.
class StaleBanner extends StatelessWidget {
  const StaleBanner({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Muat ulang')),
          ],
        ),
      ),
    );
  }
}
