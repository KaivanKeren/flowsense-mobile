import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'app_card.dart';
import 'status_chip.dart';

/// The only things an operator can do with a recommendation.
///
/// An enum rather than a free `String` label, and that is the whole point.
/// This console is **read-only**: it has no channel to a traffic light and
/// never will from here. A `String` label invites `Terapkan`, `Kirim ke lampu`
/// or `Ubah durasi` — three buttons that would promise a capability the system
/// does not have, in a domain where the promise is a safety claim.
///
/// Adding a case here is a deliberate act that a reviewer will see.
enum RecommendationAction {
  /// Open the reasoning. The default, and the only one that is always
  /// available.
  tinjau('Tinjau'),

  /// Record that a person agrees with it. Changes nothing on the road; it
  /// makes the operator's judgement part of the record.
  konfirmasi('Konfirmasi'),

  /// Write a note against it — usually disagreement, and why.
  catat('Catat');

  const RecommendationAction(this.label);

  final String label;
}

/// How much the model trusts its own output, in words as well as a number.
///
/// The bands exist because `0.62` is not a thing a person can act on. An
/// operator deciding whether to take a suggestion seriously needs `sedang`,
/// and the figure underneath it for the record.
enum ConfidenceBand {
  rendah('Kepercayaan rendah', StatusTone.critical),
  sedang('Kepercayaan sedang', StatusTone.warning),
  tinggi('Kepercayaan tinggi', StatusTone.normal);

  const ConfidenceBand(this.label, this.tone);

  final String label;
  final StatusTone tone;

  /// The band for [confidence], which is 0..1.
  ///
  /// Boundaries land on the **lower** band, the same way congestion thresholds
  /// land on the worse level: a model that is exactly 60% sure is not `tinggi`.
  static ConfidenceBand of(double confidence) {
    if (confidence <= 0.4) return ConfidenceBand.rendah;
    if (confidence <= 0.6) return ConfidenceBand.sedang;
    return ConfidenceBand.tinggi;
  }
}

/// A model suggestion, with everything needed to disagree with it.
///
/// The reasoning and the expected effect are not decoration — they are the
/// reason a person is in this loop at all. A card that showed only a
/// conclusion would be asking for assent rather than review, which is the
/// opposite of what a read-only console is for.
class RecommendationCard extends StatelessWidget {
  const RecommendationCard({
    super.key,
    required this.title,
    required this.confidence,
    required this.reason,
    required this.expectedImpact,
    this.actions = const [RecommendationAction.tinjau],
    this.onAction,
    this.footnote,
  });

  /// What is being suggested, phrased as a suggestion. `Perpanjang fase utara
  /// 8 detik` — never `Fase utara diperpanjang`.
  final String title;

  /// 0..1, as the model reports it.
  final double confidence;

  /// Why the model thinks so, in plain Indonesian.
  final String reason;

  /// What it expects to change, and by how much. Stated as an estimate,
  /// because it is one.
  final String expectedImpact;

  final List<RecommendationAction> actions;
  final ValueChanged<RecommendationAction>? onAction;

  /// Overrides the standing "this is a suggestion" line for a card that needs
  /// to say something more specific.
  final String? footnote;

  /// The line every one of these cards carries.
  ///
  /// Not a caption someone can forget to add: it is the sentence that keeps
  /// the whole screen honest, so it is part of the component.
  static const String readOnlyNote =
      'Rekomendasi model. Konsol ini tidak mengubah lampu lalu lintas.';

  double get _clamped => confidence.clamp(0.0, 1.0);

  ConfidenceBand get band => ConfidenceBand.of(_clamped);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final type = FlowTypography.of(context);
    final percent = (_clamped * 100).round();

    return AppCard(
      semanticsLabel: '$title. ${band.label}, $percent persen. '
          'Alasan: $reason. Perkiraan dampak: $expectedImpact. '
          '${footnote ?? readOnlyNote}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: type.sectionTitle),
          const SizedBox(height: FlowSpace.md),

          // Confidence: a word, a number, and a bar — three encodings of one
          // value, so it survives colour blindness and a tiny screen alike.
          Wrap(
            spacing: FlowSpace.sm,
            runSpacing: FlowSpace.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusChip(
                label: band.label,
                tone: band.tone,
                semanticsPrefix: null,
              ),
              Text('$percent%', style: type.metricUnit),
            ],
          ),
          const SizedBox(height: FlowSpace.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(FlowRadius.sm),
            child: LinearProgressIndicator(
              value: _clamped,
              minHeight: FlowSpace.sm,
              backgroundColor: colors.dataTrack,
              // Neutral ink. The bar restates the band beside it; painting it
              // a status hue would spend a reserved colour on a second copy of
              // information already on screen.
              valueColor: AlwaysStoppedAnimation<Color>(colors.dataInk),
            ),
          ),

          const SizedBox(height: FlowSpace.lg),
          _Field(label: 'Alasan', value: reason),
          const SizedBox(height: FlowSpace.md),
          _Field(label: 'Perkiraan dampak', value: expectedImpact),

          const SizedBox(height: FlowSpace.lg),
          Text(
            footnote ?? readOnlyNote,
            style: type.caption.copyWith(color: colors.textMuted),
          ),

          if (actions.isNotEmpty && onAction != null) ...[
            const SizedBox(height: FlowSpace.md),
            // Wrap, not Row: three buttons at textScale 1.3 in a 320 px card
            // do not fit on one line, and each has to keep its full 48 dp
            // rather than being squeezed to fit beside the others.
            Wrap(
              spacing: FlowSpace.sm,
              runSpacing: FlowSpace.sm,
              children: [
                for (final action in actions)
                  OutlinedButton(
                    key: ValueKey('recommendation-${action.name}'),
                    onPressed: () => onAction!(action),
                    child: Text(action.label),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final type = FlowTypography.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(FlowTypography.monoLabel(label), style: type.labelMono),
        const SizedBox(height: FlowSpace.xs),
        Text(value, style: type.body),
      ],
    );
  }
}
