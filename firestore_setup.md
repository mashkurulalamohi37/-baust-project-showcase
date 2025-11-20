# Firestore Security Rules Setup

## Deploy Firestore Rules

To fix the Firestore permission issues, you need to deploy the security rules:

### Option 1: Using Firebase CLI (Recommended)

1. Install Firebase CLI:
   ```bash
   npm install -g firebase-tools
   ```

2. Login to Firebase:
   ```bash
   firebase login
   ```

3. Initialize Firebase in your project:
   ```bash
   firebase init firestore
   ```

4. Deploy the rules:
   ```bash
   firebase deploy --only firestore:rules
   ```

### Option 2: Using Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to Firestore Database → Rules
4. Replace the existing rules with the content from `firestore.rules`
5. Click "Publish"

## Important Notes

- These rules allow full read/write access for development/testing
- For production, you should implement proper authentication-based rules
- After deploying rules, restart your Flutter app to test Firestore connectivity

## Testing

After deploying the rules:
1. Sign up as a teacher
2. Check if teacher appears in admin panel
3. Submit a project as a student
4. Check if project appears in teacher panel for approval
5. Verify projects persist after logout/login
