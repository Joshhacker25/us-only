import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/loading_state.dart';

/// Pairing / allowlist status.
///
/// Only Us is for exactly TWO authorized people. The allowlist lives in
/// Firestore at `couples/{coupleId}` with a `memberUids` array of two UIDs.
/// This screen shows that status and lets the user link a partner by UID.
///
/// Placeholder provisioning flow: entering a partner UID writes a pairing
/// request to `couples/{coupleId}/pairingRequests/{partnerUid}`. There is no
/// discovery of third users — a partner can only be linked by their exact
/// UID, and the request must be accepted / the allowlist updated by the
/// provisioning step (Part A / backend) before the partner can join.
class PairingScreen extends StatefulWidget {
  const PairingScreen({
    super.key,
    required this.coupleId,
    required this.myUid,
    this.memberUids = const <String>[],
  });

  final String coupleId;
  final String myUid;
  final List<String> memberUids;

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final TextEditingController _uidController = TextEditingController();
  bool _isLoading = false;
  String? _message;
  bool _isError = false;

  bool get _isPaired => widget.memberUids.length >= 2;
  String? get _partnerUid {
    for (final String uid in widget.memberUids) {
      if (uid != widget.myUid) return uid;
    }
    return null;
  }

  @override
  void dispose() {
    _uidController.dispose();
    super.dispose();
  }

  Future<void> _requestPairing() async {
    final String partnerUid = _uidController.text.trim();
    if (partnerUid.isEmpty) {
      setState(() {
        _message = 'Enter your partner\u2019s UID.';
        _isError = true;
      });
      return;
    }
    if (partnerUid == widget.myUid) {
      setState(() {
        _message = 'That is your own UID — enter your partner\u2019s UID.';
        _isError = true;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      await FirebaseFirestore.instance
          .collection('couples')
          .doc(widget.coupleId)
          .collection('pairingRequests')
          .doc(partnerUid)
          .set(<String, dynamic>{
        'requestedBy': widget.myUid,
        'partnerUid': partnerUid,
        'status': 'pending',
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
      setState(() {
        _message =
            'Pairing request sent. Your partner must be added to the allowlist before you can chat.';
        _isError = false;
      });
    } on FirebaseException catch (e) {
      setState(() {
        _message = e.message ?? 'Could not send the pairing request.';
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.midnight,
      appBar: AppBar(
        backgroundColor: AppColors.midnight,
        title: const Text(
          'Pairing',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Icon(Icons.favorite, color: AppColors.pink, size: 48),
            const SizedBox(height: 16),
            Text(
              _isPaired ? 'You are paired 💕' : 'Link your partner',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Allowlist: ${widget.memberUids.length} of 2 people',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 24),
            _UidRow(label: 'Your UID', uid: widget.myUid, isMine: true),
            const SizedBox(height: 12),
            if (_partnerUid != null)
              _UidRow(label: 'Partner UID', uid: _partnerUid!, isMine: false)
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'No partner linked yet. Only the two allowlisted UIDs can use this app.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            if (!_isPaired) ...<Widget>[
              const SizedBox(height: 24),
              TextField(
                controller: _uidController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Partner UID',
                  labelStyle: const TextStyle(color: AppColors.muted),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const LoadingState(message: 'Sending request...')
              else
                GradientButton(
                  label: 'Link partner by UID',
                  onPressed: _requestPairing,
                ),
            ],
            if (_message != null) ...<Widget>[
              const SizedBox(height: 16),
              Text(
                _message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _isError ? AppColors.error : AppColors.success,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UidRow extends StatelessWidget {
  const _UidRow({
    required this.label,
    required this.uid,
    required this.isMine,
  });

  final String label;
  final String uid;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMine ? AppColors.purple : AppColors.pink,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 4),
          SelectableText(
            uid,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
