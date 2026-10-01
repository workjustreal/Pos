# Suppress R8 warnings for androidx.window classes that exist only on newer
# Android versions. Sunmi T2/T2s run Android 7.1 where these code paths are
# never reached at runtime — the calling code is wrapped in version checks.
-dontwarn androidx.window.extensions.**
-dontwarn androidx.window.sidecar.**

# Keep plugin classes that may be reached via reflection (Bluetooth printer,
# barcode listener, payment SDK, etc.). Conservative — covers all current
# native plugins this project uses.
-keep class com.kacee.pos.kacee_pos.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class br.gov.caixa.** { *; }
-keep class com.example.print_bluetooth_thermal.** { *; }

# Keep classes annotated with @Keep
-keep @androidx.annotation.Keep class * { *; }
-keepclasseswithmembers class * {
    @androidx.annotation.Keep <methods>;
}
-keepclasseswithmembers class * {
    @androidx.annotation.Keep <fields>;
}
