import 'dart:async';
import 'package:flutter/material.dart';
import '../mvc/controllers/auth_service.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final String name;
  final AuthService authService;
  final VoidCallback onVerified;
  final VoidCallback onCancel;

  const EmailVerificationScreen({
    super.key,
    required this.email,
    required this.name,
    required this.authService,
    required this.onVerified,
    required this.onCancel,
  });

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;
  int _resendTimeout = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
    // Initially initiate verification if it hasn't been done
    // Assuming it's already sent from auth.dart before coming here, but we can resend later.
  }

  void _startTimer() {
    setState(() => _resendTimeout = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimeout > 0) {
        setState(() => _resendTimeout--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _verifyOTP() async {
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length < 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final success = await widget.authService.verifyEmailOTP(widget.email, otp);

    setState(() => _isVerifying = false);

    if (success) {
      widget.onVerified();
    } else {
      setState(() {
        _errorMessage = widget.authService.errorMessage ?? 'Invalid verification code';
      });
      // Clear fields on error
      for (var c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
    }
  }

  Future<void> _resendOTP() async {
    if (_resendTimeout > 0 || _isResending) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    final success = await widget.authService.initiateEmailVerification(
      widget.email,
      widget.name,
    );

    setState(() => _isResending = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification code resent!')),
      );
      _startTimer();
      for (var c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
    } else {
      setState(() {
        _errorMessage = widget.authService.errorMessage ?? 'Failed to resend code';
      });
    }
  }

  void _onDigitChanged(int index, String value) {
    setState(() => _errorMessage = null);
    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _verifyOTP(); // Auto-verify when last digit is entered
      }
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Widget _buildDigitBox(int index) {
    final theme = Theme.of(context);
    return Container(
      width: 45,
      height: 55,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(
          color: _focusNodes[index].hasFocus
              ? theme.colorScheme.primary
              : theme.colorScheme.outline.withOpacity(0.5),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: _focusNodes[index].hasFocus
            ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.2),
                  blurRadius: 8,
                  spreadRadius: 2,
                )
              ]
            : [],
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
        ),
        onChanged: (value) => _onDigitChanged(index, value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // If we are showing this as a standalone screen, Scaffold is needed.
    // However, it will be embedded in AuthGate, so we return a Card/Container.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: widget.onCancel,
              tooltip: 'Go back',
            ),
            const Text(
              'Verification',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 48), // Balance for centering
          ],
        ),
        const SizedBox(height: 24),
        Icon(
          Icons.mark_email_read,
          size: 64,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          'Check your email',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            children: [
              const TextSpan(text: 'We\'ve sent a 6-digit verification code to\n'),
              TextSpan(
                text: widget.email,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (index) => _buildDigitBox(index)),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: TextStyle(color: theme.colorScheme.error, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 32),
        FilledButton(
          onPressed: _isVerifying ? null : _verifyOTP,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isVerifying
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Verify Email',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Didn\'t receive the code? ',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (_resendTimeout > 0)
              Text(
                'Wait ${_resendTimeout}s',
                style: TextStyle(
                  color: theme.colorScheme.primary.withOpacity(0.5),
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              TextButton(
                onPressed: _isResending ? null : _resendOTP,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: _isResending
                    ? const SizedBox(
                        height: 12,
                        width: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Resend',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
          ],
        ),
      ],
    );
  }
}
