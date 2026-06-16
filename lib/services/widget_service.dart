import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// Bridges the native home-screen "quick add" widget with the Flutter app.
///
/// The widget shows Income / Expense / Transfer buttons. Each button launches
/// the app with a `finlytic://add?type=<type>` URI; [tabForUri] maps that to
/// the matching tab index of `AddTransactionScreen`.
class WidgetService {
  WidgetService._();

  /// Shared between the iOS app and its WidgetKit extension. Must match the
  /// App Group configured in Xcode.
  static const appGroupId = 'group.com.example.finlytic';

  /// Maps the three quick-add types to the tab order used by
  /// `AddTransactionScreen` (Income, Expense, Transfer, Debt).
  static const Map<String, int> _typeToTab = {
    'income': 0,
    'expense': 1,
    'transfer': 2,
  };

  static Future<void> init() async {
    if (kIsWeb) return;
    await HomeWidget.setAppGroupId(appGroupId);
  }

  /// Returns the tab index for a launch [uri], or null if it isn't a quick-add
  /// deep link.
  static int? tabForUri(Uri? uri) {
    if (uri == null) return null;
    if (uri.scheme != 'finlytic' || uri.host != 'add') return null;
    return _typeToTab[uri.queryParameters['type']];
  }

  /// Pushes the latest total balance to the native widget so it can display it.
  static Future<void> updateBalance(double total) async {
    if (kIsWeb) return;
    try {
      await HomeWidget.saveWidgetData<String>(
        'balance',
        total.toStringAsFixed(2),
      );
      await HomeWidget.updateWidget(
        androidName: 'QuickAddWidgetProvider',
        iOSName: 'QuickAddWidget',
      );
    } catch (_) {
      // Widget not added / platform unsupported — safe to ignore.
    }
  }
}
