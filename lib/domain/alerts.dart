import '../data/models/intersection.dart';
import '../data/models/traffic_snapshot.dart';
import 'congestion.dart';

/// What the rule decided for one intersection on one poll.
enum AlertDecision { none, raise, clear }

/// One poll's reading for one intersection, reduced to what the rule needs.
///
/// [name] rides along only so the notification has something to say; the rule
/// itself never reads it.
class AlertObservation {
  const AlertObservation({
    required this.cameraId,
    required this.name,
    required this.level,
    required this.isStale,
  });

  final String cameraId;
  final String name;
  final CongestionLevel level;
  final bool isStale;
}

/// Per-intersection debounce bookkeeping, carried from one poll to the next.
///
/// Immutable: [AlertRule] is a pure function of `(previous, observation)`, so
/// a test can replay any poll sequence without an engine.
class AlertState {
  const AlertState({
    this.macetPolls = 0,
    this.lancarPolls = 0,
    this.isRaised = false,
  });

  static const initial = AlertState();

  /// Consecutive polls seen as `macet`. Reset by any other known level.
  final int macetPolls;

  /// Consecutive polls seen as `lancar`. Reset by any other known level.
  final int lancarPolls;

  /// True between a `raise` and its matching `clear`.
  final bool isRaised;
}

/// [AlertRule.evaluate]'s answer: what to do, and what to remember.
class AlertOutcome {
  const AlertOutcome(this.decision, this.state);

  final AlertDecision decision;
  final AlertState state;
}

/// When a sustained jam becomes worth interrupting someone for.
///
/// Debounce is a rule, not a UI detail: a single `macet` poll is noise — a
/// bus unloading, a delivery van, one bad frame from the detector — and
/// notifying on it trains people to ignore the app. Only a jam that survives
/// [raiseAfter] consecutive polls is real, and only [clearAfter] consecutive
/// `lancar` polls call it over.
class AlertRule {
  const AlertRule({
    this.raiseAfter = 3,
    this.clearAfter = 3,
    this.maxGap = const Duration(minutes: 2),
  });

  /// Consecutive `macet` polls before an alert fires.
  final int raiseAfter;

  /// Consecutive `lancar` polls before an active alert is called off.
  final int clearAfter;

  /// The longest gap between polls that still counts as "consecutive". A phone
  /// that was asleep for an hour has three readings, not a three-poll streak,
  /// so the streaks reset — but an already-raised alert survives, because
  /// nothing observed says the jam ended.
  final Duration maxGap;

  AlertOutcome evaluate(
    AlertState previous,
    AlertObservation current, {
    required Duration since,
  }) {
    final base =
        since > maxGap ? AlertState(isRaised: previous.isRaised) : previous;

    switch (current.isStale ? CongestionLevel.unknown : current.level) {
      // Absence of data is not a traffic jam, and it is not a clear road
      // either. The connector going down must never wake anyone up, and must
      // never silently cancel a jam it can no longer see.
      case CongestionLevel.unknown:
        return AlertOutcome(
          AlertDecision.none,
          AlertState(isRaised: base.isRaised),
        );

      case CongestionLevel.macet:
        final macetPolls = base.macetPolls + 1;
        if (!base.isRaised && macetPolls >= raiseAfter) {
          return AlertOutcome(
            AlertDecision.raise,
            AlertState(macetPolls: macetPolls, isRaised: true),
          );
        }
        return AlertOutcome(
          AlertDecision.none,
          AlertState(macetPolls: macetPolls, isRaised: base.isRaised),
        );

      case CongestionLevel.lancar:
        final lancarPolls = base.lancarPolls + 1;
        if (base.isRaised && lancarPolls >= clearAfter) {
          return const AlertOutcome(AlertDecision.clear, AlertState.initial);
        }
        return AlertOutcome(
          AlertDecision.none,
          AlertState(lancarPolls: lancarPolls, isRaised: base.isRaised),
        );

      // Padat is the middle ground: not a jam to announce, not a recovery to
      // trust. It breaks both streaks and holds any active alert open.
      case CongestionLevel.padat:
        return AlertOutcome(
          AlertDecision.none,
          AlertState(isRaised: base.isRaised),
        );
    }
  }
}

/// A decision worth acting on, paired with the reading that produced it.
class AlertEvent {
  const AlertEvent({required this.decision, required this.observation});

  final AlertDecision decision;
  final AlertObservation observation;
}

/// Applies [AlertRule] across every intersection and remembers where each one
/// stands. Pure: it holds state but touches no clock, notifier, or platform.
class AlertEngine {
  AlertEngine({this.rule = const AlertRule()});

  final AlertRule rule;
  final Map<String, AlertState> _states = {};
  DateTime? _lastPollAt;

  AlertState stateFor(String cameraId) => _states[cameraId] ?? AlertState.initial;

  /// Feeds one poll's readings through the rule. Returns only the decisions
  /// worth acting on — `none` is the overwhelming majority and never escapes.
  ///
  /// Call this **once per successful poll**. Replaying the same snapshot (a
  /// cache read, a widget rebuild) would count one reading toward the
  /// threshold twice and fire early.
  List<AlertEvent> observe(List<AlertObservation> observations, DateTime at) {
    final since =
        _lastPollAt == null ? Duration.zero : at.difference(_lastPollAt!);
    _lastPollAt = at;

    final events = <AlertEvent>[];
    for (final observation in observations) {
      final outcome = rule.evaluate(
        stateFor(observation.cameraId),
        observation,
        since: since,
      );
      _states[observation.cameraId] = outcome.state;
      if (outcome.decision != AlertDecision.none) {
        events.add(
          AlertEvent(decision: outcome.decision, observation: observation),
        );
      }
    }
    return events;
  }
}

/// Reduces a snapshot to one observation per known intersection.
///
/// An intersection missing from the snapshot still yields an observation —
/// marked stale, so it neither raises nor clears. Records for cameras the
/// geometry does not know about are skipped: an alert needs a name and a place.
List<AlertObservation> observationsFor({
  required TrafficSnapshot snapshot,
  required List<Intersection> intersections,
  required DateTime now,
  required Duration staleAfter,
  int laneCapacityDefault = 12,
}) =>
    [
      for (final intersection in intersections)
        () {
          final record = snapshot.forCamera(intersection.id);
          return AlertObservation(
            cameraId: intersection.id,
            name: intersection.name,
            level: record == null
                ? CongestionLevel.unknown
                : levelForIntersection(
                    record,
                    intersection,
                    laneCapacityDefault: laneCapacityDefault,
                  ),
            isStale: record == null || isStale(record, now, staleAfter),
          );
        }(),
    ];
