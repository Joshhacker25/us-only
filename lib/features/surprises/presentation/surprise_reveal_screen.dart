/// Surprise reveal screen.
///
/// Only shows content after the Cloud Function confirms the unlock.
/// Until then it shows the sealed state — this screen never decrypts
/// or displays anything on the basis of the local clock alone.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/surprise_service.dart';
import 'surprise_provider.dart';

const _bg = Color(0xFF100B1F);
const _card = Color(0xFF1B1230);
const _purple = Color(0xFF7C3AED);
const _pink = Color(0xFFFF4D9D);
const _lavender = Color(0xFFE9D5FF);

class SurpriseRevealScreen extends StatefulWidget {
  const SurpriseRevealScreen({
    super.key,
    required this.coupleId,
    required this.surprise,
  });

  final String coupleId;
  final Surprise surprise;

  @override
  State<SurpriseRevealScreen> createState() => _SurpriseRevealScreenState();
}

class _SurpriseRevealScreenState extends State<SurpriseRevealScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _revealController;
  SurpriseReveal? _reveal;
  bool _checking = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _requestReveal();
  }

  Future<void> _requestReveal() async {
    final provider = context.read<SurpriseProvider>();
    final reveal = await provider.requestReveal(widget.surprise);
    if (!mounted) return;
    setState(() {
      _reveal = reveal;
      _checking = false;
      _error = reveal.unlocked ? null : reveal.message;
    });
    if (reveal.unlocked) {
      _revealController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surprise = widget.surprise;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Text(
          surprise.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: _checking
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: _pink),
                    SizedBox(height: 16),
                    Text(
                      'Checking the seal…',
                      style: TextStyle(color: _lavender),
                    ),
                  ],
                )
              : _reveal?.unlocked != true
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🔒', style: TextStyle(fontSize: 72)),
                        const SizedBox(height: 16),
                        const Text(
                          'Still sealed.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error ?? 'It is not time yet.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: _lavender),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            setState(() => _checking = true);
                            _requestReveal();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _purple,
                          ),
                          child: const Text('Try again'),
                        ),
                      ],
                    )
                  : ScaleTransition(
                      scale: Tween<double>(begin: 0.8, end: 1).animate(
                        CurvedAnimation(
                          parent: _revealController,
                          curve: Curves.elasticOut,
                        ),
                      ),
                      child: FadeTransition(
                        opacity: _revealController,
                        child: _RevealContent(
                          surprise: surprise,
                          reveal: _reveal!,
                        ),
                      ),
                    ),
        ),
      ),
    );
  }
}

class _RevealContent extends StatelessWidget {
  const _RevealContent({required this.surprise, required this.reveal});

  final Surprise surprise;
  final SurpriseReveal reveal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _pink, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎉', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          Text(
            surprise.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (surprise.type == SurpriseType.text)
            Text(
              reveal.plaintext ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            )
          else if (surprise.type == SurpriseType.photo &&
              reveal.mediaUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(reveal.mediaUrl!),
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  surprise.type == SurpriseType.voice
                      ? Icons.mic
                      : Icons.videocam,
                  color: _pink,
                  size: 48,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your media is unlocked. Playback opens in the '
                  'media player.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _lavender),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
