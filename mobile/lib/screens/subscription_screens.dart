import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../l10n/app_texts.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/medi_go_theme.dart';
import '_dashboard_router.dart';

class SubscriptionPlansScreen extends StatefulWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  State<SubscriptionPlansScreen> createState() =>
      _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  List<Map<String, dynamic>> _plans = [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ApiService.get('/subscriptions/plans');
      final value = response['plans'];
      if (value is! List) {
        throw const FormatException('invalid_subscription_response');
      }
      final plans = <Map<String, dynamic>>[];
      for (final item in value) {
        if (item is! Map<String, dynamic> ||
            item['key'] is! String ||
            item['priceDzd'] is! num ||
            item['features'] is! List ||
            (item['features'] as List).any((feature) => feature is! String)) {
          throw const FormatException('invalid_subscription_response');
        }
        plans.add(item);
      }
      if (plans.isEmpty) {
        throw const FormatException('no_subscription_plans');
      }
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = AppTexts.of(
          context,
          error.statusCode == 0
              ? 'connection_failed'
              : 'subscription_load_failed',
        );
        _loading = false;
      });
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = AppTexts.of(context, error.message);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppTexts.of(context, key);
    final role = context.read<AuthProvider>().role;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              MediGoTheme.backgroundStart,
              MediGoTheme.backgroundEnd,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        const _SubscriptionBrand(),
                        const SizedBox(height: 28),
                        Text(
                          t('subscription_title'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: MediGoTheme.darkNavy,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t('subscription_subtitle'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: MediGoTheme.secondaryGrey,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Center(child: _DemoBadge(label: t('demo_no_charge'))),
                        const SizedBox(height: 24),
                        if (_loading)
                          const Center(child: CircularProgressIndicator())
                        else if (_error != null)
                          _ErrorPanel(
                            message: _error!,
                            retryLabel: t('try_again'),
                            onRetry: _loadPlans,
                          )
                        else
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final wide = constraints.maxWidth >= 700;
                              if (wide) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (
                                      var index = 0;
                                      index < _plans.length;
                                      index++
                                    ) ...[
                                      if (index > 0) const SizedBox(width: 14),
                                      Expanded(
                                        child: _PlanCard(
                                          plan: _plans[index],
                                          featured:
                                              _plans[index]['key'] ==
                                              'professional',
                                          onChoose: () =>
                                              _selectPlan(_plans[index]),
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              }
                              return Column(
                                children: [
                                  for (
                                    var index = 0;
                                    index < _plans.length;
                                    index++
                                  ) ...[
                                    if (index > 0) const SizedBox(height: 14),
                                    _PlanCard(
                                      plan: _plans[index],
                                      featured:
                                          _plans[index]['key'] ==
                                          'professional',
                                      onChoose: () =>
                                          _selectPlan(_plans[index]),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                        if (role != null) ...[
                          const SizedBox(height: 22),
                          Text(
                            t('subscription_demo_disclaimer'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: MediGoTheme.secondaryGrey,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _selectPlan(Map<String, dynamic> plan) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DemoPaymentScreen(plan: plan)),
    );
  }
}

class DemoPaymentScreen extends StatefulWidget {
  const DemoPaymentScreen({super.key, required this.plan});
  final Map<String, dynamic> plan;

  @override
  State<DemoPaymentScreen> createState() => _DemoPaymentScreenState();
}

class _DemoPaymentScreenState extends State<DemoPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardholderController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _securityCodeController = TextEditingController();
  bool _processing = false;
  String? _error;

  @override
  void dispose() {
    _cardholderController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _securityCodeController.dispose();
    super.dispose();
  }

  bool _isValidExpiry(String value) {
    final match = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(value.trim());
    if (match == null) return false;
    final month = int.parse(match.group(1)!);
    final year = 2000 + int.parse(match.group(2)!);
    if (month < 1 || month > 12) return false;
    final now = DateTime.now();
    return year > now.year || (year == now.year && month >= now.month);
  }

  bool _isValidCardholder(String value) =>
      value
          .trim()
          .split(RegExp(r'\s+'))
          .where((part) => part.isNotEmpty)
          .length >=
      2;

  bool _isValidCardNumber(String value) =>
      RegExp(r'^\d{16}$').hasMatch(value.replaceAll(RegExp(r'\D'), ''));

  Future<void> _validateDemoPayment() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _processing = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthProvider>();
    _clearCardFields();
    try {
      final planKey = widget.plan['key'];
      if (planKey is! String || planKey.isEmpty) {
        throw const FormatException('invalid_subscription_response');
      }
      await auth.activateDemoSubscription(planKey);
      if (!mounted) return;
      final activatedPlanKey =
          auth.subscription?['plan_key']?.toString() ?? planKey;
      final planName = AppTexts.of(context, 'plan_${activatedPlanKey}_name');
      final successMessage = AppTexts.of(
        context,
        'subscription_success_message',
      ).replaceFirst('{plan}', planName);
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${AppTexts.of(context, 'subscription_success_title')}\n'
                  '$successMessage',
                ),
              ),
            ],
          ),
        ),
      );
      DashboardRouter.go(context, auth.role);
    } on ApiException catch (error) {
      if (mounted) {
        setState(
          () => _error = AppTexts.of(
            context,
            error.statusCode == 0
                ? 'connection_failed'
                : 'subscription_activation_failed',
          ),
        );
      }
    } on FormatException catch (error) {
      if (mounted) {
        setState(() => _error = AppTexts.of(context, error.message));
      }
    } finally {
      if (mounted) {
        _clearCardFields();
        setState(() => _processing = false);
      }
    }
  }

  void _clearCardFields() {
    _cardholderController.clear();
    _cardNumberController.clear();
    _expiryController.clear();
    _securityCodeController.clear();
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppTexts.of(context, key);
    final planKey = widget.plan['key']?.toString() ?? '';
    final price = widget.plan['priceDzd']?.toString() ?? '';
    final planName = t('plan_${planKey}_name');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(t('demo_payment_title')),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(child: _DemoBadge(label: t('demo_sandbox'))),
                        const SizedBox(height: 12),
                        Text(
                          t('demo_payment_description'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: MediGoTheme.secondaryGrey,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          t('subscription_summary'),
                          style: const TextStyle(
                            color: MediGoTheme.darkNavy,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: MediGoTheme.backgroundStart,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: MediGoTheme.cardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                planName,
                                style: const TextStyle(
                                  color: MediGoTheme.darkNavy,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                t(
                                  'demo_plan_price',
                                ).replaceFirst('{price}', price),
                                style: const TextStyle(
                                  color: MediGoTheme.primaryBlue,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        _PaymentSectionHeading(
                          icon: Icons.person_outline_rounded,
                          title: t('payment_personal_info'),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _cardholderController,
                          textCapitalization: TextCapitalization.words,
                          keyboardType: TextInputType.name,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [],
                          decoration: InputDecoration(
                            labelText: t('subscription_demo_cardholder'),
                            prefixIcon: const Icon(
                              Icons.person_outline_rounded,
                            ),
                          ),
                          validator: (value) =>
                              value == null || !_isValidCardholder(value)
                              ? t('cardholder_required')
                              : null,
                        ),
                        const SizedBox(height: 22),
                        _PaymentSectionHeading(
                          icon: Icons.credit_card_rounded,
                          title: t('payment_card_info'),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _cardNumberController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [_CardNumberInputFormatter()],
                          autofillHints: const [],
                          decoration: InputDecoration(
                            labelText: t('demo_card_number'),
                            hintText: t('demo_card_number_hint'),
                            prefixIcon: const Icon(Icons.credit_card_rounded),
                          ),
                          validator: (value) => _isValidCardNumber(value ?? '')
                              ? null
                              : t('invalid_subscription_demo_card'),
                        ),
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final expiryField = TextFormField(
                              controller: _expiryController,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              inputFormatters: [_ExpiryInputFormatter()],
                              autofillHints: const [],
                              decoration: InputDecoration(
                                labelText: t('expiry_date'),
                                hintText: 'MM/YY',
                                prefixIcon: const Icon(
                                  Icons.calendar_month_rounded,
                                ),
                              ),
                              validator: (value) => !_isValidExpiry(value ?? '')
                                  ? t('invalid_expiry')
                                  : null,
                            );
                            final cvvField = TextFormField(
                              controller: _securityCodeController,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(3),
                              ],
                              obscureText: true,
                              autofillHints: const [],
                              decoration: InputDecoration(
                                labelText: t('demo_security_code'),
                                hintText: '•••',
                                counterText: '',
                                prefixIcon: const Icon(Icons.lock_outline),
                              ),
                              validator: (value) =>
                                  RegExp(r'^\d{3}$').hasMatch(value ?? '')
                                  ? null
                                  : t('invalid_cvv'),
                            );
                            if (constraints.maxWidth < 440) {
                              return Column(
                                children: [
                                  expiryField,
                                  const SizedBox(height: 14),
                                  cvvField,
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: expiryField),
                                const SizedBox(width: 12),
                                Expanded(child: cvvField),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        _InfoRow(
                          icon: Icons.shield_outlined,
                          text: t('subscription_card_demo_notice'),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: MediGoTheme.heartRed),
                          ),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 54,
                          child: FilledButton.icon(
                            onPressed: _processing
                                ? null
                                : _validateDemoPayment,
                            icon: _processing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.verified_user_rounded),
                            label: Text(t('validate').toUpperCase()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentSectionHeading extends StatelessWidget {
  const _PaymentSectionHeading({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: MediGoTheme.primaryBlue, size: 20),
      const SizedBox(width: 8),
      Text(
        title,
        style: const TextStyle(
          color: MediGoTheme.darkNavy,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limitedDigits = digits.length > 16 ? digits.substring(0, 16) : digits;
    final formatted = limitedDigits
        .replaceAllMapped(RegExp(r'.{4}'), (match) => '${match[0]} ')
        .trimRight();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _ExpiryInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limitedDigits = digits.length > 4 ? digits.substring(0, 4) : digits;
    final formatted = limitedDigits.length > 2
        ? '${limitedDigits.substring(0, 2)}/${limitedDigits.substring(2)}'
        : limitedDigits;
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class SubscriptionSuccessScreen extends StatelessWidget {
  const SubscriptionSuccessScreen({super.key, required this.planName});
  final String planName;

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppTexts.of(context, key);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.green,
                      size: 60,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    t('subscription_success_title'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: MediGoTheme.darkNavy,
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    t(
                      'subscription_success_message',
                    ).replaceFirst('{plan}', planName),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: MediGoTheme.secondaryGrey,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _DemoBadge(label: t('demo_confirmation')),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => DashboardRouter.go(
                        context,
                        context.read<AuthProvider>().role,
                      ),
                      child: Text(t('go_to_dashboard')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.featured,
    required this.onChoose,
  });
  final Map<String, dynamic> plan;
  final bool featured;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppTexts.of(context, key);
    final planKey = plan['key']?.toString() ?? '';
    final features = (plan['features'] as List? ?? const [])
        .whereType<String>()
        .toList();
    final price = plan['priceDzd'];

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: featured ? MediGoTheme.primaryBlue : MediGoTheme.cardBorder,
          width: featured ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (featured)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: _DemoBadge(label: t('recommended_plan')),
              ),
            const SizedBox(height: 8),
            Text(
              t('plan_${planKey}_name'),
              style: const TextStyle(
                color: MediGoTheme.darkNavy,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t('demo_plan_price').replaceFirst('{price}', '$price'),
              style: const TextStyle(
                color: MediGoTheme.primaryBlue,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            for (final feature in features) ...[
              _InfoRow(
                icon: Icons.check_circle_outline_rounded,
                text: t(feature),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 10),
            OutlinedButton(onPressed: onChoose, child: Text(t('choose_plan'))),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionBrand extends StatelessWidget {
  const _SubscriptionBrand();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MediGoTheme.primaryBlue, MediGoTheme.deepBlueEnd],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Icon(
        Icons.medical_services_rounded,
        color: Colors.white,
        size: 32,
      ),
    ),
  );
}

class _DemoBadge extends StatelessWidget {
  const _DemoBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: MediGoTheme.primaryBlue.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: MediGoTheme.primaryBlue,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: MediGoTheme.primaryBlue),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(color: MediGoTheme.secondaryGrey, height: 1.4),
        ),
      ),
    ],
  );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: MediGoTheme.heartRed),
      ),
      const SizedBox(height: 12),
      OutlinedButton(onPressed: onRetry, child: Text(retryLabel)),
    ],
  );
}
