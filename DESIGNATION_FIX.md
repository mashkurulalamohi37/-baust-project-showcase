# Teacher Designation Change - Fix Summary

## Problem
Teacher designation changes were not being saved to Firestore.

## Root Causes Found

### 1. Missing Field in Firestore Operations
The `notificationsEnabled` field was missing from three critical methods:
- `FirestoreService.saveUser()` - When creating new users
- `FirestoreService.updateUser()` - When updating existing users
- `FirestoreService._userFromData()` - When reading user data from Firestore

**Impact**: This could cause incomplete updates or data reading issues.

### 2. Missing Local Storage Persistence
The `AuthService.updateUserProfile()` method was not calling `_persistCurrentUser()` to save changes to local SharedPreferences.

**Impact**: Even if Firestore was updated, the local user object wasn't persisted, so changes would be lost on app restart or refresh.

## Fixes Applied

### Fix 1: Added `notificationsEnabled` Field
**File**: `lib/mvc/controllers/firestore_service.dart`

Added the missing field to:
- Line 111 in `saveUser()`
- Line 415 in `updateUser()`
- Line 340 in `_userFromData()`

### Fix 2: Added Local Storage Persistence
**File**: `lib/mvc/controllers/auth_service.dart`

Updated `updateUserProfile()` method (line 534-556) to:
- Call `await _persistCurrentUser()` after updating Firestore
- Add comprehensive debugging logs

### Fix 3: Enhanced Debugging
Added detailed logging throughout the designation update flow:

**Profile Settings Screen** (`lib/screens/profile_settings_screen.dart`):
- Logs old and new designation values
- Tracks each step of the update process
- Shows errors with full details

**Auth Service** (`lib/mvc/controllers/auth_service.dart`):
- Logs user email and new designation
- Confirms Firestore update success
- Confirms local storage update success

**Firestore Service** (`lib/mvc/controllers/firestore_service.dart`):
- Logs user ID being updated
- Shows designation value being saved (both enum name and display name)
- Confirms successful save

## How to Test

1. **Run the app** (restart if already running):
   ```bash
   flutter run -d chrome
   ```

2. **Login as a teacher account**

3. **Navigate to Profile Settings**:
   - Tap on your profile icon
   - Go to Settings/Profile

4. **Change Designation**:
   - Find the "Designation" field
   - Tap the edit button (chevron icon)
   - Select a different designation (e.g., from "Lecturer" to "Assistant Professor")
   - Tap "Save"

5. **Verify the Change**:
   - You should see a green success message: "Designation updated successfully"
   - Check the console logs for the update flow (see expected logs below)

6. **Verify Persistence**:
   - Refresh the page (F5) or close and reopen the app
   - Navigate back to Profile Settings
   - The designation should still show the new value

7. **Verify Firestore**:
   - Open Firebase Console
   - Go to Firestore Database
   - Find your user document under the `users` collection
   - Check that the `designation` field shows the new enum value

## Expected Console Logs

When you change designation, you should see logs like this:

```
ProfileSettings: Old designation: Lecturer
ProfileSettings: New designation: Assistant Professor
ProfileSettings: Calling FirestoreService.updateUser...
FirestoreService: Updating user abc123
FirestoreService: Designation to save: assistantProfessor (Assistant Professor)
FirestoreService: User updated successfully: teacher@example.com
ProfileSettings: Calling AuthService.updateUserProfile...
AuthService: Updating user profile for teacher@example.com
AuthService: New designation: Assistant Professor
AuthService: Firestore update successful
AuthService: Local storage update successful
ProfileSettings: Update complete!
```

## If It Still Doesn't Work

If the designation still doesn't save, check:

1. **Console errors**: Look for any error messages in the console
2. **Firestore rules**: Ensure your Firestore security rules allow updates to the `users` collection
3. **Network**: Verify you have internet connection
4. **User permissions**: Ensure the logged-in user is actually a teacher (not student or admin)
5. **Firebase connection**: Check that your app is properly connected to Firebase

## Next Steps

If you still experience issues after this fix:
1. Share the console logs when attempting to change designation
2. Check the browser's Network tab for failed Firestore requests
3. Verify the Firestore security rules allow the update
