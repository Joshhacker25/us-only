/// Privacy settings: hearts opt-out, quiet hours, widget privacy mode.
///
/// The hearts opt-out and quiet hours are stored in Firestore
/// (`users/{uid}/settings/thinkingOfYou`) so the *partner's* device and
/// the notification sender can honour them — see
/// [ThinkingOfYouSettings]. Widget privacy mode is stored locally and
/// in the widget preferences (Part C, love_widget).
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../romantic/thinking_of_you/thinking_of_you_service.dart';

const _bg = Color(0xFF100B1F);
const _card = Color(0xFF1B1230);
const _pink = Color(0xFFFF4D9D);
const _lavender = Color(0xFFE9D5FF);

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final _service = ThinkingOfYouService();
  ThinkingOfYouSettings _settings = const ThinkingOfYouSettings();
  bool _loading = true;
  bool _widgetPrivacyMode = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    ThinkingOfYouSettings settings = const ThinkingOfYouSettings();
    if (uid.isNotEmpty) {
      try {
        // My own settings live under my own uid.
        settings = await _service.loadPartnerSettings(uid);
      } catch (_) {}
    }
    final local = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _widgetPrivacyMode = local.getBool('privacyMode') ?? true;
      _loading = false;
    });
  }

  Future<void> _save() async {
    try {
      await _service.saveMySettings(_settings);
    } catch (_) {}
    final local = await SharedPreferences.getInstance();
    await local.setBool('privacyMode', _widgetPrivacyMode);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Privacy settings saved.')),
      );
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = TimeOfDay(
      hour: isStart ? _settings.quietStartHour : _settings.quietEndHour,
      minute:
          isStart ? _settings.quietStartMinute : _settings.quietEndMinute,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null) return;
    setState(() {
      _settings = ThinkingOfYouSettings(
        heartsOptedOut: _settings.heartsOptedOut,
        quietHoursEnabled: _settings.quietHoursEnabled,
        quietStartHour:
            isStart ? picked.hour : _settings.quietStartHour,
        quietStartMinute:
            isStart ? picked.minute : _settings.quietStartMinute,
        quietEndHour: isStart ? _settings.quietEndHour : picked.hour,
        quietEndMinute:
            isStart ? _settings.quietEndMinute : picked.minute,
      );
    });
    await _save();
  }

  String _timeLabel(int hour, int minute) {
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
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
          'Privacy',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Turn off hearts from my partner',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Your partner will not be able to send you hearts while this is on.',
              style: TextStyle(color: _lavender),
            ),
            value: _settings.heartsOptedOut,
            activeColor: _pink,
            onChanged: (value) async {
              setState(() {
                _settings = ThinkingOfYouSettings(
                  heartsOptedOut: value,
                  quietHoursEnabled: _settings.quietHoursEnabled,
                  quietStartHour: _settings.quietStartHour,
                  quietStartMinute: _settings.quietStartMinute,
                  quietEndHour: _settings.quietEndHour,
                  quietEndMinute: _settings.quietEndMinute,
                );
              });
              await _save();
            },
          ),
          const Divider(color: _card),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Quiet hours',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Hearts arrive silently during quiet hours — no notification sound.',
              style: TextStyle(color: _lavender),
            ),
            value: _settings.quietHoursEnabled,
            activeColor: _pink,
            onChanged: (value) async {
              setState(() {
                _settings = ThinkingOfYouSettings(
                  heartsOptedOut: _settings.heartsOptedOut,
                  quietHoursEnabled: value,
                  quietStartHour: _settings.quietStartHour,
                  quietStartMinute: _settings.quietStartMinute,
                  quietEndHour: _settings.quietEndHour,
                  quietEndMinute: _settings.quietEndMinute,
                );
              });
              await _save();
            },
          ),
          if (_settings.quietHoursEnabled) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Quiet from',
                style: TextStyle(color: Colors.white),
              ),
              trailing: TextButton(
                onPressed: () => _pickTime(isStart: true),
                child: Text(
                  _timeLabel(
                    _settings.quietStartHour,
                    _settings.quietStartMinute,
                  ),
                  style: const TextStyle(color: _pink, fontSize: 16),
                ),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Quiet until',
                style: TextStyle(color: Colors.white),
              ),
              trailing: TextButton(
                onPressed: () => _pickTime(isStart: false),
                child: Text(
                  _timeLabel(
                    _settings.quietEndHour,
                    _settings.quietEndMinute,
                  ),
                  style: const TextStyle(color: _pink, fontSize: 16),
                ),
              ),
            ),
          ],
          const Divider(color: _card),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Widget privacy mode',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Hides the sweet note and last heart on the home-screen widget when the phone is locked.',
              style: TextStyle(color: _lavender),
            ),
            value: _widgetPrivacyMode,
            activeColor: _pink,
            onChanged: (value) async {
              setState(() => _widgetPrivacyMode = value);
              await _save();
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Only the two of you can see anything in Only Us. There are '
            'no public profiles, no followers, and nothing is shared '
            'outside the couple.',
            style: TextStyle(color: _lavender),
          ),
        ],
      ),
    );
  }
}
