import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/medical_taxonomy.dart';
import '../l10n/app_texts.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/medi_go_theme.dart';
import '_dashboard_router.dart';
import 'legal_document_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.initialRole});
  final String initialRole;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _professionalInfoCtrl = TextEditingController();
  String _selectedRole = 'doctor';
  String _patientSex = 'M';

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
  }

  String _doctorType = 'specialist';
  final Set<String> _doctorSpecialties = {};
  final Set<String> _patientConditions = {};
  DateTime? _dateOfBirth;
  bool _obscure = true;
  bool _isLoading = false;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _professionalInfoCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      _showError(AppTexts.of(context, 'accept_terms_error'));
      return;
    }

    if (_dateOfBirth == null) {
      _showError(AppTexts.of(context, 'date_of_birth_required'));
      return;
    }

    if (_selectedRole == 'doctor' &&
        _doctorType == 'specialist' &&
        (_doctorSpecialties.length != 1 ||
            _doctorSpecialties.any(
              (specialty) => !registrationSpecialties.contains(specialty),
            ))) {
      _showError(AppTexts.of(context, 'select_specialty'));
      return;
    }

    if (_selectedRole == 'patient' && _patientConditions.isEmpty) {
      _showError(AppTexts.of(context, 'select_disease'));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      final firstName = _firstNameCtrl.text.trim();
      final lastName = _lastNameCtrl.text.trim();
      final displayName = '$firstName $lastName';
      final extraData = <String, dynamic>{
        'firstname': firstName,
        'lastname': lastName,
        'date_of_birth':
            '${_dateOfBirth!.year.toString().padLeft(4, '0')}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}',
        'address': _addressCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      };
      if (_selectedRole == 'doctor') {
        extraData.addAll({
          'doctor_type': _doctorType,
          'specialties': _doctorType == 'specialist'
              ? _doctorSpecialties.toList()
              : <String>[],
          'professional_info': _professionalInfoCtrl.text.trim(),
        });
      } else if (_selectedRole == 'patient') {
        final dateOfBirth = _dateOfBirth!;
        final today = DateTime.now();
        var age = today.year - dateOfBirth.year;
        if (today.month < dateOfBirth.month ||
            (today.month == dateOfBirth.month && today.day < dateOfBirth.day)) {
          age--;
        }
        final disease = _patientConditions.first;
        extraData.addAll({
          'sex': _patientSex,
          'conditions': _patientConditions.toList(),
          'age': age,
          'disease': disease,
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
      _showError(
        e.message == 'email_already_registered_login' ||
                e.message == 'email_registered_login_retry'
            ? AppTexts.of(context, e.message)
            : e.message,
      );
    } catch (_) {
      _showError(AppTexts.of(context, 'connection_failed'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: MediGoTheme.heartRed),
  );

  Future<void> _selectDateOfBirth() async {
    final today = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate:
          _dateOfBirth ?? DateTime(today.year - 30, today.month, today.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(today.year, today.month, today.day),
    );
    if (selected != null && mounted) {
      setState(() => _dateOfBirth = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    String t(String key) => AppTexts.of(context, key);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              MediGoTheme.backgroundStart,
              MediGoTheme.backgroundEnd,
              MediGoTheme.cardSurface,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: MediGoTheme.cardSurface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: MediGoTheme.cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: MediGoTheme.primaryBlue.withValues(alpha: 0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 110,
                        height: 110,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primary, MediGoTheme.darkNavy],
                          ),
                          borderRadius: BorderRadius.circular(28),
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
                    Text(
                      t('register_title'),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: MediGoTheme.darkNavy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t('register_subtitle'),
                      style: const TextStyle(
                        color: MediGoTheme.secondaryGrey,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: MediGoTheme.backgroundStart,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: MediGoTheme.borderSoft),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _selectedRole == 'doctor'
                                ? Icons.medical_services_outlined
                                : _selectedRole == 'patient'
                                ? Icons.person_outline
                                : _selectedRole == 'labo'
                                ? Icons.biotech
                                : Icons.local_pharmacy,
                            color: primary,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${t('registering_as')} ${t(_selectedRole)}',
                            style: const TextStyle(
                              color: MediGoTheme.darkNavy,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _firstNameCtrl,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: t('first_name'),
                              prefixIcon: const Icon(Icons.person_outline),
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? t('required')
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _lastNameCtrl,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: t('last_name'),
                              prefixIcon: const Icon(Icons.person_outline),
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? t('required')
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FormField<DateTime>(
                      validator: (_) => _dateOfBirth == null
                          ? t('date_of_birth_required')
                          : null,
                      builder: (field) => InkWell(
                        onTap: _selectDateOfBirth,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: t('date_of_birth'),
                            prefixIcon: const Icon(Icons.cake_outlined),
                            errorText: field.errorText,
                          ),
                          child: Text(
                            _dateOfBirth == null
                                ? t('select_date')
                                : '${_dateOfBirth!.day.toString().padLeft(2, '0')}/${_dateOfBirth!.month.toString().padLeft(2, '0')}/${_dateOfBirth!.year}',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: t('address'),
                        prefixIcon: const Icon(Icons.location_on_outlined),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? t('required')
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: t('mobile_phone'),
                        prefixIcon: const Icon(Icons.phone_outlined),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? t('required')
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: t('email'),
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? t('invalid_email')
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: t('password'),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 6)
                          ? t('password_too_short')
                          : null,
                    ),
                    const SizedBox(height: 24),
                    const SizedBox(height: 16),
                    if (_selectedRole == 'doctor') ...[
                      Text(
                        t('doctor_type'),
                        style: const TextStyle(
                          color: MediGoTheme.secondaryGrey,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: [
                          ButtonSegment(
                            value: 'general_practitioner',
                            label: Text(t('general_practitioner')),
                          ),
                          ButtonSegment(
                            value: 'specialist',
                            label: Text(t('specialist')),
                          ),
                        ],
                        selected: {_doctorType},
                        onSelectionChanged: (values) => setState(() {
                          _doctorType = values.first;
                          if (_doctorType == 'general_practitioner') {
                            _doctorSpecialties.clear();
                          }
                        }),
                      ),
                      if (_doctorType == 'specialist') ...[
                        const SizedBox(height: 12),
                        Text(
                          t('doctor_specialty'),
                          style: const TextStyle(
                            color: MediGoTheme.secondaryGrey,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: registrationSpecialties.map((specialty) {
                            final selected = _doctorSpecialties.contains(
                              specialty,
                            );
                            return ChoiceChip(
                              label: Text(
                                specialty == 'diabetology'
                                    ? t('diabetes_specialty')
                                    : t('thyroid_diseases'),
                              ),
                              selected: selected,
                              onSelected: (value) {
                                setState(() {
                                  _doctorSpecialties.clear();
                                  if (value) {
                                    _doctorSpecialties.add(specialty);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        if (_doctorSpecialties.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              t('select_specialty'),
                              style: const TextStyle(
                                color: MediGoTheme.heartRed,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _professionalInfoCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: t('professional_information'),
                          prefixIcon: const Icon(Icons.badge_outlined),
                        ),
                      ),
                    ],
                    if (_selectedRole == 'patient') ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t('sex'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: MediGoTheme.secondaryGrey,
                            ),
                          ),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'M', label: Text('♂ M')),
                              ButtonSegment(value: 'F', label: Text('♀ F')),
                            ],
                            selected: {_patientSex},
                            onSelectionChanged: (values) =>
                                setState(() => _patientSex = values.first),
                            style: SegmentedButton.styleFrom(
                              selectedBackgroundColor: primary,
                              selectedForegroundColor: onPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        t('medical_conditions'),
                        style: const TextStyle(
                          color: MediGoTheme.secondaryGrey,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: allDiseases.map((condition) {
                          final selected = _patientConditions.contains(
                            condition,
                          );
                          return FilterChip(
                            label: Text(diseaseLabel(condition, context)),
                            selected: selected,
                            onSelected: (value) => setState(() {
                              if (value) {
                                _patientConditions.add(condition);
                              } else {
                                _patientConditions.remove(condition);
                              }
                            }),
                          );
                        }).toList(),
                      ),
                      if (_patientConditions.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            t('select_disease'),
                            style: const TextStyle(
                              color: MediGoTheme.heartRed,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 32),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _acceptedTerms,
                          onChanged: (v) =>
                              setState(() => _acceptedTerms = v ?? false),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 11),
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  color: MediGoTheme.darkNavy,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                                children: [
                                  const TextSpan(text: 'I accept the '),
                                  TextSpan(
                                    text: t('open_terms'),
                                    style: const TextStyle(
                                      color: MediGoTheme.primaryBlue,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const LegalDocumentScreen(
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
                                      color: MediGoTheme.primaryBlue,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const LegalDocumentScreen(
                                                  type:
                                                      LegalDocumentType.privacy,
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
                    SizedBox(
                      height: 52,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: MediGoTheme.cardSurface,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(t('create_account')),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${t('already_have_account')} ',
                          style: const TextStyle(
                            color: MediGoTheme.secondaryGrey,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Text(
                            t('login_link'),
                            style: const TextStyle(
                              color: MediGoTheme.primaryBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
