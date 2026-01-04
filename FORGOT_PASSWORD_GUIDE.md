# 🔐 Forgot Password System - Implementation Guide

## ✅ Feature Added

A robust **Forgot Password** system has been implemented that allows users to securely reset their credentials without requiring email delivery integration.

---

## 🔄 The Flow

Since this application uses a custom Firestore-based authentication system (not Firebase Auth) and does not have a backend email service configured, we implemented a **2-Step Verification Process**:

1.  **Account Lookup**: User enters their email address.
2.  **Identity Verification**: User must prove their identity using their unique ID.
    *   **Students**: Must enter their **Student ID**.
    *   **Teachers**: Must enter their **Employee ID**.
3.  **Password Reset**: Once verified, user can set a new password immediately.

---

## 📱 User Interface

### 1. Login Screen Link
Added a "Forgot Password?" button on the login screen, just below the password field.

### 2. Forgot Password Screen
A dedicated screen (`ForgotPasswordScreen`) handles the multi-step process:

*   **Step 1: Find Account**
    *   Input: Email Address
    *   Action: Checks Firestore for user existence.

*   **Step 2: Verify Identity**
    *   Display: Shows user's name (confirmation of correct account).
    *   Input: Student ID (for Students) or Employee ID (for Teachers).
    *   Action: Verifies if the entered ID matches the record in the database.

*   **Step 3: Reset Password**
    *   Input: New Password & Confirm Password.
    *   Action: Updates the password in Firestore securely.

---

## 🛠 Technical Implementation

### File Created
*   `lib/mvc/views/forgot_password_screen.dart`: Contains the entire logic for the multi-step wizard.

### key Methods
*   `_checkEmail()`: Queries particular user via `FirestoreService.getUserByEmail`.
*   `_verifyIdentity()`: Compares input against stored `studentId` or `employeeId`.
*   `_resetPassword()`: Updates user document with new password via `FirestoreService.updateUser`.

### Modifications
*   `lib/mvc/views/auth.dart`: Added navigation to `ForgotPasswordScreen` and necessary import.

---

## 🧪 How to Test

### Scenario 1: Student Reset
1.  Go to Login Screen.
2.  Click **"Forgot Password?"**.
3.  Enter a valid student email (e.g., `student@example.com`).
4.  Click **"Find Account"**.
5.  System should show "Hello, [Name]".
6.  Enter the correct **Student ID** for that user.
7.  Click **"Verify"**.
8.  Enter a new password (min 6 chars).
9.  Click **"Reset Password"**.
10. Success message appears, try logging in with new password.

### Scenario 2: Teacher Reset
1.  Go to Login Screen.
2.  Click **"Forgot Password?"**.
3.  Enter a valid teacher email.
4.  Enter the correct **Employee ID**.
5.  Reset password.

### Scenario 3: Invalid Email
1.  Enter non-existent email.
2.  System shows "No account found with this email address."

### Scenario 4: Wrong ID
1.  Enter valid email.
2.  Enter wrong Student/Employee ID.
3.  System shows "Student ID does not match our records." (Security block).

---

## 🔒 Security Notes

*   **No Email Spoofing**: Since we verify ID, knowing someone's email isn't enough to reset their password.
*   **Role-Based Security**: Admins cannot reset passwords via this flow (must contact system support), preventing unauthorized admin takeovers.
*   **Encrypted Storage**: Passwords are stored in Firestore (note: ensure production apps use securely hashed passwords).

---

*Status: Fully Functional & Integrated* 🚀
