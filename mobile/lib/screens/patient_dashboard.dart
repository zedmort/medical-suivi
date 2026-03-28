import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/medical_taxonomy.dart';
import '../l10n/app_texts.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/notification_bell.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

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
    _tabs = TabController(length: 3, vsync: this);
    _fetchAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    await Future.wait([_fetchAnalysis(), _fetchPrescriptions(), _fetchOverview()]);
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
      setState(() => _analysisRequests =
          List<Map<String, dynamic>>.from(res['requests'] ?? []));
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
        SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700));
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
    String t(String key) => AppTexts.of(context, key);
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(auth.name ?? t('patient'),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18)),
            Text(t('patient_dashboard'),
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: const Color(0xFF00897B),
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
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchAll),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(icon: const Icon(Icons.biotech), text: t('my_analyses')),
            Tab(icon: const Icon(Icons.receipt_long), text: t('prescription')),
            Tab(icon: const Icon(Icons.monitor_heart), text: t('my_progress')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_buildAnalysisTab(), _buildPrescriptionTab(), _buildProgressTab()],
      ),
    );
  }

  Widget _buildAnalysisTab() {
    if (_loadingAnalysis) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_analysisRequests.isEmpty) {
      return _empty(AppTexts.of(context, 'no_analysis_requests'), Icons.biotech_outlined);
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
          final hasResult = a['result_url'] != null;
          return Card(
            elevation: 1,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    CircleAvatar(
                      backgroundColor:
                          hasResult ? Colors.green : Colors.orange,
                      radius: 22,
                      child: Icon(
                          hasResult
                              ? Icons.check_circle
                              : Icons.hourglass_empty,
                          color: Colors.white,
                          size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${AppTexts.of(context, 'analysis_request')} #${a['id']}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(_fmtDate(a['created_at']?.toString()),
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                    _statusChip(status),
                  ]),
                  if (hasResult) ...[
                    const Divider(height: 20),
                    Row(children: [
                      const Icon(Icons.attach_file,
                          size: 16, color: Colors.teal),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(a['result_url'].toString(),
                            style: const TextStyle(
                                color: Colors.teal,
                                fontSize: 12,
                                decoration: TextDecoration.underline)),
                      ),
                    ]),
                  ],
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
      return _empty(AppTexts.of(context, 'no_prescriptions'), Icons.receipt_long_outlined);
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
          return Card(
            elevation: 1,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    CircleAvatar(
                      backgroundColor:
                          status == 'dispensed' ? Colors.green : Colors.blue,
                      radius: 22,
                      child: const Icon(Icons.receipt_long,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${AppTexts.of(context, 'prescription')} #${p['id']}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(_fmtDate(p['created_at']?.toString()),
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                    _statusChip(status),
                  ]),
                  if (p['file_url'] != null) ...[
                    const Divider(height: 20),
                    Row(children: [
                      const Icon(Icons.attach_file,
                          size: 16, color: Colors.indigo),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(p['file_url'].toString(),
                            style: const TextStyle(
                                color: Colors.indigo,
                                fontSize: 12,
                                decoration: TextDecoration.underline)),
                      ),
                    ]),
                  ],
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
      return _empty(AppTexts.of(context, 'no_progress_data'), Icons.monitor_heart_outlined);
    }

    final patient = _overview?['patient'] as Map<String, dynamic>? ?? {};
    final stats = _overview?['stats'] as Map<String, dynamic>? ?? {};
    final progression = _overview?['progression'] as Map<String, dynamic>? ?? {};
    final timeline = List<Map<String, dynamic>>.from(_overview?['timeline'] ?? []);
    final level = progression['level']?.toString() ?? 'monitoring';

    return RefreshIndicator(
      onRefresh: _fetchOverview,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _progressColor(level),
                child: Icon(_progressIcon(level), color: Colors.white),
              ),
              title: Text(
                progression['label']?.toString() ?? AppTexts.of(context, 'under_monitoring'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(progression['message']?.toString() ?? ''),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppTexts.of(context, 'care_summary'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 10),
                  Text('${AppTexts.of(context, 'disease')}: ${diseaseLabel(patient['disease']?.toString() ?? '—', context)}'),
                  Text('${AppTexts.of(context, 'next_analysis_date')}: ${_fmtDate(patient['next_analysis_date']?.toString())}'),
                  const SizedBox(height: 8),
                  Text('${AppTexts.of(context, 'analyses_completed')}: ${stats['analysis_completed'] ?? 0}'),
                  Text('${AppTexts.of(context, 'analyses_pending')}: ${stats['analysis_pending'] ?? 0}'),
                  Text('${AppTexts.of(context, 'medications_ready')}: ${stats['meds_ready'] ?? 0}'),
                  Text('${AppTexts.of(context, 'medications_pending')}: ${stats['meds_pending'] ?? 0}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(AppTexts.of(context, 'recent_activity'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          if (timeline.isEmpty)
            _empty(AppTexts.of(context, 'no_recent_activity'), Icons.history)
          else
            ...timeline.take(12).map((item) => Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: Icon(
                      item['type'] == 'analysis'
                          ? Icons.biotech_outlined
                          : Icons.medication_outlined,
                    ),
                    title: Text(item['title']?.toString() ?? ''),
                    subtitle: Text(item['subtitle']?.toString() ?? ''),
                    trailing: Text(
                      _fmtDate(item['date']?.toString()),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _empty(String msg, IconData icon) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(msg,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500)),
        ]),
      );

  Widget _statusChip(String status) {
    Color color;
    switch (status) {
      case 'completed':
      case 'dispensed':
        color = Colors.green;
        break;
      default:
        color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withAlpha(26),
          borderRadius: BorderRadius.circular(20)),
      child: Text(_statusText(status),
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
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
        return Colors.green;
      case 'attention':
        return Colors.orange;
      default:
        return Colors.blueGrey;
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
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}
