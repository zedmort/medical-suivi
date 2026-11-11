import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/medical_taxonomy.dart';
import '../l10n/app_texts.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/medi_go_theme.dart';
import '../widgets/dashboard_shell.dart';
import 'doctor_search_screen.dart';
import 'medical_assistant_screen.dart';
import 'medical_document_screen.dart';

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});
  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  List<Map<String, dynamic>> _analysisRequests = [];
  List<Map<String, dynamic>> _prescriptions = [];
  Map<String, dynamic>? _overview;
  bool _loadingAnalysis = true;
  bool _loadingPrescriptions = true;
  bool _loadingOverview = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this, initialIndex: 1);
    _fetchAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    await Future.wait([
      _fetchAnalysis(),
      _fetchPrescriptions(),
      _fetchOverview(),
    ]);
  }

  Future<void> _fetchOverview() async {
    setState(() => _loadingOverview = true);
    try {
      final res = await ApiService.get('/patients/me/overview');
      if (!mounted) return;
      setState(() => _overview = res);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loadingOverview = false);
    }
  }

  Future<void> _fetchAnalysis() async {
    setState(() => _loadingAnalysis = true);
    try {
      final res = await ApiService.get('/analysis/my-requests');
      if (!mounted) return;
      setState(
        () => _analysisRequests = List<Map<String, dynamic>>.from(
          res['requests'] ?? [],
        ),
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loadingAnalysis = false);
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

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: MediGoTheme.heartRed),
    );
  }

  void _openDoctorSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DoctorSearchScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    String t(String key) => AppTexts.of(context, key);
    final patient = _overview?['patient'] as Map<String, dynamic>? ?? {};
    final patientName =
        '${patient['firstname'] ?? ''} ${patient['lastname'] ?? ''}'.trim();
    final displayName = patientName.isNotEmpty
        ? patientName
        : (auth.name ?? '');
    return DashboardShell(
      title: t('patient_dashboard'),
      placement: 'patient_dashboard',
      actions: null,
      toolbarHeight: 64,
      extraActions: [
        IconButton(
          tooltip: t('find_doctor'),
          onPressed: _openDoctorSearch,
          icon: const Icon(Icons.search),
        ),
      ],
      tabBar: DashboardTabBar(
        controller: _tabs,
        tabs: [
          Tab(
            icon: const Icon(Icons.biotech, size: 20),
            text: t('my_analyses'),
          ),
          Tab(
            icon: const Icon(Icons.receipt_long, size: 20),
            text: t('prescription'),
          ),
          Tab(
            icon: const Icon(Icons.monitor_heart, size: 20),
            text: t('my_progress'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (displayName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: MediGoTheme.primaryBlue,
                        child: Icon(
                          Icons.person_outline,
                          color: MediGoTheme.cardSurface,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          displayName,
                          softWrap: true,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MedicalAssistantScreen(),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: MediGoTheme.backgroundEnd,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.support_agent_rounded,
                          color: MediGoTheme.primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t('medical_assistant'),
                              style: const TextStyle(
                                color: MediGoTheme.darkNavy,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              t('medical_assistant_subtitle'),
                              style: const TextStyle(
                                color: MediGoTheme.secondaryGrey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: MediGoTheme.primaryBlue,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _buildAnalysisTab(),
                _buildPrescriptionTab(),
                _buildProgressTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisTab() {
    if (_loadingAnalysis) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_analysisRequests.isEmpty) {
      return _empty(
        AppTexts.of(context, 'no_analysis_requests'),
        Icons.biotech_outlined,
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchAnalysis,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _analysisRequests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final a = _analysisRequests[i];
          final status = a['status']?.toString() ?? 'pending';
          final resultUrl = a['result_url']?.toString() ?? '';
          final hasResult = resultUrl.isNotEmpty;
          final requestFileUrl = a['file_url']?.toString() ?? '';
          return Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: hasResult
                            ? MediGoTheme.greenChipBg
                            : MediGoTheme.orangeChipBg,
                        radius: 22,
                        child: Icon(
                          hasResult
                              ? Icons.check_circle
                              : Icons.hourglass_empty,
                          color: hasResult
                              ? MediGoTheme.greenChipText
                              : MediGoTheme.orangeChipText,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${AppTexts.of(context, 'analysis_request')} #${a['id']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              _fmtDate(a['created_at']?.toString()),
                              style: const TextStyle(
                                color: MediGoTheme.secondaryGrey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _statusChip(status),
                    ],
                  ),
                  if ((a['labo_name'] ?? '').toString().isNotEmpty ||
                      (a['notes'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    if ((a['labo_name'] ?? '').toString().isNotEmpty)
                      _infoRow(
                        Icons.science_outlined,
                        '${AppTexts.of(context, 'labo')}: ${a['labo_name']}',
                      ),
                    if ((a['notes'] ?? '').toString().isNotEmpty)
                      _infoRow(Icons.notes_outlined, a['notes'].toString()),
                  ],
                  if (requestFileUrl.isNotEmpty || resultUrl.isNotEmpty) ...[
                    const Divider(height: 20),
                    if (requestFileUrl.isNotEmpty)
                      _documentButton(
                        path: requestFileUrl,
                        title:
                            '${AppTexts.of(context, 'attached_document')} #${a['id']}',
                        type: AppTexts.of(context, 'analysis_request'),
                        date: _fmtDate(a['created_at']?.toString()),
                      ),
                    if (resultUrl.isNotEmpty)
                      _documentButton(
                        path: resultUrl,
                        title:
                            '${AppTexts.of(context, 'analysis_result')} #${a['id']}',
                        type: AppTexts.of(context, 'my_analyses'),
                        date: _fmtDate(
                          a['result_uploaded_at']?.toString() ??
                              a['created_at']?.toString(),
                        ),
                      ),
                  ] else
                    _infoRow(
                      Icons.info_outline,
                      AppTexts.of(context, 'no_document_attached'),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPrescriptionTab() {
    if (_loadingPrescriptions) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_prescriptions.isEmpty) {
      return _empty(
        AppTexts.of(context, 'no_prescriptions'),
        Icons.receipt_long_outlined,
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchPrescriptions,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _prescriptions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final p = _prescriptions[i];
          final status = p['status']?.toString() ?? 'pending';
          final fileUrl = p['file_url']?.toString() ?? '';
          return Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: status == 'dispensed'
                            ? MediGoTheme.greenChipBg
                            : MediGoTheme.primaryBlue.withValues(alpha: 0.14),
                        radius: 22,
                        child: Icon(
                          Icons.receipt_long,
                          color: status == 'dispensed'
                              ? MediGoTheme.greenChipText
                              : MediGoTheme.primaryBlue,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${AppTexts.of(context, 'prescription')} #${p['id']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              _fmtDate(p['created_at']?.toString()),
                              style: const TextStyle(
                                color: MediGoTheme.secondaryGrey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _statusChip(status),
                    ],
                  ),
                  if ((p['pharmacy_name'] ?? '').toString().isNotEmpty)
                    _infoRow(
                      Icons.local_pharmacy_outlined,
                      '${AppTexts.of(context, 'pharmacy')}: ${p['pharmacy_name']}',
                    ),
                  if ((p['notes'] ?? '').toString().isNotEmpty)
                    _infoRow(Icons.medication_outlined, p['notes'].toString()),
                  if (fileUrl.isNotEmpty) ...[
                    const Divider(height: 20),
                    _documentButton(
                      path: fileUrl,
                      title:
                          '${AppTexts.of(context, 'prescription')} #${p['id']}',
                      type: AppTexts.of(context, 'prescription'),
                      date: _fmtDate(p['created_at']?.toString()),
                    ),
                  ] else
                    _infoRow(
                      Icons.info_outline,
                      AppTexts.of(context, 'no_document_attached'),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressTab() {
    if (_loadingOverview) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_overview == null) {
      return _empty(
        AppTexts.of(context, 'no_progress_data'),
        Icons.monitor_heart_outlined,
      );
    }

    final patient = _overview?['patient'] as Map<String, dynamic>? ?? {};
    final stats = _overview?['stats'] as Map<String, dynamic>? ?? {};
    final progression =
        _overview?['progression'] as Map<String, dynamic>? ?? {};
    final timeline = List<Map<String, dynamic>>.from(
      _overview?['timeline'] ?? [],
    );
    final level = progression['level']?.toString() ?? 'monitoring';
    final progressionLabel = switch (level) {
      'good' => AppTexts.of(context, 'progress_good'),
      'attention' => AppTexts.of(context, 'progress_attention'),
      _ => AppTexts.of(context, 'under_monitoring'),
    };
    final progressionMessage = switch (level) {
      'good' => AppTexts.of(context, 'progress_good_message'),
      'attention' => AppTexts.of(context, 'progress_attention_message'),
      _ => AppTexts.of(context, 'progress_monitoring_message'),
    };

    return RefreshIndicator(
      onRefresh: _fetchOverview,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _progressColor(level),
                child: Icon(
                  _progressIcon(level),
                  color: MediGoTheme.cardSurface,
                ),
              ),
              title: Text(
                progressionLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(progressionMessage),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppTexts.of(context, 'care_summary'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${AppTexts.of(context, 'disease')}: ${diseaseLabel(patient['disease']?.toString() ?? '—', context)}',
                  ),
                  Text(
                    '${AppTexts.of(context, 'next_analysis_date')}: ${_fmtDate(patient['next_analysis_date']?.toString())}',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${AppTexts.of(context, 'analyses_completed')}: ${stats['analysis_completed'] ?? 0}',
                  ),
                  Text(
                    '${AppTexts.of(context, 'analyses_pending')}: ${stats['analysis_pending'] ?? 0}',
                  ),
                  Text(
                    '${AppTexts.of(context, 'medications_ready')}: ${stats['meds_ready'] ?? 0}',
                  ),
                  Text(
                    '${AppTexts.of(context, 'medications_pending')}: ${stats['meds_pending'] ?? 0}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            AppTexts.of(context, 'recent_activity'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          if (timeline.isEmpty)
            _empty(AppTexts.of(context, 'no_recent_activity'), Icons.history)
          else
            ...timeline
                .take(12)
                .map(
                  (item) => Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Icon(
                        item['type'] == 'analysis'
                            ? Icons.biotech_outlined
                            : Icons.medication_outlined,
                      ),
                      title: Text(_timelineTitle(item)),
                      subtitle: Text(_timelineSubtitle(item)),
                      trailing: Text(
                        _fmtDate(item['date']?.toString()),
                        style: const TextStyle(
                          fontSize: 12,
                          color: MediGoTheme.secondaryGrey,
                        ),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

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

  Widget _infoRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: MediGoTheme.secondaryGrey),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            softWrap: true,
            style: const TextStyle(
              fontSize: 13,
              color: MediGoTheme.secondaryGrey,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _documentButton({
    required String path,
    required String title,
    required String type,
    required String date,
  }) => Card(
    margin: const EdgeInsets.symmetric(vertical: 4),
    child: ListTile(
      leading: const Icon(
        Icons.description_outlined,
        color: MediGoTheme.primaryBlue,
      ),
      title: Text(title),
      subtitle: Text('$type · $date'),
      trailing: const Icon(Icons.open_in_new, color: MediGoTheme.primaryBlue),
      onTap: () =>
          _openDocument(path: path, title: title, type: type, date: date),
    ),
  );

  String _timelineTitle(Map<String, dynamic> item) {
    final title = item['title']?.toString();
    return switch (title) {
      'Analysis completed' => AppTexts.of(context, 'analysis_completed'),
      'Analysis requested' => AppTexts.of(context, 'analysis_requested'),
      'Medication ready' => AppTexts.of(context, 'medication_ready'),
      'Medication pending' => AppTexts.of(context, 'medication_pending'),
      _ => title ?? '',
    };
  }

  String _timelineSubtitle(Map<String, dynamic> item) {
    final subtitle = item['subtitle']?.toString();
    return switch (subtitle) {
      'Result available' => AppTexts.of(context, 'analysis_result_available'),
      'Waiting for laboratory result' => AppTexts.of(
        context,
        'waiting_laboratory_result',
      ),
      'Pharmacy has marked it ready' => AppTexts.of(
        context,
        'pharmacy_marked_ready',
      ),
      'Pharmacy is preparing your medication' => AppTexts.of(
        context,
        'pharmacy_preparing',
      ),
      _ => subtitle ?? '',
    };
  }

  Future<void> _openDocument({
    required String path,
    required String title,
    required String type,
    required String date,
  }) async {
    if (path.trim().isEmpty) {
      _showError(AppTexts.of(context, 'document_url_invalid'));
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => MedicalDocumentScreen(
          title: title,
          type: type,
          date: date,
          fileUrl: path,
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    Color color;
    switch (status) {
      case 'completed':
      case 'dispensed':
        color = MediGoTheme.successGreen;
        break;
      default:
        color = MediGoTheme.warningOrange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusText(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _statusText(String status) {
    switch (status) {
      case 'completed':
        return AppTexts.of(context, 'completed');
      case 'dispensed':
        return AppTexts.of(context, 'dispensed');
      default:
        return AppTexts.of(context, 'pending');
    }
  }

  Color _progressColor(String level) {
    switch (level) {
      case 'good':
        return MediGoTheme.successGreen;
      case 'attention':
        return MediGoTheme.warningOrange;
      default:
        return MediGoTheme.primaryBlue;
    }
  }

  IconData _progressIcon(String level) {
    switch (level) {
      case 'good':
        return Icons.trending_up;
      case 'attention':
        return Icons.warning_amber_rounded;
      default:
        return Icons.monitor_heart;
    }
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return MaterialLocalizations.of(context).formatMediumDate(dt);
    } catch (_) {
      return iso;
    }
  }
}
