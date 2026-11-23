/// Widget setup screen: choose the widget size, what it shows, and
/// privacy mode — plus plain instructions for adding it to the home
/// screen. The widget itself is a native Android AppWidget (Kotlin);
/// this screen only configures what it displays.
library;

import 'package:flutter/material.dart';

import '../data/widget_preferences_service.dart';

const _bg = Color(0xFF100B1F);
const _card = Color(0xFF1B1230);
const _purple = Color(0xFF7C3AED);
const _pink = Color(0xFFFF4D9D);
const _lavender = Color(0xFFE9D5FF);

class WidgetSetupScreen extends StatefulWidget {
  const WidgetSetupScreen({super.key, required this.coupleId});

  final String coupleId;

  @override
  State<WidgetSetupScreen> createState() => _WidgetSetupScreenState();
}

class _WidgetSetupScreenState extends State<WidgetSetupScreen> {
  late final WidgetPreferencesService _service;
  WidgetPreferences _prefs = const WidgetPreferences();
  bool _loading = true;
  bool _saving = false;
  final _nicknameController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _service = WidgetPreferencesService();
    _load();
  }

  Future<void> _load() async {
    final prefs = await _service.load(widget.coupleId);
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _nicknameController.text = prefs.nickname;
      _noteController.text = prefs.sweetNote;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final updated = _prefs.copyWith(
      nickname: _nicknameController.text.trim(),
      sweetNote: _noteController.text.trim(),
    );
    await _service.save(widget.coupleId, updated);
    if (mounted) {
      setState(() {
        _prefs = updated;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Widget updated 💕')),
      );
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _pink)),
      );
    }
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Love Widget',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _purple.withOpacity(0.5)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add it to your home screen',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '1. Long-press an empty spot on your home screen.\n'
                  '2. Tap Widgets.\n'
                  '3. Find Only Us and drag “Love” onto your home screen.\n'
                  '4. Small shows nickname + days; Medium adds your '
                  'sweet note and last heart.',
                  style: TextStyle(color: _lavender, height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Size',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Small (2×1): nickname + days together.\n'
            'Medium (4×2): nickname + days + sweet note + last heart.',
            style: TextStyle(color: _lavender, height: 1.5),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nicknameController,
            style: const TextStyle(color: Colors.white),
            decoration: _decoration('Partner nickname on the widget'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            style: const TextStyle(color: Colors.white),
            decoration: _decoration('Sweet note (optional)'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Show nickname',
              style: TextStyle(color: Colors.white),
            ),
            value: _prefs.showNickname,
            activeColor: _pink,
            onChanged: (v) =>
                setState(() => _prefs = _prefs.copyWith(showNickname: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Show days together',
              style: TextStyle(color: Colors.white),
            ),
            value: _prefs.showDays,
            activeColor: _pink,
            onChanged: (v) =>
                setState(() => _prefs = _prefs.copyWith(showDays: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Show sweet note',
              style: TextStyle(color: Colors.white),
            ),
            value: _prefs.showNote,
            activeColor: _pink,
            onChanged: (v) =>
                setState(() => _prefs = _prefs.copyWith(showNote: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Show last heart',
              style: TextStyle(color: Colors.white),
            ),
            value: _prefs.showLastHeart,
            activeColor: _pink,
            onChanged: (v) =>
                setState(() => _prefs = _prefs.copyWith(showLastHeart: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Privacy mode',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Hides the sweet note and last heart when the phone is locked.',
              style: TextStyle(color: _lavender),
            ),
            value: _prefs.privacyMode,
            activeColor: _pink,
            onChanged: (v) =>
                setState(() => _prefs = _prefs.copyWith(privacyMode: v)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _pink,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Save widget settings'),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration(String hint) {
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
}
