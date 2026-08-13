import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/api_exception.dart';
import '../../core/max_width.dart';
import '../../data/models/intersection.dart';
import '../../domain/calibration.dart';
import '../../domain/congestion.dart';
import '../../domain/lane_label.dart';
import '../../state/auth_providers.dart';
import '../../state/calibration_providers.dart';
import '../../state/providers.dart';
import '../common/feed_view.dart';
import '../common/status_pill.dart';

/// Setting the number every level in the app divides by.
///
/// Capacity is not a display preference. `count / capacity` is the whole
/// classification, so a wrong capacity does not look like a bug — it looks
/// like traffic. Two consequences shape this screen: the operator sees the
/// level each number produces **before** committing, and the save records who
/// made the call.
class KalibrasiScreen extends ConsumerStatefulWidget {
  const KalibrasiScreen({super.key, required this.cameraId});

  final String cameraId;

  @override
  ConsumerState<KalibrasiScreen> createState() => _KalibrasiScreenState();
}

class _KalibrasiScreenState extends ConsumerState<KalibrasiScreen> {
  final _controllers = <String, TextEditingController>{};

  bool _busy = false;
  String? _error;
  CapacityCalibration? _saved;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// One controller per lane, seeded from the stored capacity the first time
  /// the lane is seen. Later rebuilds leave it alone — the field belongs to
  /// whoever is typing in it.
  TextEditingController _controllerFor(String lane, int stored) =>
      _controllers.putIfAbsent(
        lane,
        () => TextEditingController(text: '$stored'),
      );

  void _reset(Intersection intersection, int fallback) {
    setState(() {
      _error = null;
      for (final lane in intersection.lanes) {
        _controllers[lane]?.text =
            '${_storedCapacity(intersection, lane, fallback)}';
      }
    });
  }

  int _storedCapacity(Intersection intersection, String lane, int fallback) {
    final saved = _saved?.capacity[lane];
    if (saved != null) return saved;
    return intersection.capacityFor(lane, fallback: fallback);
  }

