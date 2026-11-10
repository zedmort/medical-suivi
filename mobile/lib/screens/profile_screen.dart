import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/medical_taxonomy.dart';
import '../l10n/app_texts.dart';
import '../services/api_service.dart';
import '../theme/medi_go_theme.dart';
import '../providers/app_settings_provider.dart';
import '../providers/auth_provider.dart';
import 'legal_document_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _professionalInfo = TextEditingController();
  DateTime? _dateOfBirth;
  String _doctorType = 'specialist';
  String _sex = 'M';
  final Set<String> _specialties = {};
  final Set<String> _conditions = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _address.dispose();
    _phone.dispose();
    _professionalInfo.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final response = await ApiService.get('/users/me');
      if (!mounted) return;
      final user = Map<String, dynamic>.from(response['user'] ?? {});
      final patient = Map<String, dynamic>.from(user['patient'] ?? {});
      final parts = (user['name']?.toString() ?? '').trim().split(' ');
      setState(() {
        _firstName.text =
            user['firstname']?.toString() ?? (parts.isEmpty ? '' : parts.first);
        _lastName.text =
            user['lastname']?.toString() ??
            (parts.length > 1 ? parts.sublist(1).join(' ') : '');
        _address.text = user['address']?.toString() ?? '';
        _phone.text = user['phone']?.toString() ?? '';
        _professionalInfo.text = user['professional_info']?.toString() ?? '';
        _dateOfBirth = DateTime.tryParse(
          user['date_of_birth']?.toString() ?? '',
        );
        _doctorType = user['doctor_type']?.toString() ?? 'general_practitioner';
        _sex = patient['sex']?.toString() ?? 'M';
        _specialties
          ..clear()
          ..addAll(List<String>.from(user['specialties'] ?? []));
        if (_specialties.isEmpty &&
            (user['specialty'] ?? '').toString().isNotEmpty) {
          _specialties.add(user['specialty'].toString());
        }
        _conditions
          ..clear()
          ..addAll(List<String>.from(patient['conditions'] ?? []));
        if (_conditions.isEmpty &&
            (patient['disease'] ?? '').toString().isNotEmpty) {
          _conditions.add(patient['disease'].toString());
        }
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage(error.message, isError: true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _selectDateOfBirth() async {
    final today = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(today.year - 30),
      firstDate: DateTime(1900),
      lastDate: DateTime(today.year, today.month, today.day),
    );
    if (selected != null && mounted) {
      setState(() => _dateOfBirth = selected);
    }
  }

  Future<void> _saveProfile(String role) async {
    if (_dateOfBirth == null ||
        _firstName.text.trim().isEmpty ||
        _lastName.text.trim().isEmpty ||
        _address.text.trim().isEmpty ||
        _phone.text.trim().isEmpty) {
      _showMessage(
        AppTexts.of(context, 'complete_profile_fields'),
        isError: true,
      );
      return;
    }
    if (role == 'doctor' &&
        (_doctorType == 'specialist' &&
            (_specialties.isEmpty || _specialties.length > 3))) {
      _showMessage(AppTexts.of(context, 'select_specialty'), isError: true);
      return;
    }
    if (role == 'patient' && _conditions.isEmpty) {
      _showMessage(AppTexts.of(context, 'select_disease'), isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'firstname': _firstName.text.trim(),
        'lastname': _lastName.text.trim(),
        'date_of_birth':
            '${_dateOfBirth!.year.toString().padLeft(4, '0')}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}',
        'address': _address.text.trim(),
        'phone': _phone.text.trim(),
      };
      if (role == 'doctor') {
        payload.addAll({
          'doctor_type': _doctorType,
          'specialties': _doctorType == 'specialist'
              ? _specialties.toList()
              : <String>[],
          'professional_info': _professionalInfo.text.trim(),
        });
      } else if (role == 'patient') {
        payload.addAll({'sex': _sex, 'conditions': _conditions.toList()});
      }
      await ApiService.put('/users/me', payload);
      if (!mounted) return;
      _showMessage(AppTexts.of(context, 'settings_saved'));
    } on ApiException catch (error) {
      _showMessage(error.message, isError: true);
    } catch (error) {
      _showMessage(error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? MediGoTheme.heartRed
            : MediGoTheme.successGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<AppSettingsProvider>();
    String t(String key) => AppTexts.of(context, key);

    return Scaffold(
      appBar: AppBar(title: Text(t('profile'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0755C9), Color(0xFF0C2454)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white24,
                        child: Icon(
                          Icons.person,
                          size: 30,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.name ?? 'User',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              auth.role == 'doctor' &&
                                      (auth.specialty?.isNotEmpty ?? false)
                                  ? '${t('user_role')}: ${t(auth.role ?? '')}\n${t('doctor_specialty')}: ${_specialties.map((s) => specialtyLabel(s, context)).join(', ')}'
                                  : '${t('user_role')}: ${t(auth.role ?? '')}',
                              style: const TextStyle(
                                color: Colors.white70,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _profileForm(context, auth.role ?? 'patient'),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.palette_outlined,
                          color: Color(0xFF0755C9),
                        ),
                        title: Text(t('appearance')),
                      ),
                      SwitchListTile(
                        secondary: const Icon(
                          Icons.dark_mode_outlined,
                          color: Color(0xFF0C2454),
                        ),
                        title: Text(t('dark_mode')),
                        value: settings.themeMode == ThemeMode.dark,
                        onChanged: (isDark) {
                          settings.setThemeMode(
                            isDark ? ThemeMode.dark : ThemeMode.light,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(t('settings_saved'))),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.language_outlined,
                          color: Color(0xFF0755C9),
                        ),
                        title: Text(t('language')),
                        trailing: DropdownButton<String>(
                          value: settings.locale.languageCode,
                          underline: const SizedBox.shrink(),
                          onChanged: (code) {
                            if (code == null) return;
                            settings.setLocale(Locale(code));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(t('settings_saved'))),
                            );
                          },
                          items: [
                            DropdownMenuItem(
                              value: 'en',
                              child: Text(t('language_english')),
                            ),
                            DropdownMenuItem(
                              value: 'fr',
                              child: Text(t('language_french')),
                            ),
                            DropdownMenuItem(
                              value: 'ar',
                              child: Text(t('language_arabic')),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.gavel_outlined,
                          color: Color(0xFF0755C9),
                        ),
                        title: Text(t('terms')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
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
                      const Divider(height: 0),
                      ListTile(
                        leading: const Icon(
                          Icons.privacy_tip_outlined,
                          color: Color(0xFF0755C9),
                        ),
                        title: Text(t('privacy')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
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
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _profileForm(BuildContext context, String role) {
    String t(String key) => AppTexts.of(context, key);
    final isDoctor = role == 'doctor';
    final isPatient = role == 'patient';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t('personal_information'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: MediGoTheme.darkNavy,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _firstName,
              decoration: InputDecoration(labelText: t('first_name')),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _lastName,
              decoration: InputDecoration(labelText: t('last_name')),
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cake_outlined),
              title: Text(t('date_of_birth')),
              subtitle: Text(
                _dateOfBirth == null
                    ? t('select_date')
                    : '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}',
              ),
              onTap: _selectDateOfBirth,
            ),
            TextFormField(
              controller: _address,
              decoration: InputDecoration(labelText: t('address')),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: t('mobile_phone')),
            ),
            if (isDoctor) ...[
              const SizedBox(height: 14),
              Text(t('doctor_type')),
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
                    _specialties.clear();
                  }
                }),
              ),
              if (_doctorType == 'specialist') ...[
                const SizedBox(height: 10),
                Text('${t('doctor_specialty')} (${_specialties.length}/3)'),
                Wrap(
                  spacing: 6,
                  children: specialties.map((specialty) {
                    final selected = _specialties.contains(specialty);
                    return FilterChip(
                      label: Text(specialtyLabel(specialty, context)),
                      selected: selected,
                      onSelected: (value) => setState(() {
                        if (!value) {
                          _specialties.remove(specialty);
                        } else if (_specialties.length < 3) {
                          _specialties.add(specialty);
                        } else {
                          _showMessage(
                            t('max_three_specialties'),
                            isError: true,
                          );
                        }
                      }),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 10),
              TextFormField(
                controller: _professionalInfo,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: t('professional_information'),
                ),
              ),
            ],
            if (isPatient) ...[
              const SizedBox(height: 14),
              Text(t('sex')),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'M', label: Text('♂ M')),
                  ButtonSegment(value: 'F', label: Text('♀ F')),
                ],
                selected: {_sex},
                onSelectionChanged: (values) =>
                    setState(() => _sex = values.first),
              ),
              const SizedBox(height: 10),
              Text(t('medical_conditions')),
              Wrap(
                spacing: 6,
                children: allDiseases.map((condition) {
                  final selected = _conditions.contains(condition);
                  return FilterChip(
                    label: Text(diseaseLabel(condition, context)),
                    selected: selected,
                    onSelected: (value) => setState(() {
                      if (value) {
                        _conditions.add(condition);
                      } else {
                        _conditions.remove(condition);
                      }
                    }),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : () => _saveProfile(role),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(t('save')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
