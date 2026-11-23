# Nearby Connections — setup & behaviour

Nearby Connections (Google Play Services) lets the two phones talk
directly when they are physically close — for example, to send a
message, hug, or photo while on a flight, in a tunnel, or anywhere
without mobile data or Wi-Fi. It uses Bluetooth, BLE, and Wi-Fi
Direct under the hood.

## 1. What it is for

- **Offline moments:** the two partners are next to each other but
  have no internet (plane, basement, remote area, data switched off).
- **Queue and sync:** anything sent offline is queued on the sender's
  phone and synced to Firestore when either phone is back online, so
  the chat history stays complete.
- **It is a bonus, not the core:** normal chat, calls, and surprises
  run over Firebase. Nearby is only the "we're together but offline"
  path.

## 2. Permissions (Android)

Nearby Connections needs these permissions — the app must request
them at runtime (Android 12+), and the user must grant them, or
nearby pairing will not work:

| Permission | Why |
|---|---|
| `BLUETOOTH_ADVERTISE` | Advertise this phone so the partner can find it (Android 12+) |
| `BLUETOOTH_CONNECT` | Connect to the partner's phone (Android 12+) |
| `BLUETOOTH_SCAN` | Discover the partner's phone (Android 12+) |
| `ACCESS_FINE_LOCATION` | Required by Android for Bluetooth/Wi-Fi discovery (Android < 12 needs location; Android 12+ still needs it for some discovery paths) |
| `NEARBY_WIFI_DEVICES` | Wi-Fi Direct discovery (Android 13+) |
| `ACCESS_WIFI_STATE` / `CHANGE_WIFI_STATE` | Wi-Fi Direct transport |

Notes:

- **Location must be switched ON** on the phone for discovery to work
  on many Android versions, even though the app never uses the
  location itself. Tell both partners this upfront — it is the most
  common reason pairing "does nothing".
- Permissions are requested only when the user opens the Nearby flow,
  with a plain-language explanation first. If a permission is denied,
  the app says which one is missing and how to turn it on — it does not
  silently fail.
- The app never tracks or stores location. Location permission is an
  Android requirement for radio discovery, not a feature.

## 3. Authenticated pairing flow

Nearby pairing must prove the other phone belongs to your partner —
not to a stranger's phone in the same café. The flow is:

1. Both partners open the Nearby screen in the app (both signed in
   with their provisioned accounts).
2. Phone A advertises, phone B discovers (or vice versa).
3. On connection, both phones show the **same authentication token**
   (a short code). Both partners check the codes match, then both tap
   **Accept**.
4. The app then verifies the other side: each phone presents a
   token derived from its own Firebase Auth UID, and the app accepts
   the connection only if that UID is the partner's UID from the
   allowlist (`lib/shared/utils/allowlist.dart`). A phone that cannot
   prove it is the partner is rejected — even if the codes matched.
5. Once paired, messages / hugs / photos can be exchanged directly.
6. Pairing does not persist forever: re-pair when the app restarts or
   after a long gap. The app remembers nothing sensitive from pairing.

Security notes:

- Never accept a pairing request from a phone you do not recognise.
- The authentication token check (step 3) stops casual mix-ups; the
  UID check (step 4) stops impersonation by someone who guessed the
  code. Both must pass.
- Nearby traffic is encrypted by the Nearby Connections library in
  transit between the two phones.

## 4. Offline queue & sync

- While offline, outgoing messages are stored in a local outbox on
  the sender's phone (marked "waiting to send").
- When a Nearby link is up, queued items are sent to the partner's
  phone directly.
- When either phone regains internet, queued items are uploaded to
  Firestore in order. Dedup by `clientId` (see
  `lib/shared/utils/dedup.dart` and `test/unit/message_dedup_test.dart`)
  prevents the same message appearing twice if it was delivered both
  by Nearby and by Firestore sync.
- Order is best-effort across transports: if two messages were sent
  within the same second on different paths, they may arrive swapped.
  Timestamps are recorded at send time so the chat can sort by them.

## 5. Supported vs NOT supported

### Supported

- Text messages, hugs/hearts, and small photos between the two phones
  while nearby and offline.
- Queue-then-sync when back online.
- Pairing with the authenticated flow above.

### NOT supported

- **Bluetooth-only HD video calls — NOT supported.** Video calls need
  far more bandwidth than a Bluetooth link provides. Video/voice
  calls need Wi-Fi or mobile data (see `docs/WEBRTC_TURN.md`). Do not
  expect a call to work over Bluetooth alone.
- **Long-distance offline calls — NOT supported.** Nearby only works
  within radio range (roughly the same room / same house, up to ~100 m
  in ideal conditions, much less through walls). If you are in
  different cities, you need the internet — there is no offline
  long-distance path.
- **Offline delivery when the partner's phone is off or far away.**
  The message waits in the outbox until the phones are together again
  or back online.
- **File transfers of large videos offline.** Small photos are fine;
  large videos should wait for Wi-Fi and go through the normal upload
  path.
- **Nearby with a third phone.** Pairing is strictly two phones, and
  the UID check rejects anyone else.

## 6. Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| Phones never find each other | Location is off, or a Bluetooth permission was denied — check both |
| Found, but connection fails | Bluetooth/Wi-Fi is toggling, or a VPN is interfering — retry with VPN off |
| Codes don't match | You are pairing with the wrong phone — cancel and retry |
| Messages arrive twice | Dedup should catch it — check the message has a `clientId` (see `test/unit/message_dedup_test.dart`) |
| Works at home, not on the plane | Airplane mode kills the radios — turn Bluetooth back on manually after enabling airplane mode |
