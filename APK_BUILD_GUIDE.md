# Bluelist IPTV — App Icon, Splash Screen & APK Build Guide

## Prerequisites
Make sure you have the updated `pubspec.yaml` (includes `flutter_launcher_icons` and `flutter_native_splash` in dev_dependencies, plus the logo in `assets/images/bluelist_logo.png`).

---

## Step 1: Install Dependencies

```bash
cd bluelist_iptv
flutter pub get
```

---

## Step 2: Generate App Icon

```bash
dart run flutter_launcher_icons
```

This replaces the default Flutter icon with your blue Bluelist IPTV logo on all Android densities.

---

## Step 3: Generate Native Splash Screen

```bash
dart run flutter_native_splash:create
```

This creates a native Android splash screen (shown instantly on cold start) with the blue background and your logo.

---

## Step 4: Create a Release Keystore

You only do this ONCE. Open a terminal and run:

```bash
keytool -genkey -v -keystore ~/bluelist-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias bluelist
```

It will ask for:
- A password (save this!)
- Your name, organization, city, state, country
- The keystore will be saved to `~/bluelist-keystore.jks`

---

## Step 5: Add Keystore to Android Build

Open `android/key.properties` (create it if it doesn't exist) and add:

```properties
storePassword=YOUR_PASSWORD
keyPassword=YOUR_PASSWORD
keyAlias=bluelist
storeFile=C:/Users/YOUR_USERNAME/bluelist-keystore.jks
```

> Replace YOUR_PASSWORD with the password you chose in Step 4.
> Replace YOUR_USERNAME with your Windows username.
> Use forward slashes `/` in the path, not backslashes.

---

## Step 6: Configure android/app/build.gradle for Signing

Open `android/app/build.gradle` and add BEFORE the `android {` block:

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
```

Then INSIDE the `android { ... }` block, add:

```gradle
signingConfigs {
    release {
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
        storeFile file(keystoreProperties['storeFile'])
        storePassword keystoreProperties['storePassword']
    }
}
buildTypes {
    release {
        signingConfig signingConfigs.release
        minifyEnabled true
        shrinkResources true
        proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
    }
}
```

---

## Step 7: Build the Release APK

```bash
flutter build apk --release
```

Your signed APK will be at:

```
build/app/outputs/flutter-apk/app-release.apk
```

Copy this file to your phone and install it. Done!

---

## Step 8 (Optional): Build an App Bundle for Play Store

```bash
flutter build appbundle --release
```

This produces an `.aab` file at `build/app/outputs/bundle/release/app-release.aab` for Google Play Store upload.

---

## Quick Reference Commands

| What | Command |
|------|---------|
| Install deps | `flutter pub get` |
| Generate icon | `dart run flutter_launcher_icons` |
| Generate splash | `dart run flutter_native_splash:create` |
| Build APK | `flutter build apk --release` |
| Build App Bundle | `flutter build appbundle --release` |
