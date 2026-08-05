import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show TileProvider;

import '../../app/theme.dart';
import '../../core/max_width.dart';
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
        bottomNavigationBar: _TabBar(
          current: _tab,
          onChanged: go,
        ),
      );
}

/// Hand-built rather than a [NavigationBar], because the spec's active state is
/// a soft grey capsule behind the icon *and* its label — Material's indicator
/// wraps the icon alone and cannot be talked into including the text.
class _TabBar extends StatelessWidget {
  const _TabBar({required this.current, required this.onChanged});

  final WargaTab current;
  final ValueChanged<WargaTab> onChanged;

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
          // The bar must hug its content. Without this it fills the screen and
          // the Scaffold hands the body zero height.
          shrinkWrapHeight: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                for (final tab in WargaTab.values)
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

  final WargaTab tab;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = FlowSurfaces.of(context);
    final text = Theme.of(context).textTheme;

    // Inactive tabs use the spec's #9AA0A0 for the icon but a readable ink for
    // the label: a tab name is text, and text owes 4.5:1.
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
              Icon(tab.icon, size: 22, color: iconColor),
              const SizedBox(height: 2),
              Text(
                tab.label,
                style: text.bodySmall?.copyWith(color: labelColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
