import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../mvc/controllers/firestore_service.dart';

class SystemService extends ChangeNotifier {
  static final SystemService _instance = SystemService._internal();
  factory SystemService() => _instance;
  SystemService._internal();

  bool _autoApprovalEnabled = false;
  String? _primaryTeacherId;
  String? _primaryTeacherName;
  bool _isLoading = false;

  bool get autoApprovalEnabled => _autoApprovalEnabled;
  String? get primaryTeacherId => _primaryTeacherId;
  String? get primaryTeacherName => _primaryTeacherName;
  bool get isLoading => _isLoading;

  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();

    try {
      final settings = await FirestoreService.getSystemSettings();
      _autoApprovalEnabled = settings['autoApprovalEnabled'] ?? false;
      _primaryTeacherId = settings['primaryTeacherId'];
      _primaryTeacherName = settings['primaryTeacherName'];
    } catch (e) {
      debugPrint('Error loading system settings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateAutoApproval(bool enabled) async {
    try {
      await FirestoreService.updateSystemSettings({'autoApprovalEnabled': enabled});
      _autoApprovalEnabled = enabled;
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating auto-approval: $e');
      rethrow;
    }
  }

  Future<void> updatePrimaryTeacher(String id, String name) async {
    try {
      await FirestoreService.updateSystemSettings({
        'primaryTeacherId': id,
        'primaryTeacherName': name,
      });
      _primaryTeacherId = id;
      _primaryTeacherName = name;
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating primary teacher: $e');
      rethrow;
    }
  }
}
