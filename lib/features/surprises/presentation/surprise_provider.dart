/// Provider for the surprises feature: list, create (sealed), reveal.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/surprise_service.dart';

class SurpriseProvider extends ChangeNotifier {
  SurpriseProvider({
    required this.coupleId,
    SurpriseService? service,
  }) : _service = service ?? SurpriseService() {
    _subscription =
        _service.watchSurprises(coupleId).listen((surprises) {
      _surprises = surprises;
      notifyListeners();
    }, onError: (_) {});
  }

  final String coupleId;
  final SurpriseService _service;
  StreamSubscription<List<Surprise>>? _subscription;

  List<Surprise> _surprises = const <Surprise>[];
  List<Surprise> get surprises => List<Surprise>.unmodifiable(_surprises);

  /// Surprises still sealed, soonest unlock first.
  List<Surprise> get sealed =>
      _surprises.where((s) => s.sealed).toList();

  /// Surprises already revealed.
  List<Surprise> get revealed =>
      _surprises.where((s) => !s.sealed).toList();

  bool _busy = false;
  bool get isBusy => _busy;

  String? _error;
  String? get error => _error;

  /// Creates a sealed surprise. [ciphertext] must already be encrypted
  /// (see [SurpriseService.createSurprise]). Returns the created
  /// surprise, or null on failure (check [error]).
  Future<Surprise?> createSurprise({
    required SurpriseType type,
    required String title,
    required DateTime unlockAt,
    required String ciphertext,
  }) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final created = await _service.createSurprise(
        coupleId: coupleId,
        type: type,
        title: title,
        unlockAt: unlockAt,
        ciphertext: ciphertext,
      );
      return created;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Asks the Cloud Function to reveal a surprise. Fails closed —
  /// a null / locked result means it stays sealed.
  Future<SurpriseReveal> requestReveal(Surprise surprise) async {
    _busy = true;
    notifyListeners();
    try {
      return await _service.requestReveal(
        coupleId: coupleId,
        surpriseId: surprise.id,
      );
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
