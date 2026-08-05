import 'package:flutter/material.dart';

import '../../app/theme.dart';

export 'relative_time.dart';

/// Says, without alarm, that what is on screen is not current.
///
/// Shown whenever the feed is behind or a poll failed — the map underneath
/// keeps rendering the last good data rather than blanking. A fetch failure
/// must never empty the screen; it only ever adds this strip.
class StaleBanner extends StatelessWidget {
  const StaleBanner({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final surfaces = FlowSurfaces.of(context);
    return Material(
      color: surfaces.map,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined, size: 16, color: surfaces.faintInk),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }
}
