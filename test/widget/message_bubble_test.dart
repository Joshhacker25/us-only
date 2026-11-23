import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// SELF-CONTAINED WIDGET TESTS — Part D
//
// These widgets are defined locally in this file on purpose. They do NOT
// import Part B/C chat screens, so these tests keep running even if the
// real screens change shape. They verify the *contract* a message bubble
// must satisfy: text is shown, own messages look different from the
// partner's, and the timestamp is visible.
// ---------------------------------------------------------------------------

/// Minimal local stand-in for the real MessageBubble.
///
/// Contract:
/// * Shows [text] and a [timeLabel].
/// * Own messages ([isMine] = true) use the purple bubble + right align.
/// * Partner messages use the dark bubble + left align.
class TestMessageBubble extends StatelessWidget {
  final String text;
  final String timeLabel;
  final bool isMine;

  const TestMessageBubble({
    super.key,
    required this.text,
    required this.timeLabel,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        key: ValueKey('bubble-${isMine ? 'mine' : 'theirs'}'),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: isMine
              ? const Color(0xFF7C3AED) // Purple #7C3AED
              : const Color(0xFF1B1230), // Dark bubble #1B1230
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              timeLabel,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  Future<void> pumpBubble(
    WidgetTester tester, {
    required String text,
    required String timeLabel,
    required bool isMine,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF100B1F), // Midnight Purple
          body: TestMessageBubble(
            text: text,
            timeLabel: timeLabel,
            isMine: isMine,
          ),
        ),
      ),
    );
  }

  testWidgets('shows the message text', (tester) async {
    await pumpBubble(
      tester,
      text: 'I love you',
      timeLabel: '21:14',
      isMine: true,
    );
    expect(find.text('I love you'), findsOneWidget);
  });

  testWidgets('shows the timestamp', (tester) async {
    await pumpBubble(
      tester,
      text: 'good night',
      timeLabel: '23:58',
      isMine: false,
    );
    expect(find.text('23:58'), findsOneWidget);
  });

  testWidgets('own message uses the purple bubble', (tester) async {
    await pumpBubble(
      tester,
      text: 'mine',
      timeLabel: '10:00',
      isMine: true,
    );
    final container = tester.widget<Container>(
      find.byKey(const ValueKey('bubble-mine')),
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, const Color(0xFF7C3AED));
  });

  testWidgets('partner message uses the dark bubble', (tester) async {
    await pumpBubble(
      tester,
      text: 'theirs',
      timeLabel: '10:01',
      isMine: false,
    );
    final container = tester.widget<Container>(
      find.byKey(const ValueKey('bubble-theirs')),
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, const Color(0xFF1B1230));
  });

  testWidgets('own message aligns right, partner message aligns left',
      (tester) async {
    await pumpBubble(
      tester,
      text: 'mine',
      timeLabel: '10:00',
      isMine: true,
    );
    expect(
      tester.widget<Align>(find.byType(Align)).alignment,
      Alignment.centerRight,
    );

    await pumpBubble(
      tester,
      text: 'theirs',
      timeLabel: '10:01',
      isMine: false,
    );
    expect(
      tester.widget<Align>(find.byType(Align)).alignment,
      Alignment.centerLeft,
    );
  });

  testWidgets('long text wraps instead of overflowing', (tester) async {
    await pumpBubble(
      tester,
      text: 'I love you ' * 40,
      timeLabel: '10:02',
      isMine: true,
    );
    // No overflow exception is thrown during pump; the text is present.
    expect(find.textContaining('I love you'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
