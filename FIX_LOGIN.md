# Fix Login Issue - Step by Step Instructions

## The Problem
Firestore security rules are cached on the device and need a FULL RESTART to update.

## Solution Steps

### 1. Verify Rules Are Deployed
The rules have been deployed. You can verify at:
https://console.firebase.google.com/project/projectshowcase-56c2b/firestore/rules

The current rules should be:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

### 2. FULLY RESTART THE APP (CRITICAL!)

**DO NOT use hot reload!** You must:

1. **Stop the app completely:**
   - Press the stop button in your IDE/VS Code
   - OR close the app on your device
   - OR uninstall and reinstall the app

2. **Clear app data (recommended):**
   - On Android: Settings → Apps → ProjectShowcase → Storage → Clear Data
   - This clears the cached Firestore rules

3. **Rebuild and run:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

### 3. Alternative: Manual Rule Update via Console

If restart doesn't work, manually update rules in Firebase Console:

1. Go to: https://console.firebase.google.com/project/projectshowcase-56c2b/firestore/rules
2. Replace all rules with:
   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /{document=**} {
         allow read, write: if true;
       }
     }
   }
   ```
3. Click "Publish"
4. Wait 30 seconds
5. FULLY RESTART the app (not hot reload!)

### 4. Test Login

After full restart, try logging in with:
- Email: `ohi@gmail.com`
- Password: (whatever password you set)
- Role: Student

### 5. If Still Not Working

Check the console logs. You should see:
- `FirestoreService: Query on email returned X documents` (not permission denied)
- If you still see permission denied, the rules haven't updated yet

## Why This Happens

Firestore security rules are cached on the client device for performance. When rules change:
- Hot reload: ❌ Rules stay cached
- Hot restart: ❌ Rules stay cached  
- Full app restart: ✅ Rules are re-fetched
- Clear app data + restart: ✅✅ Guaranteed fresh rules

