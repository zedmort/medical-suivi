import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mobile/providers/auth_provider.dart';
import 'package:mobile/screens/_dashboard_router.dart';
import 'package:mobile/screens/patient_dashboard.dart';
import 'package:mobile/widgets/notification_bell.dart';
import 'package:mobile/screens/role_selection_screen.dart';
import 'package:mobile/theme/medi_go_theme.dart';

void main() {
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
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
    expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    expect(find.byTooltip('Find a doctor'), findsOneWidget);
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
    expect(tester.getRect(find.byType(AppBar)).width, 360);
    expect(tester.takeException(), isNull);
  });
}

class _LongNameAuthProvider extends AuthProvider {
  @override
  String? get name => 'سماح دروم اسم طويل جدا لاختبار العنوان';
}
