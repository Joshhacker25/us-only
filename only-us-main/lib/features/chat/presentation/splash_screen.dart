import 'package:flutter/material.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/loading_state.dart';

/// Splash shown while the app restores the session (Part A owns auth;
/// this screen only displays the brand and a loader, then the caller
/// navigates to login or home based on the restored session).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.onTimeout});

  final VoidCallback? onTimeout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('💕', style: TextStyle(fontSize: 64)),
              SizedBox(height: 16),
              Text(
                'Only Us',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Just the two of you.',
                style: TextStyle(color: AppColors.muted, fontSize: 15),
              ),
              SizedBox(height: 32),
              LoadingState(),
            ],
          ),
        ),
      ),
    );
  }
}
