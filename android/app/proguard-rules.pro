# R8 / ProGuard rules for Dmoney Manager.
# This file is picked up automatically by the Flutter Gradle plugin
# (android/app/proguard-rules.pro).

# google_mlkit_text_recognition (receipt OCR) only bundles the Latin text
# model, but its TextRecognizer references the other script recognizers
# reflectively. Those classes are absent at build time, which trips R8's
# missing-class check in release builds. They are never called when only
# the Latin recognizer is used, so silence the warnings.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ML Kit loads its recognizer implementation and bundled model via
# reflection (firebase-components). R8 full mode strips/renames those
# classes in release builds, and the recognizer then crashes at runtime
# with "NullPointerException: getClass() on a null object reference"
# (debug builds are unaffected — minification is off). Keep them.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text.** { *; }
