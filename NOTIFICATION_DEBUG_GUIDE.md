# System Notification Debugging Guide

## Current Status
The in-app notifications are working correctly (showing in the notification bell), but system-level notifications (in the phone's notification panel) are not appearing.

## Possible Causes

### 1. **Permission Issues**
Android 13+ requires explicit runtime permission for notifications. The app requests this permission on startup, but users can deny it.

### 2. **App Battery Optimization**
Some Android devices (especially Xiaomi, Oppo, Vivo) aggressively kill background processes and block notifications from apps not in their whitelist.

### 3. **Notification Channel Issues**
Android requires notification channels to be properly configured. Our channel is set up, but some devices may have additional restrictions.

## How to Test

### Step 1: Run the App
```bash
flutter run
```

### Step 2: Check Initialization Logs
When the app starts, look for these debug messages in the console:
```
NotificationService: Starting initialization...
NotificationService: Permission status: PermissionStatus.granted
NotificationService: Plugin initialization result: true
NotificationService: Local notifications initialized successfully
```

If you see `PermissionStatus.denied`, the user needs to grant permission.

### Step 3: Use the Test Screen
1. Open the app
2. Tap the **menu button** (three dots) in the top right
3. Select **"Test Notifications"**
4. Tap the **"Send Test Notification"** button
5. Check your phone's notification panel

### Step 4: Check Debug Output
After tapping the test button, you should see:
```
NotificationService: Attempting to show local notification: Test Notification
NotificationService: User has notifications enabled, proceeding...
NotificationService: Initialized status: true
NotificationService: Calling _localNotifications.show()...
NotificationService: Local notification shown successfully!
```

If you see an error instead, that will tell us what's wrong.

## Common Fixes

### Fix 1: Grant Notification Permission
1. Go to **Settings** > **Apps** > **projectshowcase**
2. Tap **Notifications**
3. Enable **"Allow notifications"**
4. Restart the app

### Fix 2: Disable Battery Optimization
1. Go to **Settings** > **Apps** > **projectshowcase**
2. Tap **Battery** or **Battery usage**
3. Select **"Unrestricted"** or **"Don't optimize"**
4. Restart the app

### Fix 3: Check Do Not Disturb
1. Swipe down from the top of your screen
2. Make sure **Do Not Disturb** is OFF
3. Try the test notification again

### Fix 4: Clear App Data (Last Resort)
1. Go to **Settings** > **Apps** > **projectshowcase**
2. Tap **Storage**
3. Tap **Clear data**
4. Restart the app and grant permissions again

## Device-Specific Issues

### Xiaomi/MIUI
- Go to **Settings** > **Apps** > **Manage apps** > **projectshowcase**
- Enable **"Autostart"**
- Set **"Battery saver"** to **"No restrictions"**
- Enable all notification permissions

### Oppo/ColorOS
- Go to **Settings** > **Battery** > **App Battery Management**
- Find **projectshowcase** and disable optimization

### Vivo/FuntouchOS
- Go to **Settings** > **Battery** > **Background power consumption management**
- Add **projectshowcase** to the whitelist

## Next Steps

1. **Run the test** using the Test Notifications screen
2. **Check the console logs** for any errors
3. **Share the debug output** with me so I can identify the exact issue
4. **Try the common fixes** above based on your device

## Technical Details

The notification system uses:
- `flutter_local_notifications` package for system notifications
- `permission_handler` for runtime permission requests
- Android notification channels with:
  - Importance: MAX
  - Priority: HIGH
  - Sound: Enabled
  - Vibration: Enabled

The notification is triggered when:
1. A new notification arrives from Firestore
2. The notification is unread
3. The user has notifications enabled in their profile
4. The notification hasn't been processed before (to avoid duplicates)
