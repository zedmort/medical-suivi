import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mobile/l10n/app_texts.dart';
import 'package:mobile/providers/auth_provider.dart';
import 'package:mobile/screens/_dashboard_router.dart';
import 'package:mobile/screens/patient_dashboard.dart';
import 'package:mobile/screens/medical_document_screen.dart';
import 'package:mobile/screens/medical_assistant_screen.dart';
import 'package:mobile/screens/subscription_screens.dart';
import 'package:mobile/widgets/notification_bell.dart';
import 'package:mobile/widgets/dashboard_shell.dart';
import 'package:mobile/screens/role_selection_screen.dart';
import 'package:mobile/screens/register_screen.dart';
import 'package:mobile/theme/medi_go_theme.dart';

void main() {
  testWidgets('signup form scrolls without bottom overflow on short screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: _RoleAuthProvider('patient'),
        child: const MaterialApp(
          locale: Locale('fr'),
          supportedLocales: [Locale('fr')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: RegisterScreen(initialRole: 'patient'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  testWidgets('dashboard tabs stay readable and scroll on narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: DefaultTabController(
          length: 4,
          child: Builder(
            builder: (context) => Scaffold(
              appBar: AppBar(
                bottom: DashboardTabBar(
                  controller: DefaultTabController.of(context),
                  tabs: const [
                    Tab(icon: Icon(Icons.group), text: 'Patients'),
                    Tab(icon: Icon(Icons.biotech), text: 'Analyses'),
                    Tab(icon: Icon(Icons.receipt_long), text: 'Ordonnances'),
                    Tab(icon: Icon(Icons.monitor_heart), text: 'Consultations'),
                  ],
                ),
              ),
              body: const SizedBox(),
            ),
          ),
        ),
      ),
    );

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.isScrollable, isTrue);
    expect(tabBar.labelColor, MediGoTheme.cardSurface);
    expect(tabBar.unselectedLabelColor, MediGoTheme.secondaryGrey);
    expect(find.text('Analyses'), findsOneWidget);
    expect(find.text('Ordonnances'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('medical assistant screen refuses non-patient roles', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: _RoleAuthProvider('doctor'),
        child: const MaterialApp(
          locale: Locale('fr'),
          supportedLocales: [Locale('fr')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: MedicalAssistantScreen(),
        ),
      ),
    );

    expect(find.text('Assistant médical IA'), findsOneWidget);
    expect(
      find.text('Cette fonctionnalité est réservée aux patients.'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
  });

  test('only unsubscribed professional roles require a plan', () {
    expect(DashboardRouter.subscriptionRequired('doctor', false), isTrue);
    expect(DashboardRouter.subscriptionRequired('pharmacy', false), isTrue);
    expect(DashboardRouter.subscriptionRequired('labo', false), isTrue);
    expect(DashboardRouter.subscriptionRequired('doctor', true), isFalse);
    expect(DashboardRouter.subscriptionRequired('patient', false), isFalse);
    expect(DashboardRouter.subscriptionRequired('admin', false), isFalse);
  });

  testWidgets('subscription payment uses a local-only demo card form', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const DemoPaymentScreen(
          plan: {'key': 'professional', 'priceDzd': 2500},
        ),
      ),
    );

    expect(find.text('DÉMO • SANDBOX'), findsOneWidget);
    expect(find.text('Offre sélectionnée'), findsOneWidget);
    expect(find.text('Informations personnelles'), findsOneWidget);
    expect(find.text('Informations de la carte'), findsOneWidget);
    expect(find.text('Professionnel'), findsOneWidget);
    expect(find.textContaining('2500 DZD'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(4));
    expect(find.text('Nom complet du titulaire'), findsOneWidget);
    expect(
      find.textContaining('Les champs démo sont vérifiés sur cet appareil'),
      findsOneWidget,
    );
    expect(find.text('VALIDER'), findsOneWidget);

    await tester.ensureVisible(find.text('VALIDER'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('VALIDER'));
    await tester.pump();

    expect(
      find.text('Saisissez le nom et le prénom du titulaire'),
      findsOneWidget,
    );
    expect(
      find.text('Saisissez un numéro de carte à 16 chiffres.'),
      findsOneWidget,
    );
    expect(
      find.text('Saisissez une date future valide au format MM/AA'),
      findsOneWidget,
    );
    expect(find.text('Saisissez un CVV à 3 chiffres'), findsOneWidget);

    final cardNumberField = find.byType(TextFormField).at(1);
    final expiryField = find.byType(TextFormField).at(2);
    final cvvField = find.byType(TextFormField).at(3);
    await tester.enterText(cardNumberField, '1234567890123456');
    await tester.enterText(expiryField, '1229');
    await tester.enterText(cvvField, '987');

    expect(
      tester.widget<TextFormField>(cardNumberField).controller!.text,
      '1234 5678 9012 3456',
    );
    expect(tester.widget<TextFormField>(expiryField).controller!.text, '12/29');
    expect(tester.widget<TextFormField>(cvvField).controller!.text, '987');

    await tester.tap(find.text('VALIDER'));
    await tester.pump();
    expect(
      find.text('Saisissez un numéro de carte à 16 chiffres.'),
      findsNothing,
    );
    expect(find.text('Saisissez un CVV à 3 chiffres'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('medical document viewer identifies PDFs and missing links', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const MedicalDocumentScreen(
          title: 'Ordonnance #17',
          type: 'Ordonnance',
          date: '25 oct. 2026',
          fileUrl: '/uploads/prescription-17.pdf',
        ),
      ),
    );

    expect(find.text('Ordonnance #17'), findsNWidgets(2));
    expect(find.textContaining('Ouvrez ce PDF'), findsOneWidget);
    expect(find.text('Ouvrir le document'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        supportedLocales: const [Locale('en'), Locale('fr')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const MedicalDocumentScreen(
          title: 'Document absent',
          type: 'PDF',
          date: '–',
          fileUrl: '',
        ),
      ),
    );
    expect(
      find.text('Le lien du document est absent ou invalide.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('themed dialog action buttons fit in a row', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: MediGoTheme.buildTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => Dialog(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const TextField(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () {},
                                  child: const Text('Annuler'),
                                ),
                                ElevatedButton(
                                  onPressed: () {},
                                  child: const Text('Envoyer'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Envoyer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('role cards fit on a narrow phone screen', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: RoleSelectionScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Patient'), findsOneWidget);
    expect(find.text('Doctor'), findsOneWidget);
    expect(find.text('Laboratory'), findsOneWidget);
    expect(find.text('Pharmacy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chosen role is not requested again in registration', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RoleSelectionScreen()));
    await tester.tap(find.text('Doctor'));
    await tester.pumpAndSettle();

    expect(find.text('Registering as Doctor'), findsOneWidget);
    expect(find.text('Select your role'), findsNothing);
    expect(find.text('Diabetes'), findsOneWidget);
    expect(find.text('Thyroid diseases'), findsOneWidget);
    expect(find.text('Cardiology'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('patient signup replaces the form with one dashboard screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => DashboardRouter.go(context, 'patient'),
                child: const Text('Complete signup'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Complete signup'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('Complete signup'), findsNothing);
    expect(find.byType(PatientDashboard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arabic patient dashboard header fits on a phone screen', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewPadding);

    const notificationChannel = MethodChannel(
      'dexterous.com/flutter/local_notifications',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationChannel, (_) async => true);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(notificationChannel, null),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: _LongNameAuthProvider(),
        child: const MaterialApp(
          locale: Locale('ar'),
          supportedLocales: [Locale('ar')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: PatientDashboard(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(PatientDashboard), findsOneWidget);
    expect(find.text('سماح دروم اسم طويل جدا لاختبار العنوان'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    final appBarRect = tester.getRect(find.byType(AppBar));
    expect(tester.getSize(find.byType(AppBar)).height, 144);
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 1);
    expect(find.text('تحاليلـي'), findsOneWidget);
    expect(find.text('وصفة طبية'), findsOneWidget);
    expect(find.text('تقدمي الصحي'), findsOneWidget);
    for (final tab in tester.widgetList<Tab>(find.byType(Tab))) {
      expect(
        tester.getRect(find.byWidget(tab)).bottom,
        lessThanOrEqualTo(appBarRect.bottom),
      );
    }

    final dashboardContext = tester.element(find.byType(PatientDashboard));
    expect(Directionality.of(dashboardContext), TextDirection.rtl);
    expect(
      tester.getTopLeft(find.byType(Scaffold)).dy,
      tester.view.viewPadding.top,
    );
    expect(
      find.byTooltip(AppTexts.of(dashboardContext, 'find_doctor')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: find.byType(NotificationBell),
              matching: find.byIcon(Icons.notifications_outlined),
            ),
          )
          .color,
      MediGoTheme.darkNavy,
    );
    expect(tester.getRect(find.byType(AppBar)).width, 320);
    expect(tester.takeException(), isNull);
  });

  testWidgets('French patient labels use left-to-right layout', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale('fr'),
        supportedLocales: [Locale('fr')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const _FrenchPatientLabels(),
      ),
    );

    expect(find.text('Tableau de bord patient'), findsOneWidget);
    expect(find.text('Mes analyses'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('Tableau de bord patient'))),
      TextDirection.ltr,
    );
  });
}

class _FrenchPatientLabels extends StatelessWidget {
  const _FrenchPatientLabels();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(AppTexts.of(context, 'patient_dashboard')),
      Text(AppTexts.of(context, 'my_analyses')),
    ],
  );
}

class _LongNameAuthProvider extends AuthProvider {
  @override
  String? get name => 'سماح دروم اسم طويل جدا لاختبار العنوان';
}

class _RoleAuthProvider extends AuthProvider {
  _RoleAuthProvider(this._role);

  final String _role;

  @override
  String? get role => _role;
}
