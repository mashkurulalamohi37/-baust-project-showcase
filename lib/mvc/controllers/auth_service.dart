import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import 'firestore_service.dart';
import 'offline_storage.dart';

class AuthService extends ChangeNotifier {
  // Singleton instance so auth state is shared app-wide
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal() {
    _init();
  }

  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  UserRole? _pendingRole; // Store the role selected during login

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
    debugPrint('AuthService: Initializing...');
    // Disabled Firebase auth state listener since we're using custom authentication
    // This avoids the Firebase type casting issues
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

  Future<bool> login(String email, String password, UserRole role) async {
    _setLoading(true);
    _setError(null);
    _pendingRole = role; // Store the role for later use

    try {
      if (email.isEmpty || password.isEmpty) {
        _setError('Please fill in all fields');
        _setLoading(false);
        return false;
      }

      // Check for hardcoded admin credentials
      if (email == _adminEmail && password == _adminPassword) {
        debugPrint('AuthService: Admin login successful');
        // Create admin user directly
        _currentUser = User(
          id: 'admin_${DateTime.now().millisecondsSinceEpoch}',
          name: 'Admin',
          email: _adminEmail,
          role: UserRole.admin,
          createdAt: DateTime.now(),
          isApproved: true,
          approvedAt: DateTime.now(),
          approvedBy: 'system',
          lastLoginAt: DateTime.now(),
        );
        _setLoading(false);
        notifyListeners();
        return true;
      }

      // For regular users, use offline authentication for now
      debugPrint('AuthService: Attempting offline login for $email with role: $role');
      
      try {
        // Try to get user from Firestore first, but fallback to offline mode if it fails
        User? existingUser;
        try {
          existingUser = await FirestoreService.getUserByEmail(email);
        } catch (e) {
          debugPrint('Firestore access failed, trying offline storage: $e');
          // Try offline storage as fallback
          existingUser = await OfflineStorage.getUserByEmail(email);
        }
        
        if (existingUser != null) {
          // User exists in Firestore, check credentials
          debugPrint('AuthService: User exists in Firestore, checking credentials');
          
          // Check if role matches
          if (existingUser.role != role) {
            _setError('Invalid role for this account. Please select the correct role.');
            _setLoading(false);
            return false;
          }
          
          // Check if teacher is approved
          if (role == UserRole.teacher && !existingUser.isApproved) {
            _setError('Your teacher account is pending admin approval. Please contact an administrator.');
            _setLoading(false);
            return false;
          }
          
          // Check if account is active
          if (!existingUser.isActive) {
            _setError('Your account has been deactivated. Please contact an administrator.');
            _setLoading(false);
            return false;
          }
          
          // Update last login
          _currentUser = existingUser.copyWith(lastLoginAt: DateTime.now());
          
          // Try to save to Firestore, but don't fail if it doesn't work
          try {
            await FirestoreService.saveUser(_currentUser!);
          } catch (e) {
            debugPrint('Failed to update user in Firestore, saving offline: $e');
            await OfflineStorage.saveUser(_currentUser!);
          }
          
          // Always save to offline storage as backup
          await OfflineStorage.saveUser(_currentUser!);
          await OfflineStorage.saveCurrentUser(_currentUser!);
          
          debugPrint('AuthService: Existing user login successful');
          
        } else {
          // New user, create account offline
          debugPrint('AuthService: Creating new user offline');
          
          _currentUser = User(
            id: 'user_${DateTime.now().millisecondsSinceEpoch}',
            name: email.split('@')[0],
            email: email,
            role: role,
            createdAt: DateTime.now(),
            isApproved: role == UserRole.teacher ? false : true,
            lastLoginAt: DateTime.now(),
          );
          
          debugPrint('AuthService: Created user: ${_currentUser!.name} with role: ${_currentUser!.role}');
          
          // Try to save to Firestore, but don't fail if it doesn't work
          try {
            await FirestoreService.saveUser(_currentUser!);
            debugPrint('AuthService: Successfully saved user to Firestore');
          } catch (e) {
            debugPrint('Failed to save user to Firestore, saving offline: $e');
          }
          
          // Always save to offline storage as backup
          await OfflineStorage.saveUser(_currentUser!);
          await OfflineStorage.saveCurrentUser(_currentUser!);
          
          // If teacher, show approval message
          if (role == UserRole.teacher) {
            _setError('Teacher account created successfully! Your account is pending admin approval. You will be notified once approved.');
            _setLoading(false);
            return false;
          }
        }
        
        debugPrint('AuthService: Login successful, returning true');
        _setLoading(false);
        notifyListeners();
        return true;
        
      } catch (e) {
        debugPrint('Login error: $e');
        _setError('Login failed: ${e.toString()}');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      debugPrint('General login error: $e');
      _setError('Login failed: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signup(String name, String email, String password, UserRole role, {String? department, String? employeeId, String? phoneNumber}) async {
    _setLoading(true);
    _setError(null);

    try {
      if (name.isNotEmpty && email.isNotEmpty && password.isNotEmpty) {
        // Prevent admin signup through normal flow
        if (role == UserRole.admin) {
          _setError('Admin accounts cannot be created through signup');
          _setLoading(false);
          return false;
        }

        // Use custom authentication to avoid Firebase type casting issues
        // Teachers need admin approval, students are approved by default
        final isApproved = role != UserRole.teacher;
        final user = User(
          id: 'user_${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          email: email,
          role: role,
          createdAt: DateTime.now(),
          isApproved: isApproved,
          approvedAt: isApproved ? DateTime.now() : null,
          approvedBy: isApproved ? 'system' : null,
          department: department,
          employeeId: employeeId,
          phoneNumber: phoneNumber,
          lastLoginAt: DateTime.now(),
        );
        
        // Save user to Firestore
        try {
          await FirestoreService.saveUser(user);
          debugPrint('AuthService: Successfully saved new user to Firestore');
        } catch (e) {
          debugPrint('AuthService: Failed to save new user to Firestore: $e');
        }
        
        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        _setError('Please fill in all fields');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('Signup failed: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    await OfflineStorage.clearCurrentUser();
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> updateUserProfile(User updatedUser) async {
    _setLoading(true);
    _setError(null);

    try {
      await FirestoreService.saveUser(updatedUser);
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
    if (needsApproval()) return 'Your teacher account is pending admin approval';
    if (!isActive) return 'Your account has been deactivated';
    return 'Account active';
  }

  // Get all pending teachers (for admin approval)
  Future<List<User>> getPendingTeachers() async {
    try {
      final users = await FirestoreService.getAllUsers();
      debugPrint('AuthService: Total users found: ${users.length}');
      
      final pendingTeachers = users.where((user) => 
        user.role == UserRole.teacher && 
        !user.isApproved && 
        user.isActive
      ).toList();
      
      debugPrint('AuthService: Pending teachers found: ${pendingTeachers.length}');
      for (final teacher in pendingTeachers) {
        debugPrint('AuthService: Pending teacher - ${teacher.name} (${teacher.email}) - Role: ${teacher.role.name}, Approved: ${teacher.isApproved}, Active: ${teacher.isActive}');
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
      final user = await FirestoreService.getUser(teacherId);
      if (user == null) {
        _errorMessage = 'Teacher not found';
        return false;
      }

      final approvedUser = user.copyWith(
        isApproved: true,
        approvedAt: DateTime.now(),
        approvedBy: _currentUser?.id ?? 'admin',
      );

      await FirestoreService.saveUser(approvedUser);
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
      final user = await FirestoreService.getUser(teacherId);
      if (user == null) {
        _errorMessage = 'Teacher not found';
        return false;
      }

      final rejectedUser = user.copyWith(
        isActive: false,
        isApproved: false,
      );

      await FirestoreService.saveUser(rejectedUser);
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
      final user = await FirestoreService.getUser(userId);
      if (user == null) {
        _errorMessage = 'User not found';
        return false;
      }

      final updatedUser = user.copyWith(isActive: isActive);
      await FirestoreService.saveUser(updatedUser);
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
      debugPrint('AuthService: Starting role change for user $userId to ${newRole.name}');
      
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
    final user = await FirestoreService.getUser(userId);
    if (user == null) {
      _errorMessage = 'User not found';
      debugPrint('AuthService: User not found for ID $userId');
      return false;
    }

    debugPrint('AuthService: Changing role for ${user.name} from ${user.role.name} to ${newRole.name}');
    debugPrint('AuthService: Current approval status: ${user.isApproved}');

    final updatedUser = user.copyWith(
      role: newRole,
      isApproved: newRole == UserRole.teacher ? false : true, // Teachers need approval
    );
    
    debugPrint('AuthService: New approval status: ${updatedUser.isApproved}');
    
    await FirestoreService.saveUser(updatedUser);
    debugPrint('AuthService: User role changed successfully');
    
    notifyListeners();
    return true;
  }

  // Delete user
  Future<bool> deleteUser(String userId) async {
    try {
      _setLoading(true);
      await FirestoreService.deleteUser(userId);
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
}
