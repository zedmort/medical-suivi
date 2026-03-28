import 'package:flutter/material.dart';
import 'doctor_dashboard.dart';
import 'labo_dashboard.dart';
import 'pharmacy_dashboard.dart';
import 'patient_dashboard.dart';
import 'login_screen.dart';

/// Helper to navigate to the correct dashboard based on role,
/// clearing the entire navigation stack.
class DashboardRouter {
  static void go(BuildContext context, String? role) {
    Widget screen;
    switch (role) {
      case 'doctor':
        screen = const DoctorDashboard();
        break;
      case 'labo':
        screen = const LaboDashboard();
        break;
      case 'pharmacy':
        screen = const PharmacyDashboard();
        break;
      case 'patient':
        screen = const PatientDashboard();
        break;
      default:
        screen = const LoginScreen();
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => screen),
      (_) => false,
    );
  }
}
