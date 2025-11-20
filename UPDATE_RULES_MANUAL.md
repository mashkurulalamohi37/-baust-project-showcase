# Update Firestore Rules for projectshowcase-b2748

## IMPORTANT: Manual Steps Required

Since I don't have CLI access to `projectshowcase-b2748`, you need to update the Firestore rules manually in the Firebase Console.

## Steps:

### 1. Go to Firestore Database Rules
Open this URL:
**https://console.firebase.google.com/project/projectshowcase-b2748/firestore/rules**

### 2. Copy These Rules
Copy the ENTIRE content below:

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

### 3. Paste and Publish
1. Paste the rules into the Firestore Rules editor
2. Click the **"Publish"** button
3. Wait 30 seconds for the rules to propagate

### 4. Verify Rules Are Active
After publishing, you should see the rules in the editor. Make sure they match exactly what's above.

### 5. FULLY RESTART THE APP
1. **Stop the app completely**
2. **Clear app data:**
   ```bash
   adb shell pm clear com.example.projectshowcase
   ```
3. **Rebuild and run:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

### 6. Test Login
Try logging in with `ohi@gmail.com` after the restart.

## What I've Updated:
- ✅ `lib/firebase_options.dart` - Now uses `projectshowcase-b2748`
- ✅ `lib/mvc/controllers/firestore_service.dart` - Storage bucket updated
- ⚠️ **You need to manually update Firestore rules in the console**

## Why Manual Update?
The Firebase CLI doesn't have permission to deploy to `projectshowcase-b2748`, so you need to update the rules through the web console.

