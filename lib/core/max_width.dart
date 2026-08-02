import 'package:flutter/widgets.dart';

/// Caps content at the 448 px mobile-first width the proposal specifies.
class MaxWidth448 extends StatelessWidget {
  const MaxWidth448({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 448),
          child: child,
        ),
      );
}
