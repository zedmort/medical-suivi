import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_texts.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '_dashboard_router.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      await auth.login(_emailCtrl.text.trim(), _passwordCtrl.text);
      if (!mounted) return;
      DashboardRouter.go(context, auth.role);
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError(AppTexts.of(context, 'connection_failed'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
      );

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppTexts.of(context, key);
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Logo ──────────────────────────────────────────────────
                  Center(
                    child: Container(
                      width: 136,
                      height: 136,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1976D2).withAlpha(77),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        'lib/assets/images/medi-go-logo.jpeg',
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'MediGo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1976D2)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t('login_subtitle'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                  const SizedBox(height: 40),

                  // ── Email ─────────────────────────────────────────────────
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: t('email'),
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? t('invalid_email') : null,
                  ),
                  const SizedBox(height: 16),

                  // ── Password ──────────────────────────────────────────────
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: t('password'),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) =>
                      (v == null || v.length < 4) ? t('password_too_short') : null,
                  ),
                  const SizedBox(height: 28),

                  // ── Login button ──────────────────────────────────────────
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                          : Text(t('login')),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ── Register link ─────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        Text("${t('dont_have_account')} ",
                          style: const TextStyle(color: Colors.grey)),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const RegisterScreen()),
                        ),
                        child: Text(
                          t('register_link'),
                          style: const TextStyle(
                              color: Color(0xFF1976D2),
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
