import 'package:flutter/material.dart';

import '../../widgets/flow_tab_bar.dart';
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
        bottomNavigationBar: FlowTabBar<OperatorTab>(
          tabs: [
            for (final tab in OperatorTab.values)
              FlowTab(value: tab, label: tab.label, icon: tab.icon),
          ],
          current: _tab,
          onChanged: (tab) => setState(() => _tab = tab),
        ),
      );
}
