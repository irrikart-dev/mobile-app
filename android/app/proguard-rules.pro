# IrriKart ProGuard/R8 rules.
# Applied to release builds (minifyEnabled + shrinkResources).

# --- Flutter ---
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# --- Razorpay (payments, M2) ---
# Razorpay's checkout uses reflection and a JavaScript bridge.
-keep class com.razorpay.** { *; }
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-optimizations !method/inlining/*
-dontwarn com.razorpay.**
-dontwarn proguard.annotation.**

# --- Gson / reflection-based JSON (pulled in by payment and Firebase SDKs) ---
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-dontwarn sun.misc.**

# --- Keep model classes' fields for any reflective deserialization ---
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
