import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class OfflineStorage {
  static const String _usersKey = 'offline_users';
  static const String _currentUserKey = 'current_user';

  // Save user data offline
  static Future<void> saveUser(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getString(_usersKey) ?? '{}';
      final users = Map<String, dynamic>.from(json.decode(usersJson));
      
      users[user.email] = {
        'id': user.id,
        'name': user.name,
        'email': user.email,
        'role': user.role.name,
        'createdAt': user.createdAt.toIso8601String(),
        'isApproved': user.isApproved,
        'approvedAt': user.approvedAt?.toIso8601String(),
        'approvedBy': user.approvedBy,
        'department': user.department,
        'employeeId': user.employeeId,
        'phoneNumber': user.phoneNumber,
        'lastLoginAt': user.lastLoginAt?.toIso8601String(),
        'isActive': user.isActive,
      };
      
      await prefs.setString(_usersKey, json.encode(users));
    } catch (e) {
      print('Error saving user offline: $e');
    }
  }

  // Get user by email from offline storage
  static Future<User?> getUserByEmail(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getString(_usersKey) ?? '{}';
      final users = Map<String, dynamic>.from(json.decode(usersJson));
      
      if (users.containsKey(email)) {
        final userData = users[email];
        return User(
          id: userData['id'],
          name: userData['name'],
          email: userData['email'],
          role: UserRole.values.firstWhere((e) => e.name == userData['role']),
          createdAt: DateTime.parse(userData['createdAt']),
          isApproved: userData['isApproved'] ?? true,
          approvedAt: userData['approvedAt'] != null ? DateTime.parse(userData['approvedAt']) : null,
          approvedBy: userData['approvedBy'],
          department: userData['department'],
          employeeId: userData['employeeId'],
          phoneNumber: userData['phoneNumber'],
          lastLoginAt: userData['lastLoginAt'] != null ? DateTime.parse(userData['lastLoginAt']) : null,
          isActive: userData['isActive'] ?? true,
        );
      }
      return null;
    } catch (e) {
      print('Error getting user offline: $e');
      return null;
    }
  }

  // Save current user session
  static Future<void> saveCurrentUser(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = json.encode({
        'id': user.id,
        'name': user.name,
        'email': user.email,
        'role': user.role.name,
        'createdAt': user.createdAt.toIso8601String(),
        'isApproved': user.isApproved,
        'approvedAt': user.approvedAt?.toIso8601String(),
        'approvedBy': user.approvedBy,
        'department': user.department,
        'employeeId': user.employeeId,
        'phoneNumber': user.phoneNumber,
        'lastLoginAt': user.lastLoginAt?.toIso8601String(),
        'isActive': user.isActive,
      });
      await prefs.setString(_currentUserKey, userJson);
    } catch (e) {
      print('Error saving current user: $e');
    }
  }

  // Get current user session
  static Future<User?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_currentUserKey);
      if (userJson != null) {
        final userData = json.decode(userJson);
        return User(
          id: userData['id'],
          name: userData['name'],
          email: userData['email'],
          role: UserRole.values.firstWhere((e) => e.name == userData['role']),
          createdAt: DateTime.parse(userData['createdAt']),
          isApproved: userData['isApproved'] ?? true,
          approvedAt: userData['approvedAt'] != null ? DateTime.parse(userData['approvedAt']) : null,
          approvedBy: userData['approvedBy'],
          department: userData['department'],
          employeeId: userData['employeeId'],
          phoneNumber: userData['phoneNumber'],
          lastLoginAt: userData['lastLoginAt'] != null ? DateTime.parse(userData['lastLoginAt']) : null,
          isActive: userData['isActive'] ?? true,
        );
      }
      return null;
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  // Clear current user session
  static Future<void> clearCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_currentUserKey);
    } catch (e) {
      print('Error clearing current user: $e');
    }
  }
}
