# Only Us 💕

A private Flutter Android messenger for **exactly two people** — a
couple. No groups, no strangers, no public anything. Just the two of
you: chat, love notes, hugs, voice/video calls, and little surprises.

> **Status:** in development. The app is not released, not on the Play
> Store, and some parts are not yet verified — see
> [Known limitations](#known-limitations) and `KNOWN_LIMITATIONS.md`.
> Do not treat anything here as finished until the release checklist
> (`docs/RELEASE_CHECKLIST.md`) is fully checked.

## Features

- **Chat** — private text, photos, and voice notes between the two of you.
- **Love** — hugs, kisses, and hearts, with a home-screen love widget
  and a relationship day counter (day 1 is the day you started).
- **Calls** — voice and video calls over WebRTC (STUN by default;
  TURN when provisioned — see `docs/WEBRTC_TURN.md`).
- **Settings** — your profile, notifications, and the boring-but-
  important bits.
- **Surprises** — scheduled love notes that unlock at a set time
  (server-enforced unlock; see `docs/SECURITY_THREAT_MODEL.md`).
- **Nearby** — send a message or a hug while you're together but
  offline; it syncs when you're back online (see `docs/NEARBY.md`).

What it does **not** have — by design:

- No Couple Games, quizzes, game scores, or Games tab.
- No Play Store listing, no ads, no payments, no analytics, no
  third-party trackers.
- No iOS build (Android only).

## Design

Midnight Purple `#100B1F`, dark surface `#1B1230`, Purple `#7C3AED`,
Pink `#FF4D9D`, Lavender `#E9D5FF`. Main navigation: **Chat, Love,
Calls, Settings** — nothing else.

## Project structure

```text
only-us/
├── lib/
│   ├── main.dart                 # App entry (Part A)
│   ├── shared/
│   │   ├── theme/                # Colours, text styles
│   │   ├── widgets/              # Shared widgets
│   │   └── utils/                # Pure helpers (Part D):
│   │       ├── day_counter.dart      # relationship day number
│   │       ├── dedup.dart            # message dedup by clientId
│   │       ├── surprise_unlock.dart  # surprise lock/unlock (UTC)
│   │       ├── heart_throttle.dart   # 1 per 10s, 20 per hour
│   │       └── allowlist.dart        # the two authorised UIDs
│   └── features/
│       ├── chat/                 # Chat (Part B)
│       ├── love_widget/          # Love tab + widget
│       ├── calls/                # Voice/video calls
│       ├── surprises/            # Surprises
│       ├── relationship/         # Day counter UI
│       ├── nearby/               # Nearby Connections
│       ├── voice_notes/ media/   # Voice notes, media
│       ├── romantic/             # Romantic extras
│       └── settings/             # Settings
├── android/                      # Android shell (Part A)
├── firebase/                     # Firestore rules, indexes
├── test/
│   ├── unit/                     # Day counter, dedup, unlock,
│   │                           # throttle, allowlist (Part D)
│   ├── widget/                   # Message bubble, love buttons (Part D)
│   └── rules/
│       └── firestore_rules_test.md  # Manual access-control checklist
├── integration_test/
│   └── app_test.dart             # Full-flow outline (SKIPPED — needs
│                               # two real devices + Firebase)
├── assets/images/                # Placeholder SVG art (Part D)
├── docs/
│   ├── PROVISIONING.md           # Set up the two users
│   ├── WEBRTC_TURN.md            # STUN/TURN calling setup
│   ├── NEARBY.md                 # Nearby Connections setup
│   ├── SECURITY_THREAT_MODEL.md  # Threat model + E2EE status
│   └── RELEASE_CHECKLIST.md      # Release-readiness checklist
├── README.md / SECURITY.md / KNOWN_LIMITATIONS.md
└── pubspec.yaml
```

## Getting started (Windows + PowerShell + Android Studio)

### 1. Install the tools

1. Install **Flutter** (stable channel) from
   <https://docs.flutter.dev/get-started/install/windows> and add it
   to your PATH.
2. Install **Android Studio** (includes the Android SDK). In Android
   Studio → SDK Manager, install the Android SDK, SDK Command-line
   Tools, and an Android emulator image (or use a real phone).
3. Install **Git** for Windows.
4. Open PowerShell and check everything is found:

```powershell
flutter doctor
```

Fix anything `flutter doctor` flags (it tells you exactly what is
missing — usually an Android SDK licence: run
`flutter doctor --android-licenses` and accept).

### 2. Get the code

```powershell
git clone <your-repo-url> only-us
cd only-us
flutter pub get
```

### 3. Add Firebase config (NOT included)

The app needs Firebase. This file is **not** in the repo — you create
it during provisioning (see `docs/PROVISIONING.md`):

1. Create the Firebase project and register the Android app.
2. Download `google-services.json`.
3. Copy it to `android/app/google-services.json`.

Without it, the app will not build/run with Firebase features.

### 4. Run it

Connect a phone with USB debugging on (or start an emulator), then:

```powershell
flutter run
```

Hot reload: press `r` in the terminal; hot restart: `R`.

### 5. Tests and checks

```powershell
flutter test            # unit + widget tests (test/unit, test/widget)
flutter analyze         # static analysis — fix errors before release
```

The integration test (`integration_test/app_test.dart`) is skipped on
purpose — it needs two real devices and a provisioned Firebase
project. See the comments at the top of that file.

## Building a signed release APK

1. Create a release keystore (once, on your Windows machine):

```powershell
keytool -genkey -v -keystore C:\Users\<you>\only-us-keys\only-us-release.keystore `
  -alias onlyus -keyalg RSA -keysize 2048 -validity 10000
```

Keep the keystore **outside the repo** and back it up (encrypted) in
two places. If you lose it, you cannot update the app under the same
identity.

2. Create `android/key.properties` (git-ignored — never commit it):

```properties
storePassword=<your keystore password>
keyPassword=<your key password>
keyAlias=onlyus
storeFile=C:/Users/<you>/only-us-keys/only-us-release.keystore
```

3. Build:

```powershell
flutter build apk --release
```

The APK is at `build/app/outputs/flutter-apk/app-release.apk`.
Install it on both phones (allow "install unknown apps" for the
browser/file manager you use) and follow
`docs/RELEASE_CHECKLIST.md` before calling it a release.

> Placeholders only above: replace `<you>` and the passwords with
> your real values, and never paste the real `key.properties` into
> chat, docs, or git.

## Docs

- `docs/PROVISIONING.md` — create the two users, replace placeholder UIDs
- `docs/WEBRTC_TURN.md` — calling, STUN, and TURN setup
- `docs/NEARBY.md` — offline Nearby Connections
- `docs/SECURITY_THREAT_MODEL.md` — threat model, E2EE status, logging
- `docs/RELEASE_CHECKLIST.md` — what must pass before a release
- `SECURITY.md` — reporting a security issue
- `KNOWN_LIMITATIONS.md` — what does not work yet / is not verified

## Known limitations

Short version — full list in `KNOWN_LIMITATIONS.md`:

- E2EE is designed but **not fully verified on two devices**.
- TURN is **not provisioned** — calls can fail on restrictive networks.
- Nearby does **not** support Bluetooth-only HD video or long-distance
  offline calls.
- The home-screen widget updates only within Android's limits.
- Background / locked-screen call ringing is limited on some devices.
- Android only. No iOS, no Play Store listing.

## Contributing

This is a private two-person app, not an open project. If you are one
of the two partners, talk to the other one before changing provisioning,
rules, or anything security-related.
