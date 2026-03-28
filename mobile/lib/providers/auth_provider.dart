import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _user;
  bool _loading = false;

  Map<String, dynamic>? get user => _user;
  bool get loading => _loading;
  bool get isAuthenticated => _user != null;
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
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    _setLoading(true);
    try {
      final data = await ApiService.post(
        '/auth/login',
        {'email': email, 'password': password},
        auth: false,
      );
      await ApiService.saveToken(data['token'] as String);
      await ApiService.saveUser(data['user'] as Map<String, dynamic>);
      _user = data['user'] as Map<String, dynamic>;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> register(
    String name,
    String email,
    String password,
    String role,
    {Map<String, dynamic>? extraData}
  ) async {
    _setLoading(true);
    try {
      final payload = {
        'name': name,
        'email': email,
        'password': password,
        'role': role,
        ...?extraData,
      };
      await ApiService.post(
        '/auth/register',
        payload,
        auth: false,
      );
      // auto-login after register
      await login(email, password);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    await ApiService.clearAll();
    _user = null;
    notifyListeners();
  }

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }
}
