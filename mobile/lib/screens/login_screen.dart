import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_texts.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/medi_go_theme.dart';
import '_dashboard_router.dart';
import 'role_selection_screen.dart';

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
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              MediGoTheme.backgroundStart,
              MediGoTheme.backgroundEnd,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              child: Form(
                key: _formKey,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: MediGoTheme.primaryBlue.withValues(alpha: 0.08),
                        blurRadius: 30,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 118,
                          height: 118,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [MediGoTheme.primaryBlue, MediGoTheme.deepBlueEnd],
                            ),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: MediGoTheme.primaryBlue.withValues(alpha: 0.22),
                                blurRadius: 20,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset(
                              'lib/assets/images/medi-go-logo.jpeg',
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      RichText(
                        textAlign: TextAlign.center,
                        text: const TextSpan(
                          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.6),
                          children: [
                            TextSpan(text: 'Medi', style: TextStyle(color: MediGoTheme.darkNavy)),
                            TextSpan(text: 'Go', style: TextStyle(color: MediGoTheme.heartRed)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t('login_subtitle'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: MediGoTheme.secondaryGrey,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: t('email'),
                          prefixIcon: const Icon(Icons.email_outlined, color: MediGoTheme.secondaryGrey),
                        ),
                        validator: (v) =>
                            (v == null || !v.contains('@')) ? t('invalid_email') : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: t('password'),
                          prefixIcon: const Icon(Icons.lock_outline, color: MediGoTheme.secondaryGrey),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: MediGoTheme.secondaryGrey),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) =>
                            (v == null || v.length < 4) ? t('password_too_short') : null,
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.check_box_outline_blank, color: MediGoTheme.secondaryGrey, size: 18),
                              SizedBox(width: 8),
                              Text('Se souvenir de moi', style: TextStyle(color: MediGoTheme.secondaryGrey, fontSize: 12)),
                            ],
                          ),
                          Text('Mot de passe oublié ?', style: TextStyle(color: MediGoTheme.primaryBlue, fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _submit,
                          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                          label: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5),
                                )
                              : Text(t('login')),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: const [
                          Expanded(child: Divider(color: MediGoTheme.borderSoft)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('Ou se connecter avec', style: TextStyle(color: MediGoTheme.secondaryGrey, fontSize: 12)),
                          ),
                          Expanded(child: Divider(color: MediGoTheme.borderSoft)),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _socialButton(Icons.g_mobiledata_rounded, 'Google'),
                          const SizedBox(width: 16),
                          _socialButton(Icons.apple, 'Apple'),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Vous n\'avez pas de compte ? ', style: TextStyle(color: MediGoTheme.secondaryGrey)),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
                            ),
                            child: const Text(
                              'S\'inscrire',
                              style: TextStyle(
                                color: MediGoTheme.primaryBlue,
                                fontWeight: FontWeight.w700,
                              ),
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
        ),
      ),
    );
  }

  Widget _socialButton(IconData icon, String label) {
    return Container(
      width: 108,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MediGoTheme.borderSoft),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: MediGoTheme.darkNavy),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: MediGoTheme.darkNavy, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
