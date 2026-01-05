## Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

## Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

## Firebase
-keep class com.google.firebase.** { *; }

## Prevent obfuscating generic Flutter classes
-keep class com.example.projectshowcase.** { *; }
