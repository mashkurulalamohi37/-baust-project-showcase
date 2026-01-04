import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import '../models/user.dart';
import 'firestore_service.dart';
import 'notification_service.dart';

class AuthService extends ChangeNotifier {
  // Singleton instance so auth state is shared app-wide
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal() {
    _init();
  }
  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  UserRole? _pendingRole; // Store the role selected during login
  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  static const String _userPrefsKey = 'auth.currentUser';

  // Hardcoded admin credentials
  static const String _adminEmail = 'ohi82@gmail.com';
  static const String _adminPassword = 'ohi123@82';

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.role == UserRole.admin;
  bool get isTeacher => _currentUser?.role == UserRole.teacher;
  bool get isStudent => _currentUser?.role == UserRole.student;
  bool get isApproved => _currentUser?.isApproved ?? false;
  bool get isActive => _currentUser?.isActive ?? true;

  void _init() {
    debugPrint('AuthService: Initializing with Firestore...');
    _restoreSession();
    debugPrint('AuthService: Initialization complete');
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  Future<bool> login(String email, String password, UserRole role) async {
    _setLoading(true);
    _setError(null);
    _pendingRole = role;
    final normalizedEmail = _normalizeEmail(email);

    try {
      if (normalizedEmail.isEmpty || password.isEmpty) {
        _setError('Please fill in all fields');
        _setLoading(false);
        return false;
      }

      // 1. Admin Login (Hardcoded)
      if (normalizedEmail == _adminEmail && password == _adminPassword) {
        _currentUser = User(
          id: 'admin_${DateTime.now().millisecondsSinceEpoch}',
          name: 'Admin',
          email: _adminEmail,
          password: password,
          role: UserRole.admin,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isApproved: true,
          approvedAt: DateTime.now(),
          approvedBy: 'system',
          lastLoginAt: DateTime.now(),
        );
        await _persistCurrentUser();
        _setLoading(false);
        notifyListeners();
        return true;
      }

      // 2. Try Firebase Auth Login first
      fb_auth.UserCredential? userCredential;
      bool firebaseAuthSuccess = false;
      try {
        userCredential = await _auth.signInWithEmailAndPassword(
          email: normalizedEmail,
          password: password,
        );
        firebaseAuthSuccess = true;
        debugPrint('AuthService: Firebase Auth login successful');
      } on fb_auth.FirebaseAuthException catch (e) {
        debugPrint('AuthService: Firebase Auth login failed: ${e.code}');
        // If user not found in Auth, we check Firestore (Migration mode)
        if (e.code != 'user-not-found' && e.code != 'wrong-password' && e.code != 'invalid-credential') {
          _setError('Authentication error: ${e.message}');
          _setLoading(false);
          return false;
        }
      }

      // 3. Get/Verify user from Firestore
      User? existingUser = await FirestoreService.getUserByEmail(normalizedEmail);
      
      if (existingUser != null) {
        // Migration/Auto-Sync logic
        if (!firebaseAuthSuccess) {
          // Check password against Firestore record (Legacy)
          if (existingUser.password == password) {
            debugPrint('AuthService: Firestore password match. Migrating to Firebase Auth.');
            try {
              await _auth.createUserWithEmailAndPassword(email: normalizedEmail, password: password);
              firebaseAuthSuccess = true;
            } catch (ignore) {
              // Might already exist but different password? 
              // If we reached here, Auth should have thrown user-not-found, so this shouldn't happen.
            }
          } else {
            _setError('Invalid password. Please try again.');
            _setLoading(false);
            return false;
          }
        }

        // Check if role matches
        if (existingUser.role != role) {
          _setError('Invalid role for this account. Please select correctly.');
          _setLoading(false);
          return false;
        }

        // Check approval and active status
        if (role == UserRole.teacher && !existingUser.isApproved) {
          _setError('Your teacher account is pending admin approval.');
          _setLoading(false);
          return false;
        }
        if (!existingUser.isActive) {
          _setError('Your account has been deactivated.');
          _setLoading(false);
          return false;
        }

        // Sync Firestore password if it was reset via email
        var verifiedUser = existingUser;
        if (firebaseAuthSuccess && existingUser.password != password) {
          debugPrint('AuthService: Syncing Firestore password from Firebase Auth reset');
          verifiedUser = existingUser.copyWith(password: password);
        }

        verifiedUser = verifiedUser.copyWith(
          lastLoginAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        _currentUser = verifiedUser;
        await FirestoreService.updateUser(verifiedUser);
        await _persistCurrentUser();
        
        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        _setError('No account found with this email. Please sign up first.');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      debugPrint('Login error: $e');
      _setError('Login failed: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signup(
    String name,
    String email,
    String password,
    UserRole role, {
    String? department,
    String? employeeId,
    String? phoneNumber,
    Designation? designation,
  }) async {
    _setLoading(true);
    _setError(null);
    final normalizedEmail = _normalizeEmail(email);

    try {
      if (name.isEmpty || normalizedEmail.isEmpty || password.isEmpty) {
        _setError('Please fill in all fields');
        _setLoading(false);
        return false;
      }

      // Prevent admin signup through normal flow
      if (role == UserRole.admin) {
        _setError('Admin accounts cannot be created through signup');
        _setLoading(false);
        return false;
      }

      // Check if user already exists by email
      User? existingUser = await FirestoreService.getUserByEmail(
        normalizedEmail,
      );

      if (existingUser != null) {
        _setError(
          'An account with this email already exists. Please use login instead.',
        );
        _setLoading(false);
        return false;
      }

      // Check for duplicate employee ID (if provided)
      if (employeeId != null && employeeId.isNotEmpty) {
        User? existingEmployee = await FirestoreService.getUserByEmployeeId(
          employeeId,
        );

        if (existingEmployee != null) {
          _setError(
            'An account with this employee ID already exists. Please use a different employee ID.',
          );
          _setLoading(false);
          return false;
        }
      }

      // Create new user in Firebase Auth and Firestore
      final isApproved = role != UserRole.teacher;

      try {
        // 1. Create in Firebase Auth
        await _auth.createUserWithEmailAndPassword(
          email: normalizedEmail,
          password: password,
        );
        debugPrint('AuthService: Firebase Auth account created');

        // 2. Create local User model
        final user = User(
          id: _auth.currentUser?.uid ?? 'user_${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          email: normalizedEmail,
          role: role,
          createdAt: DateTime.now(),
          password: password,
          updatedAt: DateTime.now(),
          isApproved: isApproved,
          approvedAt: isApproved ? DateTime.now() : null,
          approvedBy: isApproved ? 'system' : null,
          department: department,
          employeeId: employeeId,
          phoneNumber: phoneNumber,
          lastLoginAt: DateTime.now(),
          designation: designation,
        );

        // 3. Save to Firestore
        await FirestoreService.saveUser(user);
        debugPrint('AuthService: Firestore record created');

        if (role == UserRole.teacher) {
          debugPrint('AuthService: Teacher signup successful - pending approval');
          await FirestoreService.logTeacherRegistered(user);
          final notificationService = NotificationService();
          await notificationService.notifyAdminsTeacherApprovalRequest(user);
          
          _setError('Teacher account created! Pending admin approval.');
          _setLoading(false);
          notifyListeners();
          return true;
        } else {
          _currentUser = user;
          await _persistCurrentUser();
          _setLoading(false);
          notifyListeners();
          return true;
        }
      } on fb_auth.FirebaseAuthException catch (e) {
        debugPrint('AuthService: Firebase Auth signup failed: ${e.code}');
        _setError('Signup failed: ${e.message}');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      debugPrint('Signup error: $e');
      _setError('Signup failed: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    _setLoading(true);
    _setError(null);
    final normalizedEmail = _normalizeEmail(email);

    try {
      // 1. Verify user exists in our Firestore database first
      User? user = await FirestoreService.getUserByEmail(normalizedEmail);
      if (user == null) {
        _setError('No account found with this email address.');
        _setLoading(false);
        return false;
      }

      // 2. Try sending the reset email via Firebase Auth
      try {
        await _auth.sendPasswordResetEmail(email: normalizedEmail);
        debugPrint('AuthService: Password reset email sent to $normalizedEmail');
      } on fb_auth.FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found') {
          // 3. User is in Firestore but not in Firebase Auth (Legacy user)
          // We need to create a temporary Firebase Auth account so they can reset it
          debugPrint('AuthService: Legacy user detected. Creating Firebase Auth placeholder.');
          try {
            // Create user with a random password because we don't store it in Auth yet
            // This won't affect their Firestore data, but will enable the reset flow
            final tempPassword = 'temp_${DateTime.now().millisecondsSinceEpoch}';
            await _auth.createUserWithEmailAndPassword(
              email: normalizedEmail,
              password: tempPassword,
            );
            // Now that they exist in Auth, send the email
            await _auth.sendPasswordResetEmail(email: normalizedEmail);
            debugPrint('AuthService: Password reset email sent after creating placeholder');
          } catch (createError) {
            debugPrint('AuthService: Failed to create placeholder user: $createError');
            _setError('Unable to send reset email. Please contact support.');
            _setLoading(false);
            return false;
          }
        } else {
          debugPrint('AuthService: Firebase Auth error: ${e.code}');
          _setError('Error sending email: ${e.message}');
          _setLoading(false);
          return false;
        }
      }
      
      _setLoading(false);
      return true;
    } catch (e) {
      debugPrint('AuthService: General error in sendPasswordResetEmail: $e');
      _setError('Something went wrong. Please try again.');
      _setLoading(false);
      return false;
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    _errorMessage = null;
    NotificationService().clearNotifications();
    await _clearPersistedUser();
    notifyListeners();
  }

  Future<bool> updateUserProfile(User updatedUser) async {
    _setLoading(true);
    _setError(null);

    try {
      await FirestoreService.updateUser(updatedUser);
      _currentUser = updatedUser;
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to update profile: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Check if user can perform specific actions based on role and approval status
  bool canUploadProjects() {
    return isAuthenticated && isStudent && isApproved;
  }

  bool canReviewProjects() {
    return isAuthenticated && isTeacher && isApproved;
  }

  bool canCommentOnProjects() {
    return isAuthenticated && isTeacher && isApproved;
  }

  bool canRateProjects() {
    return isAuthenticated && isTeacher && isApproved;
  }

  bool canManageUsers() {
    return isAuthenticated && isAdmin;
  }

  bool canApproveTeachers() {
    return isAuthenticated && isAdmin;
  }

  bool canDeleteAnyProject() {
    return isAuthenticated && isAdmin;
  }

  bool canEditOwnProjects() {
    return isAuthenticated && isStudent && isApproved;
  }

  bool canViewAllProjects() {
    return isAuthenticated && (isStudent || isTeacher || isAdmin) && isApproved;
  }

  // Check if user needs approval
  bool needsApproval() {
    return isAuthenticated && isTeacher && !isApproved;
  }

  // Get user status message
  String getUserStatusMessage() {
    if (!isAuthenticated) return 'Please log in';
    if (needsApproval())
      return 'Your teacher account is pending admin approval';
    if (!isActive) return 'Your account has been deactivated';
    return 'Account active';
  }

  // Get all pending teachers (for admin approval)
  Future<List<User>> getPendingTeachers() async {
    try {
      List<User> pendingTeachers = await FirestoreService.getPendingTeachers();
      debugPrint(
        'AuthService: Pending teachers found: ${pendingTeachers.length}',
      );
      for (final teacher in pendingTeachers) {
        debugPrint(
          'AuthService: Pending teacher - ${teacher.name} (${teacher.email}) - Role: ${teacher.role.name}, Approved: ${teacher.isApproved}, Active: ${teacher.isActive}',
        );
      }

      return pendingTeachers;
    } catch (e) {
      debugPrint('AuthService: Error getting pending teachers: $e');
      return [];
    }
  }

  // Approve a teacher
  Future<bool> approveTeacher(String teacherId) async {
    try {
      _setLoading(true);
      final user = await FirestoreService.getUserById(teacherId);
      if (user == null) {
        _errorMessage = 'Teacher not found';
        _setLoading(false);
        return false;
      }

      await FirestoreService.approveTeacher(
        teacherId,
        _currentUser?.id ?? 'admin',
      );
      
      // Log activity for teacher approval
      await FirestoreService.logTeacherApproved(
        user,
        _currentUser?.id ?? 'admin',
      );
      
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setLoading(false);
      _errorMessage = 'Failed to approve teacher: $e';
      debugPrint('AuthService: Error approving teacher: $e');
      return false;
    }
  }

  // Reject a teacher (deactivate their account)
  Future<bool> rejectTeacher(String teacherId) async {
    try {
      _setLoading(true);
      final user = await FirestoreService.getUserById(teacherId);
      if (user == null) {
        _errorMessage = 'Teacher not found';
        _setLoading(false);
        return false;
      }

      final rejectedUser = user.copyWith(isActive: false, isApproved: false);

      await FirestoreService.updateUser(rejectedUser);
      
      // Log activity for teacher rejection
      await FirestoreService.logTeacherRejected(
        user,
        _currentUser?.id ?? 'admin',
      );
      
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setLoading(false);
      _errorMessage = 'Failed to reject teacher: $e';
      debugPrint('AuthService: Error rejecting teacher: $e');
      return false;
    }
  }

  // Get all users (for admin management)
  Future<List<User>> getAllUsers() async {
    try {
      return await FirestoreService.getAllUsers();
    } catch (e) {
      debugPrint('AuthService: Error getting all users: $e');
      return [];
    }
  }

  // Get users by role
  Future<List<User>> getUsersByRole(UserRole role) async {
    try {
      final allUsers = await getAllUsers();
      return allUsers.where((user) => user.role == role).toList();
    } catch (e) {
      debugPrint('AuthService: Error getting users by role: $e');
      return [];
    }
  }

  // Update user status (activate/deactivate)
  Future<bool> updateUserStatus(String userId, bool isActive) async {
    try {
      _setLoading(true);
      final user = await FirestoreService.getUserById(userId);
      if (user == null) {
        _errorMessage = 'User not found';
        _setLoading(false);
        return false;
      }

      final updatedUser = user.copyWith(isActive: isActive);
      await FirestoreService.updateUser(updatedUser);
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setLoading(false);
      _errorMessage = 'Failed to update user status: $e';
      debugPrint('AuthService: Error updating user status: $e');
      return false;
    }
  }

  // Change user role
  Future<bool> changeUserRole(String userId, UserRole newRole) async {
    try {
      _setLoading(true);
      debugPrint(
        'AuthService: Starting role change for user $userId to ${newRole.name}',
      );

      // Add timeout to prevent hanging
      final result = await Future.any([
        _performRoleChange(userId, newRole),
        Future.delayed(const Duration(seconds: 8), () => false),
      ]);

      _setLoading(false);
      return result;
    } catch (e) {
      _setLoading(false);
      _errorMessage = 'Failed to change user role: $e';
      debugPrint('AuthService: Error changing user role: $e');
      return false;
    }
  }

  Future<bool> _performRoleChange(String userId, UserRole newRole) async {
    final user = await FirestoreService.getUserById(userId);
    if (user == null) {
      _errorMessage = 'User not found';
      debugPrint('AuthService: User not found for ID $userId');
      return false;
    }

    debugPrint(
      'AuthService: Changing role for ${user.name} from ${user.role.name} to ${newRole.name}',
    );
    debugPrint('AuthService: Current approval status: ${user.isApproved}');

    final updatedUser = user.copyWith(
      role: newRole,
      isApproved: newRole == UserRole.teacher
          ? false
          : true, // Teachers need approval
    );

    debugPrint('AuthService: New approval status: ${updatedUser.isApproved}');

    await FirestoreService.updateUser(updatedUser);
    debugPrint('AuthService: User role changed successfully');

    notifyListeners();
    return true;
  }

  // Delete user
  Future<bool> deleteUser(String userId) async {
    try {
      _setLoading(true);
      // Note: Firestore will handle cascade deletes via cloud functions if configured
      final user = await FirestoreService.getUserById(userId);
      if (user != null) {
        final deactivatedUser = user.copyWith(isActive: false);
        await FirestoreService.updateUser(deactivatedUser);
      }
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setLoading(false);
      _errorMessage = 'Failed to delete user: $e';
      debugPrint('AuthService: Error deleting user: $e');
      return false;
    }
  }

  Future<void> _persistCurrentUser() async {
    if (_currentUser == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _userPrefsKey,
        jsonEncode(_currentUser!.toJson()),
      );
    } catch (e) {
      debugPrint('AuthService: Failed to persist user session: $e');
    }
  }

  Future<void> _clearPersistedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userPrefsKey);
    } catch (e) {
      debugPrint('AuthService: Failed to clear user session: $e');
    }
  }

  Future<void> _restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_userPrefsKey);
      if (cached == null) return;

      final decoded = jsonDecode(cached) as Map<String, dynamic>;
      _currentUser = User.fromJson(decoded);
      debugPrint(
        'AuthService: Restored session for ${_currentUser?.email} (${_currentUser?.role.name})',
      );
      notifyListeners();
    } catch (e) {
      debugPrint('AuthService: Failed to restore session: $e');
    }
  }
}
