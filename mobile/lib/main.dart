import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
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
import 'screens/admin_dashboard.dart';
import 'screens/splash_screen.dart';
import 'theme/medi_go_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Workmanager().initialize(callbackDispatcher);
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
      supportedLocales: const [Locale('en'), Locale('fr'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: settings.themeMode,
      theme: MediGoTheme.buildTheme().copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(
          MediGoTheme.buildTheme().textTheme,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: MediGoTheme.darkNavy,
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: MediGoTheme.darkNavy),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0755C9),
          brightness: Brightness.dark,
        ),
      ),
      home: const SplashScreen(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/doctor': (_) => const DoctorDashboard(),
        '/labo': (_) => const LaboDashboard(),
        '/pharmacy': (_) => const PharmacyDashboard(),
        '/patient': (_) => const PatientDashboard(),
        '/admin': (_) => const AdminDashboard(),
      },
    );
  }
}
