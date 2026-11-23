/// Create a sealed surprise: pick a type, write the content, choose
/// the unlock date/time. The content is encrypted before it is stored —
/// this screen never sends plaintext to Firestore.
///
/// WIRING (Part A): pass [encryptText] (encrypts a text note with the
/// couple's shared key and returns the ciphertext) and, for photo /
/// voice / video, [pickEncryptedMedia] (lets the user pick media, uploads
/// the encrypted bytes, and returns the encrypted storage reference).
/// Until those callbacks are wired, the Seal button stays disabled and
/// the screen explains why — a surprise must never be stored unsealed.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/surprise_service.dart';
import 'surprise_countdown_screen.dart';
import 'surprise_provider.dart';

const _bg = Color(0xFF100B1F);
const _card = Color(0xFF1B1230);
const _purple = Color(0xFF7C3AED);
const _pink = Color(0xFFFF4D9D);
const _lavender = Color(0xFFE9D5FF);

class SurpriseCreateScreen extends StatefulWidget {
  const SurpriseCreateScreen({
    super.key,
    required this.coupleId,
    this.encryptText,
    this.pickEncryptedMedia,
  });

  final String coupleId;

  /// Encrypts a text note; returns the ciphertext to store.
  final Future<String> Function(String plaintext)? encryptText;

  /// Picks media of [type], uploads encrypted bytes, returns the
  /// encrypted storage reference to store as ciphertext.
  final Future<String?> Function(SurpriseType type)? pickEncryptedMedia;

  @override
  State<SurpriseCreateScreen> createState() => _SurpriseCreateScreenState();
}

class _SurpriseCreateScreenState extends State<SurpriseCreateScreen> {
  SurpriseType _type = SurpriseType.text;
  final _titleController = TextEditingController();
  final _textController = TextEditingController();
  DateTime _unlockAt = DateTime.now().add(const Duration(days: 7));
  String? _mediaReference;
  bool _sealing = false;

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  bool get _canSeal {
    if (_titleController.text.trim().isEmpty) return false;
    if (!_unlockAt.isAfter(DateTime.now())) return false;
    if (_type == SurpriseType.text) {
      return widget.encryptText != null &&
          _textController.text.trim().isNotEmpty;
    }
    return widget.pickEncryptedMedia != null && _mediaReference != null;
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _unlockAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_unlockAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _unlockAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _pickMedia() async {
    final pick = widget.pickEncryptedMedia;
    if (pick == null) return;
    final reference = await pick(_type);
    if (reference != null && mounted) {
      setState(() => _mediaReference = reference);
    }
  }

  Future<void> _seal() async {
    if (!_canSeal || _sealing) return;
    setState(() => _sealing = true);
    try {
      late final String ciphertext;
      if (_type == SurpriseType.text) {
        ciphertext =
            await widget.encryptText!(_textController.text.trim());
      } else {
        ciphertext = _mediaReference!;
      }
      final provider = context.read<SurpriseProvider>();
      final created = await provider.createSurprise(
        type: _type,
        title: _titleController.text.trim(),
        unlockAt: _unlockAt,
        ciphertext: ciphertext,
      );
      if (!mounted) return;
      if (created == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.error ?? 'Could not seal it.')),
        );
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => SurpriseCountdownScreen(
            coupleId: widget.coupleId,
            surprise: created,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sealing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final encryptionReady = widget.encryptText != null;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Seal a Surprise 🎁',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (!encryptionReady)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.shade900,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Sealing is not wired up yet — the app still needs its '
                'encryption set up before a surprise can be stored '
                'safely. Nothing you type here will be saved.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          const SizedBox(height: 16),
          const Text(
            'What kind of surprise?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: SurpriseType.values.map((type) {
              final selected = _type == type;
              return ChoiceChip(
                label: Text(type.name),
                selected: selected,
                selectedColor: _pink,
                backgroundColor: _card,
                labelStyle: const TextStyle(color: Colors.white),
                onSelected: (_) => setState(() {
                  _type = type;
                  _mediaReference = null;
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _titleController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Envelope title — e.g. "For our anniversary"'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          if (_type == SurpriseType.text)
            TextField(
              controller: _textController,
              style: const TextStyle(color: Colors.white),
              maxLines: 6,
              decoration: _inputDecoration('Write your surprise note…'),
              onChanged: (_) => setState(() {}),
            )
          else
            OutlinedButton.icon(
              onPressed: widget.pickEncryptedMedia == null
                  ? null
                  : _pickMedia,
              icon: Icon(
                _type == SurpriseType.photo
                    ? Icons.photo
                    : _type == SurpriseType.voice
                        ? Icons.mic
                        : Icons.videocam,
              ),
              label: Text(
                _mediaReference == null
                    ? 'Pick ${_type.name} (encrypted upload)'
                    : 'Media attached ✓',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: _purple),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          const SizedBox(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lock_clock, color: _pink),
            title: const Text(
              'Opens on',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              // Timezone handling: store UTC, display in local time.
              _formatLocal(_unlockAt),
              style: const TextStyle(color: _lavender),
            ),
            trailing: TextButton(
              onPressed: _pickDateTime,
              child: const Text('Change', style: TextStyle(color: _pink)),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Until that moment, neither of you can peek — not even you. '
            'The sealed envelope only shows its title and a countdown.',
            style: TextStyle(color: _lavender),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canSeal && !_sealing ? _seal : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _pink,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _sealing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Seal it 💕',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _lavender),
      filled: true,
      fillColor: _card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  String _formatLocal(DateTime dateTime) {
    final local = dateTime.toLocal();
    final months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${months[local.month - 1]} ${local.year} at $hour:$minute (your time)';
  }
}
