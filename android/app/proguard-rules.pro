# Applied automatically by the Flutter Gradle plugin to release builds (R8).

# flutter_local_notifications stores notification details with Gson; without
# these rules R8 strips the generic type info and the app crashes at runtime
# ("Missing type parameter").
-keep class com.dexterous.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keepattributes Signature
-keepattributes *Annotation*

# flutter_secure_storage (EncryptedSharedPreferences / Tink)
-keep class androidx.security.crypto.** { *; }
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
