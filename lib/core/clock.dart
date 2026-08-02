import 'dart:async';

/// Time, injected. Nothing in this app reads `DateTime.now()` or starts a
/// `Timer` directly — staleness and polling cadence are both testable only if
/// the clock can be driven by hand.
abstract class Clock {
  DateTime now();

  /// Fires once per [interval]. The first event arrives after one interval,
  /// not immediately; callers that want an eager first poll do it themselves.
  Stream<void> ticks(Duration interval);
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();

  @override
  Stream<void> ticks(Duration interval) =>
      Stream<void>.periodic(interval, (_) {});
}

/// A clock tests drive by hand: no `Future.delayed`, no real elapsed time, so
/// a six-poll scenario runs in microseconds and never flakes.
class FakeClock implements Clock {
  FakeClock([DateTime? start]) : _now = start ?? DateTime.utc(2026, 1, 1);

  DateTime _now;
  final List<StreamController<void>> _tickers = [];

  @override
  DateTime now() => _now;

  @override
  Stream<void> ticks(Duration interval) {
    final controller = StreamController<void>.broadcast();
    _tickers.add(controller);
    return controller.stream;
  }

  /// Moves the clock without firing a tick — for aging a record into
  /// staleness independently of the poll cadence.
  void advance(Duration by) => _now = _now.add(by);

  /// Fires one tick on every stream [ticks] has handed out, optionally
  /// advancing the clock first.
  void tick({Duration? by}) {
    if (by != null) advance(by);
    for (final controller in _tickers) {
      if (controller.hasListener) controller.add(null);
    }
  }

  /// True while anything is still subscribed — lets a test assert that
  /// `dispose()` really detached, rather than inferring it from silence.
  bool get hasListeners => _tickers.any((c) => c.hasListener);
}
