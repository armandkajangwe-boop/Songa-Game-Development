# Android and iOS

The project uses Godot's compatibility renderer and touch input, and requests portrait orientation. This keeps one GDScript codebase for desktop development and mobile export. **No APK, AAB, or signed iOS application has been built or validated yet.**

## Android

Use Godot 4.6.3 with its matching export templates. Follow [Godot's Android export guide](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html) to install the supported JDK and Android SDK, then configure their paths in Editor Settings.

1. Open **Project → Export → Add → Android**.
2. Choose the final application identifier with the owner. Do not publish with an example identifier.
3. Export a debug APK and test it on an Android phone.
4. For Google Play, configure the owner's release keystore and produce a signed AAB.

Never commit signing keys, keystore passwords, or `export_credentials.cfg`. The `.gitignore` excludes usual key files and Godot's local export credentials.

## iOS

Use a **Mac with Xcode**, matching Godot export templates, and an Apple Developer account for distribution. Follow [Godot's iOS export guide](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html).

Add an iOS export preset, select the owner's bundle identifier and signing team, export the Xcode project, and build/install on an iPhone. TestFlight and App Store submission happen through the owner's Apple account. The Linux cloud workspace cannot validate the Xcode build or iPhone signing.

## Before release

Test physical devices for swipe recognition, input latency, frame pacing, battery use, interrupted audio, background/resume behavior, and persistent scores. Check tall and notched displays: the prototype preserves a 9:16 aspect ratio and may letterbox; edge-to-edge safe-area layout is a later pass. Review size, screenshots, icons, privacy disclosures, content rating, accessibility, and final logo and character assets before distribution.
