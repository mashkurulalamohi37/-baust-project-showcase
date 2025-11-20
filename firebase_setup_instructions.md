# Firebase Setup Instructions

## Deploy Firestore Security Rules

To fix the Firestore permission issues, you need to deploy the security rules to your Firebase project.

### Step 1: Install Firebase CLI (if not already installed)
```bash
npm install -g firebase-tools
```

### Step 2: Login to Firebase
```bash
firebase login
```

### Step 3: Initialize Firebase in your project directory
```bash
firebase init firestore
```

### Step 4: Deploy the security rules
```bash
firebase deploy --only firestore:rules
```

### Alternative: Use Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `projectshowcase-56c2b`
3. Go to Firestore Database → Rules
4. Replace the existing rules with the content from `firestore.rules`
5. Click "Publish"

## Deploy Firebase Storage Security Rules

### Step 1: Deploy Storage Rules using Firebase CLI
```bash
firebase deploy --only storage
```

### Step 2: Or use Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `projectshowcase-56c2b`
3. Go to Storage → Rules
4. Replace the existing rules with the content from `storage.rules`
5. Click "Publish"

## After deploying the rules:
- The app will be able to read/write to Firestore
- The app will be able to upload files to Firebase Storage
- All data will be stored in Firestore instead of local storage
- Images and PDFs will be stored in Firebase Storage
- Projects will properly appear for teacher approval
- Projects will persist after logout/login

## Project ID: projectshowcase-56c2b
## Storage Bucket: projectshowcase-56c2b.firebasestorage.app

## Important Note About File Storage:
- **Firestore** stores project metadata (title, abstract, URLs, etc.)
- **Firebase Storage** stores files (images, PDFs, videos)
- This is the correct and standard Firebase architecture
- Files cannot be stored directly in Firestore (it's a document database, not a file system)
