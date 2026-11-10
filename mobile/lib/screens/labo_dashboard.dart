import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/medical_taxonomy.dart';
import '../l10n/app_texts.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/medi_go_theme.dart';
import '../widgets/dashboard_shell.dart';

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
      setState(
        () =>
            _requests = List<Map<String, dynamic>>.from(res['requests'] ?? []),
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
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

  Future<void> _uploadResult(Map<String, dynamic> request) async {
    if (request['status'] == 'completed') {
      final overwrite = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(AppTexts.of(context, 'already_processed')),
          content: Text(AppTexts.of(context, 'already_processed_content')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppTexts.of(context, 'cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppTexts.of(context, 'upload')),
            ),
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
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(AppTexts.of(context, 'uploading')),
          ],
        ),
      ),
    );

    try {
      await ApiService.uploadFile('/analysis/upload-result', filePath, {
        'request_id': request['id'].toString(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      _showSuccess(AppTexts.of(context, 'result_sent_success'));
      _fetch();
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showError(e.toString());
    }
  }


  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    String t(String key) => AppTexts.of(context, key);
    return DashboardShell(
      title: t('labo'),
      subtitle: (auth.name ?? '').isNotEmpty ? auth.name! : '',
      placement: 'labo_dashboard',
      onRefresh: _fetch,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
          ? MediEmpty(
              icon: Icons.biotech_outlined,
              message: t('no_assigned_analysis'),
            )
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
    final status = req['status']?.toString() ?? 'pending';
    final completed = status == 'completed';
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: MediGoTheme.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: completed
                      ? MediGoTheme.greenChipBg
                      : MediGoTheme.primaryBlue.withAlpha(30),
                  radius: 22,
                  child: Icon(
                    completed ? Icons.check_circle : Icons.science,
                    color: completed
                        ? MediGoTheme.successGreen
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
                        '${req['firstname'] ?? ''} ${req['lastname'] ?? ''}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _fmtDate(req['created_at']?.toString()),
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
            const Divider(height: 16),
            _infoRow(
              Icons.medical_information_outlined,
              diseaseLabel(req['disease']?.toString() ?? '–', context),
              color: MediGoTheme.heartRed,
            ),
            _infoRow(
              Icons.location_on_outlined,
              req['address']?.toString() ?? '– adresse inconnue',
            ),
            _infoRow(
              Icons.person_outline,
              '${AppTexts.of(context, 'doctor')} : ${req['doctor_name'] ?? '–'}',
            ),
            if ((req['notes'] ?? '').toString().isNotEmpty)
              _infoRow(Icons.notes, req['notes'].toString()),
            if (completed && (req['result_url'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _infoRow(
                  Icons.attach_file,
                  'Résultat déjà envoyé',
                  color: MediGoTheme.successGreen,
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _uploadResult(req),
                icon: const Icon(Icons.upload_file),
                label: Text(
                  completed
                      ? AppTexts.of(context, 'resend_result')
                      : AppTexts.of(context, 'send_result'),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MediGoTheme.primaryBlue,
                  side: const BorderSide(color: MediGoTheme.primaryBlue),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


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

  Widget _statusChip(String status) {
    final (label, color) = switch (status) {
      'completed' => ('Terminé', MediGoTheme.successGreen),
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
}
