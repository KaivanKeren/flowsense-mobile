import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show TileProvider;

import '../../widgets/flow_tab_bar.dart';
import '../langganan/langganan_screen.dart';
import '../map/map_screen.dart';
import '../simpang/simpang_screen.dart';

/// The citizen app's routes.
///
/// No login and no account: nobody needs an identity to look at traffic, and
/// leaving it out deletes an entire authentication layer from the backend.
abstract final class WargaRoutes {
  static const peta = '/';
  static const simpang = '/simpang';
  static const langganan = '/langganan';
  static const tentang = '/tentang';
}

/// The three tabs, in order.
///
/// **Three, and only three.** `Laporan` and `Profil` both turned up in the
/// design tool's output as autofill and are both refused on purpose: citizen
/// reports need moderation they will not get, and there is no account to have
/// a profile for. `Tentang` is reached from inside Langganan rather than
/// spending a quarter of the bar on a page people read once.
enum WargaTab {
  peta(label: 'peta', icon: Icons.map_outlined),
  simpang(label: 'simpang', icon: Icons.traffic_outlined),
  langganan(label: 'langganan', icon: Icons.subscriptions_outlined);

  const WargaTab({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

/// Holds the three tabs and the bar beneath them.
///
/// An [IndexedStack] rather than a swapped child: the map keeps its camera
/// position and the list keeps its scroll offset when a rider checks the other
/// tab and comes back.
class WargaShell extends StatefulWidget {
  const WargaShell({
    super.key,
    this.initialTab = WargaTab.peta,
    this.mapTileProvider,
  });

  final WargaTab initialTab;

  /// Threaded through to [MapScreen] so widget tests never fetch a tile.
  final TileProvider? mapTileProvider;

  @override
  State<WargaShell> createState() => WargaShellState();
}

class WargaShellState extends State<WargaShell> {
  late WargaTab _tab = widget.initialTab;

  /// Lets a screen send the user somewhere else — the location-denied failure
  /// state opens the list rather than dead-ending.
  void go(WargaTab tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(
          // `StackFit.expand`, not the default `StackFit.loose`. Loose makes
          // the IndexedStack shrink-wrap its children, and each child here is
          // a `Scaffold` — which has no intrinsic height and collapses to
          // zero under loose constraints. The result is a 0 px tall body on
          // every tab, with only this bar left visible.
          sizing: StackFit.expand,
          index: _tab.index,
          children: [
            MapScreen(tileProvider: widget.mapTileProvider),
            SimpangScreen(onOpenMap: () => go(WargaTab.peta)),
            const LanggananScreen(),
          ],
        ),
        bottomNavigationBar: FlowTabBar<WargaTab>(
          tabs: [
            for (final tab in WargaTab.values)
              FlowTab(value: tab, label: tab.label, icon: tab.icon),
          ],
          current: _tab,
          onChanged: go,
        ),
      );
}
