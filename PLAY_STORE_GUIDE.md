# 🚀 Play Store Publication Guide

This guide helps you build a production-ready Android App Bundle (AAB) that is optimized, secure, and ready for Google Play Store upload.

## ✅ Optimizations Automatically Applied
1.  **Code Shrinking & Obfuscation (R8/ProGuard)**: Enabled to reduce app size and make reverse engineering harder.
2.  **Resource Shrinking**: Unused resources are removed.
3.  **Security**: Removed insecure `usesCleartextTraffic` (HTTP) allowance. HTTPS is now enforced.
4.  **Signing Configuration**: Prepared the build script to use a secure release keystore.

---

## 🔐 Step 1: Generate a Release Keystore
You need a private key to sign your app. **Keep this safe!** If you lose it, you cannot update your app.

1.  Open your terminal/command prompt.
2.  Run the following command (copy-paste explicitly):
    ```powershell
    & "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkey -v -keystore d:\projectShowcase\android\upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
    ```
    *(Note: You might need to add `keytool` to your PATH or run it from the Java bin directory. It usually comes with Android Studio).*

3.  It will ask questions:
    *   **Password**: Create a strong password (remember it!).
    *   **First/Last Name, Org Unit, etc.**: Fill these out (e.g., "BAUST Project Showcase", "IT", "BAUST", "Saidpur", "Rangpur", "BD").
    *   **Confirm**: Type `yes`.

---

## 🔑 Step 2: Create `key.properties`
To tell the build system where your key is without exposing passwords in your code:

1.  Create a file named `key.properties` in the `android/` folder (`d:\projectShowcase\android\key.properties`).
2.  Add the following content (replace with your actual passwords):

    ```properties
    storePassword=YOUR_STORE_PASSWORD
    keyPassword=YOUR_KEY_PASSWORD
    keyAlias=upload
    storeFile=../upload-keystore.jks
    ```

    *   **Important**: Make sure `storeFile` points to where you created the `.jks` file. `../` means "one folder up" from `app/` (which is where `android/` is).

---

## 📦 Step 3: Build the App Bundle
Google Play requires an `.aab` (Android App Bundle) file, not an `.apk`.

1.  Open terminal in your project root (`d:\projectShowcase`).
2.  Run:
    ```bash
    flutter build appbundle --release
    ```
3.  The file will be created at:
    `build\app\outputs\bundle\release\app-release.aab`

---

## 🚀 Step 4: Upload to Play Console
1.  Go to [Google Play Console](https://play.google.com/console).
2.  Create an account (requires $25 one-time fee) if you haven't.
3.  **Create App**:
    *   App Name: "BAUST Project Showcase"
    *   Language: English
    *   App or Game: App
    *   Free or Paid: Free
4.  **Upload Bundle**: Go to "Production" (or "Testing"), create a new release, and upload your `app-release.aab`.

---

## 🛡️ Step 5: Play Protect & Data Safety
Google requires you to declare what data your app collects.

**Data Safety Form Answers** (Based on your features):
*   **Does your app collect or share any of the required user data types?** -> **Yes**
*   **Is all user data collected by your app encrypted in transit?** -> **Yes** (Firebase handles this).
*   **Do you provide a way for users to request that their data be deleted?** -> **Yes** (You can delete users in Firebase).

**Data Types to Declare:**
1.  **Personal Info**:
    *   *Name*: Collected for App functionality (Profile).
    *   *Email Address*: Collected for App functionality (Auth).
    *   *User IDs*: Collected for App functionality.
    *   *Other Info*: Designation/Dept.
2.  **Photos and Videos**:
    *   *Photos*: Collected (Profile pictures, Project thumbnails).
3.  **Files and Docs**:
    *   *Files*: Collected (Project reports/PDFs).
4.  **Device or other IDs**:
    *   *Device ID*: Used for App functionality (Notifications/Firebase Messaging).

**Permissions:**
*   You use `POST_NOTIFICATIONS`. No special declaration needed on the store, but users are asked at runtime.
*   You removed `REQUEST_INSTALL_PACKAGES` (good!).
*   You removed `usesCleartextTraffic` (good!).

---

## ⚠️ Important Tips
*   **Never commit `key.properties` or `upload-keystore.jks` to GitHub.** Add them to `.gitignore`.
*   **Test the Release Build**: Before uploading, run `flutter run --release` on a real device to make sure obfuscation didn't break anything.
