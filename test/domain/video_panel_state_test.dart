import 'package:flowsense_mobile/domain/video_panel_state.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime.utc(2026, 8, 4, 16, 42);

void main() {
  test('starts by saying it is connecting, not by showing a black box', () {
    const state = VideoPanelState();
    expect(state.phase, VideoPhase.memuat);
    expect(state.phase.label, 'Menyambungkan');
    expect(state.isBuffering, isFalse);
  });

  test('every phase says what it is', () {
    // A player sitting silently on a black rectangle is the failure the spec
    // calls out: the operator cannot tell loading from dead.
    expect(VideoPhase.berjalan.label, 'Siaran langsung');
    expect(VideoPhase.gagal.label, 'Stream terputus');
  });

  group('buffering budget', () {
    test('a short stall does nothing', () {
      final state = const VideoPanelState().buffering(_t0);

      expect(
        state.decide(_t0.add(const Duration(seconds: 9))),
        VideoPanelDecision.none,
      );
    });

    test('ten seconds of buffering triggers one reload', () {
      final state = const VideoPanelState().buffering(_t0);

      expect(
        state.decide(_t0.add(const Duration(seconds: 10))),
        VideoPanelDecision.reload,
      );

      final reloaded = state.advance(_t0.add(const Duration(seconds: 10)));
      expect(reloaded.hasAutoReloaded, isTrue);
      expect(reloaded.phase, VideoPhase.memuat);
      expect(reloaded.isBuffering, isFalse, reason: 'the stall clock resets');
    });

    test('a second stall gives up rather than reloading again', () {
      // Retrying forever is how a dead camera becomes a battery drain that
      // never admits anything is wrong.
      final stalled = const VideoPanelState()
          .buffering(_t0)
          .advance(_t0.add(const Duration(seconds: 10)))
          .buffering(_t0.add(const Duration(seconds: 11)));

      expect(
        stalled.decide(_t0.add(const Duration(seconds: 30))),
        VideoPanelDecision.giveUp,
      );
      expect(
        stalled.advance(_t0.add(const Duration(seconds: 30))).phase,
        VideoPhase.gagal,
      );
    });

    test('recovering clears the stall but not the spent allowance', () {
      final recovered = const VideoPanelState()
          .buffering(_t0)
          .advance(_t0.add(const Duration(seconds: 10)))
          .playing();

      expect(recovered.phase, VideoPhase.berjalan);
      expect(recovered.isBuffering, isFalse);
      // One free reload per session, not one per stall.
      expect(recovered.hasAutoReloaded, isTrue);
    });

    test('the stall clock starts at the first buffering report, not the last',
        () {
      var state = const VideoPanelState().buffering(_t0);
      state = state.buffering(_t0.add(const Duration(seconds: 5)));

      expect(state.bufferingSince, _t0);
      expect(
        state.decide(_t0.add(const Duration(seconds: 10))),
        VideoPanelDecision.reload,
      );
    });

    test('a stream that is not buffering is never reloaded', () {
      expect(
        const VideoPanelState().playing().decide(
              _t0.add(const Duration(hours: 1)),
            ),
        VideoPanelDecision.none,
      );
    });
  });

  group('manual reload', () {
    test('resets to connecting and restores the automatic allowance', () {
      // A person pressing the button is not the runaway loop the budget exists
      // to prevent.
      final failed = const VideoPanelState()
          .buffering(_t0)
          .advance(_t0.add(const Duration(seconds: 10)))
          .failed();
      expect(failed.hasAutoReloaded, isTrue);

      final retried = failed.manualReload();
      expect(retried.phase, VideoPhase.memuat);
      expect(retried.hasAutoReloaded, isFalse);
      expect(retried.isBuffering, isFalse);
    });
  });

  test('a failed stream stays failed while it keeps buffering', () {
    final failed = const VideoPanelState().failed().buffering(_t0);
    expect(failed.phase, VideoPhase.gagal);
  });
}
