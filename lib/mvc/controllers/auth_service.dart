import 'package:flutter/foundation.dart';
import '../models/user.dart';
import 'firestore_service.dart';
import '../../services/firestore_service.dart' as firestore_service;

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
    _pendingRole = role; // Store the role for later use
    final normalizedEmail = _normalizeEmail(email);

    try {
      if (normalizedEmail.isEmpty || password.isEmpty) {
        _setError('Please fill in all fields');
        _setLoading(false);
        return false;
      }

      // Check for hardcoded admin credentials
      if (normalizedEmail == _adminEmail && password == _adminPassword) {
        debugPrint('AuthService: Admin login successful');
        // Create admin user directly
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
        _setLoading(false);
        notifyListeners();
        return true;
      }

      // For regular users, use Firestore
      debugPrint(
        'AuthService: Attempting Firestore login for $normalizedEmail with role: $role',
      );

      try {
        // Get user from Firestore
        User? existingUser;
        try {
          debugPrint(
            'AuthService: Checking Firestore for user: $normalizedEmail',
          );
          debugPrint(
            'AuthService: Input email: "$email" -> Normalized: "$normalizedEmail"',
          );
          existingUser = await FirestoreService.getUserByEmail(normalizedEmail);
          if (existingUser != null) {
            debugPrint(
              'AuthService: User found - Email: ${existingUser.email}, Role: ${existingUser.role}, Name: ${existingUser.name}',
            );
          } else {
            debugPrint(
              'AuthService: User not found in Firestore for email: $normalizedEmail',
            );
            debugPrint('AuthService: Please verify:');
            debugPrint('  1. The email is correct');
            debugPrint('  2. The user account exists in Firestore');
            debugPrint(
              '  3. Check Firebase Console -> Firestore Database -> users collection',
            );
          }
        } catch (e, stackTrace) {
          debugPrint('AuthService: Firestore access failed: $e');
          debugPrint('AuthService: Stack trace: $stackTrace');
          debugPrint(
            'AuthService: Please check Firebase connection and configuration',
          );
          _setError(
            'Login failed: Unable to connect to database. Please check your connection and try again.',
          );
          _setLoading(false);
          return false;
        }

        if (existingUser != null) {
          debugPrint(
            'AuthService: User exists in Firestore, checking credentials',
          );
          var verifiedUser = existingUser;
          final now = DateTime.now();

          if (verifiedUser.password.isEmpty) {
            debugPrint(
              'AuthService: Legacy account detected without stored password. Updating password.',
            );
            verifiedUser = verifiedUser.copyWith(password: password);
          } else if (verifiedUser.password != password) {
            _setError('Invalid password. Please try again.');
            _setLoading(false);
            return false;
          }

          if (verifiedUser.role != role) {
            _setError(
              'Invalid role for this account. Please select the correct role (${verifiedUser.role.displayName}).',
            );
            _setLoading(false);
            return false;
          }

          if (role == UserRole.teacher && !verifiedUser.isApproved) {
            _setError(
              'Your teacher account is pending admin approval. Please contact an administrator.',
            );
            _setLoading(false);
            return false;
          }

          if (!verifiedUser.isActive) {
            _setError(
              'Your account has been deactivated. Please contact an administrator.',
            );
            _setLoading(false);
            return false;
          }

          verifiedUser = verifiedUser.copyWith(
            lastLoginAt: now,
            updatedAt: now,
          );

          _currentUser = verifiedUser;

          try {
            await FirestoreService.updateUser(verifiedUser);
          } catch (e) {
            debugPrint('Failed to update user in Firestore: $e');
          }

          debugPrint('AuthService: Existing user login successful');
        } else {
          // User doesn't exist, show helpful error message
          debugPrint(
            'AuthService: No account found for email: $normalizedEmail',
          );
          debugPrint('AuthService: Suggestions:');
          debugPrint('  1. Make sure you have signed up with this email');
          debugPrint('  2. Check if the email is spelled correctly');
          debugPrint('  3. Try signing up again if you haven\'t already');
          _setError(
            'No account found with this email. Please sign up first or check your email spelling.',
          );
          _setLoading(false);
          return false;
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

  Future<bool> signup(
    String name,
    String email,
    String password,
    UserRole role, {
    String? department,
    String? employeeId,
    String? phoneNumber,
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

      // Create new user
      final isApproved =
          role != UserRole.teacher; // Teachers need approval, students don't
      final user = User(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
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
      );

      // Save user to Firestore
      debugPrint('AuthService: Saving new user to Firestore: ${user.email}');
      try {
        await FirestoreService.saveUser(user);
        debugPrint('AuthService: Successfully saved new user to Firestore');
      } catch (e) {
        debugPrint('AuthService: Failed to save new user to Firestore: $e');
        debugPrint(
          'AuthService: Please check Firebase connection and configuration',
        );
        _setError(
          'Signup failed: Unable to connect to database. Please check your connection and try again.',
        );
        _setLoading(false);
        return false;
      }

      // Set current user for immediate login (except for teachers who need approval)
      if (role == UserRole.teacher) {
        // For teachers, don't set current user - they need admin approval
        debugPrint(
          'AuthService: Teacher signup successful for ${user.name} - pending admin approval',
        );
        
        // Log activity for teacher registration
        await firestore_service.FirestoreService.logTeacherRegistered(user);
        
        _setError(
          'Account created successfully! Your teacher account is pending admin approval. Please contact an administrator.',
        );
        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        // For students, set current user for immediate login
        _currentUser = user;
        debugPrint(
          'AuthService: Signup successful for ${user.name} with role: ${user.role}',
        );
        _setLoading(false);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Signup error: $e');
      _setError('Signup failed: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    _errorMessage = null;
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
      await firestore_service.FirestoreService.logTeacherApproved(
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
      await firestore_service.FirestoreService.logTeacherRejected(
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
}
