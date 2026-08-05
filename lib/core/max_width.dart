import 'package:flutter/widgets.dart';

/// Caps content at the 448 px mobile-first width the proposal specifies.
class MaxWidth448 extends StatelessWidget {
  const MaxWidth448({
    super.key,
    required this.child,
    this.shrinkWrapHeight = false,
  });

  final Widget child;

  /// Whether to take the child's height instead of filling the space.
  ///
  /// The default centres with `Center`, which — with no height factor —
  /// **expands to fill its constraints vertically**. That is what a full screen
  /// wants, and it is a trap anywhere the parent measures its child to decide
  /// its own size: in a `Scaffold.bottomNavigationBar` the bar swells to the
  /// whole screen and the body is handed `h=0.0`, leaving a blank app with only
  /// a navigation bar on it.
  ///
  /// Set this wherever the wrapper sits inside something that is supposed to
  /// hug its content.
  final bool shrinkWrapHeight;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        heightFactor: shrinkWrapHeight ? 1.0 : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 448),
          child: child,
        ),
      );
}
