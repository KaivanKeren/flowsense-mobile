import 'package:flutter/material.dart';

/// Three actions, three weights (spec §18).
///
/// - [FlowButton.primary]   — the one action a screen is asking for.
///                            Filled ink, single per screen.
/// - [FlowButton.secondary] — alternative or back-out action.
///                            Outlined, hairline border.
/// - [FlowButton.tertiary]  — an action that belongs inline with text
///                            (jump to detail, expand). Text-only.
///
/// A thin wrapper around Material's Filled/Outlined/TextButton — the theme
/// already pins background, foreground, radius, minimum height (44 px) and
/// text style. This exists so screens read as `FlowButton.primary(...)`
/// rather than reaching for the underlying Material widget and re-styling.
class FlowButton extends StatelessWidget {
  const FlowButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  }) : _variant = _Variant.primary;

  const FlowButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  }) : _variant = _Variant.secondary;

  const FlowButton.tertiary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  }) : _variant = _Variant.tertiary;

  final _Variant _variant;
  final String label;

  /// `null` disables the button — the theme handles the disabled colours.
  final VoidCallback? onPressed;

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Text(label),
            ],
          );

    return switch (_variant) {
      _Variant.primary => FilledButton(onPressed: onPressed, child: child),
      _Variant.secondary => OutlinedButton(onPressed: onPressed, child: child),
      _Variant.tertiary => TextButton(onPressed: onPressed, child: child),
    };
  }
}

enum _Variant { primary, secondary, tertiary }
