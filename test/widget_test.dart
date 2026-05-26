// Smoke test for the PDF Tools app.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pdf_tools/screens/home_screen.dart';

void main() {
  testWidgets('Home screen renders three tool cards', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen()),
    );
    expect(find.text('Image to PDF'), findsOneWidget);
    expect(find.text('Merge PDF'), findsOneWidget);
    expect(find.text('Compress PDF'), findsOneWidget);
  });
}
