import 'dart:convert';

class InvoiceLineItem {
  const InvoiceLineItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
  });

  final String description;
  final double quantity;
  final double unitPrice;

  double get amount => quantity * unitPrice;

  Map<String, dynamic> toJson() => {
        'description': description,
        'quantity': quantity,
        'unitPrice': unitPrice,
      };

  factory InvoiceLineItem.fromJson(Map<String, dynamic> json) {
    return InvoiceLineItem(
      description: json['description'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
    );
  }
}

List<InvoiceLineItem> parseLineItems(String jsonStr) {
  try {
    final list = jsonDecode(jsonStr) as List<dynamic>;
    return list
        .map((e) => InvoiceLineItem.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
}

String encodeLineItems(List<InvoiceLineItem> items) {
  return jsonEncode(items.map((e) => e.toJson()).toList());
}

List<String> parseStringList(String jsonStr) {
  try {
    final list = jsonDecode(jsonStr) as List<dynamic>;
    return list.map((e) => e.toString()).toList();
  } catch (_) {
    return [];
  }
}

String encodeStringList(List<String> items) {
  return jsonEncode(items);
}
