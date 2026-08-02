import 'package:flowsense_mobile/core/max_width.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MaxWidth448 caps its child', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MaxWidth448(child: SizedBox(width: 2000, height: 10)),
    ));
    // Measure the child itself: `find.byType(ConstrainedBox).first` would hit
    // MaterialApp's own scaffolding, not the cap under test.
    final child = tester.getSize(find.byType(SizedBox));
    expect(child.width, lessThanOrEqualTo(448));
  });
}
