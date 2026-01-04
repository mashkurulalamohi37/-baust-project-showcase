# 🔔 Notification Preferences - User Guide

## ✅ Feature Added: Turn Notifications On/Off

Users can now control their notification preferences from the Profile Settings screen!

---

## 📱 How to Access

### From Any Dashboard:

1. **Navigate to Profile Settings**
   - Look for a "Profile" or "Settings" button in your dashboard
   - Or add a menu item/button that navigates to `ProfileSettingsScreen`

2. **View Your Profile**
   - See your account information
   - Access notification preferences

---

## 🎛️ Notification Toggle

### Location
**Profile Settings Screen** → **Preferences Section** → **Notifications Toggle**

### What It Does

- **ON (Default):** You receive all notifications
- **OFF:** You won't receive any notifications

### How to Toggle

1. Open Profile Settings
2. Find the "Notifications" switch
3. Toggle ON/OFF
4. Changes save automatically
5. You'll see a confirmation message

---

## 📋 What Notifications You'll Receive

### For Students 👨‍🎓
When notifications are **ON**, you'll receive:
- ✅ **Project Approved** - When your project is approved
- ❌ **Project Feedback** - When your project needs improvements
- 🔄 **Revision Required** - When your project needs revision
- ⭐ **Project Featured** - When your project is featured

### For Teachers 👨‍🏫
When notifications are **ON**, you'll receive:
- 📝 **New Project** - When students submit projects for review
- 💬 **New Review** - When projects receive reviews

### For Admins 👨‍💼
When notifications are **ON**, you'll receive:
- 👨‍🏫 **Teacher Approval** - When teachers request account approval
- 🔔 **System Messages** - Important system notifications

---

## 🔧 Technical Implementation

### User Model Updates

Added `notificationsEnabled` field:
```dart
class User {
  // ... other fields
  final bool notificationsEnabled; // Default: true
}
```

### Notification Service

Before sending any notification, the system checks:
```dart
// Check if user has notifications enabled
final user = await FirestoreService.getUserById(userId);
if (user == null || !user.notificationsEnabled) {
  // Don't send notification
  return false;
}
```

### Profile Settings Screen

New screen: `lib/mvc/views/profile_settings_screen.dart`

Features:
- User information display
- Notification toggle switch
- Notification types explanation
- Account details

---

## 🎨 UI Features

### Profile Header
- User avatar (first letter of name)
- Full name
- Email address
- Role badge

### Preferences Section
- **Notifications Toggle**
  - Clear ON/OFF switch
  - Descriptive subtitle
  - Loading indicator during save
  - Success/error messages

### Notification Types Info
- Shows relevant notification types based on user role
- Icons and descriptions for each type
- Only visible when notifications are enabled

### Account Information
- Email
- Role
- Department (if applicable)
- Employee ID (if applicable)
- Designation (if applicable)
- Member since date

---

## 📁 Modified Files

### 1. `lib/mvc/models/user.dart`
**Changes:**
- Added `notificationsEnabled` field
- Updated `fromJson()` method
- Updated `toJson()` method
- Updated `copyWith()` method

### 2. `lib/mvc/controllers/notification_service.dart`
**Changes:**
- Added user preference check in `sendNotification()`
- Notifications only sent if user has them enabled

### 3. `lib/mvc/views/profile_settings_screen.dart`
**New File:**
- Complete profile settings UI
- Notification toggle functionality
- User information display

---

## 🔄 How It Works

### Flow Diagram

```
User opens Profile Settings
    ↓
Views current notification preference
    ↓
Toggles notification switch
    ↓
System updates user in Firestore
    ↓
System updates local auth state
    ↓
User sees confirmation message
    ↓
Future notifications respect this setting
```

### When Notification is Sent

```
System attempts to send notification
    ↓
Checks user's notificationsEnabled setting
    ↓
If TRUE: Send notification
    ↓
If FALSE: Skip notification (log message)
```

---

## 🚀 Integration Guide

### Add to Dashboard Navigation

#### Option 1: AppBar Action
```dart
AppBar(
  title: Text('Dashboard'),
  actions: [
    IconButton(
      icon: Icon(Icons.settings),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileSettingsScreen(),
          ),
        );
      },
    ),
  ],
)
```

#### Option 2: Drawer Menu Item
```dart
Drawer(
  child: ListView(
    children: [
      // ... other items
      ListTile(
        leading: Icon(Icons.settings),
        title: Text('Profile Settings'),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileSettingsScreen(),
            ),
          );
        },
      ),
    ],
  ),
)
```

#### Option 3: Bottom Navigation
```dart
BottomNavigationBar(
  items: [
    // ... other items
    BottomNavigationBarItem(
      icon: Icon(Icons.person),
      label: 'Profile',
    ),
  ],
  onTap: (index) {
    if (index == profileIndex) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileSettingsScreen(),
        ),
      );
    }
  },
)
```

---

## 🧪 Testing

### Test Notification Toggle

1. **Login as any user**
2. **Navigate to Profile Settings**
3. **Turn notifications OFF**
4. **Trigger a notification event:**
   - Student: Have a teacher review your project
   - Teacher: Have a student submit a project
   - Admin: Have a teacher sign up
5. **Check notifications** - Should NOT receive any
6. **Turn notifications ON**
7. **Trigger another event**
8. **Check notifications** - Should receive notification

### Verify Persistence

1. Turn notifications OFF
2. Logout
3. Login again
4. Check Profile Settings - Should still be OFF
5. Verify in Firestore - `notificationsEnabled: false`

---

## 💾 Database Structure

### Users Collection Update

```json
{
  "id": "user_123",
  "name": "John Doe",
  "email": "john@example.com",
  // ... other fields
  "notificationsEnabled": true  // New field
}
```

---

## 🎯 Benefits

✅ **User Control** - Users decide if they want notifications  
✅ **Reduced Noise** - Users can disable if overwhelmed  
✅ **Privacy** - Users control their notification experience  
✅ **Flexibility** - Can toggle on/off anytime  
✅ **Persistent** - Setting saved across sessions  
✅ **Efficient** - System doesn't create notifications for users who don't want them  

---

## 🔮 Future Enhancements

Potential improvements:

1. **Granular Control**
   - Toggle specific notification types
   - Example: Only project approvals, not rejections

2. **Notification Schedule**
   - Quiet hours (e.g., 10 PM - 8 AM)
   - Weekend notifications on/off

3. **Notification Channels**
   - Email notifications
   - Push notifications
   - SMS notifications

4. **Notification Frequency**
   - Instant
   - Daily digest
   - Weekly summary

---

## 📊 Default Settings

| User Role | Default State |
|-----------|---------------|
| Student   | ON            |
| Teacher   | ON            |
| Admin     | ON            |

All users have notifications **enabled by default**. They can opt-out anytime.

---

## 🐛 Troubleshooting

### Notifications Still Coming After Turning Off

**Solution:**
1. Check Firestore - verify `notificationsEnabled: false`
2. Logout and login again
3. Clear app cache if needed

### Toggle Not Saving

**Solution:**
1. Check internet connection
2. Verify Firestore write permissions
3. Check console for error messages

### Can't Find Profile Settings

**Solution:**
1. Add navigation button to your dashboard
2. Use one of the integration methods above
3. Contact developer to add to UI

---

## ✅ Summary

**Feature:** ✅ COMPLETE  
**User Control:** ✅ Full control over notifications  
**Persistence:** ✅ Settings saved to database  
**UI:** ✅ Beautiful, intuitive interface  
**Testing:** ⏳ Ready for testing  

---

*Notification Preferences Feature - Completed: January 4, 2026*
