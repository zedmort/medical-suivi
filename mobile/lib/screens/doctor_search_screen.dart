import 'package:flutter/material.dart';
import '../constants/medical_taxonomy.dart';
import '../l10n/app_texts.dart';
import '../services/api_service.dart';
import '../theme/medi_go_theme.dart';

class DoctorSearchScreen extends StatefulWidget {
  const DoctorSearchScreen({super.key});

  @override
  State<DoctorSearchScreen> createState() => _DoctorSearchScreenState();
}

class _DoctorSearchScreenState extends State<DoctorSearchScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _doctors = [];
  int? _currentDoctorId;
  String? _currentDoctorName;
  String _specialty = '';
  String _doctorType = '';
  bool _loading = true;
  bool _loadingRecommendations = true;
  bool _hasConditionMatch = false;
  int? _savingDoctorId;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
    _loadCurrentDoctor();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _text(String key) => AppTexts.of(context, key);

  Future<void> _loadRecommendations() async {
    setState(() {
      _loadingRecommendations = true;
      _loading = true;
    });
    try {
      final response = await ApiService.get('/patients/me/doctors');
      if (!mounted) return;
      setState(() {
        _doctors = List<Map<String, dynamic>>.from(response['doctors'] ?? []);
        _hasConditionMatch = response['hasConditionMatch'] == true;
      });
    } on ApiException catch (error) {
      _showMessage(error.message, isError: true);
    } catch (error) {
      _showMessage(error.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingRecommendations = false;
        });
      }
    }
  }

  Future<void> _loadCurrentDoctor() async {
    try {
      final response = await ApiService.get('/users/me');
      if (!mounted) return;
      final user = Map<String, dynamic>.from(response['user'] ?? {});
      final patient = Map<String, dynamic>.from(user['patient'] ?? {});
      setState(() {
        _currentDoctorId = int.tryParse(patient['doctor_id']?.toString() ?? '');
        _currentDoctorName = patient['doctor_name']?.toString();
      });
    } on ApiException catch (error) {
      _showMessage(error.message, isError: true);
    } catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _searchDoctors() async {
    setState(() => _loading = true);
    try {
      final query = Uri(
        queryParameters: {
          'search': _searchController.text.trim(),
          if (_specialty.isNotEmpty) 'specialty': _specialty,
          if (_doctorType.isNotEmpty) 'doctor_type': _doctorType,
        },
      ).query;
      final response = await ApiService.get('/users/doctors?$query');
      if (!mounted) return;
      setState(() {
        _doctors = List<Map<String, dynamic>>.from(response['doctors'] ?? []);
        _loadingRecommendations = false;
      });
    } on ApiException catch (error) {
      _showMessage(error.message, isError: true);
    } catch (error) {
      _showMessage(error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectDoctor(Map<String, dynamic> doctor) async {
    final id = int.tryParse(doctor['id']?.toString() ?? '');
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_text('confirm_doctor')),
        content: Text(
          '${_text('select_doctor_confirmation')} ${doctor['name'] ?? ''}?\n\n${_text('recommendation_not_diagnosis')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_text('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_text('confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _savingDoctorId = id);
    try {
      await ApiService.put('/patients/me/doctor', {'doctor_id': id});
      if (!mounted) return;
      setState(() {
        _currentDoctorId = id;
        _currentDoctorName = doctor['name']?.toString();
      });
      _showMessage(_text('doctor_selected'));
    } on ApiException catch (error) {
      _showMessage(error.message, isError: true);
    } catch (error) {
      _showMessage(error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _savingDoctorId = null);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
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
    return Scaffold(
      appBar: AppBar(title: Text(_text('find_doctor'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_currentDoctorName != null &&
                    _currentDoctorName!.isNotEmpty) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.medical_services_outlined,
                      color: MediGoTheme.primaryBlue,
                    ),
                    title: Text(_text('current_doctor')),
                    subtitle: Text(_currentDoctorName!),
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _searchDoctors(),
                  decoration: InputDecoration(
                    labelText: _text('search_doctors'),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      onPressed: _searchDoctors,
                      icon: const Icon(Icons.arrow_forward),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _doctorType.isEmpty ? null : _doctorType,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: _text('doctor_type'),
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('All')),
                    DropdownMenuItem(
                      value: 'general_practitioner',
                      child: Text(_text('general_practitioner')),
                    ),
                    DropdownMenuItem(
                      value: 'specialist',
                      child: Text(_text('specialist')),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _doctorType = value ?? '');
                    _searchDoctors();
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _specialty.isEmpty ? null : _specialty,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: _text('filter_specialty'),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: Text(_text('all_specialties')),
                    ),
                    ...specialties.map(
                      (specialty) => DropdownMenuItem(
                        value: specialty,
                        child: Text(specialtyLabel(specialty, context)),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _specialty = value ?? '');
                    _searchDoctors();
                  },
                ),
                if (!_loadingRecommendations && _searchController.text.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      _hasConditionMatch
                          ? _text('condition_recommendation_notice')
                          : _text('no_specialty_match_notice'),
                      style: const TextStyle(
                        color: MediGoTheme.secondaryGrey,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _doctors.isEmpty
                ? Center(
                    child: Text(
                      _text('no_doctors_found'),
                      textAlign: TextAlign.center,
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadRecommendations,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: _doctors.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, index) => _doctorCard(_doctors[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _doctorCard(Map<String, dynamic> doctor) {
    final id = int.tryParse(doctor['id']?.toString() ?? '');
    final selected = id != null && id == _currentDoctorId;
    final doctorSpecialties = List<String>.from(
      doctor['specialties'] ?? const [],
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: MediGoTheme.primaryBlue,
                  child: Icon(Icons.medical_services, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    doctor['name']?.toString() ?? '',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: MediGoTheme.darkNavy,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              doctor['doctor_type'] == 'general_practitioner'
                  ? _text('general_practitioner')
                  : _text('specialist'),
              style: const TextStyle(color: MediGoTheme.secondaryGrey),
            ),
            if (doctorSpecialties.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  doctorSpecialties
                      .map((item) => specialtyLabel(item, context))
                      .join(' • '),
                ),
              ),
            if ((doctor['professional_info'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(doctor['professional_info'].toString()),
              ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: selected || _savingDoctorId == id
                    ? null
                    : () => _selectDoctor(doctor),
                child: _savingDoctorId == id
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        selected
                            ? _text('current_doctor')
                            : _text('choose_doctor'),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
