# 🔧 Integration Guide - Adding Profile Settings to Dashboards

## Quick Integration Steps

Follow these steps to add the Profile Settings button to your existing dashboards.

---

## 📍 Where to Add

You can add the Profile Settings access in any of these locations:
1. **AppBar** (Recommended)
2. **Drawer Menu**
3. **Bottom Navigation**
4. **Floating Action Button**
5. **Settings Tab**

---

## 🎯 Method 1: AppBar Button (Recommended)

### Student Dashboard Example

**File:** `lib/mvc/views/student_dashboard.dart`

**Add to AppBar:**
```dart
AppBar(
  title: const Text('Student Dashboard'),
  actions: [
    // Add this IconButton
    IconButton(
      icon: const Icon(Icons.settings),
      tooltip: 'Profile Settings',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ProfileSettingsScreen(),
          ),
        );
      },
    ),
  ],
)
```

### Teacher Dashboard Example

**File:** `lib/mvc/views/teacher_dashboard.dart`

Same code as above - just add to the AppBar actions.

### Admin Dashboard Example

**File:** `lib/mvc/views/admin_dashboard.dart`

Same code as above - add to AppBar actions.

---

## 🎯 Method 2: Drawer Menu

### Add to Drawer

```dart
Drawer(
  child: ListView(
    padding: EdgeInsets.zero,
    children: [
      // User header
      UserAccountsDrawerHeader(
        accountName: Text(authService.currentUser?.name ?? 'User'),
        accountEmail: Text(authService.currentUser?.email ?? ''),
        currentAccountPicture: CircleAvatar(
          child: Text(
            authService.currentUser?.name[0].toUpperCase() ?? 'U',
            style: const TextStyle(fontSize: 24),
          ),
        ),
      ),
      
      // ... other menu items ...
      
      // Add Profile Settings item
      ListTile(
        leading: const Icon(Icons.settings),
        title: const Text('Profile Settings'),
        onTap: () {
          Navigator.pop(context); // Close drawer
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ProfileSettingsScreen(),
            ),
          );
        },
      ),
      
      const Divider(),
      
      // Logout
      ListTile(
        leading: const Icon(Icons.logout),
        title: const Text('Logout'),
        onTap: () async {
          await authService.logout();
          if (context.mounted) {
            Navigator.pushReplacementNamed(context, '/login');
          }
        },
      ),
    ],
  ),
)
```

---

## 🎯 Method 3: Bottom Navigation

### Add Profile Tab

```dart
int _selectedIndex = 0;

final List<Widget> _screens = [
  const HomeTab(),
  const ProjectsTab(),
  const NotificationsTab(),
  const ProfileSettingsScreen(), // Add this
];

BottomNavigationBar(
  currentIndex: _selectedIndex,
  onTap: (index) {
    setState(() {
      _selectedIndex = index;
    });
  },
  items: const [
    BottomNavigationBarItem(
      icon: Icon(Icons.home),
      label: 'Home',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.folder),
      label: 'Projects',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.notifications),
      label: 'Notifications',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person), // Add this
      label: 'Profile',
    ),
  ],
)
```

---

## 🎯 Method 4: Floating Action Button

```dart
Scaffold(
  appBar: AppBar(
    title: const Text('Dashboard'),
  ),
  body: YourDashboardContent(),
  floatingActionButton: FloatingActionButton(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ProfileSettingsScreen(),
        ),
      );
    },
    tooltip: 'Profile Settings',
    child: const Icon(Icons.settings),
  ),
)
```

---

## 🎯 Method 5: Settings Tab

### If you have a TabBar

```dart
TabBar(
  tabs: const [
    Tab(icon: Icon(Icons.home), text: 'Home'),
    Tab(icon: Icon(Icons.folder), text: 'Projects'),
    Tab(icon: Icon(Icons.settings), text: 'Settings'), // Add this
  ],
)

TabBarView(
  children: [
    const HomeTab(),
    const ProjectsTab(),
    const ProfileSettingsScreen(), // Add this
  ],
)
```

---

## 📦 Import Statement

Don't forget to add the import at the top of your dashboard file:

```dart
import 'profile_settings_screen.dart';
```

Or if it's in a different directory:

```dart
import '../views/profile_settings_screen.dart';
```

---

## 🎨 Customization Options

### Change Icon
```dart
IconButton(
  icon: const Icon(Icons.person), // or Icons.account_circle
  // ...
)
```

### Add Badge for Notifications
```dart
IconButton(
  icon: Badge(
    label: Text('!'),
    child: const Icon(Icons.settings),
  ),
  // ...
)
```

### Custom Button Style
```dart
ElevatedButton.icon(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProfileSettingsScreen(),
      ),
    );
  },
  icon: const Icon(Icons.settings),
  label: const Text('Settings'),
)
```

---

## 🔍 Example: Complete AppBar Integration

Here's a complete example showing how to add it to an existing AppBar:

### Before:
```dart
AppBar(
  title: const Text('Student Dashboard'),
)
```

### After:
```dart
AppBar(
  title: const Text('Student Dashboard'),
  actions: [
    // Notifications button
    IconButton(
      icon: const Icon(Icons.notifications),
      onPressed: () {
        // Navigate to notifications
      },
    ),
    // Profile Settings button (NEW)
    IconButton(
      icon: const Icon(Icons.settings),
      tooltip: 'Profile Settings',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ProfileSettingsScreen(),
          ),
        );
      },
    ),
  ],
)
```

---

## ✅ Checklist

After integration, verify:

- [ ] Import statement added
- [ ] Navigation button visible
- [ ] Button opens Profile Settings screen
- [ ] User information displays correctly
- [ ] Notification toggle works
- [ ] Settings save successfully
- [ ] Back button returns to dashboard

---

## 🎯 Recommended Approach

**For most dashboards, we recommend Method 1 (AppBar Button):**

✅ Always visible  
✅ Familiar location  
✅ Easy to access  
✅ Doesn't take up screen space  
✅ Standard UI pattern  

---

## 🚀 Quick Start

**Fastest way to add:**

1. Open your dashboard file
2. Find the `AppBar` widget
3. Add `actions: [...]` if not present
4. Add the IconButton code from Method 1
5. Add the import statement
6. Test!

---

## 📞 Need Help?

If you encounter issues:
1. Check the import path is correct
2. Verify `ProfileSettingsScreen` is in the right location
3. Make sure `Navigator` is available in context
4. Check console for error messages

---

*Integration should take less than 5 minutes!* ⚡
