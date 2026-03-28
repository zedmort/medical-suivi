import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';
import 'providers/auth_provider.dart';
import 'providers/app_settings_provider.dart';
import 'services/api_service.dart';
import 'services/background_notification_worker.dart';
import 'screens/login_screen.dart';
import 'screens/doctor_dashboard.dart';
import 'screens/labo_dashboard.dart';
import 'screens/pharmacy_dashboard.dart';
import 'screens/patient_dashboard.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await Workmanager().registerPeriodicTask(
    'medical-notification-check',
    notificationCheckTask,
    frequency: const Duration(minutes: 15),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );

  await ApiService.syncBackgroundConfig();
  final auth = AuthProvider();
  await auth.loadFromStorage();
  final settings = AppSettingsProvider();
  await settings.load();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: settings),
      ],
      child: const MedicalApp(),
    ),
  );
}

class MedicalApp extends StatelessWidget {
  const MedicalApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    return MaterialApp(
      title: 'MediGo',
      debugShowCheckedModeBanner: false,
      locale: settings.locale,
      supportedLocales: const [
        Locale('en'),
        Locale('fr'),
        Locale('ar'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: settings.themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1976D2)),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1976D2),
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/doctor': (_) => const DoctorDashboard(),
        '/labo': (_) => const LaboDashboard(),
        '/pharmacy': (_) => const PharmacyDashboard(),
        '/patient': (_) => const PatientDashboard(),
      },
    );
  }
}
