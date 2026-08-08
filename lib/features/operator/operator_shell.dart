import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/max_width.dart';
import 'akun_screen.dart';
import 'dashboard_screen.dart';
import 'kesehatan_screen.dart';
import 'peringatan_screen.dart';

/// The operator console's four tabs.
///
/// Four, and no fifth. The design tool's exports kept adding one; every extra
/// it proposed implied a capability the system does not have. Signing out
/// lives inside Akun rather than taking a tab of its own.
enum OperatorTab {
  dashboard(label: 'Dashboard', icon: Icons.dashboard_outlined),
  kesehatan(label: 'Kesehatan', icon: Icons.monitor_heart_outlined),
  peringatan(label: 'Peringatan', icon: Icons.warning_amber_outlined),
  akun(label: 'Akun', icon: Icons.person_outline);

  const OperatorTab({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

/// Holds the four tabs and the bar beneath them.
///
/// An [IndexedStack], so the dashboard keeps its scroll position while an
/// operator checks connector health and comes back — the same reason the
/// citizen shell uses one.
class OperatorShell extends StatefulWidget {
  const OperatorShell({super.key, this.initialTab = OperatorTab.dashboard});

  final OperatorTab initialTab;

  @override
  State<OperatorShell> createState() => _OperatorShellState();
}

class _OperatorShellState extends State<OperatorShell> {
  late OperatorTab _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(
          // Expand, not the default loose fit: a loose IndexedStack
          // shrink-wraps its children, and a nested Scaffold has no intrinsic
          // height, so every tab would render 0 px tall.
          sizing: StackFit.expand,
          index: _tab.index,
          children: const [
            DashboardScreen(),
            KesehatanScreen(),
            PeringatanScreen(),
            AkunScreen(),
          ],
        ),
        bottomNavigationBar: _TabBar(
          current: _tab,
          onChanged: (tab) => setState(() => _tab = tab),
        ),
      );
}

/// Hand-built for the same reason the citizen bar is: the spec's active state
/// is a soft grey capsule behind the icon **and** its label, and Material's
/// indicator wraps the icon alone.
class _TabBar extends StatelessWidget {
  const _TabBar({required this.current, required this.onChanged});

  final OperatorTab current;
  final ValueChanged<OperatorTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final surfaces = FlowSurfaces.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaces.page,
        border: Border(top: BorderSide(color: surfaces.roadLine)),
      ),
      child: SafeArea(
        top: false,
        child: MaxWidth448(
          // The bar has to hug its content. Without this it fills the screen
          // and the Scaffold hands the body zero height.
          shrinkWrapHeight: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              children: [
                for (final tab in OperatorTab.values)
                  Expanded(
                    child: _Tab(
                      tab: tab,
                      isActive: tab == current,
                      onTap: () => onChanged(tab),
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

class _Tab extends StatelessWidget {
  const _Tab({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  final OperatorTab tab;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = FlowSurfaces.of(context);
    final text = Theme.of(context).textTheme;

    // The inactive icon takes the spec's #9AA0A0; the label takes a readable
    // ink, because a tab name is text and text owes 4.5:1.
    final iconColor = isActive ? surfaces.textPrimary : surfaces.faintInk;
    final labelColor = isActive ? surfaces.textPrimary : surfaces.textFaint;

    return Semantics(
      button: true,
      selected: isActive,
      label: tab.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? surfaces.map : null,
            borderRadius: BorderRadius.circular(FlowRadius.card),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(tab.icon, size: 20, color: iconColor),
              const SizedBox(height: 2),
              Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(color: labelColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
