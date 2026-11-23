# WebRTC + STUN / TURN Setup

Calls in Only Us are peer-to-peer WebRTC (audio + video). This document
explains the network setup: what works with nothing extra, when you
need a TURN server, how to provision one, and where its credentials go.

**Status: TURN IS PROVISIONED (2026-11-23).** Metered, app `only-us`
(domain only-us.metered.live, plan TURN TRIAL GLOBAL 500MB, renews
2026-12-23). ICE servers in `lib/features/calls/data/webrtc_service.dart`:
STUN `stun:stun.relay.metered.ca:80`, TURN `turn:global.relay.metered.ca:80`
(+ TCP variant), `turn:global.relay.metered.ca:443`,
`turns:global.relay.metered.ca:443?transport=tcp`, Google STUN fallback.
Calls on restrictive networks should now relay through Metered. Watch
the 500MB trial quota — if calls stop connecting, check Metered usage
first. Rotate credentials in the Metered dashboard if they leak.

## 1. How calling works here

1. Partner A taps Call → the app creates a WebRTC offer.
2. Signalling (offer / answer / ICE candidates) travels over Firestore
   (the couple's call document) — only the two allowlisted UIDs can
   read/write it.
3. Media itself is peer-to-peer between the two phones — it does not go
   through Firebase.
4. If a direct peer-to-peer path cannot be found, a TURN server relays
   the media. That is the only case where call media touches a server.

## 2. STUN (default — no setup needed)

STUN lets each phone discover its public address so the other phone
can reach it directly.

Default STUN servers used by the app (public, no credentials):

- `stun:stun.l.google.com:19302`
- `stun:stun1.l.google.com:19302`

These are fine for most home Wi-Fi and many mobile networks. No
account, no password, nothing to provision. If you self-host, you can
add your own STUN server to the ICE server list in the calls code
(Part B/C) — it also needs no credentials.

## 3. When you need TURN

You need TURN when the two phones cannot reach each other directly,
typically:

- Either phone is behind a **symmetric NAT** (common on mobile data).
- Either network blocks UDP or peer-to-peer traffic (some workplaces,
  schools, hotels, some carriers).
- One phone is on mobile data and the other is on a strict Wi-Fi.

Symptom: the call rings, the other partner answers, but there is no
audio/video, or the call never connects and times out. STUN alone
cannot fix that — TURN can, because both phones connect *out* to the
TURN server and it relays between them.

## 4. Provisioning a TURN server (coturn — example outline)

This is an outline, not a copy-paste deployment. Set it up on a small
VPS you control (Ubuntu/Debian), and keep its credentials out of the
app (section 5).

```bash
# On the VPS (example — adapt to your distro and firewall):
sudo apt update && sudo apt install coturn -y

# /etc/turnserver.conf — EXAMPLE outline (fill in your own values):
#   listening-port=3478
#   tls-listening-port=5349
#   listening-ip=<your VPS public IP>
#   relay-ip=<your VPS public IP>
#   external-ip=<your VPS public IP>
#   realm=<your domain, e.g. turn.onlyus.example>
#   server-name=<your domain>
#   lt-cred-mech
#   user=<TURN_USERNAME>:<STRONG_RANDOM_PASSWORD>
#   cert=/path/to/fullchain.pem
#   pkey=/path/to/privkey.pem
#   no-cli (or set a strong CLI password; never leave the CLI open)
```

Notes:

- **Use TLS (port 5349) when you can** — credentials and media are
  encrypted in transit. Plain 3478 is a fallback for networks that
  block TLS TURN.
- Open UDP **and** TCP 3478 / 5349, plus the relay port range
  (e.g. UDP 49152–65535) in the VPS firewall.
- Use a strong, random TURN password (32+ characters, from a password
  manager). Rotate it if it ever leaks.
- coturn is one option; any TURN server (e.g. a managed TURN service)
  works the same way — what matters is the host, port, username and
  password, delivered as in section 5.
- Expect modest cost: a small VPS handles two-person relayed calls
  easily. Monitor bandwidth — video relay uses far more than audio.

**No real credentials exist yet.** Do not invent a host, username or
password here — fill them in only when the server actually exists.

## 5. Where TURN credentials go (NOT in the APK)

TURN credentials must **never** be hard-coded in the app, in
`pubspec.yaml`, or in git. Anyone who decompiles the APK would get
them and could abuse your server.

Deliver them at runtime, one of these ways (in order of preference):

1. **Firebase Remote Config** — store `turn_host`, `turn_port`,
   `turn_username`, `turn_password` as Remote Config parameters,
   fetched at app start. Rotate by changing Remote Config, no release
   needed. (Remote Config values are not secret-grade storage, but
   they are far better than the APK — and TURN credentials are
   short-lived / rotatable. For stronger protection, use option 2.)
2. **Cloud Function (recommended)** — a callable function that checks
   the caller's UID is one of the two allowlisted UIDs and returns
   **time-limited** TURN credentials (coturn supports time-limited
   credentials via a shared secret + HMAC). The app calls it when a
   call starts. Credentials expire in minutes, so a leak is useless.
3. **Manual entry (last resort)** — each partner pastes the TURN
   details into the app's Settings once. Works, but rotation means
   telling both partners the new values.

The calls code reads ICE servers from the source you choose and falls
back to STUN-only when TURN is not configured.

## 6. Local-network call notes

- **Same Wi-Fi:** calls usually connect directly (host candidates),
  no STUN/TURN needed, lowest latency. If same-Wi-Fi calls fail,
  check the router's "AP isolation" / "client isolation" setting —
  it blocks phone-to-phone traffic and must be off.
- **Different networks, same city:** STUN usually suffices.
- **Mobile data ↔ Wi-Fi:** the most common TURN case; test this pair
  explicitly before calling it done.
- **VPNs:** a VPN on either phone can break direct paths. If a call
  fails, try with the VPN off; TURN (if provisioned) usually still
  works through a VPN.
- **Battery / background:** an incoming call needs FCM + a foreground
  service to ring reliably while the app is backgrounded (see
  `KNOWN_LIMITATIONS.md` — background behaviour is limited on some
  devices).

## 7. Testing calls

- [ ] Same Wi-Fi, audio call — both directions
- [ ] Same Wi-Fi, video call — both directions
- [ ] Mobile data ↔ Wi-Fi, audio + video
- [ ] Mobile data ↔ mobile data (same carrier, then different carriers)
- [ ] Call while the other phone is locked / app backgrounded
- [ ] End call from each side; check both phones return to the Calls tab
- [ ] After TURN is provisioned, repeat the failing cases above and
  confirm they now connect
