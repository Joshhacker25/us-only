# Firestore Security Rules — manual access-control test checklist

> **Status: NOT RUN.**
>
> These checks need the Firebase emulator (`firebase emulators:start
> --only firestore`) or a real Firebase project with the rules from
> `firebase/firestore.rules` deployed. They have **not** been run yet —
> do not treat any box below as passed until it is checked against a
> live ruleset, with the date and the tester recorded in the "Result"
> column.
>
> Prerequisite: provisioning is complete (see `docs/PROVISIONING.md`) —
> two Firebase Auth users exist, their real UIDs are in the rules, and
> the placeholder UIDs (`PARTNER_A_UID_PLACEHOLDER`,
> `PARTNER_B_UID_PLACEHOLDER`) have been replaced.
>
> How to run each check: use the Firestore emulator UI or the
> `@firebase/rules-unit-testing` SDK with a signed-in test user. For
> every check, record PASS / FAIL, the date, and the UID used.

## Test accounts

| Label | UID | Expected access |
|---|---|---|
| Partner A | `<real UID A from provisioning>` | Full access to the couple's data |
| Partner B | `<real UID B from provisioning>` | Full access to the couple's data |
| Third user | Any other Firebase Auth UID | Denied everywhere |
| Unauthenticated | (no auth) | Denied everywhere |

## 1. Unauthenticated access — must be DENIED

| # | Check | Expected | Result |
|---|---|---|---|
| 1.1 | Read `couples/{coupleId}` with no auth | Denied | ☐ |
| 1.2 | Read `couples/{coupleId}/messages/{msgId}` with no auth | Denied | ☐ |
| 1.3 | Write a message with no auth | Denied | ☐ |
| 1.4 | Read `couples/{coupleId}/surprises/{id}` with no auth | Denied | ☐ |
| 1.5 | List any collection with no auth | Denied | ☐ |

## 2. Partner A / B access — must be ALLOWED

| # | Check | Expected | Result |
|---|---|---|---|
| 2.1 | Partner A reads `couples/{coupleId}` | Allowed | ☐ |
| 2.2 | Partner B reads `couples/{coupleId}` | Allowed | ☐ |
| 2.3 | Partner A writes a message (senderUid = A) | Allowed | ☐ |
| 2.4 | Partner B writes a message (senderUid = B) | Allowed | ☐ |
| 2.5 | Partner A reads partner B's messages | Allowed | ☐ |
| 2.6 | Partner A writes a hug / heart event | Allowed | ☐ |
| 2.7 | Partner A reads a surprise whose `unlockAt` has passed | Allowed | ☐ |

## 3. Third UID — must be DENIED

| # | Check | Expected | Result |
|---|---|---|---|
| 3.1 | Third UID reads `couples/{coupleId}` | Denied | ☐ |
| 3.2 | Third UID reads any message | Denied | ☐ |
| 3.3 | Third UID writes a message (senderUid = third UID) | Denied | ☐ |
| 3.4 | Third UID writes a message **forged** with senderUid = A | Denied | ☐ |
| 3.5 | Third UID reads/writes surprises, hugs, calls | Denied | ☐ |
| 3.6 | Third UID lists `couples` collection | Denied (empty / denied) | ☐ |

## 4. Forgery / tampering — must be DENIED

| # | Check | Expected | Result |
|---|---|---|---|
| 4.1 | Partner A writes a message with senderUid = B | Denied | ☐ |
| 4.2 | Partner A edits / deletes partner B's message (if rules forbid it) | Denied | ☐ |
| 4.3 | Partner A changes the couple doc's `memberUids` (adds a third UID) | Denied | ☐ |
| 4.4 | Partner A reads a surprise whose `unlockAt` is in the future (server-enforced lock, if implemented) | Denied / hidden | ☐ |
| 4.5 | Any user writes to a collection outside the allowlist | Denied | ☐ |

## 5. Rate-limit rules (if implemented in rules)

| # | Check | Expected | Result |
|---|---|---|---|
| 5.1 | Partner sends > 20 hearts within one hour (rules / function enforced) | Blocked after 20 | ☐ |
| 5.2 | Partner sends messages at abusive rate | Throttled / blocked | ☐ |

## Sign-off

| Field | Value |
|---|---|
| Rules file tested | `firebase/firestore.rules` @ commit: ________ |
| Environment | Emulator / real project: ________ |
| Date run | ________ |
| Run by | ________ |
| Result | ☐ ALL PASS — ☐ FAILURES (list below) |

Failures / notes:

- (none recorded yet)
