import 'package:flutter/material.dart';
import '../mvc/controllers/auth_service.dart';
import '../mvc/models/user.dart';
import 'forgot_password_screen.dart';

typedef RoleSelected = void Function(UserRole role);

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.onEnter, required this.authService});
  final RoleSelected onEnter;
  final AuthService authService;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  UserRole _selectedRole = UserRole.student;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'ProjectShowcase',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Select your role to continue',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Compact Segmented Control for Roles
                SegmentedButton<UserRole>(
                  segments: [
                    ButtonSegment(
                      value: UserRole.student,
                      label: const Text('Student'),
                      icon: const Icon(Icons.school, size: 18),
                    ),
                    ButtonSegment(
                      value: UserRole.teacher,
                      label: const Text('Teacher'),
                      icon: const Icon(Icons.rate_review, size: 18),
                    ),
                    ButtonSegment(
                      value: UserRole.admin,
                      label: const Text('Admin'),
                      icon: const Icon(Icons.admin_panel_settings, size: 18),
                    ),
                  ],
                  selected: {_selectedRole},
                  onSelectionChanged: (Set<UserRole> selection) {
                    setState(() => _selectedRole = selection.first);
                  },
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
                    selectedBackgroundColor: theme.colorScheme.primary,
                    selectedForegroundColor: theme.colorScheme.onPrimary,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Auth Forms inside a clear container
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: _AuthTabs(
                      authService: widget.authService,
                      selectedRole: _selectedRole,
                      onEnter: widget.onEnter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _AuthTabs extends StatefulWidget {
  const _AuthTabs({
    required this.authService,
    required this.selectedRole,
    required this.onEnter,
  });
  final AuthService authService;
  final UserRole selectedRole;
  final RoleSelected onEnter;

  @override
  State<_AuthTabs> createState() => _AuthTabsState();
}

class _AuthTabsState extends State<_AuthTabs> with SingleTickerProviderStateMixin {
  late final TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 2, vsync: this);
    _controller.addListener(_handleTabSelection);
  }

  void _handleTabSelection() {
    if (_controller.indexIsChanging || _controller.animation?.value == _controller.index) {
       setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTabSelection);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TabBar(controller: _controller, tabs: const <Tab>[Tab(text: 'Login'), Tab(text: 'Sign Up')]),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: _controller.index == 0
              ? _LoginForm(
                  key: const ValueKey('Login'),
                  authService: widget.authService,
                  selectedRole: widget.selectedRole,
                  onSubmit: () => widget.onEnter(widget.selectedRole),
                )
              : _SignupForm(
                  key: const ValueKey('Signup'),
                  authService: widget.authService,
                  initialRole: widget.selectedRole,
                  onEnter: widget.onEnter,
                ),
        ),
      ],
    );
  }
}

class _LoginForm extends StatefulWidget {
  const _LoginForm({
    super.key,
    required this.authService,
    required this.selectedRole,
    required this.onSubmit,
  });
  final AuthService authService;
  final UserRole selectedRole;
  final VoidCallback onSubmit;

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final success = await widget.authService.login(
        _emailController.text.trim(),
        _passwordController.text,
        widget.selectedRole,
      );

      if (success && mounted) {
        debugPrint('Login successful, calling onSubmit');
        widget.onSubmit();
      } else if (mounted) {
        final errorMessage = widget.authService.errorMessage ?? 'Login failed';
        debugPrint('Login failed: $errorMessage');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('Login error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred during login: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      final success = await widget.authService.signInWithGoogle(
        widget.selectedRole,
        isSignup: false, // Login flow - require existing account
      );
      
      if (success && mounted) {
        debugPrint('Google Sign In successful, calling onSubmit');
        widget.onSubmit();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.authService.errorMessage ?? 'Google Sign In failed'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.authService,
      builder: (context, child) {
        return Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ForgotPasswordScreen(),
                        ),
                      );
                    },
                    child: const Text('Forgot Password?'),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: widget.authService.isLoading ? null : _handleLogin,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: widget.authService.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Continue',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: Divider(color: Theme.of(context).colorScheme.outlineVariant)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('OR', style: Theme.of(context).textTheme.bodySmall),
                    ),
                    Expanded(child: Divider(color: Theme.of(context).colorScheme.outlineVariant)),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: widget.authService.isLoading ? null : _handleGoogleSignIn,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.grey),
                    ),
                    icon: Image.network(
                      'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/768px-Google_%22G%22_logo.svg.png',
                      height: 24,
                      width: 24,
                      errorBuilder: (context, error, stackTrace) => 
                        const Icon(Icons.g_mobiledata, size: 28, color: Colors.blue),
                    ),
                    label: const Text('Continue with Google', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
      },
    );
  }
}

