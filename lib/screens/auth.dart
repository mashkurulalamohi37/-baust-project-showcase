import 'package:flutter/material.dart';
import '../mvc/controllers/auth_service.dart';
import '../mvc/models/user.dart';

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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withOpacity(0.08),
              theme.colorScheme.secondary.withOpacity(0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: size.width > 1000 ? 1100 : 900,
                maxHeight: size.height * 0.9,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Card(
                  elevation: 6,
                  color: theme.colorScheme.surface,
                  shadowColor: theme.colorScheme.primary.withOpacity(0.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'ProjectShowcase',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Select your role to continue',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _RoleSelector(
                          selectedRole: _selectedRole,
                          onRoleChanged: (role) => setState(() => _selectedRole = role),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: _AuthTabs(
                            authService: widget.authService,
                            selectedRole: _selectedRole,
                            onEnter: widget.onEnter,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleSelector extends StatelessWidget {
  const _RoleSelector({
    required this.selectedRole,
    required this.onRoleChanged,
  });
  final UserRole selectedRole;
  final ValueChanged<UserRole> onRoleChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SegmentedButton<UserRole>(
      segments: [
        ButtonSegment(
          value: UserRole.student,
          label: Text(UserRole.student.displayName),
          icon: const Icon(Icons.school, size: 18),
        ),
        ButtonSegment(
          value: UserRole.teacher,
          label: Text(UserRole.teacher.displayName),
          icon: const Icon(Icons.rate_review, size: 18),
        ),
        ButtonSegment(
          value: UserRole.admin,
          label: Text(UserRole.admin.displayName),
          icon: const Icon(Icons.admin_panel_settings, size: 18),
        ),
      ],
      selected: {selectedRole},
      onSelectionChanged: (Set<UserRole> selection) {
        onRoleChanged(selection.first);
      },
      style: SegmentedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TabBar(
          controller: _controller,
          tabs: const <Tab>[Tab(text: 'Login'), Tab(text: 'Sign Up')],
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TabBarView(
            controller: _controller,
            children: <Widget>[
              _LoginForm(
                authService: widget.authService,
                selectedRole: widget.selectedRole,
                onSubmit: () => widget.onEnter(widget.selectedRole),
              ),
              _SignupForm(
                authService: widget.authService,
                initialRole: widget.selectedRole,
                onEnter: widget.onEnter,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoginForm extends StatefulWidget {
  const _LoginForm({
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
  bool _hidePassword = true;

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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.authService,
      builder: (context, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email, size: 20),
                    filled: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _hidePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock, size: 20),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    suffixIcon: IconButton(
                      icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                      onPressed: () => setState(() => _hidePassword = !_hidePassword),
                    ),
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
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: widget.authService.isLoading ? null : _handleLogin,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: widget.authService.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Continue',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SignupForm extends StatefulWidget {
  const _SignupForm({
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
  Designation _designation = Designation.lecturer;
  bool _hidePassword = true;
  bool _hideConfirm = true;

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
        designation: _selectedRole == UserRole.teacher ? _designation : null,
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
          message = 'Teacher account created! Your account is pending admin approval. Please contact an administrator.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
          // Don't call onEnter for teachers - they need admin approval
        } else {
          message = 'Account created successfully! Welcome $userName';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
          // Only call onEnter for students who can immediately access the app
          widget.onEnter(_selectedRole);
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.authService.errorMessage ?? 'Signup failed. Please try again.'),
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.authService,
      builder: (context, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Role selection (Student or Teacher only)
                DropdownButtonFormField<UserRole>(
                  value: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person, size: 20),
                    filled: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  items: const <DropdownMenuItem<UserRole>>[
                    DropdownMenuItem(value: UserRole.student, child: Text('Student')),
                    DropdownMenuItem(value: UserRole.teacher, child: Text('Teacher')),
                  ],
                  onChanged: (UserRole? role) {
                    if (role != null) setState(() => _selectedRole = role);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'Enter your first and last name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline, size: 20),
                    filled: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  textCapitalization: TextCapitalization.words,
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
                const SizedBox(height: 12),
                // Teacher-specific fields
                if (_selectedRole == UserRole.teacher) ...[
                  TextFormField(
                    controller: _departmentController,
                    decoration: const InputDecoration(
                      labelText: 'Department',
                      hintText: 'e.g., Computer Science, Engineering',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business, size: 20),
                      filled: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your department';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Designation>(
                    value: _designation,
                    decoration: const InputDecoration(
                      labelText: 'Designation',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.work, size: 20),
                      filled: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    items: Designation.values.map((designation) {
                      return DropdownMenuItem(
                        value: designation,
                        child: Text(designation.displayName),
                      );
                    }).toList(),
                    onChanged: (Designation? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _designation = newValue;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _employeeIdController,
                    decoration: const InputDecoration(
                      labelText: 'Employee ID',
                      hintText: 'Enter your employee ID',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge, size: 20),
                      filled: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your employee ID';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                // Phone number (optional for all)
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number (Optional)',
                    hintText: 'Enter your phone number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone, size: 20),
                    filled: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter your email address',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email, size: 20),
                    filled: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _hidePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter a secure password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock, size: 20),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    suffixIcon: IconButton(
                      icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                      onPressed: () => setState(() => _hidePassword = !_hidePassword),
                    ),
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
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _hideConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    hintText: 'Re-enter your password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    suffixIcon: IconButton(
                      icon: Icon(_hideConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                      onPressed: () => setState(() => _hideConfirm = !_hideConfirm),
                    ),
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
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: widget.authService.isLoading ? null : _handleSignup,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


