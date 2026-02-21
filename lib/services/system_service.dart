import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../mvc/controllers/firestore_service.dart';

class SystemService extends ChangeNotifier {
  static final SystemService _instance = SystemService._internal();
  factory SystemService() => _instance;
  SystemService._internal();

  bool _autoApprovalEnabled = false;
  bool _isLoading = false;

  bool get autoApprovalEnabled => _autoApprovalEnabled;
  bool get isLoading => _isLoading;

  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();

    try {
      final settings = await FirestoreService.getSystemSettings();
      _autoApprovalEnabled = settings['autoApprovalEnabled'] ?? false;
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
}
