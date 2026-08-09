import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/congestion.dart';

/// A banner-style alert, in one of three tiers (spec §27).
///
/// - [FlowAlert.critical]   — emergency vehicle, gridlock, intersection
///                            failure. Uses `semantics.emergency` — a red
///                            distinct from `macet`, so it never reads as
///                            "the road is red".
/// - [FlowAlert.warning]    — elevated traffic, degraded service. Borrows the
///                            `padat` amber pill because the app already
///                            trains the eye to read amber as attention, and
///                            introducing a second amber would compete.
/// - [FlowAlert.info]       — system notice, hint. Uses `semantics.info`.
///
/// Spec §11: colour never carries meaning alone. Every alert here shows an
/// icon + a label + a body, and the tier drives the tint only for
/// reinforcement.
class FlowAlert extends StatelessWidget {
  const FlowAlert.critical({
    super.key,
    required this.title,
    this.message,
    this.action,
    this.icon = Icons.error_outline,
  }) : _tier = _Tier.critical;

  const FlowAlert.warning({
    super.key,
    required this.title,
    this.message,
    this.action,
    this.icon = Icons.warning_amber_outlined,
  }) : _tier = _Tier.warning;

  const FlowAlert.info({
    super.key,
    required this.title,
    this.message,
    this.action,
    this.icon = Icons.info_outline,
  }) : _tier = _Tier.info;

  final _Tier _tier;

  /// The single-sentence headline. Always shown, always plain language.
  final String title;

  /// Optional supporting sentence.
  final String? message;

  /// Optional inline action. Kept text-only — a critical alert should not
  /// bury a call to action behind a filled button.
  final FlowAlertAction? action;

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final pill = _pill(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: pill.tint,
        borderRadius: BorderRadius.circular(FlowRadius.card),
        border: Border.all(color: pill.ink.withValues(alpha: 0.20)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: pill.ink),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: text.titleMedium?.copyWith(color: pill.ink),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      message!,
                      style: text.bodyMedium?.copyWith(color: pill.ink),
                    ),
                  ],
                ],
              ),
            ),
            if (action != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: action!.onPressed,
                style: TextButton.styleFrom(foregroundColor: pill.ink),
                child: Text(action!.label),
              ),
            ],
          ],
        ),
      ),
    );
  }

  PillColors _pill(BuildContext context) {
    return switch (_tier) {
      _Tier.critical => FlowSemantics.of(context).emergencyPill,
      _Tier.warning =>
        CongestionColors.of(context).pillFor(CongestionLevel.padat),
      _Tier.info => FlowSemantics.of(context).infoPill,
    };
  }
}

class FlowAlertAction {
  const FlowAlertAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}

enum _Tier { critical, warning, info }
