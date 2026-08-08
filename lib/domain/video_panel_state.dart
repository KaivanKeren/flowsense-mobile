/// What the camera panel is doing.
///
/// Three states and no fourth. A player sitting silently on a black rectangle
/// is the failure mode the layout spec calls out by name — the operator cannot
/// tell a loading stream from a dead one, so every state here says which it is.
enum VideoPhase {
  memuat,
  berjalan,
  gagal;

  String get label => switch (this) {
        VideoPhase.memuat => 'Menyambungkan',
        VideoPhase.berjalan => 'Siaran langsung',
        VideoPhase.gagal => 'Stream terputus',
      };
}

/// The rule for when a stalled stream gets one more chance.
///
/// From the layout spec: buffering for more than [stallLimit] triggers **one**
/// automatic playlist reload, and if that does not recover, the panel gives up
/// to [VideoPhase.gagal]. Automatic retries beyond the first are how a dead
/// camera turns into a battery drain that never admits anything is wrong.
///
/// Pure and clock-injected, so the whole policy is unit-tested without a
/// player, a network, or a ten-second wait.
class VideoPanelState {
  const VideoPanelState({
    this.phase = VideoPhase.memuat,
    this.bufferingSince,
    this.hasAutoReloaded = false,
  });

  static const stallLimit = Duration(seconds: 10);

  final VideoPhase phase;

  /// When the current buffering spell began, or null if it is not buffering.
  final DateTime? bufferingSince;

  /// Whether the one automatic reload has already been spent.
  final bool hasAutoReloaded;

  bool get isBuffering => bufferingSince != null;

  /// The player reported it is buffering, at [at].
  VideoPanelState buffering(DateTime at) => VideoPanelState(
        phase: phase == VideoPhase.gagal ? phase : VideoPhase.memuat,
        bufferingSince: bufferingSince ?? at,
        hasAutoReloaded: hasAutoReloaded,
      );

  /// The player produced frames. Clears the stall clock, but **not** the
  /// spent-reload flag: a stream that recovers once and stalls again should
  /// not get a second free reload in the same session.
  VideoPanelState playing() => VideoPanelState(
        phase: VideoPhase.berjalan,
        hasAutoReloaded: hasAutoReloaded,
      );

  /// The player, or the network, gave up.
  VideoPanelState failed() => VideoPanelState(
        phase: VideoPhase.gagal,
        hasAutoReloaded: hasAutoReloaded,
      );

  /// The operator pressed `Muat ulang`. A manual reload always gets a fresh
  /// automatic allowance — a person asking again is not the runaway loop this
  /// budget exists to prevent.
  VideoPanelState manualReload() => const VideoPanelState();

  /// What to do at [now], given how long it has been buffering.
  VideoPanelDecision decide(DateTime now) {
    final since = bufferingSince;
    if (since == null) return VideoPanelDecision.none;
    if (now.difference(since) < stallLimit) return VideoPanelDecision.none;
    return hasAutoReloaded
        ? VideoPanelDecision.giveUp
        : VideoPanelDecision.reload;
  }

  /// Applies [decide]'s answer.
  VideoPanelState advance(DateTime now) => switch (decide(now)) {
        VideoPanelDecision.none => this,
        VideoPanelDecision.reload => const VideoPanelState(
            hasAutoReloaded: true,
          ),
        VideoPanelDecision.giveUp => VideoPanelState(
            phase: VideoPhase.gagal,
            hasAutoReloaded: hasAutoReloaded,
          ),
      };
}

enum VideoPanelDecision { none, reload, giveUp }
