/// General settings: reduced motion + text scaling (accessibility),
/// stored locally. Part A reads these keys at startup and applies
/// them app-wide:
///   * `a11y_reduced_motion` (bool, default false)
///   * `a11y_text_scale` (double, 0.85–1.3, default 1.0)
/// When reduced motion is on, the app must skip the elastic / burst
/// animations in the romantic screens and use fades instead.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _bg = Color(0xFF100B1F);
const _card = Color(0xFF1B1230);
const _pink = Color(0xFFFF4D9D);
const _lavender = Color(0xFFE9D5FF);

class GeneralSettingsScreen extends StatefulWidget {
  const GeneralSettingsScreen({super.key});

  @override
  State<GeneralSettingsScreen> createState() => _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends State<GeneralSettingsScreen> {
  bool _reducedMotion = false;
  double _textScale = 1.0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _reducedMotion = prefs.getBool('a11y_reduced_motion') ?? false;
      _textScale = prefs.getDouble('a11y_text_scale') ?? 1.0;
      _loading = false;
    });
  }

  Future<void> _setReducedMotion(bool value) async {
    setState(() => _reducedMotion = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('a11y_reduced_motion', value);
  }

  Future<void> _setTextScale(double value) async {
    setState(() => _textScale = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('a11y_text_scale', value);
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
          'General',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Accessibility',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Reduce motion',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Replaces the hug/kiss burst and heart pulse animations with simple fades.',
              style: TextStyle(color: _lavender),
            ),
            value: _reducedMotion,
            activeColor: _pink,
            onChanged: _setReducedMotion,
          ),
          const SizedBox(height: 8),
          const Text(
            'Text size',
            style: TextStyle(color: Colors.white),
          ),
          Slider(
            value: _textScale,
            min: 0.85,
            max: 1.3,
            divisions: 9,
            label: '${(_textScale * 100).round()}%',
            activeColor: _pink,
            onChanged: _setTextScale,
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Preview: your love, in bigger words 💕',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16 * _textScale,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'About',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Only Us — a private messenger for two.\n'
            'Version 1.0.0 (Part C: calls, nearby, romantic, surprises, widget).',
            style: TextStyle(color: _lavender, height: 1.6),
          ),
        ],
      ),
    );
  }
}
