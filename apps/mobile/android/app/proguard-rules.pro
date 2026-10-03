# Flutter & Android Core
-keep class io.flutter.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# Flutter Plugins (Reflection & JNI)
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.plugins.**

# Google Play In-App Purchase & BillingClient
-keep class com.android.billingclient.** { *; }
-keep class com.android.vending.billing.** { *; }
-keep class io.flutter.plugins.inapppurchase.** { *; }
-dontwarn com.android.billingclient.**

# SQLite / Drift / Native DB
-keep class org.sqlite.** { *; }
-keep class sqlite3.** { *; }
-keep class com.simonpham.sqlite.** { *; }
-keepclassmembers class * extends androidx.room.RoomDatabase { *; }
-dontwarn org.sqlite.**

# Firebase Messaging & Core
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class io.flutter.plugins.firebase.** { *; }

# Flutter Local Notifications & WorkManager
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# Local Auth & Biometric Security
-keep class androidx.biometric.** { *; }
-keep class io.flutter.plugins.localauth.** { *; }

# Flutter Secure Storage
-keep class androidx.security.crypto.** { *; }

# Google Sign-In
-keep class com.google.android.gms.auth.api.signin.** { *; }
-dontwarn com.google.android.gms.auth.api.signin.**

# Image Picker & Pigeon APIs
-dontwarn io.flutter.plugins.imagepicker.FlutterError
-dontwarn io.flutter.plugins.imagepicker.ImagePickerApi$Companion
-dontwarn io.flutter.plugins.imagepicker.ImagePickerApi
-dontwarn io.flutter.plugins.imagepicker.ImageSelectionOptions
-dontwarn io.flutter.plugins.imagepicker.ResultUtilsKt
-dontwarn io.flutter.plugins.imagepicker.VideoSelectionOptions

# Keep generic signatures and annotations for reflection
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
