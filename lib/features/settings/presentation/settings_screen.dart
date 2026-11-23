/// Settings tab: profile, privacy, notifications, general.
/// Each section opens its own screen; sign-out lives here.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../love_widget/presentation/widget_setup_screen.dart';
import 'general_settings_screen.dart';
import 'notification_settings_screen.dart';
import 'privacy_settings_screen.dart';

const _bg = Color(0xFF100B1F);
const _card = Color(0xFF1B1230);
const _purple = Color(0xFF7C3AED);
const _pink = Color(0xFFFF4D9D);
const _lavender = Color(0xFFE9D5FF);

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.coupleId});

  final String coupleId;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Settings',
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
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: _purple,
                  child: Text('💕', style: TextStyle(fontSize: 28)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? 'My love',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        user?.email ?? '',
                        style: const TextStyle(color: _lavender),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionTile(
            icon: Icons.lock_outline,
            title: 'Privacy',
            subtitle: 'Hearts opt-out, quiet hours, widget privacy',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PrivacySettingsScreen(),
              ),
            ),
          ),
          _SectionTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Messages, calls, hearts, surprises',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const NotificationSettingsScreen(),
              ),
            ),
          ),
          _SectionTile(
            icon: Icons.tune,
            title: 'General',
            subtitle: 'Appearance, accessibility, text size',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const GeneralSettingsScreen(),
              ),
            ),
          ),
          _SectionTile(
            icon: Icons.widgets_outlined,
            title: 'Love Widget',
            subtitle: 'Home-screen widget setup',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => WidgetSetupScreen(coupleId: coupleId),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: _card,
                    title: const Text(
                      'Sign out?',
                      style: TextStyle(color: Colors.white),
                    ),
                    content: const Text(
                      'You will need to sign in again to see your messages and calls.',
                      style: TextStyle(color: _lavender),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text(
                          'Sign out',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await FirebaseAuth.instance.signOut();
                }
              },
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              label: const Text(
                'Sign out',
                style: TextStyle(color: Colors.redAccent),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'Only Us 💕 — private, just the two of you.',
              style: TextStyle(color: _lavender, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(icon, color: _pink),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(subtitle, style: const TextStyle(color: _lavender)),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: _lavender,
          size: 16,
        ),
        onTap: onTap,
      ),
    );
  }
}
