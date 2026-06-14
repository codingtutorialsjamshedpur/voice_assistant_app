# Flutter Local Notifications Plugin - Prevent R8 from stripping type info
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }

# Keep Gson generic type info (needed for notification serialization)
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Keep the notification models
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# Gson specific classes
-dontwarn sun.misc.**
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# ── Media3 / Transformer (used by flutter_native_video_trimmer) ──
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# flutter_native_video_trimmer plugin classes
-keep class com.example.video_trimmer.** { *; }
-dontwarn com.example.video_trimmer.**

# ═══════════════════════════════════════════════════════════════════
# ── Google AdMob / Mobile Ads SDK ──────────────────────────────────
# R8 strips these in release builds causing SILENT ad failures.
# Without these rules: ads load = 0, no crash, no error log.
# ═══════════════════════════════════════════════════════════════════
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**
-keep class com.google.ads.** { *; }
-dontwarn com.google.ads.**

# Required for AdMob mediation
-keep class com.google.android.gms.internal.ads.** { *; }
-dontwarn com.google.android.gms.internal.ads.**

# Keep AdMob's JavaScript engine bridge (prevents JavascriptEngine errors)
-keep class com.google.android.gms.ads.internal.** { *; }

# Keep Flutter AdMob plugin classes
-keep class io.flutter.plugins.googlemobileads.** { *; }
-dontwarn io.flutter.plugins.googlemobileads.**

# Keep Play Services Base (AdMob dependency)
-keep class com.google.android.gms.common.** { *; }
-dontwarn com.google.android.gms.common.**
