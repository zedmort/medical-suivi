import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/medical_taxonomy.dart';
import '../l10n/app_texts.dart';
import '../providers/app_settings_provider.dart';
import '../providers/auth_provider.dart';
import 'legal_document_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<AppSettingsProvider>();
    String t(String key) => AppTexts.of(context, key);

    return Scaffold(
      appBar: AppBar(title: Text(t('profile'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(auth.name ?? 'User'),
              subtitle: Text(
                auth.role == 'doctor' && (auth.specialty?.isNotEmpty ?? false)
                    ? '${t('user_role')}: ${t(auth.role ?? '')}\n${t('doctor_specialty')}: ${specialtyLabel(auth.specialty ?? '', context)}'
                    : '${t('user_role')}: ${t(auth.role ?? '')}',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: Text(t('appearance')),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: Text(t('dark_mode')),
                  value: settings.themeMode == ThemeMode.dark,
                  onChanged: (isDark) {
                    settings.setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(t('settings_saved'))),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.language_outlined),
                  title: Text(t('language')),
                  trailing: DropdownButton<String>(
                    value: settings.locale.languageCode,
                    underline: const SizedBox.shrink(),
                    onChanged: (code) {
                      if (code == null) return;
                      settings.setLocale(Locale(code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(t('settings_saved'))),
                      );
                    },
                    items: [
                      DropdownMenuItem(
                        value: 'en',
                        child: Text(t('language_english')),
                      ),
                      DropdownMenuItem(
                        value: 'fr',
                        child: Text(t('language_french')),
                      ),
                      DropdownMenuItem(
                        value: 'ar',
                        child: Text(t('language_arabic')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.gavel_outlined),
                  title: Text(t('terms')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LegalDocumentScreen(type: LegalDocumentType.terms),
                      ),
                    );
                  },
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(t('privacy')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LegalDocumentScreen(type: LegalDocumentType.privacy),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
