import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../shared/models/user_profile.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/gradient_button.dart';

/// Relationship profile: nicknames, avatars, relationship start date picker
/// and the day counter (days since the start date, computed locally).
/// Edits are saved to the users collection; Part A owns the user document
/// shape, so writes use merge and only the fields edited here.
class RelationshipProfileScreen extends StatefulWidget {
  const RelationshipProfileScreen({
    super.key,
    required this.myUid,
    required this.partner,
    this.myProfile,
  });

  final String myUid;
  final UserProfile partner;
  final UserProfile? myProfile;

  @override
  State<RelationshipProfileScreen> createState() =>
      _RelationshipProfileScreenState();
}

class _RelationshipProfileScreenState
    extends State<RelationshipProfileScreen> {
  late final TextEditingController _myNicknameController;
  late final TextEditingController _partnerNicknameController;
  DateTime? _startDate;
  bool _saving = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _myNicknameController = TextEditingController(
      text: widget.myProfile?.nickname ?? '',
    );
    _partnerNicknameController = TextEditingController(
      text: widget.partner.nickname ?? '',
    );
    _startDate = widget.partner.relationshipStartDate ??
        widget.myProfile?.relationshipStartDate;
  }

  @override
  void dispose() {
    _myNicknameController.dispose();
    _partnerNicknameController.dispose();
    super.dispose();
  }

  int? get _daysTogether {
    if (_startDate == null) return null;
    final DateTime now = DateTime.now();
    final DateTime start = DateTime(
      _startDate!.year,
      _startDate!.month,
      _startDate!.day,
    );
    final DateTime today = DateTime(now.year, now.month, now.day);
    return today.difference(start).inDays;
  }

  Future<void> _pickStartDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(1950),
      lastDate: now,
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final FirebaseFirestore db = FirebaseFirestore.instance;
      await db.collection('users').doc(widget.myUid).set(
        <String, dynamic>{
          'nickname': _myNicknameController.text.trim(),
          if (_startDate != null)
            'relationshipStartDate': Timestamp.fromDate(_startDate!),
        },
        SetOptions(merge: true),
      );
      await db.collection('users').doc(widget.partner.uid).set(
        <String, dynamic>{
          'nickname': _partnerNicknameController.text.trim(),
          if (_startDate != null)
            'relationshipStartDate': Timestamp.fromDate(_startDate!),
        },
        SetOptions(merge: true),
      );
      if (mounted) {
        setState(() => _message = 'Saved 💕');
      }
    } on FirebaseException catch (e) {
      if (mounted) setState(() => _message = e.message ?? 'Save failed.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final int? days = _daysTogether;
    return Scaffold(
      backgroundColor: AppColors.midnight,
      appBar: AppBar(
        backgroundColor: AppColors.midnight,
        title: const Text(
          'Our Profile',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                _PersonColumn(
                  label: 'You',
                  name: widget.myProfile?.shownName ?? 'You',
                  avatarUrl: widget.myProfile?.avatarUrl,
                ),
                const Icon(Icons.favorite, color: AppColors.pink, size: 32),
                _PersonColumn(
                  label: 'Partner',
                  name: widget.partner.shownName,
                  avatarUrl: widget.partner.avatarUrl,
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (days != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$days days together 💕',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            const SizedBox(height: 24),
            TextField(
              controller: _myNicknameController,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('My nickname'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _partnerNicknameController,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('Partner nickname'),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Relationship start date',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                _startDate == null
                    ? 'Not set'
                    : '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}',
                style: const TextStyle(color: AppColors.muted),
              ),
              trailing: const Icon(
                Icons.calendar_today,
                color: AppColors.pink,
              ),
              onTap: _pickStartDate,
            ),
            const SizedBox(height: 24),
            GradientButton(
              label: 'Save',
              isLoading: _saving,
              onPressed: _save,
            ),
            if (_message != null) ...<Widget>[
              const SizedBox(height: 16),
              Text(
                _message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.lavender),
              ),
            ],
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.muted),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }
}

class _PersonColumn extends StatelessWidget {
  const _PersonColumn({
    required this.label,
    required this.name,
    this.avatarUrl,
  });

  final String label;
  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        AvatarWidget(name: name, imageUrl: avatarUrl, radius: 36),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: AppColors.muted)),
        Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
