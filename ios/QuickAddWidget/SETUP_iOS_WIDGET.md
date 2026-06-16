# iOS home-screen widget — one-time Xcode setup

Everything else (all Dart code, Android widget, both-platform notifications) works with no manual
step. iOS WidgetKit extensions *must* be created as a target inside Xcode — this can't be scripted
safely — so do this once:

## 1. Add the Widget Extension target
1. `open ios/Runner.xcworkspace`
2. **File ▸ New ▸ Target… ▸ Widget Extension**.
3. Product Name: **QuickAddWidget**. Uncheck "Include Configuration Intent". Finish.
   When prompted to activate the scheme, click **Activate**.
4. Xcode generates a `QuickAddWidget` group with a sample `QuickAddWidget.swift` and `Info.plist`.
   **Delete** Xcode's generated `QuickAddWidget.swift`, then **drag in** the provided
   `ios/QuickAddWidget/QuickAddWidget.swift` (check "Copy items if needed", target =
   QuickAddWidget). You can keep Xcode's generated `Info.plist` or replace it with the provided one.

## 2. Add the App Group to BOTH targets
The widget reads the balance the Flutter app writes, so they must share an App Group.

For **Runner** and again for **QuickAddWidget**:
- Select the target ▸ **Signing & Capabilities ▸ + Capability ▸ App Groups**.
- Add group: **`group.com.example.finlytic`**
  (must match `WidgetService.appGroupId` in `lib/services/widget_service.dart`).

## 3. Deployment target
Set the **QuickAddWidget** target's *Minimum Deployments* to iOS 14.0 or higher (WidgetKit).

## 4. Run
`flutter run` (or build from Xcode). Long-press the home screen ▸ **+** ▸ search "finlytic" ▸ add
the widget. Tapping Income / Expense / Transfer opens the app on the matching tab via the
`finlytic://add?type=…` deep link (already registered in `ios/Runner/Info.plist`).

## Notes
- The `finlytic://` URL scheme is registered in `ios/Runner/Info.plist` (CFBundleURLTypes).
- `home_widget` writes data into the App Group's `UserDefaults`; the Swift `Provider` reads the
  `balance` key from the same suite.
- If the bundle id is not `com.example.finlytic`, update `appGroupId` in both the Swift file and
  `WidgetService`, and the App Group name, to stay consistent.
