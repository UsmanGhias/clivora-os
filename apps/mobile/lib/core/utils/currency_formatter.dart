import 'package:intl/intl.dart';

String formatCurrency(double amount, {String symbol = '\$'}) {
  final formatter = NumberFormat.currency(symbol: symbol, decimalDigits: 0);
  return formatter.format(amount);
}

String currencySymbol(String code) {
  switch (code.toUpperCase()) {
    case 'USD':
      return '\$';
    case 'EUR':
      return '€';
    case 'GBP':
      return '£';
    case 'PKR':
    case 'RS':
      return 'Rs ';
    default:
      return '$code ';
  }
}
