import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/user.dart';
import '../controllers/auth_service.dart';
import '../controllers/firestore_service.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({Key? key}) : super(key: key);

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _notificationsEnabled = true;
  final TextEditingController _nameController = TextEditingController();
  Designation? _selectedDesignation;

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _loadUserSettings() {
    final user = _authService.currentUser;
    if (user != null) {
      setState(() {
        _notificationsEnabled = user.notificationsEnabled;
        _nameController.text = user.name;
        _selectedDesignation = user.designation;
      });
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _authService.currentUser;
      if (user != null) {
        final updatedUser = user.copyWith(
          notificationsEnabled: value,
          updatedAt: DateTime.now(),
        );

        await FirestoreService.updateUser(updatedUser);
        await _authService.updateUserProfile(updatedUser);

        setState(() {
          _notificationsEnabled = value;
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                value
                    ? 'Notifications enabled successfully'
                    : 'Notifications disabled successfully',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editName() async {
    final user = _authService.currentUser;
    if (user == null) return;

    _nameController.text = user.name;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit, color: Colors.blue),
            SizedBox(width: 8),
            Text('Edit Name'),
          ],
        ),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'Enter your name',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_nameController.text.trim().isNotEmpty) {
                Navigator.pop(context, _nameController.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != user.name) {
      setState(() => _isLoading = true);

      try {
        final updatedUser = user.copyWith(
          name: result,
          updatedAt: DateTime.now(),
        );

        await FirestoreService.updateUser(updatedUser);
        await _authService.updateUserProfile(updatedUser);

        setState(() => _isLoading = false);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Name updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update name: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editDesignation() async {
    final user = _authService.currentUser;
    if (user == null || user.role != UserRole.teacher) return;

    Designation? selectedDesignation = user.designation ?? Designation.lecturer;

    final result = await showDialog<Designation>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.work, color: Colors.blue),
              SizedBox(width: 8),
              Text('Edit Designation'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: Designation.values.map((designation) {
              return RadioListTile<Designation>(
                title: Text(designation.displayName),
                value: designation,
                groupValue: selectedDesignation,
                onChanged: (value) {
                  setState(() {
                    selectedDesignation = value;
                  });
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, selectedDesignation),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result != null && result != user.designation) {
      setState(() => _isLoading = true);

      try {
        final updatedUser = user.copyWith(
          designation: result,
          updatedAt: DateTime.now(),
        );

        await FirestoreService.updateUser(updatedUser);
        await _authService.updateUserProfile(updatedUser);

        setState(() {
          _selectedDesignation = result;
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Designation updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update designation: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile Settings')),
        body: const Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(user, colorScheme),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('PREFERENCES'),
                  const SizedBox(height: 12),
                  _buildNotificationCard(colorScheme),
                  const SizedBox(height: 24),
                  if (_notificationsEnabled) ...[
                    _buildSectionTitle('NOTIFICATION TYPES'),
                    const SizedBox(height: 12),
                    _buildNotificationTypesGrid(user.role, colorScheme),
                    const SizedBox(height: 24),
                  ],
                  _buildSectionTitle('SHARE APP'),
                  const SizedBox(height: 12),
                  _buildShareAppCard(colorScheme),
                  const SizedBox(height: 24),
                  _buildSectionTitle('ACCOUNT INFORMATION'),
                  const SizedBox(height: 12),
                  _buildAccountInfoCard(user, colorScheme),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(User user, ColorScheme colorScheme) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      stretch: true,
      backgroundColor: colorScheme.surface,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Background Gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary,
                    colorScheme.secondary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // Subtle Decorative Circles
            Positioned(
              top: -50,
              right: -50,
              child: CircleAvatar(
                radius: 100,
                backgroundColor: Colors.white.withOpacity(0.1),
              ),
            ),
            Positioned(
              bottom: -20,
              left: -30,
              child: CircleAvatar(
                radius: 70,
                backgroundColor: Colors.white.withOpacity(0.05),
              ),
            ),
            // Profile Content
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                _buildGlowingAvatar(user, colorScheme),
                const SizedBox(height: 16),
                _buildUserInfo(user),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlowingAvatar(User user, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 54,
        backgroundColor: Colors.white.withOpacity(0.2),
        child: CircleAvatar(
          radius: 50,
          backgroundColor: Colors.white,
          backgroundImage: user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty
              ? NetworkImage(user.profileImageUrl!)
              : null,
          child: user.profileImageUrl == null || user.profileImageUrl!.isEmpty
              ? Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                  style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildUserInfo(User user) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 40), // Offset for edit button centering
            Text(
              user.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _editName,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          user.email,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w300,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Text(
            user.role.displayName.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: Colors.grey[500],
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildNotificationCard(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceVariant.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SwitchListTile(
          value: _notificationsEnabled,
          onChanged: _isLoading ? null : _toggleNotifications,
          activeColor: colorScheme.primary,
          title: const Text(
            'Push Notifications',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Text(
            _notificationsEnabled
                ? 'Stay updated with your project status'
                : 'Turn on to receive project updates',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          secondary: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (_notificationsEnabled ? colorScheme.primary : Colors.grey).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _notificationsEnabled ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
              color: _notificationsEnabled ? colorScheme.primary : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationTypesGrid(UserRole role, ColorScheme colorScheme) {
    List<Map<String, dynamic>> types = [];

    switch (role) {
      case UserRole.student:
        types = [
          {'icon': Icons.check_circle_rounded, 'color': Colors.green, 'title': 'Approved', 'desc': 'Project accepted!'},
          {'icon': Icons.feedback_rounded, 'color': Colors.red, 'title': 'Feedback', 'desc': 'New suggestions'},
          {'icon': Icons.update_rounded, 'color': Colors.blue, 'title': 'Revision', 'desc': 'Update required'},
          {'icon': Icons.stars_rounded, 'color': Colors.amber, 'title': 'Featured', 'desc': 'Showcased!'},
        ];
        break;
      case UserRole.teacher:
        types = [
          {'icon': Icons.assignment_rounded, 'color': colorScheme.primary, 'title': 'New Submission', 'desc': 'Projects to review'},
          {'icon': Icons.comment_rounded, 'color': colorScheme.secondary, 'title': 'New Review', 'desc': 'Received feedback'},
        ];
        break;
      case UserRole.admin:
        types = [
          {'icon': Icons.person_add_rounded, 'color': colorScheme.tertiary, 'title': 'Teacher Request', 'desc': 'New account approval'},
          {'icon': Icons.system_update_rounded, 'color': colorScheme.primary, 'title': 'System', 'desc': 'Site announcements'},
        ];
        break;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: types.length,
          itemBuilder: (context, index) {
            final type = types[index];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(type['icon'], color: type['color'], size: 24),
                  const SizedBox(height: 10),
                  Text(
                    type['title'],
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    type['desc'],
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAccountInfoCard(User user, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.alternate_email_rounded, 'Email', user.email, colorScheme),
          _buildDivider(),
          _buildInfoRow(Icons.shield_rounded, 'Role', user.role.displayName, colorScheme),
          if (user.department != null) ...[
            _buildDivider(),
            _buildInfoRow(Icons.apartment_rounded, 'Department', user.department!, colorScheme),
          ],
          if (user.employeeId != null) ...[
            _buildDivider(),
            _buildInfoRow(Icons.badge_rounded, 'Employee ID', user.employeeId!, colorScheme),
          ],
          if (user.designation != null) ...[
            _buildDivider(),
            _buildInfoRow(
              Icons.work_rounded,
              'Designation',
              user.designation!.displayName,
              colorScheme,
              onEdit: user.role == UserRole.teacher ? _editDesignation : null,
            ),
          ],
          _buildDivider(),
          _buildInfoRow(Icons.event_available_rounded, 'Member Since', _formatDate(user.createdAt), colorScheme),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, ColorScheme colorScheme, {VoidCallback? onEdit}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              icon: Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
              onPressed: onEdit,
            ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, indent: 70, endIndent: 20, color: Colors.grey.withOpacity(0.1));
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget _buildShareAppCard(ColorScheme colorScheme) {
    const String appUrl = 'https://mashkurulalamohi37.github.io/-baust-project-showcase/';
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // QR Code
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: QrImageView(
                data: appUrl,
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            
            // Title
            Row(
              children: [
                Icon(Icons.ios_share, color: colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Install on iOS',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.primary.withOpacity(0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInstructionStep(
                    '1',
                    'Scan the QR code or open the link in Safari',
                    colorScheme,
                  ),
                  const SizedBox(height: 12),
                  _buildInstructionStep(
                    '2',
                    'Tap the Share button (□↑) at the bottom',
                    colorScheme,
                  ),
                  const SizedBox(height: 12),
                  _buildInstructionStep(
                    '3',
                    'Select "Add to Home Screen"',
                    colorScheme,
                  ),
                  const SizedBox(height: 12),
                  _buildInstructionStep(
                    '4',
                    'Tap "Add" to install the app',
                    colorScheme,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Copy Link Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(const ClipboardData(text: appUrl));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Link copied to clipboard!'),
                      duration: Duration(seconds: 2),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy Link'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text, ColorScheme colorScheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

