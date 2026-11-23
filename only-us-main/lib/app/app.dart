/// App shell — Part A.
///
/// Wiring: Firebase Auth gate -> allowlist check -> couple/conversation
/// ids -> bottom navigation (Chat, Love, Calls, Settings — no Games).
/// Provides EncryptionService, SurpriseProvider and CallProvider.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/auth/auth_service.dart';
import '../core/auth/couple_service.dart';
import '../core/encryption/encryption_service.dart';
import '../features/calls/presentation/call_provider.dart';
import '../features/calls/presentation/calls_screen.dart';
import '../features/chat/presentation/home_screen.dart';
import '../features/chat/presentation/login_screen.dart';
import '../features/nearby/presentation/nearby_screen.dart';
import '../features/romantic/love_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/surprises/presentation/surprise_provider.dart';
import '../shared/models/user_profile.dart';
import '../shared/theme/app_colors.dart';
import '../shared/utils/allowlist.dart';

/// The two provisioned UIDs. Replace the placeholders during
/// provisioning (docs/PROVISIONING.md). Until then, nobody can sign
/// in — the app fails closed.
const List<String> kAllowedUids = <String>[
  'mzNOSMi0bgU5QNzyy29UKBEyOhX2',
  'SkZx6Wh7cFVj1XuDdM4WIlx3JxB2',
];

class OnlyUsApp extends StatelessWidget {
  const OnlyUsApp({super.key, required this.encryption});

  final EncryptionService encryption;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <Provider<dynamic>>[
        Provider<AuthService>(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        title: 'Only Us 💕',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.midnight,
          colorScheme: const ColorScheme.dark(
            primary: AppColors.purple,
            secondary: AppColors.pink,
            surface: AppColors.surface,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.midnight,
            foregroundColor: Colors.white,
          ),
          useMaterial3: true,
        ),
        home: Provider<EncryptionService>.value(
          value: encryption,
          child: const _AuthGate(),
        ),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) {
          return LoginScreen(
            onSignedIn: (_) {},
          );
        }
        final auth = context.read<AuthService>();
        if (!auth.isAuthorized(kAllowedUids)) {
          // Third UID / unprovisioned build: deny immediately.
          Future.microtask(() => auth.signOut());
          return const _DeniedScreen();
        }
        return _MainShell(myUid: user.uid);
      },
    );
  }
}

class _DeniedScreen extends StatelessWidget {
  const _DeniedScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.midnight,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'This app is private — only the two provisioned people '
            'can sign in.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      ),
    );
  }
}

class _MainShell extends StatefulWidget {
  const _MainShell({required this.myUid});

  final String myUid;

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _index = 0;
  late final CoupleService _coupleService;
  String? _partnerUid;
  String? _coupleId;
  String? _conversationId;
  UserProfile? _partner;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _coupleService = CoupleService();
    _load();
  }

  Future<void> _load() async {
    try {
      final partnerUid =
          await _coupleService.partnerUid(kAllowedUids);
      if (partnerUid == null) {
        setState(() {
          _error = 'Partner not provisioned yet.';
          _loading = false;
        });
        return;
      }
      final coupleId =
          CoupleService.coupleIdFor(widget.myUid, partnerUid);
      await _coupleService.ensureCoupleDocument(
          coupleId, <String>[widget.myUid, partnerUid]);
      final partner = await _coupleService.fetchPartner(partnerUid);
      setState(() {
        _partnerUid = partnerUid;
        _coupleId = coupleId;
        _conversationId = _coupleService.conversationIdFor(coupleId);
        _partner = partner ??
            UserProfile(
              uid: partnerUid,
              displayName: 'Your love',
              nickname: 'Your love',
            );
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.midnight,
        body: Center(child: CircularProgressIndicator(color: AppColors.pink)),
      );
    }
    if (_error != null || _partner == null || _coupleId == null) {
      return Scaffold(
        backgroundColor: AppColors.midnight,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error ?? 'Could not load your partner.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      );
    }
    final coupleId = _coupleId!;
    final partner = _partner!;
    final partnerUid = _partnerUid!;
    final encryption = context.read<EncryptionService>();

    final pages = <Widget>[
      HomeScreen(
        myUid: widget.myUid,
        partner: partner,
        conversationId: _conversationId!,
      ),
      LoveScreen(
        coupleId: coupleId,
        partnerUid: partnerUid,
        partnerNickname: partner.shownName,
      ),
      CallsScreen(coupleId: coupleId),
      SettingsScreen(coupleId: coupleId),
    ];

    return MultiProvider(
      providers: <ChangeNotifierProvider<dynamic>>[
        ChangeNotifierProvider<SurpriseProvider>(
          create: (_) => SurpriseProvider(coupleId: coupleId),
        ),
        ChangeNotifierProvider<CallProvider>(
          create: (_) => CallProvider(
            coupleId: coupleId,
            partnerUid: partnerUid,
            partnerNickname: partner.shownName,
          ),
        ),
      ],
      child: Scaffold(
        body: IndexedStack(index: _index, children: pages),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.pink,
          unselectedItemColor: AppColors.muted,
          type: BottomNavigationBarType.fixed,
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
            BottomNavigationBarItem(
                icon: Icon(Icons.favorite), label: 'Love'),
            BottomNavigationBarItem(icon: Icon(Icons.call), label: 'Calls'),
            BottomNavigationBarItem(
                icon: Icon(Icons.settings), label: 'Settings'),
          ],
        ),
        floatingActionButton: _index == 0
            ? FloatingActionButton(
                backgroundColor: AppColors.pink,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => NearbyScreen(
                      coupleId: coupleId,
                      partnerNickname: partner.shownName,
                      myUid: widget.myUid,
                      cipher: encryption,
                    ),
                  ),
                ),
                child: const Icon(Icons.wifi, color: Colors.white),
              )
            : null,
      ),
    );
  }
}
