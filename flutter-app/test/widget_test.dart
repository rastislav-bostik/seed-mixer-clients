// Minimal smoke test — verifies the app boots and renders the AppBar title.
// Full screen tests will arrive when we have stable mock fixtures; for the
// PoC this just ensures the widget tree doesn't crash on first frame.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seed_mixer_app/screens/mixtures_list_screen.dart';

void main() {
  testWidgets('MixturesListScreen renders AppBar', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: MixturesListScreen()),
      ),
    );
    // We don't pump-and-settle — the network call will be in flight, which
    // is fine; we only assert on synchronous tree state.
    expect(find.text('Seed Mixer'), findsOneWidget);
  });
}
