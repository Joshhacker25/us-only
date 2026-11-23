import 'package:flutter/material.dart';
import '../../../shared/models/user_profile.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/heart_burst_animation.dart';
import '../../../shared/widgets/loading_state.dart';
import '../../relationship/presentation/relationship_profile_screen.dart';
import 'chat_screen.dart';

/// Home: the couple's single conversation, partner header, relationship day
/// counter, online / typing status, and empty / loading / error states.
/// Only Us has one conversation — there is no multi-chat list.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.myUid,
    required this.partner,
    required this.conversationId,
    this.isLoading = false,
    this.error,
    this.onRetry,
    this.partnerTyping = false,
    this.lastMessageText,
    this.lastMessageAt,
  });

  final String myUid;
  final UserProfile partner;
  final String conversationId;
  final bool isLoading;
  final String? error;
  final VoidCallback? onRetry;
  final bool partnerTyping;
  final String? lastMessageText;
  final DateTime? lastMessageAt;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.midnight,
      appBar: AppBar(
        backgroundColor: AppColors.midnight,
        elevation: 0,
        title: const Text(
          'Only Us 💕',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.favorite, color: AppColors.pink),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RelationshipProfileScreen(
                    myUid: myUid,
                    partner: partner,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? const LoadingState(message: 'Loading your conversation...')
          : error != null
              ? ErrorState(message: error!, onRetry: onRetry)
              : Column(
                  children: <Widget>[
                    _PartnerHeader(
                      partner: partner,
                      partnerTyping: partnerTyping,
                    ),
                    Expanded(
                      child: ListView(
                        children: <Widget>[
                          ListTile(
                            leading: AvatarWidget(
                              name: partner.shownName,
                              imageUrl: partner.avatarUrl,
                              radius: 26,
                              showOnlineDot: true,
                              isOnline: partner.isOnline,
                            ),
                            title: Text(
                              partner.shownName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              partnerTyping
                                  ? 'typing...'
                                  : (lastMessageText ?? 'Say hi to your love'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: partnerTyping
                                    ? AppColors.pink
                                    : AppColors.muted,
                              ),
                            ),
                            trailing: lastMessageAt == null
                                ? null
                                : Text(
                                    '${lastMessageAt!.hour.toString().padLeft(2, '0')}:${lastMessageAt!.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ChatScreen(
                                    conversationId: conversationId,
                                    myUid: myUid,
                                    partnerUid: partner.uid,
                                    partnerName: partner.shownName,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _PartnerHeader extends StatelessWidget {
  const _PartnerHeader({required this.partner, required this.partnerTyping});

  final UserProfile partner;
  final bool partnerTyping;

  @override
  Widget build(BuildContext context) {
    final int? days = partner.daysTogether;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: <Widget>[
          HeartBurstAnimation(
            child: AvatarWidget(
              name: partner.shownName,
              imageUrl: partner.avatarUrl,
              radius: 36,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            partner.shownName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            partnerTyping
                ? 'typing...'
                : (partner.isOnline ? 'Online now' : 'Offline'),
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          if (days != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              '$days days together 💕',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Placeholder shown when no partner is linked yet.
class HomeEmptyPartner extends StatelessWidget {
  const HomeEmptyPartner({super.key, required this.onPair});

  final VoidCallback onPair;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.favorite_border,
      title: 'No partner linked yet',
      subtitle: 'Link your partner to start your private conversation.',
      actionLabel: 'Link partner',
      onAction: onPair,
    );
  }
}
