import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/friends_service.dart';
import '../providers/company_provider.dart';
import '../widgets/gradient_background.dart';
import '../theme.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onInitializationComplete;
  const SplashScreen({super.key, required this.onInitializationComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    FlutterNativeSplash.remove();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final startTime = DateTime.now();
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;
      
      if (user != null) {
        // 1. Initialize CompanyProvider
        final companyProvider = Provider.of<CompanyProvider>(context, listen: false);
        companyProvider.init(user.id);
        
        // 2. Wait for initial friends data to be available (briefly)
        // We don't want to wait forever, but a small delay ensures streams have emitted at least once
        final friendsService = Provider.of<FriendsService>(context, listen: false);
        
        // Wait for both to have data or timeout after 5 seconds
        await Future.wait([
          friendsService.streamUser(user.id).first.timeout(const Duration(seconds: 5)).catchError((_) => null),
          friendsService.streamFriends(user.id).first.timeout(const Duration(seconds: 5)).catchError((_) => <UserModel>[]),
        ]);
      }
    } catch (e) {
      debugPrint('Error during initialization: $e');
      // Even if there's an error, we eventually want to go to HomeScreen 
      // where error states are already handled (though less elegantly)
    }

    final endTime = DateTime.now();
    final elapsed = endTime.difference(startTime);
    const minimumSpinTime = Duration(seconds: 2);

    // Ensure splash screen stays for at least 2 seconds for aesthetic "premium" feel
    if (elapsed < minimumSpinTime) {
      await Future.delayed(minimumSpinTime - elapsed);
    }

    if (mounted) {
      widget.onInitializationComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo/App Name
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(seconds: 1),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Opacity(
                      opacity: value,
                      child: child,
                    ),
                  );
                },
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/logo.png',
                          height: 100,
                          width: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'comms.',
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              // Loading Indicator
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  color: AppColors.accentBlue,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Connecting to your world...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
