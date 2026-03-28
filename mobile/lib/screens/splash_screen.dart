import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_texts.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import '_dashboard_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _goNext();
  }

  Future<void> _goNext() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    if (auth.isAuthenticated) {
      DashboardRouter.go(context, auth.role);
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppTexts.of(context, key);
    return Scaffold(
      backgroundColor: const Color(0xFF1976D2),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'lib/assets/images/medi-go-logo.jpeg',
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'MediGo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t('splash_tagline'),
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 28),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
