import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/medical_taxonomy.dart';
import '../l10n/app_texts.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/medi_go_theme.dart';
import '../widgets/dashboard_shell.dart';

class PharmacyDashboard extends StatefulWidget {
  const PharmacyDashboard({super.key});

  @override
  State<PharmacyDashboard> createState() => _PharmacyDashboardState();
}

class _PharmacyDashboardState extends State<PharmacyDashboard> {
  List<Map<String, dynamic>> _prescriptions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
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
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(int id, String newStatus) async {
    try {
      await ApiService.patch('/prescriptions/$id/status', {
        'status': newStatus,
      });
      if (!mounted) return;
      _showSuccess(
        newStatus == 'dispensed'
            ? AppTexts.of(context, 'marked_delivered')
            : AppTexts.of(context, 'set_pending'),
      );
      await _fetch();
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (e) {
      if (!mounted) return;
      _showError('${AppTexts.of(context, 'error_prefix')} $e');
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


  String _fmtDate(String? iso) {
    if (iso == null) return '–';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  void _showDetail(Map<String, dynamic> p) {
    final status = p['status']?.toString() ?? 'pending';
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
              '${p['firstname'] ?? ''} ${p['lastname'] ?? ''}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _detailRow(
              Icons.medical_information_outlined,
              'Maladie',
              diseaseLabel(p['disease']?.toString() ?? '–', context),
            ),
            _detailRow(
              Icons.location_on_outlined,
              AppTexts.of(context, 'delivery_address'),
              p['address']?.toString() ?? '–',
            ),
            if ((p['phone'] ?? '').toString().isNotEmpty)
              _detailRow(
                Icons.phone_outlined,
                AppTexts.of(context, 'phone_optional'),
                p['phone'].toString(),
              ),
            if ((p['notes'] ?? '').toString().isNotEmpty)
              _detailRow(
                Icons.medication_outlined,
                AppTexts.of(context, 'medications'),
                p['notes'].toString(),
              ),
            _detailRow(
              Icons.person_outline,
              AppTexts.of(context, 'doctor'),
              p['doctor_name']?.toString() ?? '–',
            ),
            _detailRow(
              Icons.calendar_today,
              AppTexts.of(context, 'date'),
              _fmtDate(p['created_at']?.toString()),
            ),
            _detailRow(
              Icons.info_outline,
              AppTexts.of(context, 'status'),
              status == 'dispensed'
                  ? AppTexts.of(context, 'dispensed')
                  : AppTexts.of(context, 'pending'),
            ),
            const SizedBox(height: 24),
            if (status == 'pending')
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MediGoTheme.successGreen,
                    foregroundColor: MediGoTheme.cardSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.local_shipping),
                  label: Text(
                    AppTexts.of(context, 'mark_delivered'),
                    style: const TextStyle(fontSize: 15),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _updateStatus(p['id'] as int, 'dispensed');
                  },
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MediGoTheme.warningOrange,
                    side: const BorderSide(color: MediGoTheme.warningOrange),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.undo),
                  label: Text(
                    AppTexts.of(context, 'back_to_pending'),
                    style: const TextStyle(fontSize: 15),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _updateStatus(p['id'] as int, 'pending');
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
      ],
    ),
  );

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

  Widget _prescriptionCard(Map<String, dynamic> p) {
    final status = p['status']?.toString() ?? 'pending';
    final dispensed = status == 'dispensed';
    final color = dispensed
        ? MediGoTheme.successGreen
        : MediGoTheme.warningOrange;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: MediGoTheme.cardBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetail(p),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withAlpha(28),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      dispensed ? Icons.check_circle : Icons.local_shipping,
                      color: color,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${p['firstname'] ?? ''} ${p['lastname'] ?? ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withAlpha(26),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      dispensed
                          ? AppTexts.of(context, 'dispensed')
                          : AppTexts.of(context, 'pending'),
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _infoRow(
                Icons.location_on_outlined,
                p['address']?.toString() ?? '–',
              ),
              if ((p['phone'] ?? '').toString().isNotEmpty)
                _infoRow(Icons.phone_outlined, p['phone'].toString()),
              _infoRow(
                Icons.medical_information_outlined,
                diseaseLabel(p['disease']?.toString() ?? '–', context),
                color: MediGoTheme.heartRed,
              ),
              if ((p['notes'] ?? '').toString().isNotEmpty)
                _infoRow(Icons.medication_outlined, p['notes'].toString()),
              _infoRow(
                Icons.calendar_today,
                _fmtDate(p['created_at']?.toString()),
                color: MediGoTheme.secondaryGrey,
              ),
              if (status == 'pending') ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MediGoTheme.successGreen,
                      foregroundColor: MediGoTheme.cardSurface,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.local_shipping, size: 18),
                    label: Text(AppTexts.of(context, 'mark_delivered')),
                    onPressed: () => _updateStatus(p['id'] as int, 'dispensed'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    String t(String key) => AppTexts.of(context, key);
    final pending = _prescriptions
        .where((p) => p['status'] == 'pending')
        .length;
    final dispensed = _prescriptions
        .where((p) => p['status'] == 'dispensed')
        .length;

    return DashboardShell(
      title: t('pharmacy'),
      subtitle: (auth.name ?? '').isNotEmpty ? auth.name! : '',
      placement: 'pharmacy_dashboard',
      onRefresh: _fetch,
      body: Column(
        children: [
          Container(
            color: MediGoTheme.cardSurface,
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: 16,
              top: 4,
            ),
            child: Row(
              children: [
                _statChip(
                  Icons.hourglass_empty,
                  '$pending',
                  t('pending'),
                  MediGoTheme.warningOrange,
                ),
                const SizedBox(width: 10),
                _statChip(
                  Icons.check_circle_outline,
                  '$dispensed',
                  t('dispensed'),
                  MediGoTheme.successGreen,
                ),
                const SizedBox(width: 10),
                _statChip(
                  Icons.list_alt,
                  '${_prescriptions.length}',
                  t('total'),
                  MediGoTheme.primaryBlue,
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _prescriptions.isEmpty
                ? MediEmpty(
                    icon: Icons.local_pharmacy_outlined,
                    message: t('no_assigned_prescriptions'),
                  )
                : RefreshIndicator(
                    onRefresh: _fetch,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _prescriptions.length,
                      itemBuilder: (_, i) =>
                          _prescriptionCard(_prescriptions[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String value, String label, Color color) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: MediGoTheme.cardSurface.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onPrimary.withValues(alpha: 0.75),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      );
}
