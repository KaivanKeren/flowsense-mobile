import 'congestion.dart';

/// The four numbers across the top of the dashboard.
///
/// `tanpaData` counts both intersections whose feed went stale and those that
/// never reported at all. Folding either of them into `lancar` would be the
/// single most dangerous thing this console could do — an operator would read
/// a dead connector as an empty road.
class StatusSummary {
  const StatusSummary({
    required this.macet,
    required this.padat,
    required this.lancar,
    required this.tanpaData,
  });

  final int macet;
  final int padat;
  final int lancar;
  final int tanpaData;

  int get total => macet + padat + lancar + tanpaData;
}

/// Counts one entry per intersection.
///
/// [levels] and [stale] are parallel: a stale reading counts as `tanpaData`
/// whatever level it last reported, because a four-minute-old `macet` is a
/// silence rather than a jam.
StatusSummary summarise(List<({CongestionLevel level, bool isStale})> rows) {
  var macet = 0;
  var padat = 0;
  var lancar = 0;
  var tanpaData = 0;

  for (final row in rows) {
    if (row.isStale || row.level == CongestionLevel.unknown) {
      tanpaData++;
      continue;
    }
    switch (row.level) {
      case CongestionLevel.macet:
        macet++;
      case CongestionLevel.padat:
        padat++;
      case CongestionLevel.lancar:
        lancar++;
      case CongestionLevel.unknown:
        tanpaData++; // unreachable, handled above
    }
  }

  return StatusSummary(
    macet: macet,
    padat: padat,
    lancar: lancar,
    tanpaData: tanpaData,
  );
}
