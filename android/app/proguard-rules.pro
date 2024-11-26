# lib/android/app/proguard-rules.pro

# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.google.firebase.provider.FirebaseInitProvider { *; }

# Gson
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# App specific
-keep class com.nikolausfranz.uas_pokedexapp.** { *; }
-keepclassmembers class com.nikolausfranz.uas_pokedexapp.** { *; }

# General Android
-keep class android.support.v7.widget.** { *; }
-keep interface android.support.v7.widget.** { *; }

# AndroidX
-keep class androidx.** { *; }
-keep interface androidx.** { *; }
-keepclassmembers class androidx.** { *; }

# Material Design
-keep class com.google.android.material.** { *; }
-dontwarn com.google.android.material.**

# MIUI Optimization
-keep class android.view.** { *; }
-keep class android.graphics.** { *; }

# Warnings to ignore
-dontwarn android.**
-dontwarn com.google.android.material.**
-dontwarn androidx.**
-dontwarn io.flutter.embedding.**

# Keep source file names and line numbers
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Debugging
-keepattributes *Annotation*

# Native methods
-keepclasseswithmembernames class * {
   native <methods>;
}

# Enums
-keepclassmembers enum * {
   public static **[] values();
   public static ** valueOf(java.lang.String);
}

# Parcelables
-keepclassmembers class * implements android.os.Parcelable {
   public static final android.os.Parcelable$Creator *;
}

# R8 optimization
-allowaccessmodification
-repackageclasses ''