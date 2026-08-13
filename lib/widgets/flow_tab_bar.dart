import 'package:flutter/material.dart';

import '../core/max_width.dart';
import '../theme/colors.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// One destination.
@immutable
class FlowTab<T> {
  const FlowTab({
    required this.value,
    required this.label,
    required this.icon,
  });

  final T value;

  /// Written out in full. See [FlowTabBar] for why this is never abbreviated
  /// by the layout.
  final String label;

  final IconData icon;
}

/// The bar at the bottom of both shells.
///
/// Hand-built rather than a [NavigationBar] because the active state is a soft
/// capsule behind the icon **and** its label, and Material's indicator wraps
/// the icon alone.
///
/// The thing this widget exists to guarantee: **a tab label is never silently
/// cut short.** The console shipped `Dashboard` rendered into a 77 px box that
/// needed 79, and `Peringatan` into one that needed exactly its own width —
/// with `overflow: ellipsis` quietly turning them into `Dashboar…`. A label a
/// user cannot read is a destination they cannot identify, and nothing in the
/// old test suite could see it happening because every finder still located
/// the widget.
///
/// The fix is [FittedBox] with [BoxFit.scaleDown]. It cannot enlarge, only
/// shrink, so the label is laid out at its natural size and scaled back only by
/// as much as the box demands. In practice that means it gives back some of
/// what `textScaler` added and never drops below the 11 px base —
/// `test/layout/truncation_test.dart` pins that floor rather than trusting it.
class FlowTabBar<T> extends StatelessWidget {
  const FlowTabBar({
    super.key,
    required this.tabs,
    required this.current,
    required this.onChanged,
  });

  final List<FlowTab<T>> tabs;
  final T current;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceCanvas,
        border: Border(top: BorderSide(color: colors.borderSubtle)),
      ),
      child: SafeArea(
        top: false,
        child: MaxWidth448(
          // The bar has to hug its content. Without this it fills the screen
          // and the Scaffold hands the body zero height.
          shrinkWrapHeight: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: FlowSpace.xs,
              vertical: FlowSpace.xs,
            ),
            child: Row(
              children: [
                for (final tab in tabs)
                  Expanded(
                    child: _Tab<T>(
                      tab: tab,
                      isActive: tab.value == current,
                      onTap: () => onChanged(tab.value),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab<T> extends StatelessWidget {
  const _Tab({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  final FlowTab<T> tab;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final type = FlowTypography.of(context);

    final ink = isActive ? colors.textPrimary : colors.textSecondary;

    return Semantics(
      button: true,
      selected: isActive,
      label: tab.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: FlowTouch.minTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: FlowSpace.xs,
            vertical: FlowSpace.sm,
          ),
          decoration: BoxDecoration(
            color: isActive ? colors.surfaceElevated : null,
            borderRadius: BorderRadius.circular(FlowRadius.md),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(tab.icon, size: FlowIconSize.md, color: ink),
              const SizedBox(height: FlowSpace.xs),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  tab.label,
                  maxLines: 1,
                  softWrap: false,
                  style: type.caption.copyWith(color: ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
