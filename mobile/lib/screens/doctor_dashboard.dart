import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/medical_taxonomy.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../l10n/app_texts.dart';
import '../theme/medi_go_theme.dart';
import '../widgets/dashboard_shell.dart';

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});
  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  // Data
  List<Map<String, dynamic>> _patients = [];
  List<Map<String, dynamic>> _labos = [];
  List<Map<String, dynamic>> _pharmacies = [];
  List<Map<String, dynamic>> _analyses = [];
  List<Map<String, dynamic>> _prescriptions = [];
  List<Map<String, dynamic>> _consultations = [];
  final TextEditingController _patientSearchController =
      TextEditingController();

  bool _loadingPatients = true;
  bool _loadingAnalyses = true;
  bool _loadingPrescriptions = true;
  bool _loadingConsultations = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _fetchAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _patientSearchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    await Future.wait([
      _fetchData(),
      _fetchAnalyses(),
      _fetchPrescriptions(),
      _fetchConsultations(),
    ]);
  }

  Future<void> _fetchData() async {
    setState(() => _loadingPatients = true);
    try {
      final results = await Future.wait([
        ApiService.get('/patients'),
        ApiService.get('/users?role=labo'),
        ApiService.get('/users?role=pharmacy'),
      ]);
      if (!mounted) return;
      setState(() {
        _patients = List<Map<String, dynamic>>.from(
          results[0]['patients'] ?? [],
        );
        _labos = List<Map<String, dynamic>>.from(results[1]['users'] ?? []);
        _pharmacies = List<Map<String, dynamic>>.from(
          results[2]['users'] ?? [],
        );
      });
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loadingPatients = false);
    }
  }

  Future<void> _fetchAnalyses() async {
    setState(() => _loadingAnalyses = true);
    try {
      final res = await ApiService.get('/analysis/my-requests');
      if (!mounted) return;
      setState(
        () =>
            _analyses = List<Map<String, dynamic>>.from(res['requests'] ?? []),
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loadingAnalyses = false);
    }
  }

  Future<void> _fetchPrescriptions() async {
    setState(() => _loadingPrescriptions = true);
    try {
      final res = await ApiService.get('/prescriptions');
      if (!mounted) return;
      setState(
        () => _prescriptions = List<Map<String, dynamic>>.from(
          res['prescriptions'] ?? [],
        ),
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loadingPrescriptions = false);
    }
  }

  Future<void> _fetchConsultations() async {
    setState(() => _loadingConsultations = true);
    try {
      final response = await ApiService.get('/consultations/doctor');
      if (!mounted) return;
      setState(() {
        _consultations = List<Map<String, dynamic>>.from(
          response['consultations'] ?? [],
        );
      });
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _loadingConsultations = false);
    }
  }

  Future<void> _updateConsultationStatus(int id, String status) async {
    try {
      await ApiService.patch('/consultations/doctor/$id/status', {
        'status': status,
      });
      _showSuccess(
        status == 'completed'
            ? 'Consultation terminée.'
            : 'Consultation prise en charge.',
      );
      await _fetchConsultations();
    } catch (error) {
      _showError(error.toString());
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: MediGoTheme.heartRed),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: MediGoTheme.successGreen),
    );
  }

  Widget _dialogHeader({
    required IconData icon,
    required String title,
    Color? color,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (color ?? MediGoTheme.primaryBlue).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color ?? MediGoTheme.primaryBlue),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: MediGoTheme.darkNavy,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _dialogInputDecoration(String label, {IconData? prefixIcon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 18),
      filled: true,
      fillColor: const Color(0xFFF8FAFF),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: MediGoTheme.borderSoft),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: MediGoTheme.borderSoft),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: MediGoTheme.primaryBlue,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: MediGoTheme.heartRed),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: MediGoTheme.heartRed, width: 1.5),
      ),
    );
  }

  // ── Create Analysis Dialog ────────────────────────────────────────────────
  void _showCreateAnalysisDialog() {
    int? patientId;
    int? laboId;
    final notesCtrl = TextEditingController();
    final loading = ValueNotifier(false);
    String? selectedFilePath;
    String? selectedFileName;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: StatefulBuilder(
              builder: (ctx2, setS) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _dialogHeader(
                    icon: Icons.biotech_outlined,
                    title: 'Demande d\'analyse',
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    decoration: _dialogInputDecoration(
                      'Sélectionner un patient',
                      prefixIcon: Icons.person_outline,
                    ),
                    items: _patients
                        .map(
                          (p) => DropdownMenuItem<int>(
                            value: p['id'] as int,
                            child: Text('${p['firstname']} ${p['lastname']}'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => patientId = v,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    decoration: _dialogInputDecoration(
                      'Sélectionner un laboratoire',
                      prefixIcon: Icons.local_hospital_outlined,
                    ),
                    items: _labos
                        .map(
                          (l) => DropdownMenuItem<int>(
                            value: l['id'] as int,
                            child: Text(l['name'].toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => laboId = v,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesCtrl,
                    maxLines: 4,
                    minLines: 3,
                    decoration: _dialogInputDecoration(
                      'Notes / Analyses demandées',
                      prefixIcon: Icons.notes_outlined,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: MediGoTheme.borderSoft),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            selectedFileName ?? 'Aucun fichier joint',
                            style: const TextStyle(
                              fontSize: 12,
                              color: MediGoTheme.secondaryGrey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: TextButton.icon(
                            onPressed: () async {
                              final picked = await FilePicker.platform
                                  .pickFiles(
                                    type: FileType.custom,
                                    allowedExtensions: [
                                      'pdf',
                                      'jpg',
                                      'jpeg',
                                      'png',
                                    ],
                                  );
                              if (picked == null ||
                                  picked.files.single.path == null) {
                                return;
                              }
                              setS(() {
                                selectedFilePath = picked.files.single.path!;
                                selectedFileName = picked.files.single.name;
                              });
                            },
                            icon: const Icon(Icons.attach_file),
                            label: const Text('Joindre'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Annuler'),
                      ),
                      const SizedBox(width: 8),
                      ValueListenableBuilder<bool>(
                        valueListenable: loading,
                        builder: (_, isLoading, __) => ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  if (patientId == null || laboId == null) {
                                    _showError(
                                      'Sélectionnez patient et laboratoire.',
                                    );
                                    return;
                                  }
                                  loading.value = true;
                                  try {
                                    if (selectedFilePath != null) {
                                      await ApiService.uploadFile(
                                        '/analysis/create',
                                        selectedFilePath!,
                                        {
                                          'patient_id': patientId.toString(),
                                          'labo_id': laboId.toString(),
                                          'notes': notesCtrl.text.trim(),
                                        },
                                      );
                                    } else {
                                      await ApiService.post(
                                        '/analysis/create',
                                        {
                                          'patient_id': patientId,
                                          'labo_id': laboId,
                                          'notes': notesCtrl.text.trim(),
                                        },
                                      );
                                    }
                                    if (!ctx.mounted) return;
                                    Navigator.pop(ctx);
                                    _showSuccess(
                                      'Demande envoyée au laboratoire!',
                                    );
                                    _fetchAnalyses();
                                  } catch (e) {
                                    _showError(e.toString());
                                  } finally {
                                    loading.value = false;
                                  }
                                },
                          child: isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: MediGoTheme.cardSurface,
                                  ),
                                )
                              : const Text('Envoyer au labo'),
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

  // ── Create Prescription Dialog ────────────────────────────────────────────
  void _showCreatePrescriptionDialog() {
    int? patientId;
    int? pharmacyId;
    final notesCtrl = TextEditingController();
    final loading = ValueNotifier(false);
    String? selectedFilePath;
    String? selectedFileName;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: StatefulBuilder(
              builder: (ctx2, setS) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _dialogHeader(
                    icon: Icons.receipt_long,
                    title: 'Nouvelle ordonnance',
                    color: MediGoTheme.successGreen,
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    decoration: _dialogInputDecoration(
                      'Sélectionner un patient',
                      prefixIcon: Icons.person_outline,
                    ),
                    items: _patients
                        .map(
                          (p) => DropdownMenuItem<int>(
                            value: p['id'] as int,
                            child: Text('${p['firstname']} ${p['lastname']}'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => patientId = v,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    decoration: _dialogInputDecoration(
                      'Sélectionner une pharmacie',
                      prefixIcon: Icons.local_pharmacy_outlined,
                    ),
                    items: _pharmacies
                        .map(
                          (p) => DropdownMenuItem<int>(
                            value: p['id'] as int,
                            child: Text(p['name'].toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => pharmacyId = v,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesCtrl,
                    maxLines: 4,
                    minLines: 3,
                    decoration: _dialogInputDecoration(
                      'Médicaments / Instructions',
                      prefixIcon: Icons.medication_outlined,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: MediGoTheme.borderSoft),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            selectedFileName ?? 'Aucun fichier joint',
                            style: const TextStyle(
                              fontSize: 12,
                              color: MediGoTheme.secondaryGrey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: TextButton.icon(
                            onPressed: () async {
                              final picked = await FilePicker.platform
                                  .pickFiles(
                                    type: FileType.custom,
                                    allowedExtensions: [
                                      'pdf',
                                      'jpg',
                                      'jpeg',
                                      'png',
                                    ],
                                  );
                              if (picked == null ||
                                  picked.files.single.path == null) {
                                return;
                              }
                              setS(() {
                                selectedFilePath = picked.files.single.path!;
                                selectedFileName = picked.files.single.name;
                              });
                            },
                            icon: const Icon(Icons.attach_file),
                            label: const Text('Joindre'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Annuler'),
                      ),
                      const SizedBox(width: 8),
                      ValueListenableBuilder<bool>(
                        valueListenable: loading,
                        builder: (_, isLoading, __) => ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  if (patientId == null || pharmacyId == null) {
                                    _showError(
                                      'Sélectionnez patient et pharmacie.',
                                    );
                                    return;
                                  }
                                  loading.value = true;
                                  try {
                                    if (selectedFilePath != null) {
                                      await ApiService.uploadFile(
                                        '/prescriptions/create',
                                        selectedFilePath!,
                                        {
                                          'patient_id': patientId.toString(),
                                          'pharmacy_id': pharmacyId.toString(),
                                          'notes': notesCtrl.text.trim(),
                                        },
                                      );
                                    } else {
                                      await ApiService.post(
                                        '/prescriptions/create',
                                        {
                                          'patient_id': patientId,
                                          'pharmacy_id': pharmacyId,
                                          'notes': notesCtrl.text.trim(),
                                        },
                                      );
                                    }
                                    if (!ctx.mounted) return;
                                    Navigator.pop(ctx);
                                    _showSuccess(
                                      'Ordonnance envoyée à la pharmacie!',
                                    );
                                    _fetchPrescriptions();
                                  } catch (e) {
                                    _showError(e.toString());
                                  } finally {
                                    loading.value = false;
                                  }
                                },
                          child: isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: MediGoTheme.cardSurface,
                                  ),
                                )
                              : const Text('Envoyer à la pharmacie'),
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

  // ── Add Patient Dialog ────────────────────────────────────────────────────
  Future<void> _showAddPatientDialog() async {
    final loading = ValueNotifier(false);
    List<Map<String, dynamic>> availablePatients = [];

    try {
      final res = await ApiService.get('/patients/available');
      availablePatients = List<Map<String, dynamic>>.from(
        res['patients'] ?? [],
      );
    } catch (e) {
      _showError(e.toString());
      return;
    }

    if (!mounted) return;

    int? selectedPatientId = availablePatients.isNotEmpty
        ? availablePatients.first['id'] as int
        : null;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: StatefulBuilder(
              builder: (ctx2, setS) {
                Map<String, dynamic>? selectedPatient;
                for (final patient in availablePatients) {
                  if (patient['id'] == selectedPatientId) {
                    selectedPatient = patient;
                    break;
                  }
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _dialogHeader(
                      icon: Icons.person_add_alt_1,
                      title: 'Ajouter un patient',
                    ),
                    const SizedBox(height: 18),
                    if (availablePatients.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Aucun patient disponible pour votre spécialité. Le patient doit créer un compte d\'abord.',
                          style: TextStyle(color: MediGoTheme.secondaryGrey),
                        ),
                      )
                    else ...[
                      DropdownButtonFormField<int>(
                        initialValue: selectedPatientId,
                        isExpanded: true,
                        decoration: _dialogInputDecoration(
                          'Patient (compte existant)',
                          prefixIcon: Icons.person_outline,
                        ),
                        items: availablePatients
                            .map(
                              (p) => DropdownMenuItem<int>(
                                value: p['id'] as int,
                                child: Text(
                                  '${p['firstname']} ${p['lastname']}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setS(() => selectedPatientId = v),
                      ),
                      const SizedBox(height: 16),
                      if (selectedPatient != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F9FF),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: MediGoTheme.borderSoft),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _infoRow(
                                Icons.email_outlined,
                                selectedPatient['email']?.toString() ?? '—',
                              ),
                              _infoRow(
                                Icons.medical_information_outlined,
                                diseaseLabel(
                                  selectedPatient['disease']?.toString() ?? '—',
                                  context,
                                ),
                                color: MediGoTheme.heartRed,
                              ),
                              _infoRow(
                                Icons.cake_outlined,
                                '${selectedPatient['age']} ans',
                              ),
                              _infoRow(
                                Icons.location_on_outlined,
                                selectedPatient['address']?.toString() ?? '—',
                              ),
                              if ((selectedPatient['phone'] ?? '')
                                  .toString()
                                  .isNotEmpty)
                                _infoRow(
                                  Icons.phone_outlined,
                                  selectedPatient['phone'].toString(),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Les informations viennent du compte patient. Aucune ressaisie nécessaire.',
                          style: TextStyle(
                            fontSize: 12,
                            color: MediGoTheme.secondaryGrey,
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Annuler'),
                        ),
                        const SizedBox(width: 8),
                        ValueListenableBuilder<bool>(
                          valueListenable: loading,
                          builder: (_, isLoading, __) => ElevatedButton(
                            onPressed: isLoading || selectedPatientId == null
                                ? null
                                : () async {
                                    loading.value = true;
                                    try {
                                      await ApiService.post('/patients', {
                                        'patient_id': selectedPatientId,
                                      });
                                      if (!ctx.mounted) return;
                                      Navigator.pop(ctx);
                                      _showSuccess(
                                        'Patient ajouté avec succès!',
                                      );
                                      _fetchData();
                                    } catch (e) {
                                      _showError(e.toString());
                                    } finally {
                                      loading.value = false;
                                    }
                                  },
                            child: isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: MediGoTheme.cardSurface,
                                    ),
                                  )
                                : const Text('Ajouter'),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    String t(String key) => AppTexts.of(context, key);
    return DashboardShell(
      title: t('dashboard'),
      subtitle: (auth.name ?? '').isNotEmpty ? 'Dr. ${auth.name!}' : '',
      placement: 'doctor_dashboard',
      onRefresh: _fetchAll,
      tabBar: TabBar(
        controller: _tabs,
        indicatorColor: MediGoTheme.cardSurface,
        labelColor: MediGoTheme.cardSurface,
        unselectedLabelColor: MediGoTheme.cardSurface.withValues(alpha: 0.6),
        tabs: [
          Tab(icon: const Icon(Icons.group), text: t('my_patients')),
          Tab(icon: const Icon(Icons.biotech), text: t('my_analyses')),
          Tab(icon: const Icon(Icons.receipt_long), text: t('my_prescriptions')),
          Tab(icon: const Icon(Icons.monitor_heart), text: t('my_consultations')),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildPatientTab(),
          _buildAnalysisTab(),
          _buildPrescriptionTab(),
          _buildConsultationTab(),
        ],
      ),
      fab: AnimatedBuilder(
        animation: _tabs,
        builder: (_, __) {
          if (_tabs.index == 0) {
            return FloatingActionButton.extended(
              onPressed: _showAddPatientDialog,
              backgroundColor: MediGoTheme.primaryBlue,
              icon: const Icon(
                Icons.person_add,
                color: MediGoTheme.cardSurface,
              ),
              label: const Text(
                'Nouveau patient',
                style: TextStyle(color: MediGoTheme.cardSurface),
              ),
            );
          }
          if (_tabs.index == 1 && !_loadingPatients) {
            return FloatingActionButton.extended(
              onPressed: _patients.isEmpty ? null : _showCreateAnalysisDialog,
              backgroundColor: MediGoTheme.primaryBlue,
              icon: const Icon(Icons.add, color: MediGoTheme.cardSurface),
              label: const Text(
                'Nouvelle analyse',
                style: TextStyle(color: MediGoTheme.cardSurface),
              ),
            );
          }
          if (_tabs.index == 2 && !_loadingPatients) {
            return FloatingActionButton.extended(
              onPressed: _patients.isEmpty
                  ? null
                  : _showCreatePrescriptionDialog,
              backgroundColor: MediGoTheme.successGreen,
              icon: const Icon(Icons.add, color: MediGoTheme.cardSurface),
              label: const Text(
                'Nouvelle ordonnance',
                style: TextStyle(color: MediGoTheme.cardSurface),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  // ── Patients Tab ───────────────────────────────────────────────────────────
  Widget _buildPatientTab() {
    if (_loadingPatients) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_patients.isEmpty) {
      return _empty(
        'Aucun patient enregistré.\nAppuyez sur + pour en ajouter.',
        Icons.group_outlined,
      );
    }
    final search = _patientSearchController.text.trim().toLowerCase();
    final patients = _patients.where((patient) {
      final searchable =
          '${patient['firstname'] ?? ''} ${patient['lastname'] ?? ''} ${patient['disease'] ?? ''}'
              .toLowerCase();
      return searchable.contains(search);
    }).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _patientSearchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Rechercher un patient ou une maladie',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _patientSearchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _patientSearchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
        ),
        Expanded(
          child: patients.isEmpty
              ? Center(
                  child: Text('Aucun patient ne correspond à la recherche.'),
                )
              : RefreshIndicator(
                  onRefresh: _fetchData,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                    itemCount: patients.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final p = patients[i];
                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _showPatientDetail(p),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: MediGoTheme.primaryBlue
                                      .withValues(alpha: 0.12),
                                  child: Text(
                                    (p['firstname'] as String? ?? '?')[0]
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      color: MediGoTheme.primaryBlue,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${p['firstname']} ${p['lastname']}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          _chip(
                                            '${p['age']} ans',
                                            MediGoTheme.primaryBlue,
                                          ),
                                          const SizedBox(width: 6),
                                          _chip(
                                            p['sex'] == 'M'
                                                ? '♂ Homme'
                                                : '♀ Femme',
                                            p['sex'] == 'M'
                                                ? MediGoTheme.primaryBlue
                                                : MediGoTheme.heartRed,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      _infoRow(
                                        Icons.medical_information_outlined,
                                        diseaseLabel(
                                          p['disease']?.toString() ?? '–',
                                          context,
                                        ),
                                        color: MediGoTheme.heartRed,
                                      ),
                                      if ((p['next_analysis_date'] ?? '')
                                          .toString()
                                          .isNotEmpty)
                                        _infoRow(
                                          Icons.event_outlined,
                                          'Prochaine analyse : ${_fmtDate(p['next_analysis_date']?.toString())}',
                                          color: MediGoTheme.deepBlueEnd,
                                        ),
                                      _infoRow(
                                        Icons.location_on_outlined,
                                        p['address']?.toString() ?? '–',
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: MediGoTheme.secondaryGrey,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  void _showPatientDetail(Map<String, dynamic> p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: MediGoTheme.borderSoft,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${p['firstname']} ${p['lastname']}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _detailRow(Icons.cake, 'Âge', '${p['age']} ans'),
            _detailRow(
              Icons.person,
              'Sexe',
              p['sex'] == 'M' ? 'Homme' : 'Femme',
            ),
            _detailRow(
              Icons.medical_information_outlined,
              'Maladie',
              diseaseLabel(p['disease']?.toString() ?? '–', context),
            ),
            if ((p['next_analysis_date'] ?? '').toString().isNotEmpty)
              _detailRow(
                Icons.event_outlined,
                'Prochaine analyse',
                _fmtDate(p['next_analysis_date']?.toString()),
              ),
            _detailRow(
              Icons.location_on_outlined,
              'Adresse',
              p['address']?.toString() ?? '–',
            ),
            if ((p['phone'] ?? '').toString().isNotEmpty)
              _detailRow(
                Icons.phone_outlined,
                'Téléphone',
                p['phone'].toString(),
              ),
            _detailRow(
              Icons.calendar_today,
              'Ajouté le',
              _fmtDate(p['created_at']?.toString()),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.event_outlined, size: 18),
                label: const Text('Planifier prochaine analyse'),
                onPressed: () {
                  Navigator.pop(context);
                  _showScheduleNextAnalysisDialog(p);
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.biotech, size: 18),
                    label: const Text('Analyse'),
                    onPressed: () {
                      Navigator.pop(context);
                      _showCreateAnalysisDialog();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MediGoTheme.successGreen,
                    ),
                    icon: const Icon(Icons.receipt_long, size: 18),
                    label: const Text('Ordonnance'),
                    onPressed: () {
                      Navigator.pop(context);
                      _showCreatePrescriptionDialog();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showScheduleNextAnalysisDialog(Map<String, dynamic> patient) {
    DateTime? selected;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setS) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.event_outlined, color: MediGoTheme.primaryBlue),
              SizedBox(width: 8),
              Text('Planifier analyse'),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${patient['firstname']} ${patient['lastname']}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final now = DateTime.now();
                      final initial = selected ?? now;
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: initial,
                        firstDate: DateTime(now.year - 1),
                        lastDate: DateTime(now.year + 10),
                      );
                      if (picked != null) {
                        setS(() => selected = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date de prochaine analyse',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        selected == null
                            ? 'Choisir une date'
                            : _fmtDate(selected!.toIso8601String()),
                        style: TextStyle(
                          color: selected == null
                              ? MediGoTheme.secondaryGrey
                              : MediGoTheme.darkNavy.withValues(alpha: 0.87),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await ApiService.put('/patients/${patient['id']}', {
                    'firstname': patient['firstname'],
                    'lastname': patient['lastname'],
                    'address': patient['address'],
                    'age': patient['age'],
                    'sex': patient['sex'],
                    'disease': patient['disease'],
                    'phone': patient['phone'],
                    'next_analysis_date': null,
                  });
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  _showSuccess('Date de prochaine analyse retirée.');
                  _fetchData();
                } catch (e) {
                  _showError(e.toString());
                }
              },
              child: const Text('Retirer date'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selected == null) {
                  _showError('Choisissez une date.');
                  return;
                }

                final nextDate =
                    '${selected!.year.toString().padLeft(4, '0')}-${selected!.month.toString().padLeft(2, '0')}-${selected!.day.toString().padLeft(2, '0')}';

                try {
                  await ApiService.put('/patients/${patient['id']}', {
                    'firstname': patient['firstname'],
                    'lastname': patient['lastname'],
                    'address': patient['address'],
                    'age': patient['age'],
                    'sex': patient['sex'],
                    'disease': patient['disease'],
                    'phone': patient['phone'],
                    'next_analysis_date': nextDate,
                  });
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  _showSuccess('Prochaine analyse planifiée.');
                  _fetchData();
                } catch (e) {
                  _showError(e.toString());
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Analysis Tab ──────────────────────────────────────────────────────────
  Widget _buildAnalysisTab() {
    if (_loadingAnalyses) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_analyses.isEmpty) {
      return _empty(
        'Aucune demande d\'analyse.\nAppuyez sur + pour en créer une.',
        Icons.biotech_outlined,
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchAnalyses,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
        itemCount: _analyses.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final a = _analyses[i];
          final status = a['status']?.toString() ?? 'pending';
          final done = status == 'completed';
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: done
                            ? MediGoTheme.greenChipBg
                            : MediGoTheme.orangeChipBg,
                        child: Icon(
                          done ? Icons.check_circle : Icons.hourglass_empty,
                          color: done
                              ? MediGoTheme.greenChipText
                              : MediGoTheme.orangeChipText,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${a['firstname'] ?? ''} ${a['lastname'] ?? ''}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      _statusChip(status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _infoRow(
                    Icons.medical_information_outlined,
                    a['disease']?.toString() ?? '–',
                    color: MediGoTheme.heartRed,
                  ),
                  _infoRow(
                    Icons.science_outlined,
                    'Labo : ${a['labo_name'] ?? '–'}',
                  ),
                  if ((a['notes'] ?? '').toString().isNotEmpty)
                    _infoRow(Icons.notes, a['notes'].toString()),
                  if (done && (a['result_url'] ?? '').toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if ((a['file_url'] ?? '').toString().isNotEmpty)
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _openFile(a['file_url'].toString()),
                              icon: const Icon(
                                Icons.description_outlined,
                                size: 16,
                              ),
                              label: const Text('Demande'),
                            ),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _openFile(a['result_url'].toString()),
                            icon: const Icon(Icons.attach_file, size: 16),
                            label: const Text('Résultat'),
                          ),
                        ],
                      ),
                    )
                  else if ((a['file_url'] ?? '').toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: OutlinedButton.icon(
                        onPressed: () => _openFile(a['file_url'].toString()),
                        icon: const Icon(Icons.description_outlined, size: 16),
                        label: const Text('Ouvrir la demande jointe'),
                      ),
                    ),
                  _infoRow(
                    Icons.calendar_today,
                    _fmtDate(a['created_at']?.toString()),
                    color: MediGoTheme.secondaryGrey,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Prescriptions Tab ─────────────────────────────────────────────────────
  Widget _buildPrescriptionTab() {
    if (_loadingPrescriptions) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_prescriptions.isEmpty) {
      return _empty(
        'Aucune ordonnance.\nAppuyez sur + pour en créer une.',
        Icons.receipt_long_outlined,
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchPrescriptions,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
        itemCount: _prescriptions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final p = _prescriptions[i];
          final status = p['status']?.toString() ?? 'pending';
          final done = status == 'dispensed';
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: done
                            ? MediGoTheme.greenChipBg
                            : MediGoTheme.primaryBlue.withValues(alpha: 0.14),
                        child: Icon(
                          done ? Icons.local_shipping : Icons.receipt_long,
                          color: done
                              ? MediGoTheme.greenChipText
                              : MediGoTheme.primaryBlue,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${p['firstname'] ?? ''} ${p['lastname'] ?? ''}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      _statusChip(status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _infoRow(
                    Icons.local_pharmacy_outlined,
                    'Pharmacie : ${p['pharmacy_name'] ?? '–'}',
                  ),
                  _infoRow(
                    Icons.location_on_outlined,
                    p['address']?.toString() ?? '–',
                  ),
                  if ((p['notes'] ?? '').toString().isNotEmpty)
                    _infoRow(Icons.medication_outlined, p['notes'].toString()),
                  if ((p['file_url'] ?? '').toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: OutlinedButton.icon(
                        onPressed: () => _openFile(p['file_url'].toString()),
                        icon: const Icon(Icons.description_outlined, size: 16),
                        label: const Text('Ouvrir ordonnance jointe'),
                      ),
                    ),
                  _infoRow(
                    Icons.calendar_today,
                    _fmtDate(p['created_at']?.toString()),
                    color: MediGoTheme.secondaryGrey,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildConsultationTab() {
    if (_loadingConsultations) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_consultations.isEmpty) {
      return _empty(
        'Aucune consultation payée assignée.',
        Icons.monitor_heart_outlined,
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchConsultations,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
        itemCount: _consultations.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, index) {
          final consultation = _consultations[index];
          final status = consultation['status']?.toString() ?? 'paid';
          final id = int.tryParse(consultation['id']?.toString() ?? '');
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.monitor_heart_outlined,
                        color: MediGoTheme.primaryBlue,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${consultation['firstname'] ?? ''} ${consultation['lastname'] ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      _statusChip(status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _infoRow(
                    Icons.notes_outlined,
                    consultation['symptoms']?.toString() ?? '',
                  ),
                  if ((consultation['notes'] ?? '').toString().isNotEmpty)
                    _infoRow(
                      Icons.info_outline,
                      consultation['notes'].toString(),
                    ),
                  _infoRow(
                    Icons.payments_outlined,
                    '${consultation['amount']} ${consultation['currency']} — DEMO',
                    color: MediGoTheme.successGreen,
                  ),
                  _infoRow(
                    Icons.calendar_today,
                    _fmtDate(consultation['created_at']?.toString()),
                  ),
                  if (id != null && status != 'completed')
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () => _updateConsultationStatus(
                          id,
                          status == 'paid' ? 'in_progress' : 'completed',
                        ),
                        icon: Icon(
                          status == 'paid'
                              ? Icons.play_arrow
                              : Icons.check_circle_outline,
                        ),
                        label: Text(
                          status == 'paid' ? 'Prendre en charge' : 'Terminer',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Shared Widgets ────────────────────────────────────────────────────────
  Widget _infoRow(IconData icon, String text, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Icon(icon, size: 14, color: color ?? MediGoTheme.secondaryGrey),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color ?? MediGoTheme.secondaryGrey,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withAlpha(20),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );

  Widget _detailRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: MediGoTheme.primaryBlue),
        const SizedBox(width: 10),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
      ],
    ),
  );

  Widget _empty(String msg, IconData icon) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 64, color: MediGoTheme.borderSoft),
        const SizedBox(height: 12),
        Text(
          msg,
          textAlign: TextAlign.center,
          style: const TextStyle(color: MediGoTheme.secondaryGrey),
        ),
      ],
    ),
  );

  Widget _statusChip(String status) {
    final (label, color) = switch (status) {
      'completed' => ('Terminé', MediGoTheme.successGreen),
      'dispensed' => ('Livré', MediGoTheme.successGreen),
      'pending' => ('En attente', MediGoTheme.warningOrange),
      _ => (status, MediGoTheme.secondaryGrey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  Future<void> _openFile(String path) async {
    final url = ApiService.absoluteFileUrl(path);
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      _showError('Impossible d\'ouvrir le fichier.');
    }
  }
}
