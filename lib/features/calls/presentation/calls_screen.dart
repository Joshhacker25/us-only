/// Calls tab: call history (voice/video, outgoing/incoming/missed) with
/// quick redial buttons. History comes from Firestore call_sessions;
/// missed calls are sessions that ended in state `missed` or `rejected`.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/call_signaling_service.dart';
import 'call_provider.dart';
import 'video_call_screen.dart';
import 'voice_call_screen.dart';

const _bg = Color(0xFF100B1F);
const _card = Color(0xFF1B1230);
const _purple = Color(0xFF7C3AED);
const _pink = Color(0xFFFF4D9D);
const _lavender = Color(0xFFE9D5FF);

class CallsScreen extends StatelessWidget {
  const CallsScreen({super.key, required this.coupleId});

  final String coupleId;

  @override
  Widget build(BuildContext context) {
    final signaling = CallSignalingService();
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Calls',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<List<CallSession>>(
        stream: signaling.watchCallHistory(coupleId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _pink),
            );
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Could not load call history.',
                style: TextStyle(color: _lavender),
              ),
            );
          }
          final calls = snapshot.data ?? const <CallSession>[];
          if (calls.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No calls yet.\nTap the call button to ring your love. 💕',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _lavender, fontSize: 16),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: calls.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final call = calls[index];
              final outgoing = call.callerUid == myUid;
              final missed = call.state == CallState.missed ||
                  (call.state == CallState.rejected && !outgoing);
              final subtitle = _subtitleFor(call, outgoing);
              return Container(
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        missed ? Colors.red.shade900 : _purple,
                    child: Icon(
                      call.isVideo ? Icons.videocam : Icons.call,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    missed
                        ? 'Missed ${call.isVideo ? 'video' : 'voice'} call'
                        : '${outgoing ? 'Outgoing' : 'Incoming'} '
                            '${call.isVideo ? 'video' : 'voice'} call',
                    style: TextStyle(
                      color: missed ? Colors.red.shade300 : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    subtitle,
                    style: const TextStyle(color: _lavender),
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      call.isVideo ? Icons.videocam : Icons.call,
                      color: _pink,
                    ),
                    tooltip: 'Call back',
                    onPressed: () async {
                      final provider = context.read<CallProvider>();
                      await provider.startCall(call.type);
                      if (!context.mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => call.isVideo
                              ? const VideoCallScreen()
                              : const VoiceCallScreen(),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _subtitleFor(CallSession call, bool outgoing) {
    final created = call.createdAt?.toLocal();
    final date = created == null
        ? ''
        : '${created.day}/${created.month}/${created.year} '
            '${created.hour.toString().padLeft(2, '0')}:'
            '${created.minute.toString().padLeft(2, '0')}';
    final state = switch (call.state) {
      CallState.ringing => 'Ringing…',
      CallState.accepted => 'Connected',
      CallState.rejected => 'Declined',
      CallState.ended => 'Ended',
      CallState.missed => 'No answer',
    };
    return '$date  •  $state';
  }
}
