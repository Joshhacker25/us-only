import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// ---------------------------------------------------------------------------
// Only Us — end-to-end flow outline
//
// Status: SKIPPED ON PURPOSE (skip: true on every test below).
//
// This file is an OUTLINE, not a passing suite. A real run needs:
//   * a provisioned Firebase project (see docs/PROVISIONING.md),
//   * google-services.json in android/app/,
//   * TWO real Android devices (or one device + one emulator) signed in
//     as partner A and partner B,
//   * the app installed on both.
//
// Do NOT remove `skip: true` until that setup exists, and do NOT claim
// this flow ran until it has actually run on two devices. The individual
// steps are covered at unit/widget level by test/unit/ and test/widget/.
// ---------------------------------------------------------------------------

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Only Us full flow (TWO-DEVICE OUTLINE — skipped)', () {
    testWidgets(
      'login as partner A',
      (_) async {
        // 1. Launch app on device A.
        // 2. Sign in with partner A's email + password (provisioned user).
        // 3. Expect the Chat tab to appear with no error banner.
      },
      skip: true,
    );

    testWidgets(
      'partner A sends a message, partner B receives it',
      (_) async {
        // 1. On device A: open Chat, type "hello my love", tap send.
        // 2. Expect the message bubble to appear on device A (local echo).
        // 3. On device B: expect the same message to arrive via Firestore
        //    within ~5s, with exactly ONE copy (dedup — see
        //    test/unit/message_dedup_test.dart).
        // 4. On device B: reply "hello", expect it on device A.
      },
      skip: true,
    );

    testWidgets(
      'partner A sends a hug, partner B sees it',
      (_) async {
        // 1. On device A: open the Love tab, tap Hug.
        // 2. Expect the hug animation / counter to update on device A.
        // 3. On device B: expect the hug notification / animation within
        //    ~5s (FCM or Firestore listener).
        // 4. Tap Hug twice quickly on device A: expect the second tap to
        //    be throttled (max 1 per 10s — see
        //    test/unit/heart_throttle_test.dart).
      },
      skip: true,
    );

    testWidgets(
      'a third user cannot get in',
      (_) async {
        // 1. Sign in on a third device with a non-allowlisted account.
        // 2. Expect the app to show the "not authorized" screen and
        //    Firestore reads/writes to be denied (see
        //    test/rules/firestore_rules_test.md).
      },
      skip: true,
    );

    testWidgets(
      'voice/video call connects between the two devices',
      (_) async {
        // 1. On device A: open the Calls tab, tap Call.
        // 2. On device B: expect the incoming-call screen, tap Accept.
        // 3. Expect audio (and video, for video calls) flowing both ways.
        // 4. End the call from device B; expect device A to return to
        //    the Calls tab. (Requires STUN, and TURN for restrictive
        //    networks — see docs/WEBRTC_TURN.md.)
      },
      skip: true,
    );
  });
}
