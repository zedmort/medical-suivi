import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../constants/medical_taxonomy.dart';
import '../l10n/app_texts.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/notification_bell.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

class LaboDashboard extends StatefulWidget {
  const LaboDashboard({super.key});
  @override
  State<LaboDashboard> createState() => _LaboDashboardState();
}

class _LaboDashboardState extends State<LaboDashboard> {
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.get('/analysis/my-requests');
      if (!mounted) return;
      setState(() =>
          _requests = List<Map<String, dynamic>>.from(res['requests'] ?? []));
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700));
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.green.shade700));
  }

  // ── Upload Result ─────────────────────────────────────────────────────────
  Future<void> _uploadResult(Map<String, dynamic> request) async {
    // Show confirmation if already completed
    if (request['status'] == 'completed') {
      final overwrite = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(AppTexts.of(context, 'already_processed')),
          content: Text(AppTexts.of(context, 'already_processed_content')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(AppTexts.of(context, 'cancel'))),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(AppTexts.of(context, 'upload'))),
          ],
        ),
      );
      if (overwrite != true) return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result == null || result.files.single.path == null) return;
    final filePath = result.files.single.path!;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 16),
          Text(AppTexts.of(context, 'uploading')),
        ]),
      ),
    );

    try {
      await ApiService.uploadFile(
        '/analysis/upload-result',
        filePath,
        {'request_id': request['id'].toString()},
      );
      if (!mounted) return;
      Navigator.pop(context); // close loading dialog
      _showSuccess(AppTexts.of(context, 'result_sent_success'));
      _fetch();
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showError(e.toString());
    } finally {
      // loading cleanup handled by dialog pop
    }
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
            Text(auth.name ?? t('labo'),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18)),
            Text(t('dashboard'),
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: const Color(0xFF6A1B9A),
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
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? _empty()
              : RefreshIndicator(
                  onRefresh: _fetch,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _requests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _requestCard(_requests[i]),
                  ),
                ),
    );
  }

  Widget _requestCard(Map<String, dynamic> req) {
    final status    = req['status']?.toString() ?? 'pending';
    final completed = status == 'completed';
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Header ──────────────────────────────────────────────────────
          Row(children: [
            CircleAvatar(
              backgroundColor: completed
                  ? Colors.green.withAlpha(30)
                  : const Color(0xFF6A1B9A).withAlpha(30),
              radius: 22,
              child: Icon(
                  completed ? Icons.check_circle : Icons.science,
                  color: completed ? Colors.green : const Color(0xFF6A1B9A),
                  size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${req['firstname'] ?? ''} ${req['lastname'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(_fmtDate(req['created_at']?.toString()),
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ])),
            _statusChip(status),
          ]),
          const Divider(height: 16),
          // ── Patient info ─────────────────────────────────────────────────
            _infoRow(Icons.medical_information_outlined,
              diseaseLabel(req['disease']?.toString() ?? '–', context), color: Colors.red.shade400),
          _infoRow(Icons.location_on_outlined,
              req['address']?.toString() ?? '– adresse inconnue'),
          _infoRow(Icons.person_outline,
              '${AppTexts.of(context, 'doctor')} : ${req['doctor_name'] ?? '–'}'),
          if ((req['notes'] ?? '').toString().isNotEmpty)
            _infoRow(Icons.notes, req['notes'].toString()),
          if (completed && (req['result_url'] ?? '').toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _infoRow(Icons.attach_file, 'Résultat déjà envoyé',
                  color: Colors.green),
            ),
          const SizedBox(height: 12),
          // ── Upload button ────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _uploadResult(req),
              icon: const Icon(Icons.upload_file),
                label: Text(completed
                  ? AppTexts.of(context, 'resend_result')
                  : AppTexts.of(context, 'send_result')),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6A1B9A),
                side: const BorderSide(color: Color(0xFF6A1B9A)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _empty() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.biotech_outlined, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 14),
          Text(AppTexts.of(context, 'no_assigned_analysis'),
              style: TextStyle(color: Colors.grey.shade500)),
        ]),
      );

  Widget _infoRow(IconData icon, String text, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      Icon(icon, size: 14, color: color ?? Colors.grey.shade600),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: TextStyle(
          fontSize: 12, color: color ?? Colors.grey.shade700))),
    ]),
  );

  Widget _statusChip(String status) {
    final (label, color) = switch (status) {
      'completed' => ('Terminé',    Colors.green),
      'pending'   => ('En attente', Colors.orange),
      _           => (status,       Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withAlpha(26),
          borderRadius: BorderRadius.circular(20)),
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
}
