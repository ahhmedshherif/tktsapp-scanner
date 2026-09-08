import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StaffSessionStore {
  static const _tokenKey = 'tktsapp_scanner_staff_token';
  static const _userKey = 'tktsapp_scanner_staff_user';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<StaffSession?> restore() async {
    final token = await _storage.read(key: _tokenKey);
    final raw = await _storage.read(key: _userKey);
    if (token == null || raw == null) return null;
    try {
      return StaffSession(
        token,
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> save(StaffSession session) async {
    await _storage.write(key: _tokenKey, value: session.token);
    await _storage.write(key: _userKey, value: jsonEncode(session.user));
  }

  Future<void> clear() => _storage.deleteAll();
}

class StaffSession {
  const StaffSession(this.token, this.user);
  final String token;
  final Map<String, dynamic> user;
  String get role => (user['staff_role'] ?? user['role'] ?? 'staff').toString();
  bool get isAdmin => role == 'admin' || role == 'super_admin';
  bool get isOwner => role == 'organizer' && user['staff_role'] == null;
  bool get canManageTeam => isOwner;
  bool get canScan =>
      isAdmin || isOwner || role == 'manager' || role == 'scanner';
  bool get canSeeAnalytics =>
      isAdmin || isOwner || role == 'manager' || role == 'analyst';
}
