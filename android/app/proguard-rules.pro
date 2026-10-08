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
