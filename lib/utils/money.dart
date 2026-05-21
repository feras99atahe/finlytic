import 'package:intl/intl.dart';

class Money {
  static final _fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  static final _compact = NumberFormat.compactCurrency(symbol: '\$');

  static String format(double v) => _fmt.format(v);
  static String compact(double v) => _compact.format(v);
  static String signed(double v) =>
      v >= 0 ? '+${format(v)}' : format(v);
}
