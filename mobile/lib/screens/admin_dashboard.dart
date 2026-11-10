import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/medical_taxonomy.dart';
import '../l10n/app_texts.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/medi_go_theme.dart';
import 'login_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _priceController = TextEditingController();
  List<Map<String, dynamic>> _ads = [];
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _mappings = [];
  bool _loading = true;
  bool _savingPrice = false;

  String _text(String key) => AppTexts.of(context, key);

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final responses = await Future.wait([
        ApiService.get('/admin/settings'),
        ApiService.get('/admin/advertisements'),
        ApiService.get('/admin/transactions'),
        ApiService.get('/admin/condition-mappings'),
      ]);
      if (!mounted) return;
      setState(() {
        final amount = responses[0]['symptomConsultationAmountDzd'];
        _priceController.text = amount?.toString() ?? '';
        _ads = List<Map<String, dynamic>>.from(
          responses[1]['advertisements'] ?? [],
        );
        _transactions = List<Map<String, dynamic>>.from(
          responses[2]['transactions'] ?? [],
        );
        _mappings = List<Map<String, dynamic>>.from(
          responses[3]['mappings'] ?? [],
        );
      });
    } on ApiException catch (error) {
      _showMessage(error.message, isError: true);
    } catch (error) {
      _showMessage(error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _savePrice() async {
    final amount = int.tryParse(_priceController.text.trim());
    if (amount == null || amount <= 0) {
      _showMessage(_text('valid_price_required'), isError: true);
      return;
    }
    setState(() => _savingPrice = true);
    try {
      await ApiService.put('/admin/settings/consultation-price', {
        'amount_dzd': amount,
      });
      _showMessage(_text('settings_saved'));
    } on ApiException catch (error) {
      _showMessage(error.message, isError: true);
    } catch (error) {
      _showMessage(error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _savingPrice = false);
    }
  }

  Future<String?> _pickAdImage() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
    );
    if (picked == null || picked.files.single.path == null) return null;
    final response = await ApiService.uploadFile(
      '/admin/advertisements/upload',
      picked.files.single.path!,
      const {},
    );
    return response['image_url']?.toString();
  }

  Future<void> _editAd([Map<String, dynamic>? ad]) async {
    final title = TextEditingController(text: ad?['title']?.toString() ?? '');
    final description = TextEditingController(
      text: ad?['description']?.toString() ?? '',
    );
    final destination = TextEditingController(
      text: ad?['destination_url']?.toString() ?? '',
    );
    final startInitial = DateTime.tryParse(ad?['starts_at']?.toString() ?? '');
    final endInitial = DateTime.tryParse(ad?['expires_at']?.toString() ?? '');
    String placement = ad?['placement']?.toString() ?? 'dashboard';
    String? imageUrl = ad?['image_url']?.toString();
    DateTime? startsAt = startInitial;
    DateTime? expiresAt = endInitial;
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(ad == null ? _text('create_ad') : _text('edit_ad')),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    decoration: InputDecoration(labelText: _text('ad_title')),
                  ),
                  TextField(
                    controller: description,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: _text('description'),
                    ),
                  ),
                  TextField(
                    controller: destination,
                    decoration: InputDecoration(
                      labelText: _text('destination_link'),
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: placement,
                    decoration: InputDecoration(labelText: _text('placement')),
                    items: [
                      DropdownMenuItem(
                        value: 'dashboard',
                        child: Text(_text('all_dashboards')),
                      ),
                      DropdownMenuItem(
                        value: 'patient_dashboard',
                        child: Text(_text('patient')),
                      ),
                      DropdownMenuItem(
                        value: 'doctor_dashboard',
                        child: Text(_text('doctor')),
                      ),
                      DropdownMenuItem(
                        value: 'labo_dashboard',
                        child: Text(_text('labo')),
                      ),
                      DropdownMenuItem(
                        value: 'pharmacy_dashboard',
                        child: Text(_text('pharmacy')),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => placement = value ?? 'dashboard'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_text('start_date')),
                    subtitle: Text(_dateLabel(startsAt) ?? _text('not_set')),
                    onTap: () async {
                      final selected = await showDatePicker(
                        context: dialogContext,
                        initialDate: startsAt ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (selected != null) {
                        setDialogState(() => startsAt = selected);
                      }
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_text('expiration_date')),
                    subtitle: Text(_dateLabel(expiresAt) ?? _text('not_set')),
                    onTap: () async {
                      final selected = await showDatePicker(
                        context: dialogContext,
                        initialDate: expiresAt ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (selected != null) {
                        setDialogState(() => expiresAt = selected);
                      }
                    },
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final url = await _pickAdImage();
                          if (url != null) {
                            setDialogState(() => imageUrl = url);
                          }
                        } on ApiException catch (error) {
                          _showMessage(error.message, isError: true);
                        } catch (error) {
                          _showMessage(error.toString(), isError: true);
                        }
                      },
                      icon: const Icon(Icons.image_outlined),
                      label: Text(
                        imageUrl == null
                            ? _text('upload_image')
                            : _text('image_uploaded'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: Text(_text('cancel')),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (title.text.trim().isEmpty) {
                        _showMessage(_text('ad_title_required'), isError: true);
                        return;
                      }
                      setDialogState(() => saving = true);
                      final payload = <String, dynamic>{
                        'title': title.text.trim(),
                        'description': description.text.trim(),
                        'destination_url': destination.text.trim(),
                        'image_url': imageUrl,
                        'placement': placement,
                        'starts_at': _datePayload(startsAt),
                        'expires_at': _datePayload(expiresAt),
                      };
                      try {
                        if (ad == null) {
                          await ApiService.post(
                            '/admin/advertisements',
                            payload,
                          );
                        } else {
                          await ApiService.put(
                            '/admin/advertisements/${ad['id']}',
                            payload,
                          );
                        }
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        _showMessage(_text('settings_saved'));
                        _loadAds();
                      } on ApiException catch (error) {
                        _showMessage(error.message, isError: true);
                        setDialogState(() => saving = false);
                      } catch (error) {
                        _showMessage(error.toString(), isError: true);
                        setDialogState(() => saving = false);
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_text('save')),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    description.dispose();
    destination.dispose();
  }

  Future<void> _loadAds() async {
    final response = await ApiService.get('/admin/advertisements');
    if (mounted) {
      setState(() {
        _ads = List<Map<String, dynamic>>.from(
          response['advertisements'] ?? [],
        );
      });
    }
  }

  Future<void> _setAdActive(Map<String, dynamic> ad, bool active) async {
    try {
      await ApiService.patch('/admin/advertisements/${ad['id']}/status', {
        'is_active': active,
      });
      await _loadAds();
    } on ApiException catch (error) {
      _showMessage(error.message, isError: true);
    } catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _deleteAd(Map<String, dynamic> ad) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_text('delete_ad')),
        content: Text(ad['title']?.toString() ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_text('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_text('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.delete('/admin/advertisements/${ad['id']}');
      await _loadAds();
    } on ApiException catch (error) {
      _showMessage(error.message, isError: true);
    } catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _editMapping(Map<String, dynamic> mapping) async {
    final selected = Set<String>.from(mapping['specialties'] ?? []);
    final updated = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(mapping['condition'].toString()),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 6,
                children: specialties.map((specialty) {
                  final isSelected = selected.contains(specialty);
                  return FilterChip(
                    label: Text(specialtyLabel(specialty, context)),
                    selected: isSelected,
                    onSelected: (value) => setDialogState(() {
                      if (value) {
                        selected.add(specialty);
                      } else {
                        selected.remove(specialty);
                      }
                    }),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_text('cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, selected),
              child: Text(_text('save')),
            ),
          ],
        ),
      ),
    );
    if (updated == null) return;
    try {
      await ApiService.put('/admin/condition-mappings/${mapping['id']}', {
        'specialties': updated.toList(),
      });
      await _loadMappings();
    } on ApiException catch (error) {
      _showMessage(error.message, isError: true);
    } catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _loadMappings() async {
    final response = await ApiService.get('/admin/condition-mappings');
    if (mounted) {
      setState(() {
        _mappings = List<Map<String, dynamic>>.from(response['mappings'] ?? []);
      });
    }
  }

  String? _dateLabel(DateTime? date) {
    if (date == null) return null;
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String? _datePayload(DateTime? date) {
    if (date == null) return null;
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} 00:00:00';
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

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(auth.name ?? _text('administrator')),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAll),
            IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: _text('settings')),
              Tab(text: _text('advertisements')),
              Tab(text: _text('transactions')),
              Tab(text: _text('condition_mappings')),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _settingsTab(),
                  _advertisementsTab(),
                  _transactionsTab(),
                  _mappingsTab(),
                ],
              ),
      ),
    );
  }

  Widget _settingsTab() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(
        _text('simulated_payment_notice'),
        style: const TextStyle(color: MediGoTheme.warningOrange),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _priceController,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: _text('consultation_price_dzd'),
          suffixText: 'DZD',
        ),
      ),
      const SizedBox(height: 12),
      ElevatedButton(
        onPressed: _savingPrice ? null : _savePrice,
        child: _savingPrice
            ? const CircularProgressIndicator()
            : Text(_text('save')),
      ),
    ],
  );

  Widget _advertisementsTab() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: () => _editAd(),
          icon: const Icon(Icons.add),
          label: Text(_text('create_ad')),
        ),
      ),
      const SizedBox(height: 12),
      if (_ads.isEmpty)
        Center(child: Text(_text('no_advertisements')))
      else
        ..._ads.map(
          (ad) => Card(
            child: ListTile(
              title: Text(ad['title']?.toString() ?? ''),
              subtitle: Text(
                '${ad['placement']} • ${ad['impressions']} ${_text('impressions')} • ${ad['clicks']} ${_text('clicks')}',
              ),
              leading: Icon(
                ad['is_active'] == 1 || ad['is_active'] == true
                    ? Icons.campaign
                    : Icons.pause_circle_outline,
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (action) {
                  if (action == 'edit') _editAd(ad);
                  if (action == 'delete') _deleteAd(ad);
                  if (action == 'toggle') {
                    _setAdActive(
                      ad,
                      !(ad['is_active'] == 1 || ad['is_active'] == true),
                    );
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text(_text('edit'))),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(
                      ad['is_active'] == 1 || ad['is_active'] == true
                          ? _text('deactivate')
                          : _text('activate'),
                    ),
                  ),
                  PopupMenuItem(value: 'delete', child: Text(_text('delete'))),
                ],
              ),
            ),
          ),
        ),
    ],
  );

  Widget _transactionsTab() => _transactions.isEmpty
      ? Center(child: Text(_text('no_transactions')))
      : ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _transactions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, index) {
            final item = _transactions[index];
            return Card(
              child: ListTile(
                leading: const Icon(
                  Icons.credit_card,
                  color: MediGoTheme.primaryBlue,
                ),
                title: Text(
                  '${item['amount']} ${item['currency']} • ${item['status']}',
                ),
                subtitle: Text(
                  '${item['patient_name']} • ${item['reference']} • **** ${item['card_last_four'] ?? '----'}',
                ),
                trailing: Text(item['created_at']?.toString() ?? ''),
              ),
            );
          },
        );

  Widget _mappingsTab() => ListView.separated(
    padding: const EdgeInsets.all(16),
    itemCount: _mappings.length,
    separatorBuilder: (_, __) => const SizedBox(height: 6),
    itemBuilder: (_, index) {
      final mapping = _mappings[index];
      final mappedSpecialties = List<String>.from(mapping['specialties'] ?? []);
      return Card(
        child: ListTile(
          title: Text(mapping['condition'].toString()),
          subtitle: Text(
            mappedSpecialties.isEmpty
                ? _text('no_specialty_mapping')
                : mappedSpecialties
                      .map((item) => specialtyLabel(item, context))
                      .join(', '),
          ),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () => _editMapping(mapping),
        ),
      );
    },
  );
}
