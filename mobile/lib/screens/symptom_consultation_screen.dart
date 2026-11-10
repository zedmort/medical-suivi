import 'dart:math';
import 'package:flutter/material.dart';
import '../l10n/app_texts.dart';
import '../services/api_service.dart';
import '../theme/medi_go_theme.dart';

class SymptomConsultationScreen extends StatefulWidget {
  const SymptomConsultationScreen({super.key});

  @override
  State<SymptomConsultationScreen> createState() =>
      _SymptomConsultationScreenState();
}

class _SymptomConsultationScreenState extends State<SymptomConsultationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _symptoms = TextEditingController();
  final _notes = TextEditingController();
  final _cardholder = TextEditingController();
  final _cardNumber = TextEditingController();
  final _expiry = TextEditingController();
  final _cvv = TextEditingController();
  List<Map<String, dynamic>> _doctors = [];
  List<Map<String, dynamic>> _history = [];
  Map<String, dynamic>? _price;
  Map<String, dynamic>? _lastPayment;
  int? _doctorId;
  String _idempotencyKey = _newIdempotencyKey();
  bool _loading = true;
  bool _paying = false;

  static String _newIdempotencyKey() {
    final random = Random.secure();
    return List.generate(
      4,
      (_) => random.nextInt(1 << 32).toRadixString(36).padLeft(7, '0'),
    ).join('-');
  }

  String _text(String key) => AppTexts.of(context, key);

  bool _isFutureExpiry(String value) {
    final match = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(value.trim());
    if (match == null) return false;
    final month = int.parse(match.group(1)!);
    final year = 2000 + int.parse(match.group(2)!);
    if (month < 1 || month > 12) return false;
    final now = DateTime.now();
    return year > now.year || (year == now.year && month >= now.month);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _symptoms.dispose();
    _notes.dispose();
    _cardholder.dispose();
    _cardNumber.dispose();
    _expiry.dispose();
    _cvv.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final responses = await Future.wait([
        ApiService.get('/consultations/price'),
        ApiService.get('/patients/me/doctors'),
        ApiService.get('/users/doctors'),
        ApiService.get('/users/me'),
        ApiService.get('/consultations/mine'),
      ]);
      if (!mounted) return;

      final recommended = List<Map<String, dynamic>>.from(
        responses[1]['doctors'] ?? [],
      );
      final allDoctors = List<Map<String, dynamic>>.from(
        responses[2]['doctors'] ?? [],
      );
      final prioritized = <int>{};
      final ordered = <Map<String, dynamic>>[];
      for (final doctor in [...recommended, ...allDoctors]) {
        final id = int.tryParse(doctor['id']?.toString() ?? '');
        if (id != null && prioritized.add(id)) ordered.add(doctor);
      }
      final user = Map<String, dynamic>.from(responses[3]['user'] ?? {});
      final patient = Map<String, dynamic>.from(user['patient'] ?? {});
      final currentDoctorId = int.tryParse(
        patient['doctor_id']?.toString() ?? '',
      );
      final currentDoctor = currentDoctorId == null
          ? null
          : ordered.where(
              (item) =>
                  int.tryParse(item['id']?.toString() ?? '') == currentDoctorId,
            );

      setState(() {
        _price = responses[0];
        _doctors = ordered;
        _doctorId = currentDoctor != null && currentDoctor.isNotEmpty
            ? currentDoctorId
            : (recommended.isNotEmpty
                  ? int.tryParse(recommended.first['id']?.toString() ?? '')
                  : null);
        _history = List<Map<String, dynamic>>.from(
          responses[4]['consultations'] ?? [],
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

  Future<void> _pay() async {
    if (!_formKey.currentState!.validate()) return;
    if (_doctorId == null) {
      _showMessage(_text('choose_consultation_doctor'), isError: true);
      return;
    }
    if (_price?['amountDzd'] == null) {
      _showMessage(_text('price_not_configured'), isError: true);
      return;
    }

    setState(() => _paying = true);
    try {
      final response = await ApiService.post('/consultations/symptoms/pay', {
        'symptoms': _symptoms.text.trim(),
        'notes': _notes.text.trim(),
        'doctor_id': _doctorId,
        'idempotency_key': _idempotencyKey,
        'cardholder': _cardholder.text.trim(),
        'card_number': _cardNumber.text,
        'expiry': _expiry.text.trim(),
        'cvv': _cvv.text.trim(),
      });
      if (!mounted) return;
      setState(() {
        _lastPayment = Map<String, dynamic>.from(response['transaction'] ?? {});
        _idempotencyKey = _newIdempotencyKey();
      });
      _showMessage(
        response['message']?.toString() ?? _text('payment_processed'),
        isError: response['transaction']?['status'] != 'succeeded',
      );
      _cardNumber.clear();
      _cvv.clear();
      try {
        await _loadHistory();
      } on ApiException catch (error) {
        _showMessage(error.message, isError: true);
      }
    } on ApiException catch (error) {
      _showMessage(error.message, isError: true);
    } catch (error) {
      _showMessage(error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _loadHistory() async {
    final response = await ApiService.get('/consultations/mine');
    if (mounted) {
      setState(() {
        _history = List<Map<String, dynamic>>.from(
          response['consultations'] ?? [],
        );
      });
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
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(_text('symptom_consultation'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final amount = _price?['amountDzd'];
    return Scaffold(
      appBar: AppBar(title: Text(_text('symptom_consultation'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1E8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: MediGoTheme.warningOrange),
            ),
            child: Text(
              _text('emergency_warning'),
              style: const TextStyle(
                color: Color(0xFF8A3B00),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _text('recommendation_not_diagnosis'),
            style: const TextStyle(color: MediGoTheme.secondaryGrey),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _symptoms,
                      minLines: 4,
                      maxLines: 8,
                      decoration: InputDecoration(
                        labelText: _text('describe_symptoms'),
                        alignLabelWithHint: true,
                      ),
                      validator: (value) =>
                          value == null || value.trim().length < 10
                          ? _text('symptoms_required')
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _notes,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: _text('additional_information'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      initialValue: _doctorId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: _text('consultation_doctor'),
                      ),
                      items: _doctors
                          .map(
                            (doctor) => DropdownMenuItem<int>(
                              value: int.tryParse(
                                doctor['id']?.toString() ?? '',
                              ),
                              child: Text(
                                doctor['name']?.toString() ?? '',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _doctorId = value),
                      validator: (value) => value == null
                          ? _text('choose_consultation_doctor')
                          : null,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      amount == null
                          ? _text('price_not_configured')
                          : '${_text('consultation_price')}: $amount DZD',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: MediGoTheme.darkNavy,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _text('demo_payment_only'),
                      style: const TextStyle(
                        color: MediGoTheme.warningOrange,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _text('demo_card_instructions'),
                      style: const TextStyle(
                        color: MediGoTheme.secondaryGrey,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _cardholder,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: _text('cardholder_name'),
                      ),
                      validator: (value) =>
                          value == null || value.trim().length < 2
                          ? _text('cardholder_required')
                          : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _cardNumber,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: _text('demo_card_number'),
                        hintText: '4111 1111 1111 1111',
                      ),
                      validator: (value) {
                        final digits = (value ?? '').replaceAll(
                          RegExp(r'\s'),
                          '',
                        );
                        return digits.length != 16
                            ? _text('invalid_demo_card')
                            : null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _expiry,
                            keyboardType: TextInputType.datetime,
                            decoration: InputDecoration(
                              labelText: _text('expiry_date'),
                              hintText: 'MM/YY',
                            ),
                            validator: (value) => !_isFutureExpiry(value ?? '')
                                ? _text('invalid_expiry')
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _cvv,
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: _text('cvv'),
                              hintText: '123',
                            ),
                            validator: (value) =>
                                !RegExp(
                                  r'^\d{3}$',
                                ).hasMatch(value?.trim() ?? '')
                                ? _text('invalid_cvv')
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _paying || amount == null ? null : _pay,
                      icon: const Icon(Icons.lock_outline),
                      label: _paying
                          ? const CircularProgressIndicator()
                          : Text(_text('pay_demo')),
                    ),
                    if (_lastPayment != null) ...[
                      const SizedBox(height: 14),
                      _paymentReceipt(_lastPayment!),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _text('consultation_history'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
          ),
          const SizedBox(height: 8),
          if (_history.isEmpty)
            Text(_text('no_consultations'))
          else
            ..._history.map(_consultationCard),
        ],
      ),
    );
  }

  Widget _paymentReceipt(Map<String, dynamic> payment) {
    final succeeded = payment['status'] == 'succeeded';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: succeeded ? MediGoTheme.greenChipBg : MediGoTheme.orangeChipBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            succeeded
                ? _text('demo_payment_success')
                : _text('demo_payment_failed'),
            style: TextStyle(
              color: succeeded
                  ? MediGoTheme.successGreen
                  : MediGoTheme.warningOrange,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '${_text('transaction_reference')}: ${payment['reference'] ?? ''}',
          ),
          Text('${payment['amount'] ?? ''} ${payment['currency'] ?? 'DZD'}'),
        ],
      ),
    );
  }

  Widget _consultationCard(Map<String, dynamic> consultation) => Card(
    child: ListTile(
      leading: Icon(
        consultation['payment_status'] == 'succeeded'
            ? Icons.check_circle_outline
            : Icons.error_outline,
        color: consultation['payment_status'] == 'succeeded'
            ? MediGoTheme.successGreen
            : MediGoTheme.heartRed,
      ),
      title: Text(
        '${_text('consultation')} #${consultation['id']} • ${consultation['status']}',
      ),
      subtitle: Text(
        '${consultation['doctor_name'] ?? _text('doctor_not_assigned')} • ${consultation['reference']}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}
