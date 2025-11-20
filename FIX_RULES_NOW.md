# CRITICAL: Fix Firestore Rules - Step by Step

## The Problem
You're looking at the WRONG project and WRONG rules type in Firebase Console!

## Solution

### Step 1: Go to the CORRECT Project
1. Open: https://console.firebase.google.com/project/projectshowcase-56c2b/firestore/rules
2. Make sure the URL shows `projectshowcase-56c2b` (NOT `projectshowcase-b2748`)

### Step 2: Check Firestore Database Rules (NOT Storage Rules)
1. In the left sidebar, click **"Firestore Database"** (not Storage)
2. Click on the **"Rules"** tab
3. You should see rules that start with:
   ```
   rules_version = '2';
   service cloud.firestore {
   ```

### Step 3: Verify/Update the Rules
The rules should be EXACTLY this:

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

### Step 4: If Rules Are Different
1. Copy the rules above
2. Paste them into the Firestore Rules editor
3. Click **"Publish"** button
4. Wait 30 seconds

### Step 5: FULLY RESTART THE APP
1. **Stop the app completely** (close it)
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

### Step 6: Test Login
Try logging in with `ohi@gmail.com` after the full restart.

## Why This Matters
- Your app uses project: `projectshowcase-56c2b`
- Rules must be deployed to: `projectshowcase-56c2b`
- Rules must be in: **Firestore Database** (not Storage)
- Rules must allow: `read, write: if true` for all documents

