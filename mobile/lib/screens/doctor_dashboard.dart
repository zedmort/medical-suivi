import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/medical_taxonomy.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/notification_bell.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

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

  bool _loadingPatients = true;
  bool _loadingAnalyses = true;
  bool _loadingPrescriptions = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _fetchAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    await Future.wait([_fetchData(), _fetchAnalyses(), _fetchPrescriptions()]);
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
        _patients = List<Map<String, dynamic>>.from(results[0]['patients'] ?? []);
        _labos   = List<Map<String, dynamic>>.from(results[1]['users'] ?? []);
        _pharmacies = List<Map<String, dynamic>>.from(results[2]['users'] ?? []);
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
      setState(() =>
          _analyses = List<Map<String, dynamic>>.from(res['requests'] ?? []));
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
      setState(() => _prescriptions =
          List<Map<String, dynamic>>.from(res['prescriptions'] ?? []));
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loadingPrescriptions = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green.shade700),
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
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.biotech, color: Color(0xFF1976D2)),
          SizedBox(width: 8),
          Text('Demande d\'analyse'),
        ]),
        content: StatefulBuilder(builder: (ctx2, setS) {
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Sélectionner un patient'),
                  items: _patients
                      .map((p) => DropdownMenuItem<int>(
                          value: p['id'] as int,
                          child: Text('${p['firstname']} ${p['lastname']}')))
                      .toList(),
                  onChanged: (v) => patientId = v,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Sélectionner un laboratoire'),
                  items: _labos
                      .map((l) => DropdownMenuItem<int>(
                          value: l['id'] as int,
                          child: Text(l['name'].toString())))
                      .toList(),
                  onChanged: (v) => laboId = v,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Analyses demandées',
                    prefixIcon: Icon(Icons.notes),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedFileName ?? 'Aucun fichier joint',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final picked = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                        );
                        if (picked == null || picked.files.single.path == null) return;
                        setS(() {
                          selectedFilePath = picked.files.single.path!;
                          selectedFileName = picked.files.single.name;
                        });
                      },
                      icon: const Icon(Icons.attach_file),
                      label: const Text('Joindre'),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ValueListenableBuilder<bool>(
            valueListenable: loading,
            builder: (_, isLoading, __) => ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (patientId == null || laboId == null) {
                        _showError('Sélectionnez patient et laboratoire.');
                        return;
                      }
                      loading.value = true;
                      try {
                        if (selectedFilePath != null) {
                          await ApiService.uploadFile('/analysis/create', selectedFilePath!, {
                            'patient_id': patientId.toString(),
                            'labo_id': laboId.toString(),
                            'notes': notesCtrl.text.trim(),
                          });
                        } else {
                          await ApiService.post('/analysis/create', {
                            'patient_id': patientId,
                            'labo_id': laboId,
                            'notes': notesCtrl.text.trim(),
                          });
                        }
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        _showSuccess('Demande envoyée au laboratoire!');
                        _fetchAnalyses();
                      } catch (e) {
                        _showError(e.toString());
                      } finally {
                        loading.value = false;
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Envoyer au labo'),
            ),
          ),
        ],
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
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.receipt_long, color: Color(0xFF388E3C)),
          SizedBox(width: 8),
          Text('Nouvelle ordonnance'),
        ]),
        content: StatefulBuilder(
          builder: (ctx2, setS) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Sélectionner un patient'),
                items: _patients
                    .map((p) => DropdownMenuItem<int>(
                        value: p['id'] as int,
                        child: Text('${p['firstname']} ${p['lastname']}')))
                    .toList(),
                onChanged: (v) => patientId = v,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Sélectionner une pharmacie'),
                items: _pharmacies
                    .map((p) => DropdownMenuItem<int>(
                        value: p['id'] as int,
                        child: Text(p['name'].toString())))
                    .toList(),
                onChanged: (v) => pharmacyId = v,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Médicaments / Instructions',
                  prefixIcon: Icon(Icons.medication_outlined),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      selectedFileName ?? 'Aucun fichier joint',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                      );
                      if (picked == null || picked.files.single.path == null) return;
                      setS(() {
                        selectedFilePath = picked.files.single.path!;
                        selectedFileName = picked.files.single.name;
                      });
                    },
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Joindre'),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ValueListenableBuilder<bool>(
            valueListenable: loading,
            builder: (_, isLoading, __) => ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (patientId == null || pharmacyId == null) {
                        _showError('Sélectionnez patient et pharmacie.');
                        return;
                      }
                      loading.value = true;
                      try {
                        if (selectedFilePath != null) {
                          await ApiService.uploadFile('/prescriptions/create', selectedFilePath!, {
                            'patient_id': patientId.toString(),
                            'pharmacy_id': pharmacyId.toString(),
                            'notes': notesCtrl.text.trim(),
                          });
                        } else {
                          await ApiService.post('/prescriptions/create', {
                            'patient_id': patientId,
                            'pharmacy_id': pharmacyId,
                            'notes': notesCtrl.text.trim(),
                          });
                        }
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        _showSuccess('Ordonnance envoyée à la pharmacie!');
                        _fetchPrescriptions();
                      } catch (e) {
                        _showError(e.toString());
                      } finally {
                        loading.value = false;
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Envoyer à la pharmacie'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Add Patient Dialog ────────────────────────────────────────────────────
  Future<void> _showAddPatientDialog() async {
    final loading = ValueNotifier(false);
    List<Map<String, dynamic>> availablePatients = [];

    try {
      final res = await ApiService.get('/patients/available');
      availablePatients = List<Map<String, dynamic>>.from(res['patients'] ?? []);
    } catch (e) {
      _showError(e.toString());
      return;
    }

    if (!mounted) return;

    int? selectedPatientId =
        availablePatients.isNotEmpty ? availablePatients.first['id'] as int : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setS) {
          Map<String, dynamic>? selectedPatient;
          for (final patient in availablePatients) {
            if (patient['id'] == selectedPatientId) {
              selectedPatient = patient;
              break;
            }
          }

          return AlertDialog(
            title: const Row(children: [
              Icon(Icons.person_add, color: Color(0xFF0288D1)),
              SizedBox(width: 8),
              Text('Ajouter un patient'),
            ]),
            content: SizedBox(
              width: 420,
              child: availablePatients.isEmpty
                  ? const Text(
                      'Aucun patient disponible pour votre spécialité. Le patient doit créer un compte d\'abord.',
                      style: TextStyle(color: Colors.grey),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<int>(
                          initialValue: selectedPatientId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Patient (compte existant)',
                            prefixIcon: Icon(Icons.person_outline),
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
                        const SizedBox(height: 14),
                        if (selectedPatient != null) ...[
                          _infoRow(
                            Icons.email_outlined,
                            selectedPatient['email']?.toString() ?? '—',
                          ),
                          _infoRow(
                            Icons.medical_information_outlined,
                            diseaseLabel(selectedPatient['disease']?.toString() ?? '—', context),
                            color: Colors.red.shade400,
                          ),
                          _infoRow(
                            Icons.cake_outlined,
                            '${selectedPatient['age']} ans',
                          ),
                          _infoRow(
                            Icons.location_on_outlined,
                            selectedPatient['address']?.toString() ?? '—',
                          ),
                          if ((selectedPatient['phone'] ?? '').toString().isNotEmpty)
                            _infoRow(
                              Icons.phone_outlined,
                              selectedPatient['phone'].toString(),
                            ),
                          const SizedBox(height: 8),
                          const Text(
                            'Les informations viennent du compte patient. Aucune ressaisie nécessaire.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ],
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
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
                            _showSuccess('Patient ajouté avec succès!');
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
                            color: Colors.white,
                          ),
                        )
                      : const Text('Ajouter'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dr. ${auth.name ?? ""}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18)),
            const Text('Tableau de bord',
                style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        actions: [
          const NotificationBell(),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _fetchAll),
          IconButton(
              icon: const Icon(Icons.logout), onPressed: _logout),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.group), text: 'Patients'),
            Tab(icon: Icon(Icons.biotech), text: 'Analyses'),
            Tab(icon: Icon(Icons.receipt_long), text: 'Ordonnances'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildPatientTab(),
          _buildAnalysisTab(),
          _buildPrescriptionTab(),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabs,
        builder: (_, __) {
          if (_tabs.index == 0) {
            return FloatingActionButton.extended(
              onPressed: _showAddPatientDialog,
              backgroundColor: const Color(0xFF0288D1),
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text('Nouveau patient',
                  style: TextStyle(color: Colors.white)),
            );
          }
          if (_tabs.index == 1 && !_loadingPatients) {
            return FloatingActionButton.extended(
              onPressed: _patients.isEmpty
                  ? null
                  : _showCreateAnalysisDialog,
              backgroundColor: const Color(0xFF1976D2),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Nouvelle analyse',
                  style: TextStyle(color: Colors.white)),
            );
          }
          if (_tabs.index == 2 && !_loadingPatients) {
            return FloatingActionButton.extended(
              onPressed: _patients.isEmpty
                  ? null
                  : _showCreatePrescriptionDialog,
              backgroundColor: const Color(0xFF388E3C),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Nouvelle ordonnance',
                  style: TextStyle(color: Colors.white)),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  // ── Patients Tab ───────────────────────────────────────────────────────────
  Widget _buildPatientTab() {
    if (_loadingPatients) return const Center(child: CircularProgressIndicator());
    if (_patients.isEmpty) {
      return _empty('Aucun patient enregistré.\nAppuyez sur + pour en ajouter.', Icons.group_outlined);
    }
    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
        itemCount: _patients.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final p = _patients[i];
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _showPatientDetail(p),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF1976D2).withAlpha(20),
                    child: Text(
                      (p['firstname'] as String? ?? '?')[0].toUpperCase(),
                      style: const TextStyle(color: Color(0xFF1976D2), fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${p['firstname']} ${p['lastname']}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Row(children: [
                      _chip('${p['age']} ans', Colors.blue),
                      const SizedBox(width: 6),
                      _chip(p['sex'] == 'M' ? '♂ Homme' : '♀ Femme',
                          p['sex'] == 'M' ? Colors.blue : Colors.pink),
                    ]),
                    const SizedBox(height: 4),
                    _infoRow(Icons.medical_information_outlined,
                      diseaseLabel(p['disease']?.toString() ?? '–', context), color: Colors.red.shade400),
                    if ((p['next_analysis_date'] ?? '').toString().isNotEmpty)
                      _infoRow(
                        Icons.event_outlined,
                        'Prochaine analyse : ${_fmtDate(p['next_analysis_date']?.toString())}',
                        color: Colors.deepPurple,
                      ),
                    _infoRow(Icons.location_on_outlined, p['address']?.toString() ?? '–'),
                  ])),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPatientDetail(Map<String, dynamic> p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text('${p['firstname']} ${p['lastname']}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _detailRow(Icons.cake, 'Âge', '${p['age']} ans'),
          _detailRow(Icons.person, 'Sexe', p['sex'] == 'M' ? 'Homme' : 'Femme'),
          _detailRow(Icons.medical_information_outlined, 'Maladie',
              diseaseLabel(p['disease']?.toString() ?? '–', context)),
          if ((p['next_analysis_date'] ?? '').toString().isNotEmpty)
            _detailRow(
              Icons.event_outlined,
              'Prochaine analyse',
              _fmtDate(p['next_analysis_date']?.toString()),
            ),
          _detailRow(Icons.location_on_outlined, 'Adresse',
              p['address']?.toString() ?? '–'),
          if ((p['phone'] ?? '').toString().isNotEmpty)
            _detailRow(Icons.phone_outlined, 'Téléphone', p['phone'].toString()),
          _detailRow(Icons.calendar_today, 'Ajouté le',
              _fmtDate(p['created_at']?.toString())),
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
          Row(children: [
            Expanded(child: ElevatedButton.icon(
              icon: const Icon(Icons.biotech, size: 18),
              label: const Text('Analyse'),
              onPressed: () { Navigator.pop(context); _showCreateAnalysisDialog(); },
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF388E3C)),
              icon: const Icon(Icons.receipt_long, size: 18),
              label: const Text('Ordonnance'),
              onPressed: () { Navigator.pop(context); _showCreatePrescriptionDialog(); },
            )),
          ]),
        ]),
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
              Icon(Icons.event_outlined, color: Color(0xFF1976D2)),
              SizedBox(width: 8),
              Text('Planifier analyse'),
            ],
          ),
          content: Column(
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
                      color: selected == null ? Colors.grey.shade600 : Colors.black87,
                    ),
                  ),
                ),
              ),
            ],
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
    if (_loadingAnalyses) return const Center(child: CircularProgressIndicator());
    if (_analyses.isEmpty) {
      return _empty('Aucune demande d\'analyse.\nAppuyez sur + pour en créer une.',
          Icons.biotech_outlined);
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
          final done   = status == 'completed';
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: done ? Colors.green.withAlpha(30) : Colors.orange.withAlpha(30),
                    child: Icon(done ? Icons.check_circle : Icons.hourglass_empty,
                        color: done ? Colors.green : Colors.orange, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    '${a['firstname'] ?? ''} ${a['lastname'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  )),
                  _statusChip(status),
                ]),
                const SizedBox(height: 8),
                _infoRow(Icons.medical_information_outlined,
                    a['disease']?.toString() ?? '–', color: Colors.red.shade400),
                _infoRow(Icons.science_outlined,
                    'Labo : ${a['labo_name'] ?? '–'}'),
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
                            onPressed: () => _openFile(a['file_url'].toString()),
                            icon: const Icon(Icons.description_outlined, size: 16),
                            label: const Text('Demande'),
                          ),
                        OutlinedButton.icon(
                          onPressed: () => _openFile(a['result_url'].toString()),
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
                _infoRow(Icons.calendar_today, _fmtDate(a['created_at']?.toString()),
                    color: Colors.grey),
              ]),
            ),
          );
        },
      ),
    );
  }

  // ── Prescriptions Tab ─────────────────────────────────────────────────────
  Widget _buildPrescriptionTab() {
    if (_loadingPrescriptions) return const Center(child: CircularProgressIndicator());
    if (_prescriptions.isEmpty) {
      return _empty('Aucune ordonnance.\nAppuyez sur + pour en créer une.',
          Icons.receipt_long_outlined);
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
          final done   = status == 'dispensed';
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: done ? Colors.green.withAlpha(30) : Colors.blue.withAlpha(30),
                    child: Icon(
                      done ? Icons.local_shipping : Icons.receipt_long,
                      color: done ? Colors.green : Colors.blue, size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    '${p['firstname'] ?? ''} ${p['lastname'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  )),
                  _statusChip(status),
                ]),
                const SizedBox(height: 8),
                _infoRow(Icons.local_pharmacy_outlined,
                    'Pharmacie : ${p['pharmacy_name'] ?? '–'}'),
                _infoRow(Icons.location_on_outlined,
                    p['address']?.toString() ?? '–'),
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
                _infoRow(Icons.calendar_today, _fmtDate(p['created_at']?.toString()),
                    color: Colors.grey),
              ]),
            ),
          );
        },
      ),
    );
  }

  // ── Shared Widgets ────────────────────────────────────────────────────────
  Widget _infoRow(IconData icon, String text, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      Icon(icon, size: 14, color: color ?? Colors.grey.shade600),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: TextStyle(
          fontSize: 12, color: color ?? Colors.grey.shade700))),
    ]),
  );

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
        color: color.withAlpha(20), borderRadius: BorderRadius.circular(12)),
    child: Text(text, style: TextStyle(
        color: color, fontSize: 11, fontWeight: FontWeight.w600)),
  );

  Widget _detailRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 18, color: const Color(0xFF1976D2)),
      const SizedBox(width: 10),
      SizedBox(width: 80,
          child: Text(label, style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 13))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
    ]),
  );

  Widget _empty(String msg, IconData icon) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(msg,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );

  Widget _statusChip(String status) {
    final (label, color) = switch (status) {
      'completed' => ('Terminé',   Colors.green),
      'dispensed' => ('Livré',     Colors.green),
      'pending'   => ('En attente', Colors.orange),
      _           => (status,      Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withAlpha(26), borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
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
