import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _subscription;
  bool _loading = false;

  Map<String, dynamic>? get user => _user;
  bool get loading => _loading;
  bool get isAuthenticated => _user != null;
  bool get hasActiveSubscription => _subscription?['status'] == 'active';
  Map<String, dynamic>? get subscription => _subscription;
  String? get role => _user?['role'];
  String? get name => _user?['name'];
  String? get specialty => _user?['specialty']?.toString();
  int? get userId {
    final id = _user?['id'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '');
  }

  /// Called at app startup to restore session from secure storage.
  Future<void> loadFromStorage() async {
    final token = await ApiService.getToken();
    final user = await ApiService.getSavedUser();
    if (token != null && user != null) {
      _user = user;
      final savedSubscription = user['subscription'];
      _subscription = savedSubscription is Map<String, dynamic>
          ? savedSubscription
          : null;
      if (role != 'patient' &&
          const {'doctor', 'pharmacy', 'labo'}.contains(role)) {
        try {
          await refreshSubscription();
        } on ApiException {
          // Keep the last persisted status when the server is temporarily unreachable.
        }
      }
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    _setLoading(true);
    try {
      final data = await ApiService.post('/auth/login', {
        'email': email.trim().toLowerCase(),
        'password': password,
      }, auth: false);
      await ApiService.saveToken(data['token'] as String);
      _subscription = null;
      _user = data['user'] as Map<String, dynamic>;
      await ApiService.saveUser(_user!);
      try {
        await refreshSubscription();
      } on ApiException catch (error) {
        debugPrint(
          'Subscription lookup failed after login '
          '(HTTP ${error.statusCode}): ${error.message}',
        );
        _subscription = null;
        _user = {..._user!, 'subscription': null};
        await ApiService.saveUser(_user!);
        notifyListeners();
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> register(
    String name,
    String email,
    String password,
    String role, {
    Map<String, dynamic>? extraData,
  }) async {
    _setLoading(true);
    try {
      final payload = {
        'name': name,
        'email': email,
        'password': password,
        'role': role,
        ...?extraData,
      };
      try {
        await ApiService.post('/auth/register', payload, auth: false);
      } on ApiException catch (error) {
        if (error.statusCode != 409) rethrow;
        try {
          await login(email, password);
          return;
        } on ApiException catch (loginError) {
          if (loginError.statusCode == 401 || loginError.statusCode == 403) {
            throw const ApiException('email_already_registered_login', 409);
          }
          throw const ApiException('email_registered_login_retry', 409);
        }
      }
      await login(email, password);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    await ApiService.clearAll();
    _user = null;
    _subscription = null;
    notifyListeners();
  }

  Future<void> refreshSubscription() async {
    final currentRole = role;
    if (currentRole == 'patient' ||
        !const {'doctor', 'pharmacy', 'labo'}.contains(currentRole)) {
      _subscription = null;
      if (_user != null) {
        _user = {..._user!, 'subscription': null};
        await ApiService.saveUser(_user!);
      }
      notifyListeners();
      return;
    }

    final data = await ApiService.get('/subscriptions/me');
    final value = data['subscription'];
    _subscription = value is Map<String, dynamic> ? value : null;
    if (_user != null) {
      _user = {..._user!, 'subscription': _subscription};
      await ApiService.saveUser(_user!);
    }
    notifyListeners();
  }

  Future<void> activateDemoSubscription(String planKey) async {
    final data = await ApiService.post('/subscriptions/activate-demo', {
      'plan_key': planKey,
    });
    final value = data['subscription'];
    if (value is! Map<String, dynamic> || value['status'] != 'active') {
      throw const ApiException('The demo subscription was not activated.', 500);
    }
    _subscription = value;
    if (_user != null) {
      _user = {..._user!, 'subscription': _subscription};
      await ApiService.saveUser(_user!);
    }
    notifyListeners();
  }

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }
}
