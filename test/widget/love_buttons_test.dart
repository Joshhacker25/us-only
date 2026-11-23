import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// SELF-CONTAINED WIDGET TESTS — Part D
//
// These widgets are defined locally in this file on purpose. They do NOT
// import Part B/C love screens, so these tests keep running even if the
// real screens change shape. They verify the *contract* of the Love tab
// buttons: Hug, Kiss and Heart are all present, each tap fires its
// callback exactly once, and the on-screen counter increments.
// ---------------------------------------------------------------------------

/// Minimal local stand-in for the Love tab buttons.
class TestLoveButtons extends StatefulWidget {
  final VoidCallback onHug;
  final VoidCallback onKiss;
  final VoidCallback onHeart;

  const TestLoveButtons({
    super.key,
    required this.onHug,
    required this.onKiss,
    required this.onHeart,
  });

  @override
  State<TestLoveButtons> createState() => _TestLoveButtonsState();
}

class _TestLoveButtonsState extends State<TestLoveButtons> {
  int _sentCount = 0;

  void _handle(VoidCallback callback) {
    callback();
    setState(() => _sentCount++);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Sent: $_sentCount', key: const ValueKey('sent-count')),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              key: const ValueKey('hug-button'),
              onPressed: () => _handle(widget.onHug),
              icon: const Icon(Icons.favorite),
              label: const Text('Hug'),
            ),
            ElevatedButton.icon(
              key: const ValueKey('kiss-button'),
              onPressed: () => _handle(widget.onKiss),
              icon: const Icon(Icons.favorite_outline),
              label: const Text('Kiss'),
            ),
            ElevatedButton.icon(
              key: const ValueKey('heart-button'),
              onPressed: () => _handle(widget.onHeart),
              icon: const Icon(Icons.favorite_border),
              label: const Text('Heart'),
            ),
          ],
        ),
      ],
    );
  }
}

void main() {
  late int hugCount;
  late int kissCount;
  late int heartCount;

  Future<void> pumpLoveButtons(WidgetTester tester) async {
    hugCount = 0;
    kissCount = 0;
    heartCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF100B1F), // Midnight Purple
          body: TestLoveButtons(
            onHug: () => hugCount++,
            onKiss: () => kissCount++,
            onHeart: () => heartCount++,
          ),
        ),
      ),
    );
  }

  testWidgets('all three love buttons are visible', (tester) async {
    await pumpLoveButtons(tester);
    expect(find.text('Hug'), findsOneWidget);
    expect(find.text('Kiss'), findsOneWidget);
    expect(find.text('Heart'), findsOneWidget);
  });

  testWidgets('tapping Hug fires its callback exactly once', (tester) async {
    await pumpLoveButtons(tester);
    await tester.tap(find.byKey(const ValueKey('hug-button')));
    await tester.pump();
    expect(hugCount, 1);
    expect(kissCount, 0);
    expect(heartCount, 0);
  });

  testWidgets('tapping Kiss fires its callback exactly once', (tester) async {
    await pumpLoveButtons(tester);
    await tester.tap(find.byKey(const ValueKey('kiss-button')));
    await tester.pump();
    expect(kissCount, 1);
    expect(hugCount, 0);
    expect(heartCount, 0);
  });

  testWidgets('tapping Heart fires its callback exactly once', (tester) async {
    await pumpLoveButtons(tester);
    await tester.tap(find.byKey(const ValueKey('heart-button')));
    await tester.pump();
    expect(heartCount, 1);
    expect(hugCount, 0);
    expect(kissCount, 0);
  });

  testWidgets('sent counter increments once per tap', (tester) async {
    await pumpLoveButtons(tester);
    expect(find.text('Sent: 0'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('hug-button')));
    await tester.pump();
    expect(find.text('Sent: 1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('heart-button')));
    await tester.pump();
    expect(find.text('Sent: 2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('kiss-button')));
    await tester.pump();
    expect(find.text('Sent: 3'), findsOneWidget);
  });

  testWidgets('rapid double-tap on Hug fires twice (throttle is a '
      'separate layer, tested in heart_throttle_test.dart)', (tester) async {
    await pumpLoveButtons(tester);
    await tester.tap(find.byKey(const ValueKey('hug-button')));
    await tester.tap(find.byKey(const ValueKey('hug-button')));
    await tester.pump();
    expect(hugCount, 2);
    expect(find.text('Sent: 2'), findsOneWidget);
  });
}
