import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../l10n/app_texts.dart';
import '../services/api_service.dart';
import '../constants/medical_taxonomy.dart';
import 'legal_document_screen.dart';
import '_dashboard_router.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _patientFirstCtrl = TextEditingController();
  final _patientLastCtrl = TextEditingController();
  final _patientAgeCtrl = TextEditingController();
  final _patientLocationCtrl = TextEditingController();
  final _patientPhoneCtrl = TextEditingController();
  String _selectedRole = 'doctor';
  String _patientSex = 'M';
  String? _doctorSpecialty;
  String? _patientDisease;
  bool _obscure = true;
  bool _isLoading = false;
  bool _acceptedTerms = false;

  static const _roles = [
    {'value': 'doctor', 'labelKey': 'doctor', 'icon': Icons.medical_services},
    {'value': 'patient', 'labelKey': 'patient', 'icon': Icons.person},
    {'value': 'labo', 'labelKey': 'labo', 'icon': Icons.biotech},
    {'value': 'pharmacy', 'labelKey': 'pharmacy', 'icon': Icons.local_pharmacy},
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _patientFirstCtrl.dispose();
    _patientLastCtrl.dispose();
    _patientAgeCtrl.dispose();
    _patientLocationCtrl.dispose();
    _patientPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      _showError(AppTexts.of(context, 'accept_terms_error'));
      return;
    }

    if (_selectedRole == 'doctor' && (_doctorSpecialty == null || _doctorSpecialty!.isEmpty)) {
      _showError(AppTexts.of(context, 'select_specialty'));
      return;
    }

    if (_selectedRole == 'patient') {
      if (_patientFirstCtrl.text.trim().isEmpty ||
          _patientLastCtrl.text.trim().isEmpty ||
          _patientAgeCtrl.text.trim().isEmpty ||
          _patientLocationCtrl.text.trim().isEmpty ||
          (_patientDisease == null || _patientDisease!.isEmpty)) {
        _showError(AppTexts.of(context, 'fill_patient_fields'));
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      final displayName = _selectedRole == 'patient'
          ? '${_patientFirstCtrl.text.trim()} ${_patientLastCtrl.text.trim()}'.trim()
          : _nameCtrl.text.trim();

      final extraData = <String, dynamic>{};
      if (_selectedRole == 'doctor') {
        extraData['specialty'] = _doctorSpecialty;
      } else if (_selectedRole == 'patient') {
        extraData.addAll({
          'firstname': _patientFirstCtrl.text.trim(),
          'lastname': _patientLastCtrl.text.trim(),
          'age': int.tryParse(_patientAgeCtrl.text.trim()) ?? 0,
          'address': _patientLocationCtrl.text.trim(),
          'sex': _patientSex,
          'disease': _patientDisease,
          'phone': _patientPhoneCtrl.text.trim(),
        });
      }

      await auth.register(
        displayName,
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
        _selectedRole,
        extraData: extraData,
      );
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF1976D2),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 136,
                    height: 136,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1976D2).withAlpha(44),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
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
                const SizedBox(height: 20),
                Text(
                  t('register_title'),
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1976D2)),
                ),
                const SizedBox(height: 6),
                Text(t('register_subtitle'),
                    style: const TextStyle(color: Colors.grey, fontSize: 15)),
                const SizedBox(height: 32),

                // ── Name (non-patient roles) ──────────────────────────────
                if (_selectedRole != 'patient') ...[
                  TextFormField(
                    controller: _nameCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: t('full_name'),
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    validator: (v) => _selectedRole == 'patient'
                        ? null
                        : (v == null || v.trim().isEmpty)
                            ? t('enter_name')
                            : null,
                  ),
                  const SizedBox(height: 16),
                ],

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
                      (v == null || v.length < 6) ? t('password_too_short') : null,
                ),
                const SizedBox(height: 24),

                // ── Role selector ─────────────────────────────────────────
                  Text(t('select_role'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF37474F),
                        fontSize: 15)),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 2.8,
                  children: _roles.map((r) {
                    final selected = _selectedRole == r['value'].toString();
                    return GestureDetector(
                      onTap: () => setState(() {
                        _selectedRole = r['value'].toString();
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFF1976D2)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF1976D2)
                                : const Color(0xFFE0E0E0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(r['icon'] as IconData,
                                size: 18,
                                color:
                                    selected ? Colors.white : Colors.grey),
                            const SizedBox(width: 8),
                            Text(
                              t(r['labelKey'].toString()),
                              style: TextStyle(
                                color: selected ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                if (_selectedRole == 'doctor') ...[
                  DropdownButtonFormField<String>(
                    initialValue: _doctorSpecialty,
                    decoration: InputDecoration(
                      labelText: t('doctor_specialty'),
                      prefixIcon: const Icon(Icons.local_hospital_outlined),
                    ),
                    items: specialties
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(specialtyLabel(s, context)),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() => _doctorSpecialty = value),
                    validator: (value) =>
                        _selectedRole == 'doctor' && (value == null || value.isEmpty)
                            ? t('select_specialty')
                            : null,
                  ),
                ],

                if (_selectedRole == 'patient') ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _patientFirstCtrl,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: t('first_name'),
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                          validator: (v) => _selectedRole == 'patient' && (v == null || v.trim().isEmpty)
                              ? t('required')
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _patientLastCtrl,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: t('last_name'),
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                          validator: (v) => _selectedRole == 'patient' && (v == null || v.trim().isEmpty)
                              ? t('required')
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _patientAgeCtrl,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: t('age'),
                      prefixIcon: const Icon(Icons.cake_outlined),
                    ),
                    validator: (v) => _selectedRole == 'patient' && (v == null || int.tryParse(v) == null)
                        ? t('valid_age_required')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _patientLocationCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: t('location'),
                      prefixIcon: const Icon(Icons.location_on_outlined),
                    ),
                    validator: (v) => _selectedRole == 'patient' && (v == null || v.trim().isEmpty)
                        ? t('required')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _patientPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: t('phone_optional'),
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Text(t('sex'),
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'M', label: Text('♂ M')),
                          ButtonSegment(value: 'F', label: Text('♀ F')),
                        ],
                        selected: {_patientSex},
                        onSelectionChanged: (values) =>
                            setState(() => _patientSex = values.first),
                        style: SegmentedButton.styleFrom(
                          selectedBackgroundColor: const Color(0xFF1976D2),
                          selectedForegroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _patientDisease,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: t('disease'),
                      prefixIcon: const Icon(Icons.medical_information_outlined),
                    ),
                    items: allDiseases
                        .map((d) => DropdownMenuItem(
                              value: d,
                              child: Text(diseaseLabel(d, context)),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() => _patientDisease = value),
                    validator: (value) =>
                        _selectedRole == 'patient' && (value == null || value.isEmpty)
                            ? t('select_disease')
                            : null,
                  ),
                ],
                const SizedBox(height: 32),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _acceptedTerms,
                      onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 11),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 13,
                              height: 1.4,
                            ),
                            children: [
                              const TextSpan(text: 'I accept the '),
                              TextSpan(
                                text: t('open_terms'),
                                style: const TextStyle(
                                  color: Color(0xFF1976D2),
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const LegalDocumentScreen(
                                          type: LegalDocumentType.terms,
                                        ),
                                      ),
                                    );
                                  },
                              ),
                              const TextSpan(text: ' and '),
                              TextSpan(
                                text: t('open_privacy'),
                                style: const TextStyle(
                                  color: Color(0xFF1976D2),
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const LegalDocumentScreen(
                                          type: LegalDocumentType.privacy,
                                        ),
                                      ),
                                    );
                                  },
                              ),
                              const TextSpan(text: '.'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // ── Register button ───────────────────────────────────────
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
                        : Text(t('create_account')),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${t('already_have_account')} ',
                        style: const TextStyle(color: Colors.grey)),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text(t('login_link'),
                          style: const TextStyle(
                              color: Color(0xFF1976D2),
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
