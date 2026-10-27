# Ask ELVIS — Flutter Prototype

A cross-platform (Android / iOS) Flutter prototype of **Ask ELVIS**, the donkey identification app developed at the University of Southampton with the Isle of Wight Donkey Sanctuary. The native iOS version with full name identification is in [Ask-Elvis](https://github.com/YCL-Jeff/Ask-Elvis).

This repository is a fork of the [Ultralytics YOLO Flutter plugin](https://github.com/ultralytics/yolo-flutter-app). The plugin code (`lib/`, `android/`, `ios/`, …) is unchanged; the Ask ELVIS work is in the example app. The original plugin documentation is kept in [README.ultralytics.md](README.ultralytics.md) and [`doc/`](doc/).

## Status

| Feature | State |
|---|---|
| Live camera detection with YOLO11n | ✅ Working (Ultralytics detection model, downloaded on first launch) |
| "Ask Elvis" camera screen with donkey-detected state and animated *Identification* button | ✅ Working |
| Highest-confidence detection shown with a link to its page on the sanctuary website (in-app WebView) | ✅ Working |
| Identifying individual donkeys by name | ❌ Not implemented — the *Identification* button is a placeholder (`TODO` in the code) |

Because the bundled model is a general detector, it reports class names such as `horse`, not individual donkey names. Name identification would need the re-identification stage used in the iOS app.

## Ask ELVIS changes

| File | Change |
|---|---|
| `example/lib/presentation/screens/camera_inference_screen.dart` | Ask ELVIS title, donkey/horse detection state, top-detection display, *Identification* button, links to the sanctuary website |
| `example/lib/presentation/screens/webview_screen.dart` | In-app WebView used to open sanctuary pages |

## Run the example

Requirements: Flutter SDK, Android Studio or Xcode, and a physical device (the camera does not work in emulators/simulators).

```bash
git clone https://github.com/YCL-Jeff/Ask-Elvis_Flutter.git
cd Ask-Elvis_Flutter/example
flutter pub get
flutter run
```

On first launch the app downloads the `yolo11n` detection model from the Ultralytics release assets, so the device needs internet access once.

## Licence

[AGPL-3.0](LICENSE), inherited from the Ultralytics YOLO Flutter plugin.

## Author

Ask ELVIS changes by Yu-Cheng Lai ([YCL-Jeff](https://github.com/YCL-Jeff)). Plugin by [Ultralytics](https://github.com/ultralytics/yolo-flutter-app).
