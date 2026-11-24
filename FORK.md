# Fork of Alice 2.0.0 for FlutterFlow projects

This is a copy of [alice 2.0.0](https://pub.dev/packages/alice) (Apache
License 2.0, see `LICENSE`; original source https://github.com/jhomlala/alice)
with the changes listed below. Everything else is upstream 2.0.0.

## 1. Dependency ranges (2.0.0+pbb.1)

The dependency ranges in `pubspec.yaml` are widened so Alice resolves next to
the versions FlutterFlow pins, which a FlutterFlow project cannot override.

| Dependency | alice 2.0.0 | This fork |
|---|---|---|
| rxdart | ^0.28.0 | >=0.27.7 <0.29.0 |
| xml | ^7.0.0 | >=6.5.0 <8.0.0 |
| equatable | ^3.0.0 | >=2.0.5 <4.0.0 |
| share_plus | ^13.3.0 | >=12.0.0 <14.0.0 |
| open_file | ^4.0.0 | >=3.5.10 <5.0.0 |
| permission_handler | ^13.0.2 | >=12.0.1 <14.0.0 |
| package_info_plus | ^10.2.1 | >=9.0.0 <11.0.0 |
| sensors_plus | ^7.1.0 | >=6.1.0 <8.0.0 |

`publish_to: none`.
Checked on Flutter 3.50.1 (iOS simulator build) with rxdart 0.27.7, xml 6.6.1,
equatable 2.1.0, share_plus 12.0.2, open_file 3.5.10, permission_handler
12.0.3, package_info_plus 9.0.1, sensors_plus 6.1.2/7.1.1.

## 2. Overlay bubble and shake options (2.0.0+pbb.2)

New `AliceConfiguration` options. Their defaults keep upstream behaviour.

| Option | Default | Effect |
|---|---|---|
| `snapOverlayBubbleToEdge` | `false` | On release, the bubble glides to the nearest screen edge (left, right, top or bottom, 8 px inside the safe area) and stays on that edge when the screen or bubble size changes. |
| `shakeAction` | `AliceShakeAction.openInspector` | `toggleOverlayBubble` makes a shake show or hide the bubble instead of opening the inspector. |
| `shakeThresholdGravity` | `4` | Acceleration (g) a shake must exceed; upstream hard-coded 4. Android only since 2.0.0+pbb.3 (iOS uses the native gesture, below), and the iOS fallback. |

Also:

- `hideOverlayBubble()` now keeps the bubble hidden when new calls arrive
  (upstream re-showed it on the next call) until `showOverlayBubble()`.
- New `Alice.toggleOverlayBubble()` and `AliceCore.toggleOverlayBubble()` /
  `AliceCore.handleShake()`.

Changed files: `lib/alice.dart`, `lib/src/model/alice_configuration.dart`,
`lib/src/model/alice_shake_action.dart` (new), `lib/src/core/alice.dart`,
`lib/src/core/alice_core.dart`, `lib/src/services/overlay/alice_overlay_service.dart`,
`lib/src/ui/overlay/alice_overlay_bubble.dart`; tests
`test/core/alice_core_shake_test.dart` and
`test/ui/overlay/alice_overlay_bubble_snap_test.dart` (new). All 138 tests
pass on Flutter 3.50.1 (run outside the upstream pub workspace, so drop the
`resolution: workspace` line from `pubspec.yaml` first).

## 3. Native iOS shake gesture (2.0.0+pbb.3)

On iOS, shakes now come from iOS itself (`UIEvent` `motionShake`) instead of
the accelerometer, so the Simulator's Device > Shake works too and one
physical shake never fires twice. Android keeps the accelerometer.

- The package is now also a Flutter plugin for iOS only (`flutter.plugin.platforms.ios.pluginClass: AlicePlugin`;
  CocoaPods `ios/alice.podspec` and Swift Package Manager `ios/alice/Package.swift`).
- `AlicePlugin.swift` adds a `motionEnded(_:with:)` override to `UIWindow`
  that posts a notification and then calls the previous implementation with
  the same selector (so the event still travels up the responder chain), and
  sends each shake on the `alice/shake` event channel. `alice/shake_control`
  answers `isAvailable`.
- Dart: `AliceNativeShakeListener` (`lib/src/services/shake_detector/native_shake_listener.dart`);
  `AliceCore` uses it on iOS and falls back to the accelerometer when the iOS
  part is missing (web, or the plugin not linked).
- Test: `test/services/native_shake_listener_test.dart` (141 tests pass).
  Checked on the iOS Simulator with
  `xcrun simctl spawn <udid> notifyutil -p com.apple.UIKit.SimulatorShake`.

## 4. Bubble keeps its spot; no double bubble (2.0.0+pbb.4)

- `AliceOverlayService` remembers where the user last released the bubble
  (position and snapped edge) and passes it to the re-created bubble, so it
  comes back to the same spot after it is hidden and shown, or after the
  inspector closes (upstream always restarted at the top-right default).
- Fix: a new overlay entry is not `mounted` until the next frame, so upstream
  inserted a second bubble when two calls were recorded in the same frame
  (stacked bubbles; hide removed only one). `ensureInserted` now treats an
  entry inserted this frame as present.
- Tests: bubble placement (`alice_core_shake_test.dart`,
  `alice_overlay_bubble_snap_test.dart`) and one-bubble-per-frame; 144 pass.

## 5. iOS hook only while Alice listens (2.0.0+pbb.5)

`UIWindow`'s `motionEnded(_:with:)` override is now installed when Dart
starts listening on `alice/shake` (only an active Alice does), not when the
plugin registers. Builds that never create Alice, such as production builds,
leave UIWindow unchanged.

## Using it

Use it as a git dependency pinned to a commit:

```yaml
alice:
  git:
    url: <this repository>
    ref: <commit sha>
```

`alice_http` cannot be combined with a git-sourced Alice (it depends on Alice
from pub.dev), so copy its `AliceHttpAdapter` (Apache 2.0) into the app.
