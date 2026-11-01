# Building 3 APES

**Requirements:** Flutter 3.47.7, Go 1.27+, Python 3.12, Android SDK with NDK 30.0.16248370 (Android), Xcode (iOS).

**1. Build the Xray core.** Clone libXray next to this folder and check out the pinned commit:

```
git clone https://github.com/XTLS/libXray ../libXray
git -C ../libXray checkout 4e1f7843e6cddb750ac7abc23ef36800820a8098
```

This commit uses Xray-core `701af60772cd`. Build it for your platform as described in the libXray README (for Android: `python3 ../libXray/build/main.py android`).

**2. Prepare the app:**

```
flutter pub get
flutter gen-l10n
dart run ffigen
```

**3. Build:** `flutter build apk --release` (Android) or `flutter build ipa` (iOS). Release signing keys are not included; use your own.
