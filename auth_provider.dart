import 'package:flutter/material.dart';
import '../db/database_helper.dart';

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _currentUser;
  bool _isLoading = false;

  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?['role'] == 'admin';
  int? get userId => _currentUser?['id'] as int?;
  String get userName => _currentUser?['full_name'] ?? _currentUser?['username'] ?? '';

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final user = await DatabaseHelper.instance.login(username.trim(), password.trim());
      if (user != null) {
        _currentUser = user;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }
}
