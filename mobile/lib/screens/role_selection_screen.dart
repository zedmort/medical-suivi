import 'package:flutter/material.dart';

import '../l10n/app_texts.dart';
import '../theme/medi_go_theme.dart';
import 'register_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  static const _roles = [
    {
      'value': 'patient',
      'icon': Icons.person_rounded,
      'description': 'role_patient_description',
    },
    {
      'value': 'doctor',
      'icon': Icons.medical_services_rounded,
      'description': 'role_doctor_description',
    },
    {
      'value': 'labo',
      'icon': Icons.biotech_rounded,
      'description': 'role_labo_description',
    },
    {
      'value': 'pharmacy',
      'icon': Icons.local_pharmacy_rounded,
      'description': 'role_pharmacy_description',
    },
  ];

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppTexts.of(context, key);

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    width: 98,
                    height: 98,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          MediGoTheme.primaryBlue,
                          MediGoTheme.deepBlueEnd,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(
                      Icons.medical_information_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  t('select_role'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: MediGoTheme.darkNavy,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t('role_selection_subtitle'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: MediGoTheme.secondaryGrey,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 26),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 680 ? 2 : 1;
                    final roles = _roles.map((role) {
                      final value = role['value'] as String;
                      return _roleCard(
                        context,
                        title: t(value),
                        description: t(role['description'] as String),
                        icon: role['icon'] as IconData,
                        role: value,
                      );
                    }).toList();

                    if (columns == 1) {
                      return Column(
                        children: [
                          for (
                            var index = 0;
                            index < roles.length;
                            index++
                          ) ...[
                            if (index > 0) const SizedBox(height: 12),
                            roles[index],
                          ],
                        ],
                      );
                    }

                    return GridView.count(
                      crossAxisCount: columns,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 2.25,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: roles,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required String role,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => RegisterScreen(initialRole: role)),
        );
      },
      borderRadius: BorderRadius.circular(22),
      child: Container(
        constraints: const BoxConstraints(minHeight: 104),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: MediGoTheme.borderSoft),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F0B57D8),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [MediGoTheme.primaryBlue, MediGoTheme.deepBlueEnd],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: MediGoTheme.darkNavy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: MediGoTheme.secondaryGrey,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: MediGoTheme.primaryBlue,
            ),
          ],
        ),
      ),
    );
  }
}
