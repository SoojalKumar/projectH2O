import 'package:intl/intl.dart';

final _money = NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 2);
final _gallons = NumberFormat.decimalPattern('en_US');

String formatMoney(num value) => _money.format(value);

String formatGallons(num value) => '${_gallons.format(value.round())} gal';

String formatPercent(num value) {
  final sign = value > 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(1)}%';
}
