import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('Xtreme IPTV')),
      ),
    );
    expect(find.text('Xtreme IPTV'), findsOneWidget);
  });
}
