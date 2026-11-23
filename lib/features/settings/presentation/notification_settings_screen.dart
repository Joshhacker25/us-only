/// Notification settings: per-kind toggles, stored locally.
/// The push sender (Part A) must read these same keys before sending:
/// `notif_messages`, `notif_calls`, `notif_hearts`, `notif_surprises`,
/// `notif_sound`, `notif_preview`. Quiet hours live in Privacy.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _bg = Color(0xFF100B1F);
const _pink = Color(0xFFFF4D9D);
const _lavender = Color(0xFFE9D5FF);

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final Map<String, bool> _toggles = <String, bool>{
    'notif_messages': true,
    'notif_calls': true,
    'notif_hearts': true,
    'notif_surprises': true,
    'notif_sound': true,
    'notif_preview': false,
  };
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
      for (final key in _toggles.keys) {
        _toggles[key] = prefs.getBool(key) ?? _toggles[key]!;
      }
      _loading = false;
    });
  }

  Future<void> _set(String key, bool value) async {
    setState(() => _toggles[key] = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
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
          'Notifications',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Toggle(
            title: 'Messages',
            subtitle: 'Notify me when my love messages me.',
            value: _toggles['notif_messages']!,
            onChanged: (v) => _set('notif_messages', v),
          ),
          _Toggle(
            title: 'Calls',
            subtitle: 'Ring for incoming voice and video calls.',
            value: _toggles['notif_calls']!,
            onChanged: (v) => _set('notif_calls', v),
          ),
          _Toggle(
            title: 'Hearts',
            subtitle: 'A gentle note when a heart arrives.',
            value: _toggles['notif_hearts']!,
            onChanged: (v) => _set('notif_hearts', v),
          ),
          _Toggle(
            title: 'Surprises',
            subtitle: 'Remind me when a sealed surprise opens.',
            value: _toggles['notif_surprises']!,
            onChanged: (v) => _set('notif_surprises', v),
          ),
          const Divider(color: Color(0xFF1B1230)),
          _Toggle(
            title: 'Sound',
            subtitle: 'Play a sound with notifications.',
            value: _toggles['notif_sound']!,
            onChanged: (v) => _set('notif_sound', v),
          ),
          _Toggle(
            title: 'Show message preview',
            subtitle:
                'Off by default — previews can show on your lock screen.',
            value: _toggles['notif_preview']!,
            onChanged: (v) => _set('notif_preview', v),
          ),
          const SizedBox(height: 16),
          const Text(
            'Quiet hours are set under Privacy. During quiet hours, '
            'hearts arrive silently.',
            style: TextStyle(color: _lavender),
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(subtitle, style: const TextStyle(color: _lavender)),
      value: value,
      activeColor: _pink,
      onChanged: onChanged,
    );
  }
}
