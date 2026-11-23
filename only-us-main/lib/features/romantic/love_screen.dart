/// Love tab home: Hug / Kiss / Heart buttons, recent romantic events,
/// and a link into Surprises. This is the `Love` entry in the main nav
/// (Chat, Love, Calls, Settings).
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/encryption/encrypted_media.dart';
import '../../core/encryption/encryption_service.dart';
import 'hugs_kisses/romantic_event_service.dart';
import 'thinking_of_you/thinking_of_you_screen.dart';
import '../surprises/presentation/surprise_create_screen.dart';
import 'hugs_kisses/hugs_kisses_screen.dart';

const _bg = Color(0xFF100B1F);
const _card = Color(0xFF1B1230);
const _purple = Color(0xFF7C3AED);
const _pink = Color(0xFFFF4D9D);
const _lavender = Color(0xFFE9D5FF);

class LoveScreen extends StatelessWidget {
  const LoveScreen({
    super.key,
    required this.coupleId,
    required this.partnerUid,
    required this.partnerNickname,
  });

  final String coupleId;
  final String partnerUid;
  final String partnerNickname;

  @override
  Widget build(BuildContext context) {
    final service = RomanticEventService();
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Love 💕',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'For $partnerNickname',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'A little love, whenever you feel it.',
            style: TextStyle(color: _lavender),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _LoveAction(
                emoji: '🤗',
                label: 'Hug',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => HugsKissesScreen(
                      coupleId: coupleId,
                      partnerNickname: partnerNickname,
                    ),
                  ),
                ),
              ),
              _LoveAction(
                emoji: '💋',
                label: 'Kiss',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => HugsKissesScreen(
                      coupleId: coupleId,
                      partnerNickname: partnerNickname,
                    ),
                  ),
                ),
              ),
              _LoveAction(
                emoji: '❤️',
                label: 'Heart',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ThinkingOfYouScreen(
                      coupleId: coupleId,
                      partnerUid: partnerUid,
                      partnerNickname: partnerNickname,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_purple, _pink],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: const Text('🎁', style: TextStyle(fontSize: 32)),
              title: const Text(
                'Surprises',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'Seal a note, photo or voice note — it opens on the day you choose.',
                style: TextStyle(color: Colors.white70),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white,
                size: 18,
              ),
              onTap: () {
                final encryption =
                    context.read<EncryptionService>();
                final uploader = EncryptedMediaUploader(
                  encryption: encryption,
                  coupleId: coupleId,
                );
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SurpriseCreateScreen(
                      coupleId: coupleId,
                      encryptText: encryption.encryptText,
                      pickEncryptedMedia:
                          uploader.pickAndUploadEncrypted,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Recent love',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<RomanticEvent>>(
            stream: service.watchRecentEvents(coupleId, limit: 10),
            builder: (context, snapshot) {
              final events = snapshot.data ?? const <RomanticEvent>[];
              if (events.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No love sent yet — tap a button above. 💕',
                    style: TextStyle(color: _lavender),
                  ),
                );
              }
              return Column(
                children: events.map((event) {
                  final mine = event.senderUid == myUid;
                  final time = event.createdAt?.toLocal();
                  final timeText = time == null
                      ? ''
                      : '${time.day}/${time.month} '
                          '${time.hour.toString().padLeft(2, '0')}:'
                          '${time.minute.toString().padLeft(2, '0')}';
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Text(
                        event.emoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                      title: Text(
                        mine
                            ? 'You sent a ${event.label.toLowerCase()}'
                            : '$partnerNickname sent a '
                                '${event.label.toLowerCase()}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: Text(
                        timeText,
                        style: const TextStyle(color: _lavender),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LoveAction extends StatelessWidget {
  const _LoveAction({
    required this.emoji,
    required this.label,
    required this.onPressed,
  });

  final String emoji;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: _card,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Text(emoji, style: const TextStyle(fontSize: 40)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
