/// Sealed surprises.
///
/// A surprise is created sealed and can only be opened at or after
/// `unlockAt`. The content is NEVER stored in plaintext and NEVER
/// exposed (nor its key) before the unlock time.
///
/// Storage model — `couples/{coupleId}/surprises/{surpriseId}`:
///   * `type`: `text` | `photo` | `voice` | `video`
///   * `unlockAt`: server timestamp (the single source of truth)
///   * `sealed`: always `true` until the reveal check passes
///   * `ciphertext`: the encrypted payload (text), or — for photo /
///     voice / video — the encrypted storage path / download token.
///     Media bytes live in encrypted storage; this document holds no
///     media and no plaintext.
///   * `title`: a short public label shown on the sealed envelope
///     (e.g. "For our anniversary") — never the content itself.
///
/// SECURITY — why the client cannot cheat:
///   * The client only ever *requests* a reveal. The reveal check runs
///     in a Cloud Function (owned by Part A, in `firebase/`): it reads
///     the server time, compares it with `unlockAt`, and only then
///     returns the decryption material / signed URL. Before `unlockAt`
///     it returns nothing.
///   * Firestore rules (Part A) deny reads of `ciphertext` to everyone
///     until `sealed == false`, and deny any client write that flips
///     `sealed` to false. Only the Cloud Function may unseal.
///   * This service's [requestReveal] is therefore a thin client for
///     that function; if the function is not deployed yet, reveals fail
///     closed (locked) rather than leaking content.
///   * [isUnlockedLocally] is a UI convenience only (countdown display).
///     It is NEVER an authorization decision.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Surprise content kinds.
enum SurpriseType { text, photo, voice, video }

/// A sealed (or revealed) surprise.
class Surprise {
  const Surprise({
    required this.id,
    required this.coupleId,
    required this.creatorUid,
    required this.type,
    required this.unlockAt,
    required this.sealed,
    required this.title,
    this.ciphertext,
  });

  factory Surprise.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return Surprise(
      id: doc.id,
      coupleId: data['coupleId'] as String? ?? '',
      creatorUid: data['creatorUid'] as String? ?? '',
      type: SurpriseType.values.firstWhere(
        (t) => t.name == (data['type'] as String?),
        orElse: () => SurpriseType.text,
      ),
      unlockAt: (data['unlockAt'] as Timestamp?)?.toDate(),
      sealed: data['sealed'] as bool? ?? true,
      title: data['title'] as String? ?? 'A surprise 💕',
      ciphertext: data['ciphertext'] as String?,
    );
  }

  final String id;
  final String coupleId;
  final String creatorUid;
  final SurpriseType type;

  /// When the surprise may be opened. Server timestamp, always stored
  /// in UTC; display it with `.toLocal()`.
  final DateTime? unlockAt;

  /// True until the Cloud Function reveal check passes.
  final bool sealed;

  /// Public label for the sealed envelope. Never the content.
  final String title;

  /// Encrypted payload (or encrypted media reference). Null / unreadable
  /// while sealed — the client must never try to use it directly.
  final String? ciphertext;

  /// UI-only convenience: has the unlock time passed on this device's
  /// clock? NOT authorization — the Cloud Function decides the reveal.
  bool get isUnlockedLocally {
    final at = unlockAt;
    if (at == null) return false;
    return DateTime.now().isAfter(at);
  }
}

/// Result of a reveal request.
class SurpriseReveal {
  const SurpriseReveal({
    required this.unlocked,
    this.plaintext,
    this.mediaUrl,
    this.message,
  });

  /// True only when the Cloud Function verified `unlockAt` has passed.
  final bool unlocked;

  /// Decrypted text (type `text` only).
  final String? plaintext;

  /// Time-limited signed URL for photo / voice / video (when unlocked).
  final String? mediaUrl;

  /// Human-readable note, e.g. "Opens in 3 days".
  final String? message;
}

class SurpriseService {
  SurpriseService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  String get _myUid {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('SurpriseService: no signed-in user.');
    }
    return uid;
  }

  CollectionReference<Map<String, dynamic>> _surprises(String coupleId) {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('surprises');
  }

  /// Creates a sealed surprise.
  ///
  /// [ciphertext] must already be encrypted by the caller with the
  /// couple's shared key (Part A EncryptionService): this service never
  /// sees plaintext content. [unlockAt] must be in the future; it is
  /// stored as a server timestamp so neither phone's clock can cheat.
  /// For photo/voice/video, pass the encrypted storage reference as
  /// [ciphertext] and upload the encrypted bytes to storage first.
  Future<Surprise> createSurprise({
    required String coupleId,
    required SurpriseType type,
    required String title,
    required DateTime unlockAt,
    required String ciphertext,
  }) async {
    if (title.trim().isEmpty) {
      throw ArgumentError('A surprise needs a title for its envelope.');
    }
    if (ciphertext.isEmpty) {
      throw ArgumentError(
        'ciphertext is required: surprises are stored sealed, never plaintext.',
      );
    }
    if (!unlockAt.isAfter(DateTime.now())) {
      throw ArgumentError('unlockAt must be in the future.');
    }
    final doc = _surprises(coupleId).doc();
    await doc.set(<String, dynamic>{
      'coupleId': coupleId,
      'creatorUid': _myUid,
      'type': type.name,
      'title': title.trim(),
      'unlockAt': Timestamp.fromDate(unlockAt.toUtc()),
      'sealed': true,
      'ciphertext': ciphertext,
      'createdAt': FieldValue.serverTimestamp(),
    });
    final snap = await doc.get();
    return Surprise.fromDoc(snap);
  }

  /// All surprises for the couple, soonest unlock first.
  Stream<List<Surprise>> watchSurprises(String coupleId) {
    return _surprises(coupleId)
        .orderBy('unlockAt')
        .snapshots()
        .map((snap) => snap.docs.map(Surprise.fromDoc).toList());
  }

  /// Requests a reveal. Calls the `revealSurprise` Cloud Function
  /// (Part A, `firebase/`), which checks server time against `unlockAt`
  /// and only then returns the content. Fails closed: any error, or a
  /// not-yet-unlocked response, means the surprise stays sealed.
  Future<SurpriseReveal> requestReveal({
    required String coupleId,
    required String surpriseId,
  }) async {
    try {
      final result = await _functions.httpsCallable('revealSurprise').call(
        <String, dynamic>{
          'coupleId': coupleId,
          'surpriseId': surpriseId,
        },
      );
      final data = result.data as Map<String, dynamic>? ?? const {};
      return SurpriseReveal(
        unlocked: data['unlocked'] as bool? ?? false,
        plaintext: data['plaintext'] as String?,
        mediaUrl: data['mediaUrl'] as String?,
        message: data['message'] as String?,
      );
    } on FirebaseFunctionsException catch (e) {
      return SurpriseReveal(
        unlocked: false,
        message: e.message ?? 'Reveal is not available yet.',
      );
    } catch (_) {
      return const SurpriseReveal(
        unlocked: false,
        message: 'Could not check the surprise — try again later.',
      );
    }
  }
}
