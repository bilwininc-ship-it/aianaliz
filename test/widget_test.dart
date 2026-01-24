// AI Spor Pro uygulaması için temel widget testleri

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Basit widget testi', (WidgetTester tester) async {
    // Test widget'ı oluştur
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('AI Spor Pro Test'),
          ),
        ),
      ),
    );

    // Text widget'ının bulunduğunu doğrula
    expect(find.text('AI Spor Pro Test'), findsOneWidget);
  });

  testWidgets('Button tap testi', (WidgetTester tester) async {
    int counter = 0;
    
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => counter++,
              child: const Text('Test Button'),
            ),
          ),
        ),
      ),
    );

    // Button'ı bul ve tap yap
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    // Counter'ın arttığını doğrula
    expect(counter, 1);
  });
}
