/// Finds text that is on screen but not readable.
///
/// This is the failure `overflow_test.dart` cannot see. A `RenderFlex`
/// overflow throws and turns the screen yellow and black; a `Text` squeezed
/// into a box too narrow for it just **clips**, silently, and every finder
/// still locates it. That is how a bottom-navigation label truncated to `Ove`
/// survives a green test suite.
library;

import 'package:flowsense_mobile/features/operator/operator_shell.dart';
import 'package:flowsense_mobile/widgets/flow_tab_bar.dart';
import 'package:flowsense_mobile/features/shell/warga_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screen_harness.dart';

/// One clipped or ellipsized paragraph.
typedef Truncation = ({String text, double laidOut, double needed});

/// Every paragraph on screen whose full text does not fit the box it was given.
///
/// Compares the laid-out width against the width the text would need on one
/// line. A paragraph that legitimately wraps to several lines is skipped —
/// wrapping is not truncation.
List<Truncation> truncatedText(WidgetTester tester) {
  final found = <Truncation>[];

  void visit(RenderObject node) {
    if (node is RenderParagraph) {
      final text = node.text.toPlainText();
      if (text.trim().isNotEmpty) {
        // Width the text would need on one line.
        final needed = node.getMaxIntrinsicWidth(double.infinity);
        // Height of exactly one line, for this style.
        final oneLine = node.getMinIntrinsicHeight(double.infinity);

        // Two ways text goes missing quietly. `maxLines` with an ellipsis or a
        // clip reports itself; `softWrap: false` in a narrow box does not, and
        // is caught by the second clause — one line tall, but wider than the
        // box it was given.
        //
        // Half a pixel of slack throughout: intrinsic and laid-out widths are
        // computed by different paths and disagree in the last bit.
        final clipped = node.didExceedMaxLines ||
            (needed > node.size.width + 0.5 &&
                node.size.height <= oneLine + 0.5);

        if (clipped) {
          found.add((text: text, laidOut: node.size.width, needed: needed));
        }
      }
    }
    node.visitChildren(visit);
  }

  visit(tester.binding.rootElement!.renderObject!);
  return found;
}

String _describe(List<Truncation> items) => items
    .map((t) => '  "${t.text}" got ${t.laidOut.toStringAsFixed(0)}px, '
        'needs ${t.needed.toStringAsFixed(0)}px')
    .join('\n');

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadTestFonts();
  });

  group('navigation labels are never cut short', () {
    // The brief's second broken-layout item, and the one that is invisible to
    // every other kind of test: `Overview` rendered as `Ove`. A tab label that
    // does not fit is not a styling problem, it is a destination the user
    // cannot identify.
    for (final width in kTestWidths) {
      for (final scale in kTestTextScales) {
        testWidgets('operator, ${width.toInt()}px at ${scale}x',
            (tester) async {
          await pumpScreen(
            tester,
            const OperatorShell(),
            width: width,
            textScale: scale,
          );

          final labels = OperatorTab.values.map((t) => t.label).toSet();
          final cut =
              truncatedText(tester).where((t) => labels.contains(t.text));

          expect(
            cut,
            isEmpty,
            reason: 'tab labels cut off at ${width.toInt()}px, '
                'textScale $scale:\n${_describe(cut.toList())}',
          );
        });

        testWidgets('warga, ${width.toInt()}px at ${scale}x', (tester) async {
          await pumpScreen(
            tester,
            const WargaShell(),
            width: width,
            textScale: scale,
          );

          final labels = WargaTab.values.map((t) => t.label).toSet();
          final cut =
              truncatedText(tester).where((t) => labels.contains(t.text));

          expect(
            cut,
            isEmpty,
            reason: 'tab labels cut off at ${width.toInt()}px, '
                'textScale $scale:\n${_describe(cut.toList())}',
          );
        });
      }
    }
  });

  group('shrinking a label has a floor', () {
    // `FlowTabBar` scales a label down rather than clipping it, which is only
    // an improvement while the result stays readable. The base size is 11 —
    // the bottom of the type scale — so the guarantee is that scaling gives
    // back what `textScaler` added and no more. Without this test, "it fits
    // now" would be satisfied by rendering the label at four pixels.
    for (final width in kTestWidths) {
      for (final scale in kTestTextScales) {
        testWidgets('${width.toInt()}px at ${scale}x stays at 11 px or above',
            (tester) async {
          await pumpScreen(
            tester,
            const OperatorShell(),
            width: width,
            textScale: scale,
          );

          for (final tab in OperatorTab.values) {
            // Scoped to the bar. `Dashboard` is also the screen's own title,
            // whose base size is 18 rather than 11 — measuring that one
            // against an 11 px floor would make this test pass by accident.
            final finder = find.descendant(
              of: find.byType(FlowTabBar<OperatorTab>),
              matching: find.text(tab.label),
            );
            expect(finder, findsOneWidget);
            final paragraph = tester.renderObject<RenderParagraph>(finder);

            // `getRect` walks the ancestor transforms, so a FittedBox's scale
            // is in this number while the paragraph's own `size` is not.
            final painted = tester.getRect(finder.first).width;
            final natural = paragraph.getMaxIntrinsicWidth(double.infinity);
            final shrink = painted / natural;

            // 11 is `FlowTextSize.caption`, the floor of the type scale.
            final effective = 11 * scale * shrink;
            expect(
              effective,
              greaterThanOrEqualTo(11 - 0.5),
              reason: '${tab.label} rendered at '
                  '${effective.toStringAsFixed(1)} px '
                  'at ${width.toInt()}px, textScale $scale',
            );
          }
        });
      }
    }
  });

  testWidgets('the detector actually detects', (tester) async {
    // A negative control. Without this, a bug in `truncatedText` would make
    // every test above pass by finding nothing, which is the worst possible
    // failure mode for a test whose whole job is finding something.
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 30,
            child: Text('Overview', maxLines: 1, overflow: TextOverflow.clip),
          ),
        ),
      ),
    ));

    final cut = truncatedText(tester);
    expect(cut.map((t) => t.text), contains('Overview'));
  });
}
