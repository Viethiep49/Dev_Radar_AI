import 'package:dev_radar_ai/presentation/widgets/radar_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('RadarLogo smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RadarLogo(size: 80),
        ),
      ),
    );

    expect(find.byType(RadarLogo), findsOneWidget);
    expect(find.byIcon(Icons.radar_rounded), findsOneWidget);
  });
}
