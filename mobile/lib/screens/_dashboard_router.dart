import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'doctor_dashboard.dart';
import 'labo_dashboard.dart';
import 'pharmacy_dashboard.dart';
import 'patient_dashboard.dart';
import 'login_screen.dart';
import 'admin_dashboard.dart';
import 'subscription_screens.dart';

/// Helper to navigate to the correct dashboard based on role,
/// clearing the entire navigation stack.
class DashboardRouter {
  static bool subscriptionRequired(String? role, bool hasActiveSubscription) =>
      const {'doctor', 'pharmacy', 'labo'}.contains(role) &&
      !hasActiveSubscription;

  static Widget screenForRole(BuildContext context, String? role) {
    final auth = context.read<AuthProvider>();
    final effectiveRole = auth.role ?? role;
    if (subscriptionRequired(effectiveRole, auth.hasActiveSubscription)) {
      return const SubscriptionPlansScreen();
    }

    switch (effectiveRole) {
      case 'doctor':
        return const DoctorDashboard();
      case 'labo':
        return const LaboDashboard();
      case 'pharmacy':
        return const PharmacyDashboard();
      case 'patient':
        return const PatientDashboard();
      case 'admin':
        return const AdminDashboard();
      default:
        return const LoginScreen();
    }
  }

  static void go(BuildContext context, String? role) {
    final screen = screenForRole(context, role);
    Navigator.pushAndRemoveUntil<void>(
      context,
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, _, _) => screen,
      ),
      (_) => false,
    );
  }
}