class _SignupForm extends StatefulWidget {
  const _SignupForm({
    super.key,
    required this.authService,
    required this.initialRole,
    required this.onEnter,
  });
  final AuthService authService;
  final UserRole initialRole;
  final RoleSelected onEnter;

  @override
  State<_SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<_SignupForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _departmentController = TextEditingController();
  final _employeeIdController = TextEditingController();
  final _phoneController = TextEditingController();
  late UserRole _selectedRole;
  Designation? _selectedDesignation;
  
  // Custom error texts for Google Sign-In validation (only for required fields)
  String? _nameError;
  String? _departmentError;
  String? _designationError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _departmentController.dispose();
    _employeeIdController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Only allow student and teacher signup, not admin
    _selectedRole = widget.initialRole == UserRole.admin ? UserRole.student : widget.initialRole;
    if (_selectedRole == UserRole.admin) _selectedRole = UserRole.student;
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    try {
      final success = await widget.authService.signup(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
        _selectedRole,
        department: _selectedRole == UserRole.teacher ? _departmentController.text.trim() : null,
        employeeId: _selectedRole == UserRole.teacher ? _employeeIdController.text.trim() : null,
        phoneNumber: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
      );

      if (success && mounted) {
        // Store the name before clearing the form
        final userName = _nameController.text.trim();
        
        // Clear the form after successful signup
        _nameController.clear();
        _emailController.clear();
        _passwordController.clear();
        _confirmPasswordController.clear();
        _departmentController.clear();
        _employeeIdController.clear();
        _phoneController.clear();
        
        // Show success message based on role
        String message;
        if (_selectedRole == UserRole.teacher) {
          message = 'Teacher account created! Your account is pending admin approval. Welcome $userName';
        } else {
          message = 'Account created successfully! Welcome $userName';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        
        widget.onEnter(_selectedRole);
      } else if (mounted) {
        final errorText = widget.authService.errorMessage ?? 'Signup failed. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorText),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      // For teachers, validate only the essential fields for Google Sign-In
      if (_selectedRole == UserRole.teacher) {
        // Clear previous errors and check required fields
        bool hasErrors = false;
        String? nameErr;
        String? deptErr;
        String? desigErr;
        
        if (_nameController.text.trim().isEmpty) {
          hasErrors = true;
          nameErr = 'Please enter your full name';
        }
        if (_departmentController.text.trim().isEmpty) {
          hasErrors = true;
          deptErr = 'Please enter your department';
        }
        if (_selectedDesignation == null) {
          hasErrors = true;
          desigErr = 'Please select your designation';
        }
        
        if (hasErrors) {
          // Set custom errors only for the 3 required fields
          setState(() {
            _nameError = nameErr;
            _departmentError = deptErr;
            _designationError = desigErr;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Please complete required fields above'),
              backgroundColor: Theme.of(context).colorScheme.error,
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }
        
        // Clear errors if validation passes
        setState(() {
          _nameError = null;
          _departmentError = null;
          _designationError = null;
        });
      }
      
      final success = await widget.authService.signInWithGoogle(
        _selectedRole,
        isSignup: true, // Signup flow - allow account creation
        name: _selectedRole == UserRole.teacher ? _nameController.text.trim() : null,
        department: _selectedRole == UserRole.teacher ? _departmentController.text.trim() : null,
        employeeId: _selectedRole == UserRole.teacher && _employeeIdController.text.trim().isNotEmpty 
            ? _employeeIdController.text.trim() 
            : null, // Optional for Google Sign-In
        designation: _selectedRole == UserRole.teacher ? _selectedDesignation : null,
        phoneNumber: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
      );
      
      if (success && mounted) {
        debugPrint('Google Sign In successful, calling onEnter');
        widget.onEnter(_selectedRole);
      } else if (mounted) {
        final errorMessage = widget.authService.errorMessage ?? 'Google Sign In failed';
         if (errorMessage.contains('approval')) {
             // Teacher pending approval specific handling usually just a snackbar
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.authService,
      builder: (context, child) {
        return Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              const SizedBox(height: 16),
              // Role selection (Student or Teacher only)
              DropdownButtonFormField<UserRole>(
                value: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  items: const <DropdownMenuItem<UserRole>>[
                    DropdownMenuItem(value: UserRole.student, child: Text('Student')),
                    DropdownMenuItem(value: UserRole.teacher, child: Text('Teacher')),
                  ],
                  onChanged: (UserRole? role) {
                    if (role != null) setState(() => _selectedRole = role);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'Enter your first and last name',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.person_outline),
                    errorText: _nameError,
                  ),
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) {
                    if (_nameError != null) {
                      setState(() => _nameError = null);
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your full name';
                    }
                    if (value.trim().split(' ').length < 2) {
                      return 'Please enter your first and last name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Teacher-specific fields
                if (_selectedRole == UserRole.teacher) ...[
                  TextFormField(
                    controller: _departmentController,
                    decoration: InputDecoration(
                      labelText: 'Department',
                      hintText: 'e.g., Computer Science, Engineering',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.business),
                      errorText: _departmentError,
                    ),
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) {
                      if (_departmentError != null) {
                        setState(() => _departmentError = null);
                      }
                    },
                    validator: (value) {
                      if (_selectedRole == UserRole.teacher && (value == null || value.trim().isEmpty)) {
                        return 'Please enter your department';
                      }
                      if (_selectedRole == UserRole.teacher && _departmentController.text.trim().isEmpty) {
                        return 'Department required for teachers';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _employeeIdController,
                    decoration: const InputDecoration(
                      labelText: 'Employee ID',
                      hintText: 'Enter your employee ID',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge),
                    ),
                    validator: (value) {
                      if (_selectedRole == UserRole.teacher && (value == null || value.isEmpty)) {
                        return 'Please enter your employee ID';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Designation>(
                    decoration: InputDecoration(
                      labelText: 'Designation',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.workspace_premium),
                      errorText: _designationError,
                    ),
                    items: Designation.values.map((designation) {
                      return DropdownMenuItem(
                        value: designation,
                        child: Text(designation.displayName),
                      );
                    }).toList(),
                    validator: (value) {
                      if (_selectedRole == UserRole.teacher && value == null) {
                        return 'Please select your designation';
                      }
                      return null;
                    },
                    onChanged: (Designation? value) {
                      setState(() {
                        _selectedDesignation = value;
                        if (_designationError != null) {
                          _designationError = null;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                // Phone number (optional for all)
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number (Optional)',
                    hintText: 'Enter your phone number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter your email address',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  autofillHints: const [AutofillHints.email],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter a secure password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    if (value.length > 128) {
                      return 'Password must be less than 128 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    hintText: 'Re-enter your password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: widget.authService.isLoading ? null : _handleSignup,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: widget.authService.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Create Account',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: Divider(color: Theme.of(context).colorScheme.outlineVariant)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('OR', style: Theme.of(context).textTheme.bodySmall),
                    ),
                    Expanded(child: Divider(color: Theme.of(context).colorScheme.outlineVariant)),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: widget.authService.isLoading ? null : _handleGoogleSignIn,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.grey),
                    ),
                    icon: Image.network(
                      'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/768px-Google_%22G%22_logo.svg.png',
                      height: 24,
                      width: 24,
                      errorBuilder: (context, error, stackTrace) => 
                        const Icon(Icons.g_mobiledata, size: 28, color: Colors.blue),
                    ),
                    label: const Text('Sign up with Google', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
      },
    );
  }
}


