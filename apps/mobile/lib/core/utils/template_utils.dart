import '../../data/database/database.dart';
import '../../data/database/user_scoped_queries.dart';

/// Placeholders supported in message templates (case-insensitive).
const kTemplateVariableHints = [
  '{{clientName}}',
  '{{businessName}}',
  '{{invoiceNumber}}',
  '{{amount}}',
  '{{projectName}}',
  '{{dueDate}}',
];

/// Fills `{{placeholders}}` in message templates. Matching is case-insensitive
/// and accepts common aliases (`{{clientname}}`, `{{client_name}}`, etc.).
String fillTemplate(
  String template, {
  String clientName = '',
  String businessName = '',
  String invoiceNumber = '',
  String amount = '',
  String projectName = '',
  String dueDate = '',
}) {
  final values = <String, String>{
    'clientName': clientName,
    'businessName': businessName,
    'invoiceNumber': invoiceNumber,
    'amount': amount,
    'projectName': projectName,
    'dueDate': dueDate,
  };

  var result = template;
  for (final entry in values.entries) {
    result = _replacePlaceholder(result, entry.key, entry.value);
  }
  return result;
}

String _replacePlaceholder(String text, String key, String value) {
  final aliases = <String>[key, ..._aliasesFor(key)];
  for (final alias in aliases) {
    text = text.replaceAllMapped(
      RegExp(r'\{\{\s*' + RegExp.escape(alias) + r'\s*\}\}', caseSensitive: false),
      (_) => value,
    );
  }
  return text;
}

List<String> _aliasesFor(String key) {
  switch (key) {
    case 'clientName':
      return const ['clientname', 'client_name', 'customerName', 'customername'];
    case 'businessName':
      return const ['businessname', 'business_name', 'companyName', 'companyname'];
    case 'invoiceNumber':
      return const ['invoicenumber', 'invoice_number', 'invoiceNo', 'invoiceno'];
    case 'amount':
      return const ['total', 'invoiceAmount', 'invoiceamount'];
    case 'projectName':
      return const ['projectname', 'project_name'];
    case 'dueDate':
      return const ['duedate', 'due_date'];
    default:
      return const [];
  }
}

Future<String> fillTemplateForInvoice(
  AppDatabase db,
  int ownerUserId,
  String template,
  Invoice invoice,
) async {
  final customer = await db.getCustomerForUser(ownerUserId, invoice.customerId);
  final profile = await db.watchBusinessProfileForUser(ownerUserId).first;
  final due = invoice.dueDate != null ? invoice.dueDate!.toLocal().toString().split(' ').first : '';
  return fillTemplate(
    template,
    clientName: customer?.contactPerson ?? customer?.company ?? 'Client',
    businessName: profile.businessName.isNotEmpty ? profile.businessName : profile.ownerName,
    invoiceNumber: invoice.invoiceNumber,
    amount: '${invoice.currency} ${invoice.total.toStringAsFixed(2)}',
    dueDate: due,
  );
}

Future<String> fillTemplateForProject(
  AppDatabase db,
  int ownerUserId,
  String template,
  Project project,
) async {
  final customer = await db.getCustomerForUser(ownerUserId, project.customerId);
  final profile = await db.watchBusinessProfileForUser(ownerUserId).first;
  return fillTemplate(
    template,
    clientName: customer?.contactPerson ?? customer?.company ?? 'Client',
    businessName: profile.businessName.isNotEmpty ? profile.businessName : profile.ownerName,
    projectName: project.name,
    amount: project.budget > 0 ? '${project.currency} ${project.budget.toStringAsFixed(2)}' : '',
  );
}

/// Loads the best matching saved template for a category, or returns [fallback].
Future<({String subject, String body})> resolveMessageTemplate(
  AppDatabase db,
  int ownerUserId, {
  String category = 'invoice',
  String nameHint = 'payment',
  required String fallbackSubject,
  required String fallbackBody,
}) async {
  final templates = await db.watchMessageTemplatesForUser(ownerUserId, category: category).first;
  MessageTemplate? match;
  for (final t in templates) {
    if (t.name.toLowerCase().contains(nameHint.toLowerCase())) {
      match = t;
      break;
    }
  }
  match ??= templates.isNotEmpty ? templates.first : null;
  if (match == null) {
    return (subject: fallbackSubject, body: fallbackBody);
  }
  return (subject: match.subject, body: match.body);
}