  Future<void> _save(Intersection intersection) async {
    if (_busy) return;

    // Every lane has to be valid before anything is written. A partial save
    // would leave the classification in a state nobody chose.
    final capacity = <String, int>{};
    for (final lane in intersection.lanes) {
      final raw = _controllers[lane]?.text ?? '';
      if (capacityError(raw) != null) {
        setState(() => _error = 'Perbaiki kapasitas yang bertanda merah.');
        return;
      }
      capacity[lane] = int.parse(raw.trim());
    }

    final auth = ref.read(authProvider);
    if (auth is! AuthSignedIn) {
      setState(() => _error = 'Masuk dulu untuk menyimpan kalibrasi.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final saved = await ref.read(calibrationApiProvider).save(
            widget.cameraId,
            capacity: capacity,
            by: auth.operator.nama,
          );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _saved = saved;
      });
      ref.invalidate(calibrationProvider(widget.cameraId));
    } on ApiException {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Gagal menyimpan kalibrasi. Coba lagi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = FlowSurfaces.of(context);
    final text = Theme.of(context).textTheme;
    final config = ref.watch(appConfigProvider);

    // Watched, not merely read at save time. `authProvider` resolves the
    // stored token asynchronously, so a screen that only reads it on the
    // button press sees `AuthRestoring` and refuses a save that should have
    // worked.
    final auth = ref.watch(authProvider);

    final intersections = ref.watch(intersectionsProvider).valueOrNull;
    final intersection = intersections
        ?.where((i) => i.id == widget.cameraId)
        .cast<Intersection?>()
        .firstWhere((i) => true, orElse: () => null);

    // The reading being classified. A stale one is still the right number to
    // preview against — the operator is calibrating the divisor, not judging
    // the traffic.
    final feed = ref.watch(snapshotProvider).valueOrNull;
    final record = feed == null
        ? null
        : FeedView.of(feed, ref.watch(clockProvider).now())
            .snapshot
            ?.forCamera(widget.cameraId);

    final stored = _saved ??
        ref.watch(calibrationProvider(widget.cameraId)).valueOrNull;
    final lastChanged = stored == null ? null : lastChangedLine(stored);

    return Scaffold(
      backgroundColor: surfaces.page,
      // `Kalibrasi — Simpang DPRD` needed 293 px and was given 288 at
      // textScale 1.3 on a 320 px screen, so it shipped as
      // `Kalibrasi — Simpang DPR…`. The name is not chrome and does not
      // belong in a bar sized by whatever is left over; it leads the body
      // instead, where it can wrap.
      appBar: AppBar(title: const Text('Kalibrasi')),
      body: intersection == null
          ? const Center(child: CircularProgressIndicator())
          : MaxWidth448(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      FlowSpace.lg,
                      FlowSpace.md,
                      FlowSpace.lg,
                      FlowSpace.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(intersection.name, style: text.titleLarge),
                        const SizedBox(height: FlowSpace.xs),
                        Text(
                          'Kapasitas adalah jumlah kendaraan yang memenuhi '
                          'lajur saat berhenti total.',
                          style: text.bodyMedium
                              ?.copyWith(color: surfaces.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        for (final lane in intersection.lanes)
                          _LaneRow(
                            lane: lane,
                            count: record?.perLane[lane],
                            controller: _controllerFor(
                              lane,
                              _storedCapacity(
                                intersection,
                                lane,
                                config.laneCapacityDefault,
                              ),
                            ),
                            onChanged: () => setState(() {}),
                          ),
                      ],
                    ),
                  ),
                  _Footer(
                    // Saving needs a signed-in operator to attribute it to,
                    // so the button waits for the session rather than failing
                    // on press.
                    busy: _busy || auth is! AuthSignedIn,
                    error: _error,
                    lastChanged: lastChanged,
                    onSave: () => _save(intersection),
                    onCancel: () =>
                        _reset(intersection, config.laneCapacityDefault),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Lane name and current count on the left, the level this capacity produces
/// in the middle, the number being edited on the right.
class _LaneRow extends StatelessWidget {
  const _LaneRow({
    required this.lane,
    required this.count,
    required this.controller,
    required this.onChanged,
  });

  final String lane;

  /// The reading being classified, or null when nothing has arrived.
  final int? count;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final surfaces = FlowSurfaces.of(context);
    final text = Theme.of(context).textTheme;

    final error = capacityError(controller.text);
    final capacity = error == null ? int.parse(controller.text.trim()) : 0;

    // With an invalid capacity the preview shows `unknown` rather than
    // guessing — the same rule the rest of the app follows, and the reason
    // zero is rejected on save.
    final level = count == null
        ? CongestionLevel.unknown
        : levelForLane(count!, capacity);

    return Container(
      key: ValueKey('capacity-$lane'),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: surfaces.roadLine)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(laneLabel(lane), style: text.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      count == null
                          ? 'belum ada data'
                          : 'sekarang $count kendaraan',
                      style: text.bodySmall
                          ?.copyWith(color: surfaces.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              StatusPill(level: level, isStale: false),
              const SizedBox(width: 10),
              SizedBox(
                width: 64,
                child: TextField(
                  controller: controller,
                  onChanged: (_) => onChanged(),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  style: text.titleMedium,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(FlowRadius.control),
                      borderSide: BorderSide(
                        color: error == null
                            ? surfaces.textPrimary
                            : surfaces.errorInk,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(FlowRadius.control),
                      borderSide: BorderSide(
                        color: error == null
                            ? surfaces.textPrimary
                            : surfaces.errorInk,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 6),
            Text(
              error,
              style: text.bodySmall?.copyWith(color: surfaces.errorInk),
            ),
          ],
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.busy,
    required this.error,
    required this.lastChanged,
    required this.onSave,
    required this.onCancel,
  });

  final bool busy;
  final String? error;
  final String? lastChanged;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final surfaces = FlowSurfaces.of(context);
    final text = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaces.page,
        border: Border(top: BorderSide(color: surfaces.roadLine)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error != null) ...[
                Text(
                  error!,
                  style: text.bodySmall?.copyWith(color: surfaces.errorInk),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : onCancel,
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: busy ? null : onSave,
                      child: busy
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: surfaces.card,
                              ),
                            )
                          : const Text('Simpan'),
                    ),
                  ),
                ],
              ),
              if (lastChanged != null) ...[
                const SizedBox(height: 10),
                Text(
                  lastChanged!,
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: surfaces.textFaint),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
